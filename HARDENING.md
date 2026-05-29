# Finder Paste Fix Hardening Notes

Use this checklist with Diagnostics enabled in the menu bar item. After each section, use **Open Diagnostics Log** or **Copy Diagnostics Log** if we need to tune Finder detection.

## Finder Rename Coverage

- Desktop icon rename
- Finder window icon view rename
- Finder window list view rename
- Finder window column view rename
- Finder window gallery view rename
- Folder rename
- File rename
- Extension-only rename, such as selecting just `txt`
- Rename with existing text fully selected
- Rename with insertion point in the middle of the name

## Finder False Positives

These should not sanitize or alter normal pasting.

- Finder search field
- Go to Folder sheet
- Save/Open panels if Finder is not actually frontmost
- Sidebar/location text fields, if present
- Any Finder dialog text field
- Tags/comment metadata fields, if present

## Clipboard Safety

- Plain text clipboard
- Rich text copied from Safari, Mail, Notes, or a web page
- File copied in Finder
- Image copied to clipboard
- Universal Clipboard from iPhone/iPad
- Clipboard manager enabled
- Very large copied text
- Rapid repeated `Cmd+V`
- Copy something new immediately after a sanitized paste
- Finder Edit > Paste with **Menu Paste Support** enabled
- Context-menu paste with **Menu Paste Support** enabled
- Leave rename mode without pasting after **Menu Paste Support** pre-sanitizes the clipboard

## Character Rules

- Colon: `Project: Notes`
- Multiple colons: `A:B:C`
- One line break
- Multiple line breaks
- Windows-style CRLF line breaks
- Leading dot: `.env` should be preserved
- Leading/trailing whitespace should be preserved
- Repeated spaces should be preserved
- Emoji and non-Latin text
- Slash `/`, which Finder may display differently from POSIX paths

## Permission And Lifecycle

- Create local signing identity
- Install to `~/Applications/FinderPasteFix.app`
- Reset privacy permissions after changing signing/install workflow
- First launch before Accessibility is granted
- After Accessibility is granted but before watcher refresh
- Quit and relaunch
- Restart Finder
- Sleep/wake
- Fast user switching or screen lock
- Remove Accessibility permission while app is running

## Current Known Risk Areas

- Finder rename detection is stricter now, but diagnostics still capture the ancestor chain so we can tune any missed inline rename view.
- The app temporarily rewrites the pasteboard, then restores it if the pasteboard has not changed.
- Mouse/menu paste is experimental and opt-in because it temporarily changes the clipboard while Finder appears to be inline-renaming an item.
