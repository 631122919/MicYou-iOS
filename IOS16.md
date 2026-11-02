# MicYou for iOS 16

This is a fork of [MicYou-iOS](https://github.com/MicYou-Dev/MicYou-iOS) 1.2.1 ported to
**iOS 16.0 and later**, for devices that cannot install the upstream release (iOS 17+).

## What changed

- Deployment target 17.0 -> **16.0** (`Package.swift`, `-platform_version ios 16.0`)
- `@Observable` -> `ObservableObject` + `@Published` (`AppModel`, `AppSettings`, `ServerBrowser`,
  `UpdateChecker`, `NetworkMonitor`); the model forwards the changes of the objects it owns, so
  views still refresh when the browser or the settings change
- `@Environment(Type.self)` -> `@EnvironmentObject`, `@Bindable` removed
- iOS 17 only SwiftUI replaced with iOS 16 equivalents: `onChange(of:initial:)`,
  `sensoryFeedback`, `symbolEffect`/`numericText` content transitions, `phaseAnimator`,
  `scrollBounceBehavior`, `onGeometryChange`, `.smooth(duration:)`, `.spring(duration:bounce:)`,
  `.topBarLeading`
- The widget extension, the Live Activity and the App Intents are removed from this fork, they
  depend on iOS 17/18 (interactive Live Activities, Control Center buttons) and on
  `libswiftObservation`; the app, its discovery, streaming and UI are unchanged
- `NSSupportsLiveActivities` dropped from the Info.plist

## Build

`.github/workflows/ios16.yml` builds an unsigned IPA on a macOS runner and uploads it as the
`MicYou-iOS16` artifact. Sign it with AltStore, SideStore, Sideloadly or TrollStore.

Locally, with xtool and a Darwin SDK: `Tools/build-ipa.sh`, then `Tools/verify-ipa16.sh`.
