import AppKit
import Darwin
import Foundation

private enum LKSwiftUISupportAuthServerConstants {
    static let supportedProtocolVersion = 1

    static let helperPathEnvironmentKey = "LOOKINSIDE_AUTH_SERVER_PATH"
    static let helperSocketPathEnvironmentKey = "LOOKINSIDE_AUTH_SERVER_SOCKET_PATH"

    static let helperLaunchTimeout: TimeInterval = 8
    static let helperShutdownTimeout: TimeInterval = 3
}

private struct LKSwiftUISupportAuthServerInstallation {
    let executableURL: URL
    let socketURL: URL
}

private struct LKSwiftUISupportEmptyPayload: Codable {}

private struct LKSwiftUISupportAuthServerRequestEnvelope<Payload: Encodable>: Encodable {
    let protocolVersion: Int
    let requestID: String
    let method: String
    let payload: Payload

    private enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case requestID = "request_id"
        case method
        case payload
    }
}

private struct LKSwiftUISupportAuthServerResponseEnvelope<Payload: Decodable>: Decodable {
    let protocolVersion: Int
    let requestID: String
    let ok: Bool
    let payload: Payload?
    let error: LKSwiftUISupportAuthServerErrorPayload?

    private enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case requestID = "request_id"
        case ok
        case payload
        case error
    }
}

private struct LKSwiftUISupportAuthServerErrorPayload: Decodable, Error {
    let code: String
    let message: String
}

private struct LKSwiftUISupportAuthServerHealthPayload: Decodable {
    let serverVersion: String
    let protocolVersion: Int
    let statusSummary: String

    private enum CodingKeys: String, CodingKey {
        case serverVersion = "server_version"
        case protocolVersion = "protocol_version"
        case statusSummary = "status_summary"
    }
}

private struct LKSwiftUISupportAuthServerAccessDecisionPayload: Decodable {
    enum Decision: String, Decodable {
        case allow
        case allowWithWarning = "allow_with_warning"
        case block
    }

    let decision: Decision
    let title: String
    let message: String
    let statusSummary: String?

    private enum CodingKeys: String, CodingKey {
        case decision
        case title
        case message
        case statusSummary = "status_summary"
    }
}

private enum LKSwiftUISupportAuthServerError: LocalizedError {
    case helperMissing(String)
    case incompatibleProtocol(expected: Int, found: Int)
    case socketPathInvalid(String)
    case launchFailed(String)
    case launchTimedOut(String)
    case rpcTransport(String)
    case rpcServer(code: String, message: String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case let .helperMissing(path):
            return "LookInside Auth Server is not installed.\nExpected executable:\n\(path)"
        case let .incompatibleProtocol(expected, found):
            return "LookInside Auth Server protocol is incompatible.\nApp expects v\(expected), helper provides v\(found)."
        case let .socketPathInvalid(path):
            return "LookInside Auth Server socket path is too long for a Unix domain socket.\n\(path)"
        case let .launchFailed(message):
            return "LookInside Auth Server could not be launched.\n\(message)"
        case let .launchTimedOut(path):
            return "LookInside Auth Server did not respond after launch.\nSocket path:\n\(path)"
        case let .rpcTransport(message):
            return "LookInside Auth Server connection failed.\n\(message)"
        case let .rpcServer(code, message):
            return "LookInside Auth Server returned \(code).\n\(message)"
        case let .invalidResponse(message):
            return "LookInside Auth Server returned an unreadable response.\n\(message)"
        }
    }
}

private final class LKSwiftUISupportAuthServerBridge {
    private let lock = NSLock()
    private var launchedProcess: Process?
    private var lastPresentedErrorDescription: String?

    func preloadRuntime() {
        guard LKSwiftUISupportInstallerLayout.isInstalled else {
            return
        }
        do {
            let installation = try resolveInstallation()
            _ = try ensureServerAvailable(using: installation)
        } catch {
            NSLog("LookInside Auth Server preload failed: %@", error.localizedDescription)
        }
    }

