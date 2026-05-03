# Changelog

## Version 1.1.0 (2026-05-03)

This is a major feature update that transforms the app from a simple local file printer into a full-featured waybill printing solution with automatic server discovery and a polished user experience.

这是一个重要的功能版本，将 App 从一个简单的本地文件打印工具，升级为一个功能齐全的、支持自动服务器发现和精美用户体验的运单打印解决方案。

### ✨ Features (新功能)

- **Waybill Printing as Core Feature**: Migrated waybill printing logic from the `ScanSystem` app. Users can now scan a waybill's barcode, and the app will automatically download the corresponding PDF from the server for printing.
- **运单打印核心功能**：从 `ScanSystem` 应用迁移了运单打印逻辑。用户现在可以通过扫描运单条码，自动从服务器下载对应的 PDF 并打印。

- **mDNS Auto-Discovery**: Implemented mDNS/Bonjour for both the server and the app. The app can now automatically discover and connect to the print server on the same local network, eliminating the need for manual IP address configuration.
- **mDNS 自动发现**：为服务器和 App 端实现了 mDNS/Bonjour 协议。App 现在可以自动发现并连接到同一局域网中的打印服务器，无需手动配置 IP 地址。

- **Full Internationalization (i18n)**: Added comprehensive support for English and Chinese. The UI now automatically adapts based on the user's iOS system language.
- **完全国际化 (i18n)**：增加了对英文和中文的全面支持。UI 会根据用户的 iOS 系统语言自动切换。

- **New Branding and Logo**: Renamed the app to "SwiftPrint BLE" (or "蓝印" in Chinese) and designed a new, modern app icon and logo to reflect its core functions of wireless connectivity and printing.
- **新品牌与 Logo**：将 App 更名为“SwiftPrint BLE”（中文“蓝印”），并设计了全新的、现代化的图标和 Logo，以体现其无线连接和打印的核心功能。

- **Enhanced User Feedback**:
  - Added a centered, 3-second toast notification to explicitly confirm when the app successfully auto-connects to the server.
  - Added a debug section in the settings page to show the real-time status of mDNS discovery.
- **增强的用户反馈**：
  - 增加了居中、持续 3 秒的 Toast 提示，在 App 成功自动连接到服务器时给予用户明确反馈。
  - 在设置页面增加了调试区域，以显示 mDNS 自动发现的实时状态。

### 🐛 Bug Fixes & Optimizations (问题修复与优化)

- **UI Responsiveness**: Fixed a warning where the camera session (`AVCaptureSession`) was started on the main thread. This operation is now dispatched to a background queue to prevent UI unresponsiveness.
- **UI 响应性**：修复了相机在主线程启动而可能导致 UI 卡顿的警告。相关操作已移至后台队列执行。

- **App Icon Visibility**: Resolved an issue where the app icon was not appearing on real devices (like iPhone 8). Regenerated the entire icon set to be fully opaque (no alpha channel) and conformant with all required sizes.
- **App 图标显示问题**：解决了 App 图标在真机（如 iPhone 8）上不显示的问题。重新生成了完全不透明且符合所有尺寸规范的全套图标资源。

- **Server-Side Stability**: Fixed multiple bugs in the Python print server, including `IndentationError` and `NameError` related to the `subprocess` module, ensuring the mDNS service broadcasts reliably on startup.
- **服务器稳定性**：修复了 Python 打印服务器中的多个错误，包括与 `subprocess` 模块相关的 `IndentationError` 和 `NameError`，确保 mDNS 服务在启动时能可靠地广播。

- **Build Failures**: Corrected several Swift compile-time errors that occurred during development, including type mismatches and incorrect view modifier usage.
- **编译失败**：修正了在开发过程中出现的多个 Swift 编译时错误，包括类型不匹配和视图修饰符使用不当的问题。
