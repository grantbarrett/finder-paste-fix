# Session Notes

Last updated: 2026-05-29

## Repository

- GitHub: https://github.com/grantbarrett/finder-paste-fix
- Branch: `main`
- Latest pushed commit before these notes: `9ebba6b Use Applications folder for installs`
- Project status in README: alpha

## Current Local State

- Workspace: `/Users/grantbarrett/Documents/Projects-Work/fix Finder pastes`
- Canonical installed app: `/Applications/FinderPasteFix.app`
- Bundle ID: `local.finderpastefix`
- Running process at handoff: `/Applications/FinderPasteFix.app/Contents/MacOS/FinderPasteFix`
- Code signing identity in use: `Apple Development: grantbarrett@gmail.com (B2L8F74K47)`
- Current privacy status from `./Scripts/check-permissions.sh`:
  - `kTCCServiceAccessibility`: allowed
  - `kTCCServiceListenEvent`: allowed

## Important Context

- The app began as a Finder rename paste sanitizer. It watches normal `Command-V` and only sanitizes when Finder appears to be inline-renaming a file or folder.
- Sanitizing is currently conservative:
  - `:` becomes ` - `
  - line breaks become spaces
  - leading/trailing whitespace and leading `.` are preserved
- Menu/context paste support is experimental and opt-in.
- Diagnostics write JSONL to `~/Library/Application Support/FinderPasteFix/diagnostics.jsonl`.
- The old per-user install path was replaced with `/Applications/FinderPasteFix.app`.
- If a legacy copy exists at `~/Applications/FinderPasteFix.app`, remove it before permission testing so macOS does not show or remember the wrong app copy.

## Useful Commands

```sh
./Scripts/build.sh
./Scripts/install.sh
./Scripts/restart.sh
./Scripts/check-permissions.sh
./Scripts/reset-privacy.sh
```

For permission-sensitive testing, always install and run from `/Applications/FinderPasteFix.app`.

## Next Good Tasks

- Remove any legacy `~/Applications/FinderPasteFix.app` copy on the local machine.
- Continue the hardening checklist in `HARDENING.md`, especially Finder view-mode coverage and false positives.
- Re-test permission lifecycle after any signing, bundle ID, or install-path change.
- Decide on a license and add `LICENSE`.
- Consider packaging/notarization once the alpha behavior stabilizes.
