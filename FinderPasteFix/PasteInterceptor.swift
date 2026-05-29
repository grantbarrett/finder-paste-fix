import AppKit
import CoreGraphics

final class PasteInterceptor {
    private weak var state: AppState?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start(state: AppState) -> Bool {
        stop()

        self.state = state

        let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: keyDownMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            state?.markEventTapRecoveredAfterSystemPause()
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, isPlainCommandV(event) else {
            return Unmanaged.passUnretained(event)
        }

        _ = state?.handlePotentialFinderPaste()
        return Unmanaged.passUnretained(event)
    }

    private func isPlainCommandV(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        return keyCode == 9
            && flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskShift)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let interceptor = Unmanaged<PasteInterceptor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    return interceptor.handle(type: type, event: event)
}
