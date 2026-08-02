// LKMCPBridgeServer.swift
//
// The MCPBridge server is the GPL-side surface that exposes LookInside's
// inspection state over a local Unix domain socket. Proprietary consumers
// (currently only the `lookinside-mcp` MCP shim, but the surface is designed
// to also serve future CI bridges, remote inspectors, and automation runners)
// connect to this socket and exchange newline-delimited JSON frames.
//
// Process model: the server runs inside the LookInside.app host process.
// Activation is keyed off `applicationDidFinishLaunching:` and shutdown is
// keyed off `applicationWillTerminate:`. The server is intentionally a
// process-global singleton (the host has exactly one inspection state).
//
// Socket location: a single per-user UNIX socket inside the user's
// Application Support directory, with `0o600` permissions and a `0o700`
// parent directory. The path is stable across host restarts.

import Darwin
import Dispatch
import Foundation
import os

@objc(LKMCPBridgeServer)
public final class LKMCPBridgeServer: NSObject {

    // MARK: - Singleton

    @objc public static let sharedInstance = LKMCPBridgeServer()

    // MARK: - Configuration

    /// Maximum number of pending connections in the kernel accept queue.
    private static let listenBacklog: Int32 = 16

    private static let logger = Logger(subsystem: "com.lookinside.app", category: "MCPBridge.Server")

    // MARK: - State

    private let stateQueue = DispatchQueue(label: "com.lookinside.mcp-bridge.state")