    func shutdownRuntime() {
        let process = lock.withLock {
            launchedProcess
        }

        guard let installation = try? resolveInstallation() else {
            return
        }

        if process != nil {
            do {
                _ = try sendRequest(
                    method: "server.shutdown",
                    payload: LKSwiftUISupportEmptyPayload(),
                    installation: installation,
                    responseType: LKSwiftUISupportEmptyPayload.self
                )
            } catch {
                NSLog("LookInside Auth Server shutdown request failed: %@", error.localizedDescription)
            }
        }

        unlink(installation.socketURL.path + ".lock")
        unlink(installation.socketURL.path)

        let deadline = Date().addingTimeInterval(LKSwiftUISupportAuthServerConstants.helperShutdownTimeout)
        while Date() < deadline {
            let isRunning = lock.withLock {
                launchedProcess?.isRunning == true
            }
            if isRunning == false {
                break
            }
            usleep(50_000)
        }

        lock.withLock {
            if let launchedProcess, launchedProcess.isRunning {
                launchedProcess.terminate()
            }
            self.launchedProcess = nil
        }
    }

    func showActivationWindow(from window: NSWindow?) {
        performVoidRequest(method: "ui.show_activation", from: window)
    }

    func showLicenseWindow(from window: NSWindow?) {
        performVoidRequest(method: "ui.show_license", from: window)
    }

    func refreshLicenseStatus(from window: NSWindow?) {
        do {
            let installation = try ensureInstalledAndRunning(window: window)
            let response = try sendRequest(
                method: "license.refresh_status",
                payload: LKSwiftUISupportEmptyPayload(),
                installation: installation,
                responseType: LKSwiftUISupportAuthServerAccessDecisionPayload.self
            )

            guard let payload = response.payload else {
                throw LKSwiftUISupportAuthServerError.invalidResponse("Missing access decision payload.")
            }

            presentAccessAlert(title: payload.title, detail: payload.message, window: window)
        } catch {
            presentRuntimeAlert(title: "LookInside Auth Server Required", detail: error.localizedDescription, window: window)
        }
    }

    func allowProtectedFeatureAccess(for window: NSWindow?) -> Bool {
        do {
            let installation = try ensureInstalledAndRunning(window: window)
            let response = try sendRequest(
                method: "license.check_access",
                payload: LKSwiftUISupportEmptyPayload(),
                installation: installation,
                responseType: LKSwiftUISupportAuthServerAccessDecisionPayload.self
            )

            guard let payload = response.payload else {
                throw LKSwiftUISupportAuthServerError.invalidResponse("Missing access decision payload.")
            }

            switch payload.decision {
            case .allow:
                return true
            case .allowWithWarning:
                presentAccessAlert(title: payload.title, detail: payload.message, window: window)
                return true
            case .block:
                presentAccessAlert(title: payload.title, detail: payload.message, window: window)
                return false
            }
        } catch {
            presentRuntimeAlert(title: "LookInside Auth Server Required", detail: error.localizedDescription, window: window)
            return false
        }
    }

    private func performVoidRequest(method: String, from window: NSWindow?) {
        do {
            let installation = try ensureInstalledAndRunning(window: window)
            _ = try sendRequest(
                method: method,
                payload: LKSwiftUISupportEmptyPayload(),
                installation: installation,
                responseType: LKSwiftUISupportEmptyPayload.self
            )
        } catch {
            presentRuntimeAlert(title: "LookInside Auth Server Required", detail: error.localizedDescription, window: window)
        }
    }

    private func ensureInstalledAndRunning(window: NSWindow?) throws -> LKSwiftUISupportAuthServerInstallation {
        try LKSwiftUISupportInstaller.shared.ensureInstalled(presentingWindow: window)
        let installation = try resolveInstallation()
        return try ensureServerAvailable(using: installation)
    }

    private func ensureServerAvailable(
        using installation: LKSwiftUISupportAuthServerInstallation
    ) throws -> LKSwiftUISupportAuthServerInstallation {
        do {
            let response = try sendRequest(
                method: "health.ping",
                payload: LKSwiftUISupportEmptyPayload(),
                installation: installation,
                responseType: LKSwiftUISupportAuthServerHealthPayload.self
            )
            guard let payload = response.payload else {
                throw LKSwiftUISupportAuthServerError.invalidResponse("Missing health payload.")
            }
            guard payload.protocolVersion == LKSwiftUISupportAuthServerConstants.supportedProtocolVersion else {
                throw LKSwiftUISupportAuthServerError.incompatibleProtocol(
                    expected: LKSwiftUISupportAuthServerConstants.supportedProtocolVersion,
                    found: payload.protocolVersion
                )
            }
            return installation
        } catch {
            try launchHelperIfNeeded(for: installation)
            return try waitForHealthyServer(using: installation)
        }
    }

