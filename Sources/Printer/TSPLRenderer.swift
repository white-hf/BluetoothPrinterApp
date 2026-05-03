//
//  TSPLRenderer.swift
//  ScanSystem
//
//  Created by John Tang on 2025-09-22.
//

import CoreGraphics
import Foundation
import PDFKit
import UIKit

struct TSPLRenderer {
    struct Output {
        let data: Data
        let widthDots: Int
        let heightDots: Int
        let bytesPerRow: Int
        let bitmap: Data
    }

    enum RendererError: LocalizedError {
        case pdfUnavailable
        case pageRenderingFailed
        case contextCreationFailed

        var errorDescription: String? {
            switch self {
            case .pdfUnavailable:
                return L10n.errInvalidPDF
            case .pageRenderingFailed:
                return L10n.errRenderPage
            case .contextCreationFailed:
                return L10n.errCreateContext
            }
        }
    }

    private let labelWidthMM: Int = 105   // media width in mm (10.5 cm)
    private let labelHeightMM: Int = 136  // media height (step) ≈ 6 inches (152.4 mm); TSPL expects integer mm

    func render(pdfData: Data, settings: PrintSettings, tno: String? = nil) throws -> Output {
        guard let document = PDFDocument(data: pdfData), let page = document.page(at: 0) else {
            throw RendererError.pdfUnavailable
        }

        let width = settings.resolution.widthDots
        let height = settings.resolution.heightDots
        let bytesPerRow = (width + 7) / 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw RendererError.contextCreationFailed
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.saveGState()

        let pdfRect = page.bounds(for: .mediaBox)
        let scaleX = CGFloat(width) / pdfRect.width
        let scaleY = CGFloat(height) / pdfRect.height
        context.scaleBy(x: scaleX, y: scaleY)
        context.translateBy(x: -pdfRect.minX, y: -pdfRect.minY)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        if settings.showWaybillOverlay, let sanitized = sanitizeWaybill(tno) {
            let lines = makeWaybillLines(from: sanitized)
            if !lines.isEmpty {
                drawWaybill(lines: lines, invert: settings.invert, in: context, width: width, height: height, resolution: settings.resolution)
            }
        }

        guard let buffer = context.data else {
            throw RendererError.pageRenderingFailed
        }

        let copy = Data(bytes: buffer, count: width * height)
        let monochrome = makeMonochrome(
            from: copy,
            width: width,
            height: height,
            settings: settings
        )

        let payload: Data
        if settings.compressionEnabled {
            payload = rleCompress(data: monochrome, bytesPerRow: bytesPerRow, rows: height)
        } else {
            payload = monochrome
        }

        // --- media geometry (PL80E: 203 dpi ≈ 8 dots/mm) ---
        let dotsPerMM = 8
        let labelWidthDots  = labelWidthMM  * dotsPerMM
        let labelHeightDots = labelHeightMM * dotsPerMM

        // Horizontal: center; align to 8-dot (1 byte) boundary to avoid bit-shift artifacts
        var xOffset = max(0, (labelWidthDots  - width)  / 2)
        xOffset = (xOffset / 8) * 8

        // Vertical: TOP-ALIGN for gap/continuous media (avoid accumulated overfeed)
        let topMarginMM = 0
        let yOffset = min(max(0, topMarginMM * dotsPerMM), max(0, labelHeightDots - height))
        // --- end media geometry ---

        var tspl = Data()
        tspl.append("SIZE \(labelWidthMM) mm,\(labelHeightMM) mm\r\n".data(using: .utf8)!)
        // Continuous media: no gap — advance per page is exactly SIZE height
        tspl.append("GAP 0 mm,0 mm\r\n".data(using: .utf8)!)
        // Disable automatic tear advance to avoid extra feed after PRINT
        // (Some TSPL printers advance to tear bar by default.)
        tspl.append("SET TEAR OFF\r\n".data(using: .utf8)!)

        tspl.append("CLS\r\n".data(using: .utf8)!)
        tspl.append("BITMAP \(xOffset),\(yOffset),\(bytesPerRow),\(height),\(settings.compressionEnabled ? 1 : 0),".data(using: .utf8)!)
        tspl.append(payload)
        tspl.append("\r\nPRINT 1\r\n".data(using: .utf8)!)
        // Compensate for PL80E's post-print forward feed (tear advance)
        tspl.append("BACKFEED 8 mm\r\n".data(using: .utf8)!)

        return Output(data: tspl, widthDots: width, heightDots: height, bytesPerRow: bytesPerRow, bitmap: monochrome)
    }

