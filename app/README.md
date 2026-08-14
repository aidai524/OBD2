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
```

## Environments

The tracked files under `config/` select exactly one environment. Public
Supabase client values come from an ignored local env file:

```sh
cp .env.example .env.dev
cp .env.example .env.staging
cp .env.example .env.prod
```

Replace the placeholders in each copy, then select an environment at build or
run time. Keep the local env file first so the tracked profile remains the
authoritative `APP_ENV` value. The application rejects unchanged example
placeholders at startup:

```sh
fvm flutter run \
  --dart-define-from-file=.env.dev \
  --dart-define-from-file=config/dev.json

fvm flutter run \
  --dart-define-from-file=.env.staging \
  --dart-define-from-file=config/staging.json

fvm flutter run \
  --dart-define-from-file=.env.prod \
  --dart-define-from-file=config/prod.json
```

Only public client configuration belongs in these files. Supabase service-role
keys, LLM keys, RevenueCat REST or webhook secrets, signing material, and
database credentials must remain in their server-side secret stores.

`AppConfig.fromCompileTime()` rejects missing or unknown profiles, malformed
URLs, non-HTTPS staging/production URLs, and missing publishable keys. It also
redacts the key from diagnostic output.

## Dependency baseline

T-00-02 pins the V1 packages and commits both the Dart and iOS Swift Package
Manager resolution files. T-00-03 wires Riverpod and go_router for the
application shell only. BLE, Supabase, Drift, RevenueCat, reports, and
notifications remain deferred to their backlog tasks and have no runtime
initialization yet.

Compatibility pins are intentional. The stable code generators are kept on a
combination that resolves without a prerelease Analyzer stack, and
`flutter_secure_storage` remains on 10.3.1 until the Flutter Android toolchain can
build the plugin's compileSdk 37 requirement. Dependency upgrades are separate
tasks and must repeat both Dart tests and native builds.

Android SPP is locked to an in-house platform channel over the official Android
`BluetoothSocket` / RFCOMM API. No third-party SPP Flutter package is included.

## Identifier status

`obd2app` is a neutral internal package name. The generated Android application
ID and iOS bundle ID, `com.example.obd2app`, are local placeholders. Do not use
them for store signing, RevenueCat, OAuth, push notifications, or production
services. Replace them after the company-owned reverse domain is confirmed.

## Presentation baseline

T-00-04 fixes V1 to an accessible Material 3 dark theme, the system font, and
the documented design colors. Runtime localization is intentionally limited to
`en-US`; all current user-visible shell and recovery copy comes from Flutter's
generated localization resources. Android and iOS launch backgrounds use the
same dark background token before Flutter renders its first frame.

The unit preference defaults to imperial and can be changed in memory through
Riverpod. Persistence and the Settings control belong to T-04-07. Conversions
are display-only: OBD/domain values stay in their documented canonical units,
and database mileage remains stored as integer miles. The API deliberately
distinguishes PID distance sourced in kilometers from stored mileage sourced in
miles.

V1 display formatting uses en-US grouping and removes unnecessary trailing
zeroes:

| Canonical source | Imperial display | Metric display | Maximum decimals |
|---|---|---|---|
| Temperature in `°C` | `°F` | `°C` | 1 |
| Speed in `km/h` | `mph` | `km/h` | 0 |
| Pressure in `kPa` | `psi` | `kPa` | 1 imperial / 0 metric |
| PID distance in `km` | `mi` | `km` | 1 imperial / 0 metric |
| Stored mileage in `mi` | `mi` | `km` | 0 |

Safety rules and thresholds must continue to use unrounded canonical values,
never the formatted display value.

## Scope

This directory currently contains the T-00-01 platform scaffold, the T-00-02
dependency and environment configuration baseline, the T-00-03 Riverpod /
go_router application shell, and the T-00-04 theme, en-US localization, and unit
display framework. The shell has Garage, Diagnostics, Live Data, History, and
Settings tabs, plus recoverable startup and unknown-route states. The tab pages
are placeholders: OBD support, onboarding, cloud services, subscriptions, and
AI diagnosis belong to later backlog tasks.
