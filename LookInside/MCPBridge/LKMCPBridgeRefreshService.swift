// LKMCPBridgeRefreshService.swift
//
// Handles the `hierarchy.refresh` bridge route: re-fetching the target
// app's whole view tree (RPC 202) and handing it to the host's data
// source, which is exactly what the inspector's toolbar reload button
// does.
//
// Why this needs to exist at all: LookInside is a manual-refresh
// inspector by design. Nothing polls the target and nothing pushes "the
// UI changed" — the host's tree is whatever the last fetch produced. A
// human closes that gap by clicking reload; before this route an agent
// had no equivalent and could only read a snapshot that silently went
// stale the moment the app navigated.
//
// This service is deliberately NOT folded into `LKMCPBridgeInspectionService`.
// That service is pure cached reads with no RPC; refresh round-trips to
// the target and mutates host state, and merging them would quietly
// retire the "the read surface never emits RPC" property.
//
// The actual reload is not reimplemented here. It runs through
// `-[LKStaticWindowController reloadHierarchySignal]`, the same method
// the toolbar button now calls, so both paths share one re-entrancy gate
// and one fetch chain. Duplicating the chain in Swift would have left two
// copies to drift apart, and writing the window controller's private
// `isFetchingHierarchy` flag from here would have meant this service
// silently driving the host's toolbar enablement.

import AppKit
import Foundation
import os

@MainActor
public final class LKMCPBridgeRefreshService {

    // MARK: - Constants pulled from upstream LookinDefines.h
    //
    // Re-declared rather than imported, matching the other RPC-emitting
    // services: pulling LookinDefines.h into the bridging header would
    // touch every Swift compilation in the target.

    /// `LookinErrCode_NoConnect` from `LookinDefines.h:128`.
    private static let lookinErrCodeNoConnect = -403

    /// `LookinErrCode_Timeout` from `LookinDefines.h:132`.
    private static let lookinErrCodeTimeout = -405

    /// `LookinErrCode_LicenseRequired` from `LookinDefines.h:153`.
    private static let lookinErrCodeLicenseRequired = -408

    private static let logger = Logger(subsystem: "com.lookinside.app", category: "MCPBridge.Refresh")

    public init() {}

    // MARK: - Entry point

    public func handle(request: LKMCPBridgeRequest) async -> LKMCPBridgeResponse {
        guard request.method == "hierarchy.refresh" else {
            return .failure(identifier: request.identifier, error: .unknownMethod)
        }
        return await handleHierarchyRefresh(
            identifier: request.identifier,
            parameters: request.parameters
        )
    }

    // MARK: - hierarchy.refresh

    private func handleHierarchyRefresh(
        identifier: String,
        parameters: [String: LKMCPBridgeJSONValue]?
    ) async -> LKMCPBridgeResponse {
        guard let parameters = parameters,
              case .string(let targetIdentifier)? = parameters["targetIdentifier"]
        else {
            return .failure(identifier: identifier, error: .invalidParameters)
        }

        guard let document = LKMCPBridgeLiveDocumentLookup.findLiveDocument(targetIdentifier: targetIdentifier) else {
            return .failure(
                identifier: identifier,
                error: LKMCPBridgeErrorPayload(
                    code: "hierarchy.targetNotFound",
                    message: "No live inspection document found for target identifier \(targetIdentifier)."
                )
            )
        }

        guard let windowController = document.staticWindowController else {
            return .failure(
                identifier: identifier,
                error: LKMCPBridgeErrorPayload(
                    code: "hierarchy.notReady",
                    message: "Live document has no inspector window yet."
                )
            )
        }

        // Read the old size before starting: the data source is replaced
        // in place during the reload, so after the fact there is nothing
        // left to compare against.
        let previousNodeCount = document.hierarchyDataSource?.rawFlatItems?.count ?? 0

        guard let signal = windowController.reloadHierarchySignal() else {
            return .failure(
                identifier: identifier,
                error: LKMCPBridgeErrorPayload(
                    code: "refresh.internalError",
                    message: "The inspector window returned no signal for the hierarchy reload."
                )
            )
        }

        let startInstant = ContinuousClock.now
        do {
            // The value is discarded: by the time it arrives the window
            // controller has already handed it to the data source, and
            // everything reported below is read back from there so the
            // response describes the host's settled state rather than the
            // wire payload.
            _ = try await LKMCPBridgeRACBridge.awaitFirstValue(of: signal, as: AnyObject.self)
        } catch let error as NSError {
            return .failure(identifier: identifier, error: mapRefreshError(error))
        } catch RACBridgeError.completedWithoutValue {
            return .failure(
                identifier: identifier,
                error: LKMCPBridgeErrorPayload(
                    code: "refresh.disconnected",
                    message: "The target app did not return a hierarchy. The channel may have been closed mid-request."
                )
            )
        } catch RACBridgeError.cancelled {
            return .failure(
                identifier: identifier,
                error: LKMCPBridgeErrorPayload(
                    code: "refresh.cancelled",
                    message: "The refresh was cancelled before the target app produced a hierarchy."
                )
            )
        } catch {
            Self.logger.error("hierarchy.refresh bridge error: \(error.localizedDescription, privacy: .public)")
            return .failure(identifier: identifier, error: .internalError)
        }
        let elapsedComponents = (ContinuousClock.now - startInstant).components
        let durationMilliseconds = Int(elapsedComponents.seconds) * 1000
            + Int(elapsedComponents.attoseconds / 1_000_000_000_000_000)

        let rootIdentifiers = LKMCPBridgeLiveDocumentLookup
            .topLevelDisplayItems(in: document)
            .map { LKMCPBridgeLiveDocumentLookup.objectIdentifierString(for: $0) }

        let result = LKMCPBridgeRefreshResult(
            targetIdentifier: targetIdentifier,
            rootObjectIdentifiers: rootIdentifiers,
            nodeCount: document.hierarchyDataSource?.rawFlatItems?.count ?? 0,
            previousNodeCount: previousNodeCount,
            durationMilliseconds: durationMilliseconds
        )

        do {
            let payload = try encodeAsJSONValue(result)
            return .success(identifier: identifier, result: payload)
        } catch {
            Self.logger.error("hierarchy.refresh encode failed: \(error.localizedDescription, privacy: .public)")
            return .failure(identifier: identifier, error: .internalError)
        }
    }

