# OBD2 App

Flutter client for the OBD2 vehicle diagnostics project.

## Toolchain

- Flutter 3.47.0, the stable release selected for T-00-01
- Dart 3.13.0
- Flutter framework revision `4cf24164269a5ebf0c16a028a00727d0e77bbb05`
- iOS and Android only for V1

Run Flutter through FVM so every developer and CI job uses the version pinned in
the repository root:

```sh
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run
```

## Identifier status

`obd2app` is a neutral internal package name. The generated Android application
ID and iOS bundle ID, `com.example.obd2app`, are local placeholders. Do not use
them for store signing, RevenueCat, OAuth, push notifications, or production
services. Replace them after the company-owned reverse domain is confirmed.

## Scope

This directory currently contains the T-00-01 platform scaffold and architecture
folders only. Routing, state management, the five-tab shell, OBD support, cloud
services, subscriptions, and AI diagnosis belong to later backlog tasks.
