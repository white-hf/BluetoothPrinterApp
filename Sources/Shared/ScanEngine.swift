import UIKit
import AVFoundation

protocol ScanEngineDelegate: AnyObject {
  func scanEngine(_ engine: ScanEngine, didOutput code: String)
  func scanEngineNeedsCameraPermission(_ engine: ScanEngine)
}

final class ScanEngine: NSObject {
  weak var delegate: ScanEngineDelegate?

  private let session = AVCaptureSession()
  private var metadataOutput: AVCaptureMetadataOutput?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var isConfigured = false
  private let sessionQueue = DispatchQueue(label: "com.swiftprintble.scanengine.sessionqueue") // Dedicated queue for session operations

  private func dbg(_ msg: String) {
    #if DEBUG
    print("[ScanEngine] \(msg)")
    #endif
  }

  func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
    if let layer = previewLayer { return layer }
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    previewLayer = layer
    return layer
  }

  func start() {
    dbg("start() called")
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      sessionQueue.async { // Dispatch to background queue
        self.configureIfNeeded()
        self.dbg("session.startRunning() (authorized)")
        self.session.startRunning()
      }
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async { // UI updates still on main thread
          guard let self else { return }
          self.dbg("camera permission granted=\(granted)")
          if granted {
            self.sessionQueue.async { // Dispatch to background queue
              self.configureIfNeeded()
              self.session.startRunning()
            }
          } else {
            self.delegate?.scanEngineNeedsCameraPermission(self)
          }
        }
      }
    default:
      dbg("camera permission denied")
      delegate?.scanEngineNeedsCameraPermission(self)
    }
  }

  func stop() {
    dbg("stop() called, isRunning=\(session.isRunning)")
    sessionQueue.async { // Dispatch to background queue
      if self.session.isRunning { self.session.stopRunning() }
    }
  }

  func setTorch(enabled: Bool) {
    guard let device = AVCaptureDevice.default(for: .video),
          device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = enabled ? .on : .off
      device.unlockForConfiguration()
    } catch { /* ignore */ }
  }

  /// Update the scanning area to match a normalized rect within the preview layer.
  /// - Parameters:
  ///   - previewLayer: The preview layer attached to the session.
  ///   - normalizedRect: A rect expressed in the preview layer's coordinate space as fractions (0...1),
  ///                     e.g. x=0.05, y=0.10, width=0.90, height=0.80.
  func updateRectOfInterest(using previewLayer: AVCaptureVideoPreviewLayer, normalizedRect: CGRect) {
    dbg("updateRectOfInterest normalized=\(normalizedRect)")
    guard let output = metadataOutput else { dbg("metadataOutput=nil"); return }
    guard let layerSession = previewLayer.session, layerSession == session else { dbg("previewLayer not bound to session yet"); return }

    // Ensure the preview has a valid frame and a live connection before converting
    guard previewLayer.bounds.width > 0, previewLayer.bounds.height > 0 else { dbg("previewLayer bounds are zero"); return }

    // Convert the normalized rect (0..1) to the preview layer's pixel coordinates
    let bounds = previewLayer.bounds
    let layerRect = CGRect(
      x: bounds.width * normalizedRect.origin.x,
      y: bounds.height * normalizedRect.origin.y,
      width: bounds.width * normalizedRect.size.width,
      height: bounds.height * normalizedRect.size.height
    )
    dbg("previewLayer.bounds=\(bounds)")
    dbg("layerRect=\(layerRect)")

    var rof = previewLayer.metadataOutputRectConverted(fromLayerRect: layerRect)
    if rof.width == 0 || rof.height == 0 {
      // If conversion failed (e.g., early in lifecycle), retry shortly and fallback to full frame temporarily
      dbg("metadataOutputRectConverted returned zero; scheduling retry and setting full frame temporarily")
      output.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
        self?.updateRectOfInterest(using: previewLayer, normalizedRect: normalizedRect)
      }
      return
    }
    dbg("rectOfInterest=\(rof)")
    output.rectOfInterest = rof
  }

  /// Update preview/output rotation using iOS 17 `videoRotationAngle` when available.
  /// Falls back to `videoOrientation` on older systems.
  func updatePreviewRotationAngle(_ angle: CGFloat, for layer: AVCaptureVideoPreviewLayer) {
    dbg("updatePreviewRotationAngle requested=\(angle)")
    if #available(iOS 17.0, *) {
      let corrected = (angle + 90).truncatingRemainder(dividingBy: 360) // compensate 90° left
      dbg("iOS17+ using videoRotationAngle, corrected=\(corrected)")
      if let conn = layer.connection, conn.isVideoRotationAngleSupported(corrected) {
        conn.videoRotationAngle = corrected
        dbg("preview connection angle=\(conn.videoRotationAngle)")
      } else { dbg("preview connection does NOT support corrected angle") }
      for output in session.outputs {
        for connection in output.connections where connection.isVideoRotationAngleSupported(corrected) {
          connection.videoRotationAngle = corrected
          dbg("output connection angle set=\(connection.videoRotationAngle)")
        }
      }
    } else {
      // Map common angles back to AVCaptureVideoOrientation for iOS < 17
      let orientation: AVCaptureVideoOrientation
      switch Int(angle) % 360 {
      case 0: orientation = .portrait
      case 90: orientation = .landscapeRight
      case 180: orientation = .portraitUpsideDown
      case 270: orientation = .landscapeLeft
      default: orientation = .portrait
      }
      dbg("<iOS17 fallback orientation=\(orientation)")
      if let conn = layer.connection, conn.isVideoOrientationSupported {
        conn.videoOrientation = orientation
      }
      for output in session.outputs {
        for connection in output.connections where connection.isVideoOrientationSupported {
          connection.videoOrientation = orientation
        }
      }
    }
  }

  @available(*, deprecated, message: "Use updatePreviewRotationAngle(_:for:) on iOS 17+.")
  func updatePreviewOrientation(_ orientation: AVCaptureVideoOrientation, for layer: AVCaptureVideoPreviewLayer) {
    // Best-effort mapping to angle and forward
    let angle: CGFloat
    switch orientation {
    case .portrait: angle = 0
    case .portraitUpsideDown: angle = 180
    case .landscapeRight: angle = 90
    case .landscapeLeft: angle = 270
    @unknown default: angle = 0
    }
    updatePreviewRotationAngle(angle, for: layer)
  }

  private func configureIfNeeded() {
    dbg("configureIfNeeded() isConfigured=\(isConfigured)")
    guard !isConfigured else { return }
    session.beginConfiguration()
    session.sessionPreset = .high

    // Input
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input) else {
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    dbg("input added: \(String(describing: AVCaptureDevice.default(for: .video)))")

    // Output
    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else {
      session.commitConfiguration()
      return
    }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    let desired: [AVMetadataObject.ObjectType] = [.qr, .ean8, .ean13, .code128, .code39, .code93, .pdf417, .aztec, .upce, .itf14]
    let available = output.availableMetadataObjectTypes
    let selected = desired.filter { available.contains($0) }
    output.metadataObjectTypes = selected
    dbg("available types=\(available)")
    dbg("selected types=\(selected)")
    metadataOutput = output
    output.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    dbg("default rectOfInterest set to full frame")

    dbg("commitConfiguration()")
    session.commitConfiguration()
    isConfigured = true
    dbg("configured ✅")
  }
}

extension ScanEngine: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let code = obj.stringValue, !code.isEmpty else { return }
    dbg("didOutput code=\(code)")
    delegate?.scanEngine(self, didOutput: code)
  }
}
