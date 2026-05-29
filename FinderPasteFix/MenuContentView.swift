import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        Toggle("Enabled", isOn: $state.isEnabled)

        Toggle("Diagnostics", isOn: $state.isDiagnosticsEnabled)

        Toggle("Menu Paste Support", isOn: $state.isMenuPasteSupportEnabled)

        Divider()

        Text(state.lastStatus)
            .font(.caption)

        Text("Run Location: \(state.launchLocationDescription)")
            .font(.caption)

        if state.shouldWarnAboutLaunchLocation {
            Text("Use the installed app before granting permissions.")
                .font(.caption)
        }

        Text("Accessibility: \(state.isAccessibilityTrusted ? "Allowed" : "Needed")")
            .font(.caption)

        Text("Input Monitoring: \(state.isInputMonitoringTrusted ? "Allowed" : "Needed")")
            .font(.caption)

        Text("Event Tap: \(state.isEventTapActive ? "Active" : "Inactive")")
            .font(.caption)

        Divider()

        Button("Record Current Focus Snapshot") {
            state.recordCurrentFocusSnapshot()
        }

        Button("Grant Accessibility Permission") {
            state.requestAccessibilityPermission()
        }

        Button("Grant Input Monitoring Permission") {
            state.requestInputMonitoringPermission()
        }

        Button("Open Accessibility Settings") {
            state.openAccessibilitySettings()
        }

        Button("Open Input Monitoring Settings") {
            state.openInputMonitoringSettings()
        }

        Button("Refresh / Restart Watcher") {
            state.restartWatcher()
        }

        Button("Copy Last Focus Snapshot") {
            state.copyLastFocusSnapshot()
        }
        .disabled(state.lastFocusSnapshot.isEmpty)

        Button("Copy App Diagnostics") {
            state.copyAppDiagnostics()
        }

        Button("Open Diagnostics Log") {
            state.openDiagnosticsLog()
        }

        Button("Copy Diagnostics Log") {
            state.copyDiagnosticsLog()
        }

        Button("Clear Diagnostics Log") {
            state.clearDiagnosticsLog()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
