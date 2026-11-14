# KeyClean

A tiny macOS menu bar app that locks your keyboard so you can clean it.

- Click "Blocca tastiera" in the menu bar panel: every key, modifier and media key stops doing anything.
- Unlock from the trackpad or mouse only: hold the button for 1.5 seconds.
- The lock lives only while the app is running. Quit the app and the keyboard is free again.
- The Touch ID key cannot be blocked by any app: wipe it gently.

Website and download: https://keyclean.alessiocardelli.com

## Requirements

macOS 26 on Apple Silicon. Tested on macOS 26.5.1. The interface is in Italian.

## Install

1. Open the dmg and drag KeyClean to Applications.
2. The app is not signed with an Apple Developer account. On first launch macOS blocks it: open System Settings, Privacy & Security, and click "Open Anyway".
3. Turn on KeyClean in System Settings, Privacy & Security, Accessibility. This permission is what lets the app discard key presses.

## Privacy

KeyClean discards keyboard events while the lock is on. It does not read, store or send what you type, and it never connects to the internet.

## Build

No Xcode needed, only the Command Line Tools:

```sh
scripts/build.sh    # builds, signs ad hoc and installs in /Applications
scripts/package.sh  # makes the dmg in dist/release
```

## License

MIT. Made by Alessio Cardelli.
