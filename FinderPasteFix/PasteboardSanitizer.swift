import AppKit

enum PasteboardSanitizationResult {
    case changed(original: String, sanitized: String)
    case unchanged
    case noString
}

enum RenameSessionPasteboardSanitizationResult {
    case changed(snapshot: PasteboardRestoreSnapshot, changeCount: Int)
    case unchanged
    case noString
}

struct PasteboardRestoreSnapshot {
    let originalString: String
    let items: [NSPasteboardItem]
}

enum PasteboardSanitizer {
    static func sanitizeGeneralPasteboardForOnePaste() -> PasteboardSanitizationResult {
        let pasteboard = NSPasteboard.general

        guard let originalString = pasteboard.string(forType: .string) else {
            return .noString
        }

        let sanitizedString = sanitizeFilenameText(originalString)

        guard sanitizedString != originalString else {
            return .unchanged
        }

        let snapshot = PasteboardRestoreSnapshot(
            originalString: originalString,
            items: snapshotItems(from: pasteboard)
        )

        pasteboard.clearContents()
        pasteboard.setString(sanitizedString, forType: .string)

        let sanitizedChangeCount = pasteboard.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            restore(snapshot, ifCurrentChangeCountIs: sanitizedChangeCount)
        }

        return .changed(original: originalString, sanitized: sanitizedString)
    }

    static func sanitizeGeneralPasteboardForRenameSession() -> RenameSessionPasteboardSanitizationResult {
        let pasteboard = NSPasteboard.general

        guard let originalString = pasteboard.string(forType: .string) else {
            return .noString
        }

        let sanitizedString = sanitizeFilenameText(originalString)

        guard sanitizedString != originalString else {
            return .unchanged
        }

        let snapshot = PasteboardRestoreSnapshot(
            originalString: originalString,
            items: snapshotItems(from: pasteboard)
        )

        pasteboard.clearContents()
        pasteboard.setString(sanitizedString, forType: .string)

        return .changed(snapshot: snapshot, changeCount: pasteboard.changeCount)
    }

    static func restore(_ snapshot: PasteboardRestoreSnapshot, ifCurrentChangeCountIs changeCount: Int) {
        let pasteboard = NSPasteboard.general

        guard pasteboard.changeCount == changeCount else {
            return
        }

        pasteboard.clearContents()

        if !snapshot.items.isEmpty {
            pasteboard.writeObjects(snapshot.items)
        } else {
            pasteboard.setString(snapshot.originalString, forType: .string)
        }
    }

    static func sanitizeFilenameText(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: ":", with: " - ")
    }

    private static func snapshotItems(from pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()

            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }

            return copy
        } ?? []
    }
}
