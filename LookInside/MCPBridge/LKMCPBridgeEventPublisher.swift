// LKMCPBridgeEventPublisher.swift
//
// Turns host-side state changes into `LKMCPBridgeEvent` frames and hands
// them to `LKMCPBridgeServer.broadcast(event:)`.
//
// What belongs here, and what deliberately does not:
//
// Only things a bridge client cannot learn on its own get published. A
// client that calls a tool already has the tool's return value, so
// echoing the same fact back as an event would be noise at best and, at
// worst, read as independent news about the app.
//
// That rules out the data source's three item-change subjects
// (`itemDidChangeAttrGroup`, `itemDidChangeHiddenAlphaValue`,
// `itemsDidChangeFrame`). All three fire only from inside
// `-[LKStaticHierarchyDataSource modifyWithDisplayItemDetail:]`, which is
// the moment fetched detail lands in the cache -- and the fetch was
// almost always the caller's own `details.read` / `screenshot.read` /
// `attribute.modify`. Publishing them would tell a client "something
// changed" about a change it just made.
//
// `hierarchy.reloaded` is the one case where the client's own action and
// a human's produce the same signal, so it carries an `initiator` field
// instead of being dropped.
//
// What this publisher does NOT and cannot offer: notice that the
// inspected app's UI changed by itself. LookInside is a manual-refresh
// inspector; the host only learns the UI moved when someone asks it to
// look. Every topic here is about the *host's* state, never about the
// target app spontaneously changing. The CLI's resource descriptions say
// so in as many words, because a client that assumes otherwise will
// subscribe and then wait forever.
//
// Subscription filtering is not done here. The host stays ignorant of how
// many bridge clients exist and what each one cares about; it broadcasts
// to every open connection and lets each client filter. That keeps this
// file free of any Model Context Protocol concepts, which the GPL/MIT
// split requires.

import AppKit
import Foundation
import os

@MainActor
public final class LKMCPBridgeEventPublisher {

    /// `LookinPush_SwiftUISupportDetected` from `LookinDefines.h`. Declared
    /// locally for the same reason the RPC services declare their error
    /// codes locally: pulling LookinDefines.h into the bridging header
    /// would touch every Swift compilation in the target.
    private static let lookinPushSwiftUISupportDetected: UInt32 = 305

    private static let logger = Logger(subsystem: "com.lookinside.app", category: "MCPBridge.Events")

    /// Where finished events go. Injected rather than reaching for the
    /// server singleton so this type can be exercised without a socket.
    private let broadcast: @MainActor (LKMCPBridgeEvent) -> Void

    /// Subscriptions that live as long as the publisher does.
    private var globalDisposables: [RACDisposable] = []

    /// One entry per open live document, holding that document's
    /// `didReloadHierarchyInfo` subscription. Documents come and go, so
    /// these are attached on open and disposed on close; leaving a stale
    /// one behind would keep a closed document's data source alive and
    /// keep publishing reloads for a window nobody can see.
    private var documentDisposables: [ObjectIdentifier: RACDisposable] = [:]

    private var hasStarted = false

    public init(broadcast: @escaping @MainActor (LKMCPBridgeEvent) -> Void) {
        self.broadcast = broadcast
    }