    private func waitForHealthyServer(
        using installation: LKSwiftUISupportAuthServerInstallation
    ) throws -> LKSwiftUISupportAuthServerInstallation {
        let deadline = Date().addingTimeInterval(LKSwiftUISupportAuthServerConstants.helperLaunchTimeout)
        var lastError: Error?

        while Date() < deadline {
            do {
                let response = try sendRequest(
                    method: "health.ping",
                    payload: LKSwiftUISupportEmptyPayload(),
                    installation: installation,
                    responseType: LKSwiftUISupportAuthServerHealthPayload.self
                )
                guard let payload = response.payload else {
                    throw LKSwiftUISupportAuthServerError.invalidResponse("Missing health payload.")
                }
                guard payload.protocolVersion == LKSwiftUISupportAuthServerConstants.supportedProtocolVersion else {
                    throw LKSwiftUISupportAuthServerError.incompatibleProtocol(
                        expected: LKSwiftUISupportAuthServerConstants.supportedProtocolVersion,
                        found: payload.protocolVersion
                    )
                }
                return installation
            } catch {
                lastError = error
                usleep(100_000)
            }
        }

        if let lastError {
            NSLog("LookInside Auth Server launch health check failed: %@", lastError.localizedDescription)
        }
        throw LKSwiftUISupportAuthServerError.launchTimedOut(installation.socketURL.path)
    }

    private func resolveInstallation() throws -> LKSwiftUISupportAuthServerInstallation {
        let environment = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        let executableURL: URL
        if let explicitPath = environment[LKSwiftUISupportAuthServerConstants.helperPathEnvironmentKey],
           explicitPath.isEmpty == false {
            executableURL = URL(fileURLWithPath: explicitPath)
        } else {
            executableURL = LKSwiftUISupportInstallerLayout.installedExecutableURL
        }

        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw LKSwiftUISupportAuthServerError.helperMissing(executableURL.path)
        }

        let socketURL: URL
        if let explicitPath = environment[LKSwiftUISupportAuthServerConstants.helperSocketPathEnvironmentKey],
           explicitPath.isEmpty == false {
            socketURL = URL(fileURLWithPath: explicitPath)
        } else {
            socketURL = LKSwiftUISupportInstallerLayout.installedSocketURL
        }

