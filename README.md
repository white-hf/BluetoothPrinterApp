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

## Requirements

- Xcode 16+ (tested with Xcode 26.2 toolchain in this environment)
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

## Notes

- Bluetooth permissions are configured in `Info.plist`.
- Queue uses a dictionary (`fileDictionary`) to map each print job to its imported local file URL.
- If your printer uses a different write characteristic UUID, update it in **Settings**.

## Build check used in this workspace

Unsigned build command:

```bash
xcodebuild -project BluetoothPrinterApp.xcodeproj -scheme BluetoothPrinterApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/BluetoothPrinterDerived CODE_SIGNING_ALLOWED=NO build
```

