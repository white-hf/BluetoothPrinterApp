import Foundation

enum L10n {
    static var isChinese: Bool {
        let lang = Locale.preferredLanguages.first ?? ""
        return lang.hasPrefix("zh")
    }
    
    static func tr(_ en: String, _ zh: String) -> String {
        return isChinese ? zh : en
    }
    
    // Brand
    static var appName: String { tr("SwiftPrint BLE", "蓝印") }
    
    // Common Strings
    static var ok: String { tr("OK", "确定") }
    static var cancel: String { tr("Cancel", "取消") }
    static var error: String { tr("Error", "错误") }
    static var success: String { tr("Success", "成功") }
    static var warning: String { tr("Warning", "警告") }
    static var info: String { tr("Info", "信息") }
    
    // BLE States
    static var bleConnected: String { tr("Connected", "已连接") }
    static var bleConnecting: String { tr("Connecting", "正在连接") }
    static var bleDisconnected: String { tr("Disconnected", "已断开") }
    static var bleScanning: String { tr("Scanning...", "正在扫描...") }
    static var bleFailed: String { tr("Failed", "连接失败") }
    
    // Job States
    static var jobQueued: String { tr("Queued", "等待打印") }
    static var jobDownloading: String { tr("Downloading", "下载中") }
    static var jobRendering: String { tr("Rendering", "渲染中") }
    static var jobSending: String { tr("Sending", "发送中") }
    static var jobWaitingConfirm: String { tr("Waiting confirm", "等待确认") }
    static var jobSuccess: String { tr("Success", "已完成") }
    static var jobFailed: String { tr("Failed", "失败") }
    static var jobSkipped: String { tr("Skipped", "已跳过") }
    
    // Tabs
    static var tabScan: String { tr("Scan Waybill", "扫描运单") }
    static var tabLocal: String { tr("Local Files", "本地文件") }
    static var tabDevices: String { tr("Devices", "设备管理") }
    static var tabSettings: String { tr("Settings", "系统设置") }
    static var tabHistory: String { tr("History", "历史记录") }
    
    // Buttons
    static var btnStart: String { tr("Start", "开始打印") }
    static var btnPause: String { tr("Pause", "暂停") }
    static var btnClear: String { tr("Clear", "清空") }
    static var btnRetry: String { tr("Retry", "重试") }
    static var btnSkip: String { tr("Skip", "跳过") }
    static var btnConfirm: String { tr("Confirm", "确认") }
    static var btnPreview: String { tr("Preview", "预览") }
    static var btnClose: String { tr("Close", "关闭") }
    static var btnSave: String { tr("Save", "保存") }
    static var btnConnect: String { tr("Connect", "连接") }
    static var btnScan: String { tr("Scan", "扫描") }
    static var btnStopScan: String { tr("Stop Scan", "停止扫描") }
    static var btnDisconnect: String { tr("Disconnect", "断开连接") }
    static var btnRefresh: String { tr("Refresh", "刷新") }
    
    // Titles & Prompts
    static var printPreview: String { tr("Print Preview", "打印预览") }
    static var searchPlaceholder: String { tr("Search...", "搜索...") }
    static var searchWaybillPrompt: String { tr("Search waybill number", "搜索运单号") }
    static var clearHistoryConfirm: String { tr("Clear all history?", "确定要清空所有历史记录吗？") }
    static var cameraPermissionTitle: String { tr("Camera Permission Required", "需要相机权限") }
    static var cameraPermissionMsg: String { tr("Please allow camera access in system settings to use scanning.", "请在系统设置中允许相机访问，以使用扫码功能。") }
    static var scanPrompt: String { tr("Place barcode inside frame to scan", "将条码置于框内以扫描") }
    static var noFileToShare: String { tr("No file to share", "未找到可分享的文件") }
    
