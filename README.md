# BluetoothPrinterApp (iOS)

A standalone iOS app extracted from the original warehouse project, focused only on Bluetooth thermal printing.

## What this app does

- Scans and connects to BLE thermal printers (optimized for Polono PL80E style devices).
- Imports PDF files from iPhone Files (local/on-device/cloud providers) and prints them.
- Converts PDF to TSPL bitmap commands and sends data in BLE chunks.
- Supports queued printing, retry/skip, auto-confirm timeout, and print history.
- Persists printer and rendering settings locally.

## Key change from original module

The original printer flow depended on a download API. This standalone app adds local file printing:

- Use **Choose PDF files** in the app.
- Files are copied into app storage.
- The print queue renders and prints directly from local files.

## Project structure

- `BluetoothPrinterApp.xcodeproj`: generated project.
- `Sources/App`: app entry and tab navigation.
- `Sources/Printer`: BLE manager, TSPL renderer, settings, device/config views.
- `Sources/Queue`: local file import, print queue coordinator, history.
- `Sources/Shared`: toast UI/feedback helpers.
- `Config/Info.plist`: app permissions and bundle metadata.
- `project.yml`: XcodeGen spec used to regenerate project.
- `docs/ARCHITECTURE.md`: architecture and data flow.
- `docs/TEST_PLAN.md`: test strategy and manual checks.

## Requirements

- Xcode 16+
- iOS 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

1. Open terminal at this folder:
   ```bash
   cd BluetoothPrinterApp
   ```
2. Generate project:
   ```bash
   xcodegen generate
   ```
3. Open `BluetoothPrinterApp.xcodeproj` in Xcode.
4. Set your **Signing Team** for target `BluetoothPrinterApp`.
5. Run on a real iPhone (Bluetooth printer testing requires device).

## How to use

1. Open **Devices** tab and scan/connect your printer.
2. Open **Settings** tab:
   - Tap **Use current connected printer**.
   - Adjust threshold/chunk size/resolution if needed.
3. Open **Print** tab:
   - Tap **Choose PDF files**.
   - Select one or multiple PDFs from iPhone Files.
   - Tap **Start** to begin printing queue.
4. Confirm each printed label or use retry/skip when needed.
5. View results in **History** tab.

## Compatibility

### Verified baseline

- iOS 16+ iPhone devices with Bluetooth enabled.
- Polono PL80E BLE thermal printer.

### Likely compatible

- TSPL-compatible BLE thermal printers that expose a writable BLE characteristic.
- You may need to configure characteristic UUIDs in app settings.

## Known limitations

- BLE only. Classic Bluetooth-only printers are not supported.
- Prints first page of selected PDF (multi-page batch splitting is not implemented).
- No real-time printer status protocol; completion uses manual confirm + timeout.
- Rendering and transport are tuned for shipping-label style PDFs.

## Open source project files

- `LICENSE`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `.github/ISSUE_TEMPLATE/*`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/ios.yml`

## Build command

```bash
xcodebuild -project BluetoothPrinterApp.xcodeproj -scheme BluetoothPrinterApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/BluetoothPrinterDerived CODE_SIGNING_ALLOWED=NO build
```
