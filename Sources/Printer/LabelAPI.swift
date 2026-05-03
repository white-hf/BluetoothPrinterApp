//
//  LabelAPI.swift
//  ScanSystem
//
//  Created by John Tang on 2025-09-22.
//

import Foundation

enum LabelAPIError: LocalizedError {
    case invalidBaseURL
    case invalidResponse(status: Int)
    case emptyFile
    case decodingFailure
    case fileSaveFailed(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return L10n.errInvalidServer
        case .invalidResponse(let status):
            return L10n.errServerStatus(status)
        case .emptyFile:
            return L10n.errEmptyFile
        case .decodingFailure:
            return L10n.errDecoding
        case .fileSaveFailed(let err):
            return L10n.errSaveFile(err.localizedDescription)
        case .network(let error):
            return error.localizedDescription
        }
    }
}

struct LabelAPI {
    var session: URLSession = .shared
    var timeout: TimeInterval = 15

    func downloadLabel(tno: String, baseURL: URL?) async throws -> Data {
        guard let baseURL else { throw LabelAPIError.invalidBaseURL }
        var request = URLRequest(url: baseURL.appendingPathComponent("download_label_by_tno"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["tno": tno], options: [])

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LabelAPIError.decodingFailure
            }
            guard (200..<300).contains(http.statusCode) else {
                throw LabelAPIError.invalidResponse(status: http.statusCode)
            }
            guard !data.isEmpty else { throw LabelAPIError.emptyFile }
            return data
        } catch {
            if let apiError = error as? LabelAPIError { throw apiError }
            throw LabelAPIError.network(error)
        }
    }

    /// 下载缺失订单 CSV：GET /download_missing_orders
    /// - Parameter baseURL: 服务器基址（例如 https://print.example.com）
    /// - Returns: 已保存到临时目录的本地文件 URL
    func downloadMissingOrdersCSV(baseURL: URL?) async throws -> URL {
        guard let baseURL else { throw LabelAPIError.invalidBaseURL }
        var request = URLRequest(url: baseURL.appendingPathComponent("download_missing_orders"))
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        do {
            // 使用 download(for:) 获得临时文件 URL
            let (tempLocalUrl, response) = try await session.download(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LabelAPIError.decodingFailure
            }
            guard (200..<300).contains(http.statusCode) else {
                throw LabelAPIError.invalidResponse(status: http.statusCode)
            }

            // 生成建议文件名：优先 Content-Disposition，其次时间戳
            let suggestedName: String = {
                if let disposition = http.value(forHTTPHeaderField: "Content-Disposition"),
                   let name = parseFilename(fromContentDisposition: disposition) {
                    return name
                }
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyyMMdd_HHmmss"
                return "missing_orders_\(fmt.string(from: Date())).csv"
            }()

            let destURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(suggestedName)

            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.moveItem(at: tempLocalUrl, to: destURL)
                // 简单校验非空
                if let attrs = try? fm.attributesOfItem(atPath: destURL.path),
                   let fileSize = attrs[.size] as? NSNumber,
                   fileSize.intValue == 0 {
                    throw LabelAPIError.emptyFile
                }
                return destURL
            } catch {
                throw LabelAPIError.fileSaveFailed(error)
            }
        } catch {
            if let apiError = error as? LabelAPIError { throw apiError }
            throw LabelAPIError.network(error)
        }
    }

    /// 从 Content-Disposition 头中解析文件名（支持 filename 与 RFC 5987 的 filename*）
    private func parseFilename(fromContentDisposition header: String) -> String? {
        // 例：attachment; filename="missing.csv"
        // 或：attachment; filename*=UTF-8''missing.csv
        let parts = header.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        if let fnStar = parts.first(where: { $0.lowercased().hasPrefix("filename*=") }) {
            let value = fnStar.dropFirst("filename*=".count)
            let raw = String(value)
            if let range = raw.range(of: "''") {
                let encoded = String(raw[range.upperBound...])
                return encoded.removingPercentEncoding
            }
        }
        if let fn = parts.first(where: { $0.lowercased().hasPrefix("filename=") }) {
            var name = String(fn.dropFirst("filename=".count)).trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("\"") && name.hasSuffix("\"") {
                name.removeFirst()
                name.removeLast()
            }
            return name
        }
        return nil
    }
}