    // Discovery & Status
    static var nearbyDevices: String { tr("Nearby Devices", "附近的设备") }
    static var actions: String { tr("Actions", "操作") }
    static var status: String { tr("Status", "状态") }
    static var unknown: String { tr("Unknown", "未知设备") }
    static var idle: String { tr("Idle", "空闲") }
    static var connectionSection: String { tr("Connection", "连接状态") }
    static var queueSection: String { tr("Queue", "队列") }
    static var currentJobSection: String { tr("Current Job", "当前任务") }
    static var serverSection: String { tr("Server", "服务器") }
    static var printerSection: String { tr("Printer", "打印机") }
    static var renderSection: String { tr("Render & Transfer", "渲染与传输") }
    
    // Settings Labels
    static var baseURLPlaceholder: String { tr("Base URL (e.g. http://1.2.3.4:5000)", "服务器地址 (如 http://1.2.3.4:5000)") }
    static var defaultPrinter: String { tr("Default Printer", "默认打印机") }
    static var notSet: String { tr("Not Set", "未设置") }
    static var autoConfirmSeconds: String { tr("Auto confirm (seconds)", "自动确认时间 (秒)") }
    static var useConnectedPrinter: String { tr("Use current connected printer", "使用当前连接的打印机") }
    static var thresholdLabel: String { tr("Threshold", "阈值") }
    static var invertLabel: String { tr("Invert", "反色") }
    static var lsbFirstLabel: String { tr("LSB First", "LSB优先") }
    static var compressionLabel: String { tr("TSPL Compression", "TSPL 压缩") }
    static var filenameOverlayLabel: String { tr("Draw filename overlay", "绘制文件名水印") }
    static var resolutionLabel: String { tr("Resolution", "分辨率") }
    static var bleChunkSizeLabel: String { tr("BLE chunk size", "蓝牙分片大小") }
    static var writeUUIDsLabel: String { tr("Write characteristic UUIDs (comma or newline separated)", "写入特征 UUID (逗号或换行分隔)") }
    static var testBluetooth: String { tr("Test Bluetooth", "测试蓝牙连接") }
    
    // Toasts & Messages
    static var printComplete: String { tr("Print Complete", "打印完成") }
    static var sentToPrinter: String { tr("Sent to printer", "已发送到打印机") }
    static var batchPrintStarted: String { tr("Batch printing started", "已开始发送当前批次") }
    static var downloadMissingStarted: String { tr("Downloading missing list...", "正在下载缺失列表…") }
    static var downloadComplete: String { tr("Download complete", "下载完成") }
    static var settingsSaved: String { tr("Settings saved", "设置已保存") }
    static var bleConnectionHealthy: String { tr("Bluetooth connection is healthy", "蓝牙连接正常") }
    static var bleNoPrinters: String { tr("No printers found yet.", "尚未发现打印机。") }
    static var bleSetupFirst: String { tr("Go to Devices tab and connect a printer first.", "请先前往设备管理页面连接打印机。") }
    static var choosePDFFiles: String { tr("Choose PDF files", "选择 PDF 文件") }
    static var queueEmpty: String { tr("Queue is empty.", "队列为空。") }
    static var queueEmptyMsg: String { tr("Queue is empty, waiting for new waybill scan.", "队列为空，等待扫描新的运单号。") }
    static var scannerOn: String { tr("Scanner On", "扫描已开启") }
    static var scannerPaused: String { tr("Scanner Paused", "扫描已暂停") }
    static var downloadMissingList: String { tr("Download Missing List", "下载缺失列表") }
    static var noHistoryYet: String { tr("No history yet", "暂无历史记录") }
    static var waitConfirmation: String { tr("Waiting confirmation", "等待确认") }
    
    static func totalItems(_ count: Int) -> String {
        return tr("Total \(count)", "共 \(count) 条记录")
    }
    
    static func totalItemsBrief(_ count: Int) -> String {
        return tr("Total \(count) items", "共 \(count) 项")
    }
    
    static func queueCount(_ count: Int) -> String {
        return tr("Queue: \(count)", "队列：\(count)")
    }
    
    static func importFailed(_ err: String) -> String {
        return tr("Import failed: \(err)", "导入失败：\(err)")
    }
    
    static func filePickerError(_ err: String) -> String {
        return tr("File picker error: \(err)", "文件选择错误：\(err)")
    }
    