        return LKSwiftUISupportAuthServerInstallation(
            executableURL: executableURL,
            socketURL: socketURL
        )
    }

    private func launchHelperIfNeeded(for installation: LKSwiftUISupportAuthServerInstallation) throws {
        let shouldLaunch = lock.withLock {
            if let launchedProcess, launchedProcess.isRunning {
                return false
            }

            let process = Process()
            process.executableURL = installation.executableURL
            process.arguments = ["--socket-path", installation.socketURL.path]

            var environment = ProcessInfo.processInfo.environment
            environment[LKSwiftUISupportAuthServerConstants.helperSocketPathEnvironmentKey] = installation.socketURL.path
            process.environment = environment
            process.terminationHandler = { [weak self] _ in
                self?.lock.withLock {
                    self?.launchedProcess = nil
                }
            }
            self.launchedProcess = process
            return true
        }

        guard shouldLaunch else {
            return
        }

        do {
            let process = lock.withLock { launchedProcess }
            try process?.run()
        } catch {
            lock.withLock {
                self.launchedProcess = nil
            }
            throw LKSwiftUISupportAuthServerError.launchFailed(error.localizedDescription)
        }
    }

    private func sendRequest<RequestPayload: Encodable, ResponsePayload: Decodable>(
        method: String,
        payload: RequestPayload,
        installation: LKSwiftUISupportAuthServerInstallation,
        responseType _: ResponsePayload.Type
    ) throws -> LKSwiftUISupportAuthServerResponseEnvelope<ResponsePayload> {
        let request = LKSwiftUISupportAuthServerRequestEnvelope(
            protocolVersion: LKSwiftUISupportAuthServerConstants.supportedProtocolVersion,
            requestID: UUID().uuidString.lowercased(),
            method: method,
            payload: payload
        )
        let requestData = try Self.jsonEncoder.encode(request)
        let responseData = try Self.sendSocketRequest(
            requestData,
            to: installation.socketURL.path
        )

        let response = try Self.jsonDecoder.decode(
            LKSwiftUISupportAuthServerResponseEnvelope<ResponsePayload>.self,
            from: responseData
        )

        guard response.protocolVersion == LKSwiftUISupportAuthServerConstants.supportedProtocolVersion else {
            throw LKSwiftUISupportAuthServerError.incompatibleProtocol(
                expected: LKSwiftUISupportAuthServerConstants.supportedProtocolVersion,
                found: response.protocolVersion
            )
        }

        if response.ok == false {
            let payload = response.error ?? .init(code: "unknown_error", message: "The helper did not provide an error payload.")
            throw LKSwiftUISupportAuthServerError.rpcServer(code: payload.code, message: payload.message)
        }

        return response
    }

    private func presentRuntimeAlert(title: String, detail: String, window: NSWindow?) {
        presentAlert(title: title, detail: detail, window: window, deduplicate: true)
    }

    private func presentAccessAlert(title: String, detail: String, window: NSWindow?) {
        presentAlert(title: title, detail: detail, window: window, deduplicate: false)
    }

    private func presentAlert(title: String, detail: String, window: NSWindow?, deduplicate: Bool) {
        if deduplicate {
            let shouldPresent = lock.withLock {
                if lastPresentedErrorDescription == detail {
                    return false
                }
                lastPresentedErrorDescription = detail
                return true
            }

            guard shouldPresent else {
                return
            }
        }

        let block = {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = detail
            alert.addButton(withTitle: "OK")
            if let window {
                alert.beginSheetModal(for: window, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func sendSocketRequest(_ data: Data, to socketPath: String) throws -> Data {
        let fileManager = FileManager.default
        let socketDirectory = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        try fileManager.createDirectory(at: socketDirectory, withIntermediateDirectories: true)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw LKSwiftUISupportAuthServerError.rpcTransport(String(cString: strerror(errno)))
        }

        defer {
            close(fd)
        }

        var address = sockaddr_un()
        #if os(macOS)
            address.sun_len = UInt8(MemoryLayout<sockaddr_un>.stride)
        #endif
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= maxPathLength else {
            throw LKSwiftUISupportAuthServerError.socketPathInvalid(socketPath)
        }

        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            let destination = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: CChar.self)
            destination.initialize(repeating: 0, count: maxPathLength)
            pathBytes.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    return
                }
                _ = strncpy(destination, baseAddress, maxPathLength - 1)
            }
        }

        let connectResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.stride))
            }
        }

        guard connectResult == 0 else {
            throw LKSwiftUISupportAuthServerError.rpcTransport(String(cString: strerror(errno)))
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do {
            try handle.write(contentsOf: data)
            Darwin.shutdown(fd, SHUT_WR)
            guard let responseData = try handle.readToEnd(), responseData.isEmpty == false else {
                throw LKSwiftUISupportAuthServerError.invalidResponse("The helper closed the connection without a payload.")
            }
            return responseData
        } catch {
            throw LKSwiftUISupportAuthServerError.rpcTransport(error.localizedDescription)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}

@objcMembers
public final class LKSwiftUISupportGatekeeper: NSObject {
    private static let shared = LKSwiftUISupportGatekeeper()
    private let runtimeBridge = LKSwiftUISupportAuthServerBridge()

    @objc public class func sharedInstance() -> LKSwiftUISupportGatekeeper {
        shared
    }

    @objc(preloadRuntime)
    public func preloadRuntime() {
        runtimeBridge.preloadRuntime()
    }

    @objc(shutdownRuntime)
    public func shutdownRuntime() {
        runtimeBridge.shutdownRuntime()
    }

    @objc(showActivationWindow)
    public func showActivationWindow() {
        runtimeBridge.showActivationWindow(from: NSApp.keyWindow)
    }

    @objc(showLicenseWindow)
    public func showLicenseWindow() {
        runtimeBridge.showLicenseWindow(from: NSApp.keyWindow)
    }

    @objc(refreshLicenseStatus)
    public func refreshLicenseStatus() {
        runtimeBridge.refreshLicenseStatus(from: NSApp.keyWindow)
    }

    @objc(allowProtectedFeatureAccessForWindow:)
    public func allowProtectedFeatureAccess(for window: NSWindow?) -> Bool {
        runtimeBridge.allowProtectedFeatureAccess(for: window)
    }
}
