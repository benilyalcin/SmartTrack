# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

SmartTrack is a Flutter app (Android/iOS/Web) that pairs with an Aselsan STC-8255 digital tachograph over Bluetooth (BLE and Classic SPP) to read live driving data (speed, odometer, VIN/VRN, calibration constants) and surface EU 561/2006 driving-time compliance (continuous/daily/weekly/bi-weekly limits) to the driver. UI strings are Turkish-first with EN/DE translations; most in-app labels and comments are in Turkish.

## Commands

- Install deps: `flutter pub get`
- Run app: `flutter run` (pick a connected device/emulator, or `-d chrome` / `-d windows`)
- Static analysis: `flutter analyze`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Build: `flutter build apk` / `flutter build ios` / `flutter build web`

Note: `test/widget_test.dart` is still the unmodified Flutter counter-app template and does not test any real app code — don't treat it as a reference for existing behavior.

## Architecture

### State management
There is no external state-management package (no Provider/Riverpod/Bloc). App-wide state lives in a single `ChangeNotifier` (`lib/core/providers/app_state.dart`) exposed via a custom `InheritedWidget` (`AppStateProvider`). Any widget reads/mutates state via `AppStateProvider.of(context)`, which returns the `AppState` singleton instance for the current `AppStateProvider` in the tree (created once in `main.dart`, wrapping `MaterialApp.router`). `AppState` persists a subset of fields (tachograph mode, active driver) to `shared_preferences`.

`AppState` currently mixes several concerns: language selection, Bluetooth connection status, tachograph "mode" (which card is inserted: Sürücü/Şirket/Kontrol/Servis), the active driver, and live tachograph data (`TachographLiveData`). It also holds a `DrivingTimeCalculator` and precomputed `DrivingRuleResult`s for the four EU driving-time limits, currently seeded from `_simulateDrivingHistory()` (fake data) rather than real device history.

### Routing
`go_router` (`lib/core/router/app_router.dart`) drives navigation with a single `ShellRoute` wrapping `MainLayout`, which renders `NavigationRail` (desktop, width ≥ 768px) or bottom `NavigationBar` (mobile) around the four top-level pages: `/dashboard`, `/logs`, `/timeline`, `/settings`.

### Bluetooth + tachograph protocol stack
This is the core domain logic, split across `lib/core/services/`:

- **`bluetooth_service.dart`** (`AppBluetoothService`, singleton): unifies scanning/connecting across `flutter_blue_plus` (BLE) and `flutter_classic_bluetooth` (SPP/Classic) behind one `AppBluetoothDevice` model and one scan-results stream. On Classic SPP connect, it drives `_performTachographHandshake`, a sequential request/response exchange over the K-LINE protocol to pull VIN, VRN, odometer, speed, calibration constants, etc., then writes the result into `AppState` via `setTachographLiveData`.
- **`kline_protocol.dart`**: byte-level KWP2000/ISO 14230 frame builder/parser for the STC-8255's K-LINE interface (`KLineFrame`), the RDBI/WDBI record-ID constants (`TachoRecordId`), test-menu routine IDs (`TachoRoutineId`), and a response parser (`RdbiResponseParser`) plus the `TachographLiveData` model. Frame format is documented at the top of the file; follow it exactly when adding new record IDs or requests (checksum = sum of preceding bytes & 0xFF).
- **`tachograph_parser.dart`**: a separate, unrelated binary format — a generic TLV/ASN.1 decoder (`TlvDecoder`) plus a `.ddd` driver-card file parser (`DddFileParser`) producing `TachographDriverData`. This is for parsing downloaded driver-card files, distinct from the live K-LINE RDBI data in `kline_protocol.dart`. Don't conflate the two data models (`TachographLiveData` vs `TachographDriverData`).
- **`driving_time_calculator.dart`**: pure calculation logic for the four EU 561/2006 limits (continuous 4h30, daily 9h, weekly 56h, bi-weekly 90h) from a list of `TachographActivity` records. Explicitly a "solid baseline" per its own doc comment — it does not implement extended limits, split breaks, or ferry-mode exceptions.

### Localization
`lib/core/localization/localization.dart` is a single static `Map<String, Map<String, String>>` keyed by `'section.key'` (e.g. `'dashboard.speed'`), looked up via `AppLocalizations.getText(lang, key)` with TR as the fallback language. There is no `.arb`/gen-l10n pipeline — new strings are added directly to this map. Pages typically define a local `_t(key)` helper that reads the current language off `AppStateProvider`.

### Feature pages
Each top-level route has its own directory under `lib/features/<name>/` with a single large page file (dashboard, logs, settings, timeline are each 400–900+ lines) that both builds UI and contains its own private `_build*` helper methods — there isn't a separate widgets/viewmodel layer per feature.