    static func addedFiles(_ count: Int) -> String {
        return tr("Added \(count) file(s)", "已添加 \(count) 个文件")
    }
    
    static func retryCount(_ count: Int) -> String {
        return tr("Retry \(count) times", "重试 \(count) 次")
    }
    
    static func inQueue(_ tno: String) -> String {
        return tr("Already in queue: \(tno)", "已在队列中：\(tno)")
    }
    
    static func addedToQueue(_ tno: String) -> String {
        return tr("Added to queue: \(tno)", "已加入队列：\(tno)")
    }

    static func skippedJob(_ name: String) -> String {
        return tr("Skipped \(name)", "已跳过 \(name)")
    }
    
    static func printFailed(_ err: String) -> String {
        return tr("Print failed: \(err)", "打印失败：\(err)")
    }
    
    static func noWaybillFound(_ tno: String) -> String {
        return tr("No waybill PDF found, skipped: \(tno)", "没有需要打印的运单PDF，已跳过：\(tno)")
    }

    static func bleDiscoveryStatus(discovered: String?) -> String {
        if let d = discovered {
            return tr("Auto Connected: \(d)", "自动连接：\(d)")
        } else {
            return tr("No server discovered (mDNS)", "未发现服务器 (mDNS)")
        }
    }
    
    static func manualServerStatus(_ url: String) -> String {
        return tr("Manual Connected: \(url)", "手动连接：\(url)")
    }
    
    static func bleConnectingTo(_ name: String?) -> String {
        let n = name ?? "-"
        return tr("Connecting: \(n)", "正在连接：\(n)")
    }
    
    static func bleConnectedTo(_ name: String?) -> String {
        let n = name ?? "-"
        return tr("Connected: \(n)", "已连接：\(n)")
    }
    
    static func bleFailedWithError(_ error: String) -> String {
        return tr("Failed: \(error)", "失败：\(error)")
    }
    
    static func autoConnectedToServer(_ serverName: String) -> String {
        return tr("Auto-connected to \(serverName)", "已自动连接到 \(serverName)")
    }
    
    static func connectingTo(_ name: String?) -> String {
        let n = name ?? "-"
        return tr("Connecting → \(n)", "正在连接 → \(n)")
    }
    
    static func connectedTo(_ name: String?) -> String {
        let n = name ?? "-"
        return tr("Connected: \(n)", "已连接：\(n)")
    }
    static func failedWithError(_ error: String) -> String {
        return tr("Failed: \(error)", "失败：\(error)")
    }

    static var errInvalidServer: String { tr("Invalid server address", "无效的服务器地址") }
    static func errServerStatus(_ status: Int) -> String { tr("Server returned error code \(status)", "服务器返回错误码 \(status)") }
    static var errEmptyFile: String { tr("Server returned empty file", "服务器返回空文件") }
    static var errDecoding: String { tr("Response decoding failed", "响应解析失败") }
    static func errSaveFile(_ msg: String) -> String { tr("Failed to save file: \(msg)", "保存文件失败：\(msg)") }

    static var errInvalidPDF: String { tr("Invalid PDF data", "PDF 数据无效") }
    static var errRenderPage: String { tr("Failed to render PDF page", "无法渲染 PDF 页面") }
    static var errCreateContext: String { tr("Failed to create rendering context", "创建渲染上下文失败") }

    static var bleBusy: String { tr("Printer is still sending data", "打印机仍在发送数据") }
    static var bleNotReady: String { tr("Printer not connected", "打印机未连接") }
    static var bleMissingChar: String { tr("Write characteristic not found", "未找到写入特征") }
    static var bleInvalidParams: String { tr("Invalid parameters", "参数非法") }

    static var resStandard: String { tr("Standard 800x1200", "标准 800x1200") }
    
    static var resFast: String { tr("Fast 600x900", "快速 600x900") }
    static var setupPrinterFirst: String { tr("Set a default printer first", "请先设置默认打印机") }
    static var noPreview: String { tr("No preview available", "无可预览内容") }
    static var noPagesToPreview: String { tr("No pages to preview", "无预览页面") }
}
