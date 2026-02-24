# Contributing

Thanks for contributing to BluetoothPrinterApp.

## Development setup

1. Install Xcode 16+ and XcodeGen.
2. Generate project:
   ```bash
   xcodegen generate
   ```
3. Build locally:
   ```bash
   xcodebuild -project BluetoothPrinterApp.xcodeproj -scheme BluetoothPrinterApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/BluetoothPrinterDerived CODE_SIGNING_ALLOWED=NO build
   ```

## Branching and commits

- Create a feature branch from `main`.
- Keep commits focused and small.
- Use clear commit messages.

## Pull requests

- Describe the problem and solution.
- Include screenshots/video for UI changes.
- Update docs (`README.md`, `docs/*`) when behavior changes.
- Ensure CI passes.

## Scope

- This project targets BLE thermal printing for iOS.
- Avoid adding unrelated warehouse/business flows back into this repo.
