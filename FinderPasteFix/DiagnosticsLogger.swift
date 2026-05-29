import AppKit
import Foundation

struct ClipboardSnapshot: Codable {
    let types: [String]
    let stringLength: Int?
    let stringPreview: String?

    static func current() -> ClipboardSnapshot {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.pasteboardItems?
            .flatMap { item in item.types.map(\.rawValue) }
            .uniqued()
            .sorted() ?? []

        let string = pasteboard.string(forType: .string)

        return ClipboardSnapshot(
            types: types,
            stringLength: string?.count,
            stringPreview: string.map { DiagnosticsLogger.preview($0) }
        )
    }
}

struct DiagnosticFocusSnapshot: Codable {
    let frontmostBundleIdentifier: String?
    let role: String?
    let subrole: String?
    let title: String?
    let description: String?
    let valueLength: Int?
    let valuePreview: String?
    let parentRole: String?
    let parentSubrole: String?
    let parentTitle: String?
    let grandparentRole: String?
    let ancestors: [DiagnosticAccessibilityNodeSnapshot]
    let isFinderRenameCandidate: Bool

    init(_ focus: FocusSnapshot) {
        frontmostBundleIdentifier = focus.frontmostBundleIdentifier
        role = focus.role
        subrole = focus.subrole
        title = focus.title
        description = focus.description
        valueLength = focus.value?.count
        valuePreview = focus.value.map { DiagnosticsLogger.preview($0) }
        parentRole = focus.parentRole
        parentSubrole = focus.parentSubrole
        parentTitle = focus.parentTitle
        grandparentRole = focus.grandparentRole
        ancestors = focus.ancestors.map(DiagnosticAccessibilityNodeSnapshot.init)
        isFinderRenameCandidate = focus.isFinderRenameCandidate
    }
}

struct DiagnosticAccessibilityNodeSnapshot: Codable {
    let role: String?
    let subrole: String?
    let title: String?
    let description: String?

    init(_ snapshot: AccessibilityNodeSnapshot) {
        role = snapshot.role
        subrole = snapshot.subrole
        title = snapshot.title
        description = snapshot.description
    }
}

struct DiagnosticRecord: Codable {
    let timestamp: String
    let kind: String
    let message: String
    let focus: DiagnosticFocusSnapshot?
    let clipboard: ClipboardSnapshot?
    let originalPreview: String?
    let sanitizedPreview: String?

    init(
        kind: String,
        message: String,
        focus: FocusSnapshot? = nil,
        clipboard: ClipboardSnapshot? = nil,
        original: String? = nil,
        sanitized: String? = nil
    ) {
        timestamp = ISO8601DateFormatter().string(from: Date())
        self.kind = kind
        self.message = message
        self.focus = focus.map(DiagnosticFocusSnapshot.init)
        self.clipboard = clipboard
        originalPreview = original.map { DiagnosticsLogger.preview($0) }
        sanitizedPreview = sanitized.map { DiagnosticsLogger.preview($0) }
    }
}

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    let logURL: URL

    private let queue = DispatchQueue(label: "local.finderpastefix.diagnostics")
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private init() {
        let fileManager = FileManager.default

        if let appSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            logURL = appSupportURL
                .appendingPathComponent("FinderPasteFix", isDirectory: true)
                .appendingPathComponent("diagnostics.jsonl")
        } else {
            logURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("FinderPasteFix-diagnostics.jsonl")
        }
    }

    func append(_ record: DiagnosticRecord) {
        queue.async { [encoder, logURL] in
            do {
                try FileManager.default.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if !FileManager.default.fileExists(atPath: logURL.path) {
                    FileManager.default.createFile(atPath: logURL.path, contents: nil)
                }

                var data = try encoder.encode(record)
                data.append(0x0A)

                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                // Diagnostics must never interrupt paste handling.
            }
        }
    }

    func ensureLogFileExists() {
        queue.sync {
            do {
                try FileManager.default.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if !FileManager.default.fileExists(atPath: logURL.path) {
                    FileManager.default.createFile(atPath: logURL.path, contents: nil)
                }
            } catch {
                // The menu exposes best-effort diagnostics only.
            }
        }
    }

    func readLog() -> String {
        queue.sync {
            (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        }
    }

    func clearLog() {
        queue.sync {
            try? "".write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    static func preview(_ string: String, limit: Int = 80) -> String {
        let collapsed = string
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        if collapsed.count <= limit {
            return collapsed
        }

        return String(collapsed.prefix(limit - 3)) + "..."
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
