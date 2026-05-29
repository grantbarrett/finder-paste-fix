import AppKit
import Foundation

final class RenameSessionPasteboardGuard {
    private let detector: FinderRenameDetector
    private var timer: Timer?
    private var restoreSnapshot: PasteboardRestoreSnapshot?
    private var sanitizedChangeCount: Int?
    private var wasInRenameSession = false

    init(detector: FinderRenameDetector) {
        self.detector = detector
    }

    func start() {
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        restoreIfUnchanged()
        wasInRenameSession = false
    }

    private func tick() {
        let focus = detector.currentFocus()

        guard focus.isFinderRenameCandidate else {
            if wasInRenameSession {
                restoreIfUnchanged()
            }
            wasInRenameSession = false
            return
        }

        wasInRenameSession = true

        guard restoreSnapshot == nil else {
            return
        }

        switch PasteboardSanitizer.sanitizeGeneralPasteboardForRenameSession() {
        case .changed(let snapshot, let changeCount):
            restoreSnapshot = snapshot
            sanitizedChangeCount = changeCount
        case .unchanged, .noString:
            break
        }
    }

    private func restoreIfUnchanged() {
        guard let snapshot = restoreSnapshot, let sanitizedChangeCount else {
            return
        }

        PasteboardSanitizer.restore(snapshot, ifCurrentChangeCountIs: sanitizedChangeCount)
        restoreSnapshot = nil
        self.sanitizedChangeCount = nil
    }
}