    func makePreviewImage(from output: Output, settings: PrintSettings) -> UIImage? {
        // Content (rendered bitmap) geometry
        let contentBytesPerRow = output.bytesPerRow
        let contentWidth = output.widthDots
        let contentHeight = output.heightDots
        let bitmap = output.bitmap
        guard bitmap.count == contentBytesPerRow * contentHeight else { return nil }

        // Simulate the real label canvas and placement used for printing
        // PL80E is 203 dpi ≈ 8 dots/mm (to match the centering logic in render())
        let dotsPerMM = 8
        let canvasWidth = labelWidthMM * dotsPerMM
        let canvasHeight = labelHeightMM * dotsPerMM

        // Offsets (match render()): horizontal center, vertical TOP align
        let xOffset = max(0, (canvasWidth  - contentWidth)  / 2)
        let topMarginDots = 0
        let yOffset = min(max(0, topMarginDots), max(0, canvasHeight - contentHeight))

        // Build an 8-bit grayscale preview of the WHOLE label (white background)
        var pixels = [UInt8](repeating: 255, count: canvasWidth * canvasHeight)
        let lsbFirst = settings.lsbFirst

        bitmap.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<contentHeight {
                for x in 0..<contentWidth {
                    let byte = base[y * contentBytesPerRow + (x / 8)]
                    let bitIndex = x % 8
                    let isBlack: Bool
                    if lsbFirst {
                        isBlack = (byte & (1 << bitIndex)) == 0
                    } else {
                        isBlack = (byte & (1 << (7 - bitIndex))) == 0
                    }
                    if isBlack {
                        let dstX = xOffset + x
                        let dstY = yOffset + y
                        if dstX >= 0 && dstX < canvasWidth && dstY >= 0 && dstY < canvasHeight {
                            pixels[dstY * canvasWidth + dstX] = 0
                        }
                    }
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let cgImage = CGImage(
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: canvasWidth,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private func makeMonochrome(from grayscale: Data, width: Int, height: Int, settings: PrintSettings) -> Data {
        let bytesPerRow = (width + 7) / 8
        var buffer = [UInt8](repeating: 0xFF, count: bytesPerRow * height)
        let threshold = UInt8(clamping: settings.threshold)

        grayscale.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                var byte: UInt8 = 0xFF
                var bitIndex = 0
                for x in 0..<width {
                    let gray = base[y * width + x]
                    var isBlack = gray < threshold
                    if settings.invert {
                        isBlack.toggle()
                    }
                    if isBlack {
                        if settings.lsbFirst {
                            byte &= ~(1 << bitIndex)
                        } else {
                            byte &= ~(1 << (7 - bitIndex))
                        }
                    }
                    bitIndex += 1
                    if bitIndex == 8 {
                        let outIndex = y * bytesPerRow + (x / 8)
                        buffer[outIndex] = byte
                        byte = 0xFF
                        bitIndex = 0
                    }
                }
                if bitIndex != 0 {
                    let outIndex = y * bytesPerRow + (width / 8)
                    buffer[outIndex] = byte
                }
            }
        }

        return Data(buffer)
    }

    private func rleCompress(data: Data, bytesPerRow: Int, rows: Int) -> Data {
        var output = Data()
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for row in 0..<rows {
                let rowPointer = base.advanced(by: row * bytesPerRow)
                var cursor = 0
                while cursor < bytesPerRow {
                    let value = rowPointer[cursor]
                    var count: UInt8 = 1
                    var idx = cursor + 1
                    while idx < bytesPerRow, rowPointer[idx] == value, count < 255 {
                        count &+= 1
                        idx &+= 1
                    }
                    output.append(count)
                    output.append(value)
                    cursor = idx
                }
            }
        }
        return output
    }
}

private extension String {
    func chunked(into size: Int) -> [String] {
        guard size > 0 else { return [self] }
        var result: [String] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(String(self[start..<end]))
            start = end
        }
        return result
    }
}

private extension TSPLRenderer {
    func sanitizeWaybill(_ tno: String?) -> String? {
        guard var raw = tno?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        raw.removeAll { character in
            character == "\"" || character == "\r" || character == "\n"
        }
        guard !raw.isEmpty else { return nil }
        let asciiOnly = String(raw.unicodeScalars.compactMap { scalar in
            scalar.isASCII ? Character(scalar) : nil
        })
        return asciiOnly.isEmpty ? nil : asciiOnly
    }

    func makeWaybillLines(from text: String) -> [String] {
        text.chunked(into: 42)
    }

    func drawWaybill(lines: [String], invert: Bool, in context: CGContext, width: Int, height: Int, resolution: PrintSettings.Resolution) {
        guard !lines.isEmpty else { return }
        let overlay = lines.joined(separator: "\n")
        let overlayString = overlay as NSString

        let fontSize: CGFloat = resolution == .standard ? 40 : 32
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: invert ? UIColor.white : UIColor.black,
            .paragraphStyle: paragraph
        ]

        let lineHeight = font.lineHeight
        let totalHeight = lineHeight * CGFloat(lines.count)
        let inset: CGFloat = 20
        let availableWidth = (CGFloat(width) - inset * 2) * 5 / 6
        let xOffset = inset + (CGFloat(width) - inset * 2 - availableWidth) / 2
        let bottomRect = CGRect(x: xOffset, y: CGFloat(height) - totalHeight - inset, width: availableWidth, height: totalHeight)
        let topRect = CGRect(x: xOffset, y: inset, width: availableWidth, height: totalHeight)

        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let backgroundColor = invert ? UIColor.black : UIColor.white
        context.setFillColor(backgroundColor.cgColor)
        context.fill(bottomRect.insetBy(dx: -4, dy: -2))
        context.fill(topRect.insetBy(dx: -4, dy: -2))
        UIGraphicsPushContext(context)
        overlayString.draw(in: bottomRect, withAttributes: attributes)
        overlayString.draw(in: topRect, withAttributes: attributes)
        UIGraphicsPopContext()
        context.restoreGState()
    }

}
