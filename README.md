# Finder Paste Fix

Finder Paste Fix is an alpha macOS menu bar app that watches for normal paste commands while Finder is renaming a file or folder. When pasted text contains characters that Finder rejects in names, the app briefly sanitizes the clipboard so the rename can complete instead of failing with an error and undoing the edit.

The goal is intentionally narrow: keep the user's normal Finder rename workflow, including the usual `Command-V` paste, and avoid requiring a special paste command.

## Project Status

**Alpha.** This works in basic local testing, but it is still being hardened against Finder UI edge cases, macOS permission quirks, and clipboard-manager interactions.

Issue reports and pull requests are very welcome, especially reports with macOS version, Finder view mode, paste method, and diagnostics output.

## What It Does

- Watches for plain `Command-V` key-down events.
- Checks whether Finder appears to be focused on an inline file or folder rename field.
- Temporarily rewrites the pasteboard only for that paste.
- Restores the original clipboard afterward if nothing else changed it.
- Provides optional diagnostics for tuning Finder rename detection.
- Includes experimental menu/context paste support that is off by default.

## Sanitizing Rules

Current rules are deliberately conservative:

- `:` becomes ` - `
- line breaks become spaces

Legal filename text is preserved, including leading/trailing whitespace, repeated spaces, leading periods such as `.env`, emoji, and non-Latin text.

## Requirements

- macOS 14 or later
- Xcode
- A valid Apple Development code-signing identity is strongly recommended

Local/ad-hoc signing can make macOS Accessibility and Input Monitoring permissions behave unpredictably after rebuilds. The scripts try to use the first valid Apple Development identity reported by:

```sh
security find-identity -v -p codesigning
```

If you do not have an Apple Development identity, `./Scripts/create-local-signing-identity.sh` can create a local fallback.

## Build And Run

Build and install the app to `/Applications/FinderPasteFix.app`:

```sh
./Scripts/install.sh
```

Run the installed app:

```sh
./Scripts/run.sh
```

Restart the installed app:

```sh
./Scripts/restart.sh
```

`./Scripts/run.sh` intentionally refuses to launch the temporary Xcode/DerivedData build. Privacy permissions should be granted only to the stable installed copy:

```text
/Applications/FinderPasteFix.app
```

If `/Applications` is not writable on your machine, run the install from an admin account. For development-only installs, you can override the location with `FINDERPASTEFIX_INSTALL_DIR`, but permission testing should use `/Applications`.

You can build without installing:

```sh
./Scripts/build.sh
```

The temporary built app appears under:

```text
build/DerivedData/Build/Products/Debug/FinderPasteFix.app
```

Do not use Xcode's Run button for permission testing; it launches the build-folder copy, which can confuse macOS privacy permissions.

## First Run

1. Run `./Scripts/install.sh`.
2. Run `./Scripts/restart.sh`.
3. Open the Finder Paste Fix menu bar item.
4. Choose **Grant Accessibility Permission**.
5. Choose **Grant Input Monitoring Permission**.
6. Enable Finder Paste Fix in System Settings if macOS opens the Privacy & Security panel.
7. Use **Refresh / Restart Watcher** if the menu still shows the watcher inactive.

If permissions get stuck after changing signing or install workflow:

```sh
./Scripts/reset-privacy.sh
./Scripts/restart.sh
```

Then grant Accessibility and Input Monitoring again for `/Applications/FinderPasteFix.app`.

To verify what macOS is actually seeing:

```sh
./Scripts/check-permissions.sh
```

## Testing

Try these basic rename cases in Finder:

1. Copy `Project: Notes`.
2. Rename a file or folder in Finder.
3. Press `Command-V`.
4. Finder should receive `Project -  Notes` without showing the invalid-name error.

Then try multi-line copied text, Desktop renames, Finder window renames, and different Finder view modes. The broader test checklist lives in [HARDENING.md](HARDENING.md).

## Diagnostics

Turn on **Diagnostics** from the menu bar item when hardening Finder detection. The app writes newline-delimited JSON records to:

```text
~/Library/Application Support/FinderPasteFix/diagnostics.jsonl
```

Useful menu actions:

- **Record Current Focus Snapshot** records the currently focused accessibility element.
- **Copy Last Focus Snapshot** copies the latest raw focus snapshot.
- **Open Diagnostics Log** reveals the JSONL log file in Finder.
- **Copy Diagnostics Log** copies the log contents.
- **Clear Diagnostics Log** starts a fresh diagnostic run.
- **Copy App Diagnostics** copies the current bundle path and permission statuses.
- **Menu Paste Support** enables experimental mouse/menu/context paste handling.

Diagnostics include short previews of clipboard text and focused Finder values, so clear the log before testing with sensitive names.

## Known Risk Areas

- Finder's Accessibility hierarchy can vary by macOS version, view mode, and active sheet/dialog.
- Input Monitoring and Accessibility permissions are attached to app identity and launch path, so unstable signing or running from DerivedData can break trust.
- Clipboard managers and Universal Clipboard may interact oddly with temporary pasteboard rewrites.
- Menu/context paste support is experimental because it pre-sanitizes while Finder appears to be in rename mode.
- The app is not packaged, notarized, or distributed as a release build yet.

## Contributing

Issues and PRs are welcome. Good issue reports include:

- macOS version
- Finder view mode
- Whether the rename was on Desktop or in a Finder window
- Paste method, such as keyboard, menu, or context menu
- Expected pasted name and actual result
- Relevant diagnostics output with private names redacted

For code changes, please keep the app's scope narrow: automatic Finder rename paste sanitizing with minimal clipboard disturbance.
