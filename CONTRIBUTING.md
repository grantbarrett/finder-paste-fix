# Contributing

Thanks for helping harden Finder Paste Fix. This project is alpha, so the most useful contributions are careful bug reports, reproducible Finder edge cases, and narrowly scoped fixes.

## Issue Reports

Please include:

- macOS version
- Finder location, such as Desktop or Finder window
- Finder view mode
- Paste method, such as keyboard, menu, or context menu
- Example copied text
- Expected result and actual result
- Diagnostics output when possible, with private names redacted

## Pull Requests

Pull requests are welcome. Please keep changes focused and include a note about how you tested Finder rename behavior.

Before opening a PR:

```sh
./Scripts/build.sh
```

For permission-sensitive changes, test from the installed app:

```sh
./Scripts/install.sh
./Scripts/restart.sh
```

Avoid broad rewrites unless they directly reduce risk in Finder detection, pasteboard handling, or macOS permission lifecycle behavior.
