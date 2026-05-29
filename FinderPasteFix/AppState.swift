import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            configureRenameSessionGuard()
            synchronizeWatcher()
            updateStatus()
        }
    }

    @Published var isDiagnosticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDiagnosticsEnabled, forKey: Self.diagnosticsDefaultsKey)
            if isDiagnosticsEnabled {
                log(kind: "diagnosticsEnabled", message: "Diagnostics enabled")
            }
        }
    }

    @Published var isMenuPasteSupportEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMenuPasteSupportEnabled, forKey: Self.menuPasteDefaultsKey)
            configureRenameSessionGuard()
            log(kind: "menuPasteSupportChanged", message: "Menu paste support enabled=\(isMenuPasteSupportEnabled)")
        }
    }

    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var isInputMonitoringTrusted = CGPreflightListenEventAccess()
    @Published private(set) var isEventTapActive = false
    @Published private(set) var lastStatus = "Starting..."
    @Published private(set) var lastFocusSnapshot = ""
    @Published private(set) var diagnosticsLogURL = DiagnosticsLogger.shared.logURL

    private static let enabledDefaultsKey = "FinderPasteFix.isEnabled"
    private static let diagnosticsDefaultsKey = "FinderPasteFix.isDiagnosticsEnabled"
    private static let menuPasteDefaultsKey = "FinderPasteFix.isMenuPasteSupportEnabled"

    private let detector = FinderRenameDetector()
    private let interceptor = PasteInterceptor()
    private lazy var renameSessionGuard = RenameSessionPasteboardGuard(detector: detector)
    private let diagnostics = DiagnosticsLogger.shared
    private var permissionRefreshTimer: Timer?

    private init() {
        if UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        }

        if UserDefaults.standard.object(forKey: Self.diagnosticsDefaultsKey) == nil {
            isDiagnosticsEnabled = false
        } else {
            isDiagnosticsEnabled = UserDefaults.standard.bool(forKey: Self.diagnosticsDefaultsKey)
        }

        if UserDefaults.standard.object(forKey: Self.menuPasteDefaultsKey) == nil {
            isMenuPasteSupportEnabled = false
        } else {
            isMenuPasteSupportEnabled = UserDefaults.standard.bool(forKey: Self.menuPasteDefaultsKey)
        }
    }

    var menuBarSystemImage: String {
        if !isEnabled {
            return "text.cursor.slash"
        }

        if isAccessibilityTrusted && isEventTapActive {
            return "text.cursor"
        }

        return "exclamationmark.triangle"
    }

    var launchLocationDescription: String {
        if isRunningFromInstalledLocation {
            return "Installed app"
        }

        if isRunningFromBuildLocation {
            return "Build folder"
        }

        return "Other location"
    }

    var shouldWarnAboutLaunchLocation: Bool {
        !isRunningFromInstalledLocation
    }

    func start() {
        refreshPermissions()
        synchronizeWatcher()
        log(
            kind: "appStart",
            message: "App started; eventTapActive=\(isEventTapActive); accessibilityTrusted=\(isAccessibilityTrusted); inputMonitoringTrusted=\(isInputMonitoringTrusted); path=\(Bundle.main.bundlePath)"
        )
        configureRenameSessionGuard()
        updateStatus()
        startPermissionRefreshTimer()
    }

    func restartWatcher() {
        refreshPermissions()
        synchronizeWatcher(restart: true)
        log(
            kind: "watcherRestart",
            message: "Watcher restarted; eventTapActive=\(isEventTapActive); accessibilityTrusted=\(isAccessibilityTrusted); inputMonitoringTrusted=\(isInputMonitoringTrusted); path=\(Bundle.main.bundlePath)"
        )
        configureRenameSessionGuard()
        updateStatus()
    }

    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        refreshPermissions()
        log(kind: "permissionPrompt", message: "Accessibility permission prompt requested")
    }

    func requestInputMonitoringPermission() {
        let granted = CGRequestListenEventAccess()
        refreshPermissions()
        log(kind: "inputMonitoringPrompt", message: "Input Monitoring prompt requested; granted=\(granted)")

        if !granted {
            openInputMonitoringSettings()
        }
    }

    func refreshPermissions() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        isInputMonitoringTrusted = CGPreflightListenEventAccess()
    }

    @discardableResult
    func handlePotentialFinderPaste() -> Bool {
        guard isEnabled else {
            lastStatus = "Disabled"
            return false
        }

        let focus = detector.currentFocus()
        let clipboard = isDiagnosticsEnabled ? ClipboardSnapshot.current() : nil
        lastFocusSnapshot = focus.debugDescription

        log(
            kind: "pasteCandidate",
            message: "Command-V observed",
            focus: focus,
            clipboard: clipboard
        )

        guard focus.isFinderRenameCandidate else {
            lastStatus = "Ignored paste outside Finder rename"
            log(
                kind: "pasteIgnored",
                message: "Focused element was not a Finder rename candidate",
                focus: focus,
                clipboard: clipboard
            )
            return false
        }

        let result = PasteboardSanitizer.sanitizeGeneralPasteboardForOnePaste()

        switch result {
        case .changed(let original, let sanitized):
            lastStatus = "Sanitized paste: \(Self.preview(original)) -> \(Self.preview(sanitized))"
            log(
                kind: "pasteSanitized",
                message: "Pasteboard text was sanitized for Finder rename",
                focus: focus,
                clipboard: clipboard,
                original: original,
                sanitized: sanitized
            )
            return true
        case .unchanged:
            lastStatus = "Finder rename paste already safe"
            log(
                kind: "pasteUnchanged",
                message: "Finder rename paste was already safe",
                focus: focus,
                clipboard: clipboard
            )
            return false
        case .noString:
            lastStatus = "Finder rename paste had no text"
            log(
                kind: "pasteNoString",
                message: "Finder rename paste did not contain a string",
                focus: focus,
                clipboard: clipboard
            )
            return false
        }
    }

    func markEventTapRecoveredAfterSystemPause() {
        isEventTapActive = true
        lastStatus = "Event tap recovered after macOS paused it"
        log(kind: "eventTapRecovered", message: "Event tap recovered after macOS paused it")
    }

    func recordCurrentFocusSnapshot() {
        let focus = detector.currentFocus()
        lastFocusSnapshot = focus.debugDescription
        lastStatus = "Recorded current focus snapshot"
        log(kind: "focusSnapshot", message: "Manual focus snapshot", focus: focus)
    }

    func copyLastFocusSnapshot() {
        guard !lastFocusSnapshot.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastFocusSnapshot, forType: .string)
        lastStatus = "Copied last focus snapshot"
    }

    func copyAppDiagnostics() {
        let text = """
        bundleIdentifier: \(Bundle.main.bundleIdentifier ?? "<nil>")
        bundlePath: \(Bundle.main.bundlePath)
        launchLocation: \(launchLocationDescription)
        processIdentifier: \(ProcessInfo.processInfo.processIdentifier)
        accessibilityTrusted: \(isAccessibilityTrusted)
        inputMonitoringTrusted: \(isInputMonitoringTrusted)
        eventTapActive: \(isEventTapActive)
        diagnosticsLogURL: \(diagnostics.logURL.path)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastStatus = "Copied app diagnostics"
    }

    func openAccessibilitySettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openDiagnosticsLog() {
        diagnostics.ensureLogFileExists()
        NSWorkspace.shared.activateFileViewerSelecting([diagnostics.logURL])
        lastStatus = "Opened diagnostics log in Finder"
    }

    func copyDiagnosticsLog() {
        diagnostics.ensureLogFileExists()
        let contents = diagnostics.readLog()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contents, forType: .string)
        lastStatus = "Copied diagnostics log"
    }

    func clearDiagnosticsLog() {
        diagnostics.clearLog()
        lastStatus = "Cleared diagnostics log"
    }

    private func updateStatus() {
        if shouldWarnAboutLaunchLocation {
            lastStatus = "Running from \(launchLocationDescription); use installed app before granting permissions"
        } else if !isEnabled {
            lastStatus = "Disabled"
        } else if !isAccessibilityTrusted {
            lastStatus = "Needs Accessibility permission"
        } else if !isInputMonitoringTrusted {
            lastStatus = "Needs Input Monitoring permission"
        } else if !isEventTapActive {
            lastStatus = "Watcher inactive; refresh after granting permissions"
        } else {
            lastStatus = "Watching Finder paste commands"
        }
    }

    private static func preview(_ string: String) -> String {
        DiagnosticsLogger.preview(string, limit: 42)
    }

    private func log(
        kind: String,
        message: String,
        focus: FocusSnapshot? = nil,
        clipboard: ClipboardSnapshot? = nil,
        original: String? = nil,
        sanitized: String? = nil
    ) {
        guard isDiagnosticsEnabled else {
            return
        }

        diagnostics.append(
            DiagnosticRecord(
                kind: kind,
                message: message,
                focus: focus,
                clipboard: clipboard,
                original: original,
                sanitized: sanitized
            )
        )
    }

    private func openSystemSettingsPane(_ string: String) {
        guard let url = URL(string: string) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func configureRenameSessionGuard() {
        if isEnabled && isAccessibilityTrusted && isMenuPasteSupportEnabled {
            renameSessionGuard.start()
        } else {
            renameSessionGuard.stop()
        }
    }

    private func synchronizeWatcher(restart: Bool = false) {
        guard isEnabled, isAccessibilityTrusted, isInputMonitoringTrusted else {
            interceptor.stop()
            isEventTapActive = false
            return
        }

        if restart || !isEventTapActive {
            interceptor.stop()
            isEventTapActive = interceptor.start(state: self)
        }
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollPermissionState()
        }
    }

    private func pollPermissionState() {
        let oldAccessibility = isAccessibilityTrusted
        let oldInputMonitoring = isInputMonitoringTrusted

        refreshPermissions()

        guard oldAccessibility != isAccessibilityTrusted || oldInputMonitoring != isInputMonitoringTrusted else {
            return
        }

        log(
            kind: "permissionStateChanged",
            message: "Permissions changed; accessibilityTrusted=\(isAccessibilityTrusted); inputMonitoringTrusted=\(isInputMonitoringTrusted)"
        )
        synchronizeWatcher()
        configureRenameSessionGuard()
        updateStatus()
    }

    private var isRunningFromBuildLocation: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/DerivedData/") || path.contains("/Build/Products/")
    }

    private var isRunningFromInstalledLocation: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path == Self.installedAppURL.standardizedFileURL.path
    }

    private static var installedAppURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .appendingPathComponent("FinderPasteFix.app")
    }
}