    /// Shared parent for every connection's private serial queue. Kept
    /// concurrent so separate connections make progress independently;
    /// each `LKMCPBridgeConnection` targets its own serial queue at this
    /// one, which is what keeps a single connection's frames from
    /// interleaving. Do not hand this queue to a connection as its
    /// working queue directly.
    private let ioQueue = DispatchQueue(
        label: "com.lookinside.mcp-bridge.io",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private var listenFileDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var activeConnections: Set<ObjectIdentifier> = []
    private var openConnections: [ObjectIdentifier: LKMCPBridgeConnection] = [:]
    private var isRunning = false

    /// Routes inspection-method requests (`targets.list`, `hierarchy.read`,
    /// …) to the host's per-window inspection state. Lazily constructed on
    /// the main actor on first use because `NSDocumentController` access
    /// requires main-thread isolation.
    private var inspectionService: LKMCPBridgeInspectionService?

    /// Routes mutating / RPC-emitting methods (`invoke.method`). Kept
    /// separate from `inspectionService` so the inspection surface stays
    /// read-only even as new mutating verbs land; lazily constructed on
    /// the main actor on first use.
    private var invocationService: LKMCPBridgeInvocationService?

    /// Routes `attribute.modify` (RPC 204 InbuiltAttrModification).
    /// Kept distinct from `invocationService` so each route's setter
    /// lookup / value decoding code stays self-contained.
    private var modificationService: LKMCPBridgeModificationService?

    /// Routes `details.read` (batch RPC 203 HierarchyDetails prefetch).
    /// Kept distinct from the read-only inspection service because
    /// details.read actively pumps the Peertalk channel rather than
    /// reading cached state.
    private var detailsService: LKMCPBridgeDetailsService?

    /// Routes `screenshot.read` (RPC 203 with a Solo/Group task type).
    /// Separate from `detailsService` because the two ask the same RPC
    /// for entirely different payloads — attribute groups versus image
    /// bytes — and their error vocabularies differ accordingly.
    private var screenshotService: LKMCPBridgeScreenshotService?

    // MARK: - Lifecycle

    @objc public func start() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            guard self.isRunning == false else { return }
            do {
                try self.bindAndListen()
                self.isRunning = true
                Self.logger.notice("MCPBridge started at \(LKMCPBridgeServer.socketURL.path, privacy: .public)")
            } catch {
                Self.logger.error("MCPBridge failed to start: \(error.localizedDescription, privacy: .public)")
                self.cleanUpListenSocket()
            }
        }
    }

    @objc public func stop() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }
            self.isRunning = false
            self.acceptSource?.cancel()
            self.acceptSource = nil
            self.cleanUpListenSocket()
            for connection in self.openConnections.values {
                connection.close(reason: "server shutdown")
            }
            self.openConnections.removeAll()
            self.activeConnections.removeAll()
            Self.logger.notice("MCPBridge stopped")
        }
    }

    // MARK: - Bind / Listen / Accept

    private func bindAndListen() throws {
        let socketURL = Self.socketURL
        try ensureRuntimeDirectory(at: socketURL.deletingLastPathComponent())

        // Socket creation lives in LKMCPBridgeListenSocket so its
        // blocking mode — which `acceptPendingConnections()` depends on
        // for loop termination — can be asserted by a test that does not
        // need the whole inspection stack. See that file's header.
        let descriptor = try LKMCPBridgeListenSocket.makeListening(
            atPath: socketURL.path,
            backlog: Self.listenBacklog
        )
        listenFileDescriptor = descriptor

        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: stateQueue)
        source.setEventHandler { [weak self] in
            self?.acceptPendingConnections()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        acceptSource = source
        source.resume()
    }

    private func acceptPendingConnections() {
        while true {
            // Goes through LKMCPBridgeListenSocket because the accepted
            // descriptor has to be put back into blocking mode; see that
            // method's documentation.
            let clientDescriptor = LKMCPBridgeListenSocket.acceptConnection(
                listenDescriptor: listenFileDescriptor
            )
            if clientDescriptor < 0 {
                let errorNumber = errno
                if errorNumber == EAGAIN || errorNumber == EWOULDBLOCK {
                    return
                }
                Self.logger.error("accept() failed (errno \(errorNumber))")
                return
            }
            let connection = LKMCPBridgeConnection(
                fileDescriptor: clientDescriptor,
                queue: ioQueue,
                requestHandler: { [weak self] request in
                    return await self?.handle(request: request) ?? .failure(
                        identifier: request.identifier,
                        error: .internalError
                    )
                },
                onClose: { [weak self] closingConnection in
                    self?.removeConnection(closingConnection)
                }
            )
            let key = ObjectIdentifier(connection)
            openConnections[key] = connection
            activeConnections.insert(key)
            Self.logger.notice("Accepted connection (fd=\(clientDescriptor))")
            connection.start()
        }
    }

    private func removeConnection(_ connection: LKMCPBridgeConnection) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            let key = ObjectIdentifier(connection)
            self.openConnections.removeValue(forKey: key)
            self.activeConnections.remove(key)
        }
    }

    // MARK: - Request dispatch

    private func handle(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        // `ping` stays as a transport-level smoke test that doesn't require
        // the inspection state to be initialized; mutating verbs route to
        // the invocation service; everything else routes to the (read-only)
        // inspection service. The split keeps the read surface free of
        // any Peertalk-round-trip work so cached reads stay snappy.
        switch request.method {
        case "ping":
            return .success(
                identifier: request.identifier,
                result: .object([
                    "pong": .bool(true),
                    "serverVersion": .string(currentHostMarketingVersion()),
                ])
            )
        case "invoke.method":
            return await invocationDispatch(request: request)
        case "attribute.modify":
            return await modificationDispatch(request: request)
        case "details.read":
            return await detailsDispatch(request: request)
        case "screenshot.read":
            return await screenshotDispatch(request: request)
        default:
            return await inspectionDispatch(request: request)
        }
    }

    private func inspectionDispatch(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        let service = await MainActor.run { () -> LKMCPBridgeInspectionService in
            if let existing = self.inspectionService {
                return existing
            }
            let created = LKMCPBridgeInspectionService()
            self.inspectionService = created
            return created
        }
        return await service.handle(request: request)
    }

    private func invocationDispatch(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        let service = await MainActor.run { () -> LKMCPBridgeInvocationService in
            if let existing = self.invocationService {
                return existing
            }
            let created = LKMCPBridgeInvocationService()
            self.invocationService = created
            return created
        }
        return await service.handle(request: request)
    }

    private func modificationDispatch(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        let service = await MainActor.run { () -> LKMCPBridgeModificationService in
            if let existing = self.modificationService {
                return existing
            }
            let created = LKMCPBridgeModificationService()
            self.modificationService = created
            return created
        }
        return await service.handle(request: request)
    }

    private func detailsDispatch(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        let service = await MainActor.run { () -> LKMCPBridgeDetailsService in
            if let existing = self.detailsService {
                return existing
            }
            let created = LKMCPBridgeDetailsService()
            self.detailsService = created
            return created
        }
        return await service.handle(request: request)
    }

    private func screenshotDispatch(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        let service = await MainActor.run { () -> LKMCPBridgeScreenshotService in
            if let existing = self.screenshotService {
                return existing
            }
            let created = LKMCPBridgeScreenshotService()
            self.screenshotService = created
            return created
        }
        return await service.handle(request: request)
    }

    // MARK: - Helpers

    private func cleanUpListenSocket() {
        if listenFileDescriptor >= 0 {
            close(listenFileDescriptor)
            listenFileDescriptor = -1
        }
        unlink(Self.socketURL.path)
    }

    private func ensureRuntimeDirectory(at directoryURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // createDirectory ignores posixPermissions on pre-existing dirs;
        // re-apply 0o700 to lock down any inherited permissive state.
        _ = chmod(directoryURL.path, 0o700)
    }

    private func currentHostMarketingVersion() -> String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    // MARK: - Socket location

    /// Canonical socket location: `~/Library/Application Support/LookInside/Host/run/lookinside-host-mcp.sock`.
    public static let socketURL: URL = {
        let fileManager = FileManager.default
        let applicationSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupportURL
            .appendingPathComponent("LookInside", isDirectory: true)
            .appendingPathComponent("Host", isDirectory: true)
            .appendingPathComponent("run", isDirectory: true)
            .appendingPathComponent("lookinside-host-mcp.sock", isDirectory: false)
    }()
}