    /// Runs `body` on the main actor, synchronously when already there.
    ///
    /// Every subject this file watches is main-queue bound today --
    /// Peertalk builds its protocol, channel, and USB hub on
    /// `dispatch_get_main_queue()`, and hierarchy reloads are driven from
    /// the inspector's UI. `MainActor.assumeIsolated` would document that
    /// and check it, but it checks by trapping: if any of those ever
    /// moves off the main queue, the whole inspector dies on the next
    /// target disconnect. Publishing an event is not worth that. The
    /// synchronous path is kept because a reload's payload is read from
    /// mutable host state (`rawFlatItems`, `lastReloadInitiator`) that a
    /// later reload would overwrite.
    private static func onMainActor(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body() }
        } else {
            Task { @MainActor in body() }
        }
    }

    // MARK: - Lifecycle

    /// Idempotent. The bridge server starts asynchronously and may be
    /// asked to start more than once over a process's life.
    public func start() {
        guard hasStarted == false else { return }
        hasStarted = true

        subscribeToDocumentLifecycle()
        subscribeToConnectionManager()
        subscribeToActivationState()

        // Documents can already exist: the bridge server starts on
        // `applicationDidFinishLaunching:`, but a document opened by an
        // auto-connect environment variable races that. Adopt whatever is
        // already open rather than only ever seeing the next one.
        for document in LKMCPBridgeLiveDocumentLookup.enumerateLiveDocuments() {
            attachReloadSubscription(to: document)
        }
    }

    public func stop() {
        guard hasStarted else { return }
        hasStarted = false
        NotificationCenter.default.removeObserver(self)
        for disposable in globalDisposables {
            disposable.dispose()
        }
        globalDisposables.removeAll()
        for disposable in documentDisposables.values {
            disposable.dispose()
        }
        documentDisposables.removeAll()
    }

    // MARK: - Document lifecycle

    private func subscribeToDocumentLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentDidOpen(_:)),
            name: NSNotification.Name(rawValue: "LookinLiveDocumentDidOpenNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentWillClose(_:)),
            name: NSNotification.Name(rawValue: "LookinLiveDocumentWillCloseNotification"),
            object: nil
        )
    }

    @objc private func handleDocumentDidOpen(_ notification: Notification) {
        guard let document = notification.object as? LookinLiveDocument else { return }
        attachReloadSubscription(to: document)
        // Carries the whole target record rather than just an identifier:
        // a client that learns a target appeared will immediately want to
        // know what it is, and the round-trip back to `targets.list` buys
        // nothing the host does not already have in hand.
        broadcast(
            LKMCPBridgeEvent(
                topic: "targets.attached",
                payload: targetPayload(for: document)
            )
        )
    }

    @objc private func handleDocumentWillClose(_ notification: Notification) {
        guard let document = notification.object as? LookinLiveDocument else { return }
        detachReloadSubscription(from: document)
        broadcast(
            LKMCPBridgeEvent(
                topic: "targets.detached",
                payload: targetPayload(for: document)
            )
        )
    }

    // MARK: - Per-document reload subscription

    private func attachReloadSubscription(to document: LookinLiveDocument) {
        let key = ObjectIdentifier(document)
        guard documentDisposables[key] == nil else { return }
        guard let dataSource = document.hierarchyDataSource else { return }

        // `didReloadHierarchyInfo` is the data source's own announcement
        // that it has finished absorbing a new tree, so by the time this
        // fires the hierarchy a client would read is already the new one.
        let disposable = dataSource.didReloadHierarchyInfo.subscribeNext { [weak self, weak document] _ in
            Self.onMainActor {
                guard let self, let document else { return }
                self.publishHierarchyReloaded(for: document)
            }
        }
        documentDisposables[key] = disposable
    }

    private func detachReloadSubscription(from document: LookinLiveDocument) {
        let key = ObjectIdentifier(document)
        documentDisposables.removeValue(forKey: key)?.dispose()
    }

    private func publishHierarchyReloaded(for document: LookinLiveDocument) {
        var payload = targetPayload(for: document)
        payload["nodeCount"] = .integer(Int64(document.hierarchyDataSource?.rawFlatItems?.count ?? 0))
        // `agent` means "a bridge client asked for this", so a client that
        // did the asking can recognize its own echo and ignore it. Only
        // `host` is news.
        let initiator = document.staticWindowController?.lastReloadInitiator ?? .host
        payload["initiator"] = .string(initiator == .agent ? "agent" : "host")
        broadcast(LKMCPBridgeEvent(topic: "hierarchy.reloaded", payload: payload))
    }

    // MARK: - Connection manager

    private func subscribeToConnectionManager() {
        guard let connectionManager = LKConnectionManager.sharedInstance() else { return }

        // A channel ending is the one thing here that is genuinely about
        // the target app rather than the host: the app was killed, the USB
        // cable came out, the simulator shut down. A client holding object
        // identifiers for that target needs to stop trusting them.
        let channelEndDisposable = connectionManager.channelWillEnd.subscribeNext { [weak self] channel in
            Self.onMainActor {
                guard let self else { return }
                self.publishDisconnected(channel: channel)
            }
        }
        globalDisposables.append(channelEndDisposable)

        // `didReceivePush` carries a RACTuple of (channel, pushType, data)
        // for every server-initiated push. Only one push type exists today.
        let pushDisposable = connectionManager.didReceivePush.subscribeNext { [weak self] value in
            Self.onMainActor {
                guard let self, let tuple = value as? RACTuple else { return }
                self.handleServerPush(tuple)
            }
        }
        globalDisposables.append(pushDisposable)
    }

    /// Resolves a `Lookin_PTChannel` back to the document that owns it, so
    /// an event can name a target identifier the client already knows
    /// rather than an opaque channel the bridge protocol never exposes.
    ///
    /// Delegates to the host's own `liveDocumentForChannel:` instead of
    /// walking the documents here: matching a channel to a document is
    /// exactly the question that method answers, and reimplementing it
    /// would leave two versions to disagree after a reconnect swaps a
    /// document's underlying channel.
    private func document(forChannel channel: Any?) -> LookinLiveDocument? {
        guard let typedChannel = channel as? Lookin_PTChannel else { return nil }
        return LookinLiveDocumentController.sharedInstance().liveDocument(for: typedChannel)
    }

    private func publishDisconnected(channel: Any?) {
        guard let document = document(forChannel: channel) else { return }
        broadcast(
            LKMCPBridgeEvent(
                topic: "targets.disconnected",
                payload: targetPayload(for: document)
            )
        )
    }

    private func handleServerPush(_ tuple: RACTuple) {
        guard let pushTypeNumber = tuple.second as? NSNumber,
              pushTypeNumber.uint32Value == Self.lookinPushSwiftUISupportDetected
        else { return }
        var payload: [String: LKMCPBridgeJSONValue] = [:]
        if let document = document(forChannel: tuple.first) {
            payload = targetPayload(for: document)
        }
        payload["capability"] = .string("swiftUI")
        broadcast(LKMCPBridgeEvent(topic: "capabilities.swiftUIDetected", payload: payload))
    }

    // MARK: - Activation state

    private func subscribeToActivationState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleActivationStateDidChange(_:)),
            name: LKSwiftUISupportGatekeeper.activationStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleActivationStateDidChange(_ notification: Notification) {
        // Read silently. `allowProtectedFeatureAccessForWindow:` would put
        // an activation window on screen, which an event handler must
        // never do -- nobody asked for it.
        let state = LKSwiftUISupportGatekeeper.sharedInstance().activationState
        broadcast(
            LKMCPBridgeEvent(
                topic: "license.stateChanged",
                payload: ["state": .string(Self.wireName(for: state))]
            )
        )
    }

    private static func wireName(for state: LKSwiftUISupportActivationState) -> String {
        switch state {
        case .activated:
            return "activated"
        case .notActivated:
            return "notActivated"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }

    // MARK: - Payload helper

    /// The same target description `targets.list` returns, minus the
    /// fields that require a round-trip. Kept in one place so every topic
    /// names a target the same way.
    private func targetPayload(for document: LookinLiveDocument) -> [String: LKMCPBridgeJSONValue] {
        var payload: [String: LKMCPBridgeJSONValue] = [:]
        guard let appInfo = document.inspectableApp.appInfo else {
            return payload
        }
        payload["targetIdentifier"] = .string(String(appInfo.appInfoIdentifier))
        if let applicationName = appInfo.appName, applicationName.isEmpty == false {
            payload["applicationName"] = .string(applicationName)
        }
        if let bundleIdentifier = appInfo.appBundleIdentifier, bundleIdentifier.isEmpty == false {
            payload["bundleIdentifier"] = .string(bundleIdentifier)
        }
        if let deviceDescription = appInfo.deviceDescription, deviceDescription.isEmpty == false {
            payload["deviceDescription"] = .string(deviceDescription)
        }
        if let operatingSystemDescription = appInfo.osDescription, operatingSystemDescription.isEmpty == false {
            payload["operatingSystemDescription"] = .string(operatingSystemDescription)
        }
        return payload
    }
}