    // MARK: - Error mapping

    private func mapRefreshError(_ error: NSError) -> LKMCPBridgeErrorPayload {
        // Two domains reach here. The window controller's own domain means
        // the host declined to start; `LookinErrorDomain` means the target
        // app failed the fetch. Keeping them apart matters to the caller:
        // the first is worth retrying in a moment, the second usually is
        // not.
        if error.domain == LKStaticWindowControllerReloadErrorDomain {
            switch error.code {
            case LKStaticWindowControllerReloadErrorCode.alreadyInProgress.rawValue:
                return LKMCPBridgeErrorPayload(
                    code: "refresh.alreadyInProgress",
                    message: "A hierarchy reload is already running for this target — either a user clicked reload or another refresh call is still in flight. Retry once it settles."
                )
            case LKStaticWindowControllerReloadErrorCode.detailSyncInProgress.rawValue:
                return LKMCPBridgeErrorPayload(
                    code: "refresh.detailSyncInProgress",
                    message: "The inspector is still syncing view details. Reloading now would discard that work; wait for it to finish."
                )
            case LKStaticWindowControllerReloadErrorCode.noInspectableApp.rawValue:
                return LKMCPBridgeErrorPayload(
                    code: "refresh.notAttached",
                    message: "The inspector window is not attached to an app. Attach a target in LookInside and try again."
                )
            case LKStaticWindowControllerReloadErrorCode.windowClosed.rawValue:
                return LKMCPBridgeErrorPayload(
                    code: "refresh.windowClosed",
                    message: "The inspector window closed while the hierarchy was being fetched, so the result was discarded."
                )
            default:
                Self.logger.error("hierarchy.refresh received unmapped host refusal \(error.code, privacy: .public)")
                return LKMCPBridgeErrorPayload(
                    code: "refresh.internalError",
                    message: "The inspector declined the reload for an unexpected reason (code \(error.code))."
                )
            }
        }

        switch error.code {
        case Self.lookinErrCodeLicenseRequired:
            return .licenseRequired
        case Self.lookinErrCodeNoConnect:
            return LKMCPBridgeErrorPayload(
                code: "refresh.disconnected",
                message: "The target app is no longer connected. Re-attach from the LookInside inspector and try again."
            )
        case Self.lookinErrCodeTimeout:
            return LKMCPBridgeErrorPayload(
                code: "refresh.timeout",
                message: "The target app did not return its hierarchy within the request timeout. Check whether it is paused in Xcode or blocked on the main thread."
            )
        default:
            Self.logger.error("hierarchy.refresh received unmapped error code \(error.code, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return LKMCPBridgeErrorPayload(
                code: "refresh.internalError",
                message: "The target app reported an unexpected error (code \(error.code))."
            )
        }
    }

    // MARK: - Encoding helper (duplicated from InspectionService)

    private func encodeAsJSONValue(_ value: some Encodable) throws -> LKMCPBridgeJSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(LKMCPBridgeJSONValue.self, from: data)
    }
}
