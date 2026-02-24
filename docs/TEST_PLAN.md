# Test Plan

## Build validation

- Generate project: `xcodegen generate`
- Build unsigned:
  `xcodebuild -project BluetoothPrinterApp.xcodeproj -scheme BluetoothPrinterApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/BluetoothPrinterDerived CODE_SIGNING_ALLOWED=NO build`

## Functional tests

1. Printer discovery
- Scan BLE devices and connect to target printer.
- Disconnect and reconnect.

2. Settings persistence
- Update chunk size, threshold, UUIDs.
- Relaunch app and verify settings persist.

3. File import
- Select single and multiple PDFs from Files app providers.
- Verify files enqueue and import errors are surfaced.

4. Rendering and send
- Print valid PDFs and verify output alignment/readability.
- Test retry and skip when printer unavailable.

5. Queue behavior
- Confirm queued items process serially.
- Verify waiting-confirm timeout auto-advances.

6. History
- Verify success/failed/skipped entries persist after restart.
- Clear history and confirm persistence.

## Compatibility matrix (minimum)

- iOS: 16, 17, 18+
- Devices: at least one iPhone with BLE enabled
- Printers: Polono PL80E baseline, and one additional TSPL-compatible model
