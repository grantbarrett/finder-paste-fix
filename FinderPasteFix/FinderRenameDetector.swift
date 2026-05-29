import AppKit
import ApplicationServices

struct AccessibilityNodeSnapshot {
    let role: String?
    let subrole: String?
    let title: String?
    let description: String?
}

struct FocusSnapshot {
    let frontmostBundleIdentifier: String?
    let role: String?
    let subrole: String?
    let title: String?
    let description: String?
    let value: String?
    let parentRole: String?
    let parentSubrole: String?
    let parentTitle: String?
    let grandparentRole: String?
    let ancestors: [AccessibilityNodeSnapshot]
    let isFinderRenameCandidate: Bool

    var debugDescription: String {
        let ancestorDescription = ancestors.enumerated()
            .map { index, ancestor in
                """
                ancestor[\(index)].role: \(ancestor.role ?? "<nil>")
                ancestor[\(index)].subrole: \(ancestor.subrole ?? "<nil>")
                ancestor[\(index)].title: \(ancestor.title ?? "<nil>")
                ancestor[\(index)].description: \(ancestor.description ?? "<nil>")
                """
            }
            .joined(separator: "\n")

        return """
        frontmostBundleIdentifier: \(frontmostBundleIdentifier ?? "<nil>")
        role: \(role ?? "<nil>")
        subrole: \(subrole ?? "<nil>")
        title: \(title ?? "<nil>")
        description: \(description ?? "<nil>")
        value: \(value ?? "<nil>")
        parentRole: \(parentRole ?? "<nil>")
        parentSubrole: \(parentSubrole ?? "<nil>")
        parentTitle: \(parentTitle ?? "<nil>")
        grandparentRole: \(grandparentRole ?? "<nil>")
        \(ancestorDescription)
        isFinderRenameCandidate: \(isFinderRenameCandidate)
        """
    }
}

final class FinderRenameDetector {
    func currentFocus() -> FocusSnapshot {
        let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        guard bundleIdentifier == "com.apple.finder" else {
            return FocusSnapshot(
                frontmostBundleIdentifier: bundleIdentifier,
                role: nil,
                subrole: nil,
                title: nil,
                description: nil,
                value: nil,
                parentRole: nil,
                parentSubrole: nil,
                parentTitle: nil,
                grandparentRole: nil,
                ancestors: [],
                isFinderRenameCandidate: false
            )
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard
            result == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return FocusSnapshot(
                frontmostBundleIdentifier: bundleIdentifier,
                role: nil,
                subrole: nil,
                title: nil,
                description: nil,
                value: nil,
                parentRole: nil,
                parentSubrole: nil,
                parentTitle: nil,
                grandparentRole: nil,
                ancestors: [],
                isFinderRenameCandidate: false
            )
        }

        let focusedElement = focusedValue as! AXUIElement
        let parent = axElementAttribute(kAXParentAttribute, from: focusedElement)
        let grandparent = parent.flatMap { axElementAttribute(kAXParentAttribute, from: $0) }
        let ancestors = ancestorSnapshots(from: focusedElement)

        let role = stringAttribute(kAXRoleAttribute, from: focusedElement)
        let subrole = stringAttribute(kAXSubroleAttribute, from: focusedElement)
        let title = stringAttribute(kAXTitleAttribute, from: focusedElement)
        let description = stringAttribute(kAXDescriptionAttribute, from: focusedElement)
        let value = stringAttribute(kAXValueAttribute, from: focusedElement)
        let parentRole = parent.flatMap { stringAttribute(kAXRoleAttribute, from: $0) }
        let parentSubrole = parent.flatMap { stringAttribute(kAXSubroleAttribute, from: $0) }
        let parentTitle = parent.flatMap { stringAttribute(kAXTitleAttribute, from: $0) }
        let grandparentRole = grandparent.flatMap { stringAttribute(kAXRoleAttribute, from: $0) }

        let snapshot = FocusSnapshot(
            frontmostBundleIdentifier: bundleIdentifier,
            role: role,
            subrole: subrole,
            title: title,
            description: description,
            value: value,
            parentRole: parentRole,
            parentSubrole: parentSubrole,
            parentTitle: parentTitle,
            grandparentRole: grandparentRole,
            ancestors: ancestors,
            isFinderRenameCandidate: Self.isLikelyFinderRenameField(
                role: role,
                subrole: subrole,
                title: title,
                description: description,
                parentRole: parentRole,
                parentSubrole: parentSubrole,
                parentTitle: parentTitle,
                grandparentRole: grandparentRole,
                ancestors: ancestors
            )
        )

        return snapshot
    }

    private static func isLikelyFinderRenameField(
        role: String?,
        subrole: String?,
        title: String?,
        description: String?,
        parentRole: String?,
        parentSubrole: String?,
        parentTitle: String?,
        grandparentRole: String?,
        ancestors: [AccessibilityNodeSnapshot]
    ) -> Bool {
        guard role == kAXTextFieldRole as String else {
            return false
        }

        let ancestorRoles = ancestors.compactMap(\.role)
        if ancestorRoles.contains("AXSheet") || ancestorRoles.contains("AXDialog") {
            return false
        }

        let directFields = [
            subrole,
            title,
            description,
            parentRole,
            parentSubrole,
            parentTitle,
            grandparentRole
        ]

        let ancestorFields = ancestors.flatMap { [$0.role, $0.subrole, $0.title, $0.description] }

        let searchableFields = (directFields + ancestorFields)
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        let normalizedFields = " \(searchableFields) "
        let excludedTokens = [
            " search ",
            " go to ",
            " go-to ",
            " goto ",
            " comment ",
            " comments ",
            " tag ",
            " tags "
        ]

        if excludedTokens.contains(where: normalizedFields.contains) {
            return false
        }

        return true
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func axElementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard
            result == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func ancestorSnapshots(from element: AXUIElement) -> [AccessibilityNodeSnapshot] {
        var snapshots: [AccessibilityNodeSnapshot] = []
        var current = axElementAttribute(kAXParentAttribute, from: element)

        while let element = current, snapshots.count < 8 {
            snapshots.append(
                AccessibilityNodeSnapshot(
                    role: stringAttribute(kAXRoleAttribute, from: element),
                    subrole: stringAttribute(kAXSubroleAttribute, from: element),
                    title: stringAttribute(kAXTitleAttribute, from: element),
                    description: stringAttribute(kAXDescriptionAttribute, from: element)
                )
            )

            current = axElementAttribute(kAXParentAttribute, from: element)
        }

        return snapshots
    }
}
