import AVFoundation
import Cocoa
import CoreImage
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  private var faceTrackingPlugin: MacOSFaceTrackingPlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    faceTrackingPlugin = MacOSFaceTrackingPlugin.register(
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}

final class MacOSFaceTrackingPlugin: NSObject,
  FlutterStreamHandler,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  private static let methodChannelName = "madogiwa.vrm_lab/macos_face_tracking"
  private static let eventChannelName = "madogiwa.vrm_lab/macos_face_tracking_events"

  private let captureQueue = DispatchQueue(
    label: "jp.madogiwa.vrm-lab.camera",
    qos: .userInitiated
  )
  private let captureSession = AVCaptureSession()
  private let previewContext = CIContext(options: [.cacheIntermediates: false])
  private var eventSink: FlutterEventSink?
  private var configured = false
  private var configuredDeviceID: String?
  private var lastAnalysisTime = 0.0
  private var lastPreviewTime = 0.0
  private var startedAt = 0.0
  private var processedFrames = 0
  private var droppedFrames = 0

  static func register(messenger: FlutterBinaryMessenger) -> MacOSFaceTrackingPlugin {
    let plugin = MacOSFaceTrackingPlugin()
    let methods = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    methods.setMethodCallHandler { [weak plugin] call, result in
      guard let plugin else {
        result(FlutterError(code: "unavailable", message: "Tracker released.", details: nil))
        return
      }
      switch call.method {
      case "start":
        let arguments = call.arguments as? [String: Any]
        plugin.start(deviceID: arguments?["deviceId"] as? String, result: result)
      case "stop":
        plugin.stop(result: result)
      case "listDevices":
        result(plugin.videoDevices().map(plugin.deviceMap))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let events = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    events.setStreamHandler(plugin)
    return plugin
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func start(deviceID: String?, result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureAndStart(deviceID: deviceID, result: result)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        guard let self else { return }
        if granted {
          self.configureAndStart(deviceID: deviceID, result: result)
        } else {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "camera_denied",
                message: "カメラへのアクセスが許可されていません。",
                details: nil
              )
            )
          }
        }
      }
    case .denied, .restricted:
      result(
        FlutterError(
          code: "camera_denied",
          message: "システム設定でカメラへのアクセスを許可してください。",
          details: nil
        )
      )
    @unknown default:
      result(
        FlutterError(
          code: "camera_unavailable",
          message: "カメラの権限状態を取得できません。",
          details: nil
        )
      )
    }
  }

  private func configureAndStart(deviceID: String?, result: @escaping FlutterResult) {
    captureQueue.async { [weak self] in
      guard let self else { return }
      do {
        if !self.configured || self.configuredDeviceID != deviceID {
          if self.captureSession.isRunning {
            self.captureSession.stopRunning()
          }
          try self.configureCaptureSession(deviceID: deviceID)
        }
        self.processedFrames = 0
        self.droppedFrames = 0
        self.lastAnalysisTime = 0
        self.lastPreviewTime = 0
        self.startedAt = CFAbsoluteTimeGetCurrent()
        if !self.captureSession.isRunning {
          self.captureSession.startRunning()
        }
        self.emitDeviceEvent(type: "running")
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "camera_start_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func configureCaptureSession(deviceID: String?) throws {
    let devices = videoDevices()
    let camera = deviceID.flatMap { requestedID in
      devices.first { $0.uniqueID == requestedID }
    } ?? AVCaptureDevice.default(for: .video) ?? devices.first
    guard let camera else {
      throw NSError(
        domain: "MadogiwaVrmLab",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "利用可能なカメラがありません。"]
      )
    }
    let input = try AVCaptureDeviceInput(device: camera)

    captureSession.beginConfiguration()
    defer { captureSession.commitConfiguration() }
    for input in captureSession.inputs {
      captureSession.removeInput(input)
    }
    for output in captureSession.outputs {
      captureSession.removeOutput(output)
    }
    guard captureSession.canAddInput(input) else {
      throw NSError(
        domain: "MadogiwaVrmLab",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "カメラ入力を追加できません。"]
      )
    }
    if captureSession.canSetSessionPreset(.vga640x480) {
      captureSession.sessionPreset = .vga640x480
    }
    captureSession.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String:
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
    output.setSampleBufferDelegate(self, queue: captureQueue)
    guard captureSession.canAddOutput(output) else {
      throw NSError(
        domain: "MadogiwaVrmLab",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "映像フレーム出力を追加できません。"]
      )
    }
    captureSession.addOutput(output)
    configured = true
    configuredDeviceID = camera.uniqueID
  }

  fileprivate func videoDevices() -> [AVCaptureDevice] {
    var deviceTypes: [AVCaptureDevice.DeviceType] = [
      .builtInWideAngleCamera,
      .externalUnknown,
    ]
    if #available(macOS 14.0, *) {
      deviceTypes.append(.continuityCamera)
    }
    return AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .unspecified
    ).devices
  }

  fileprivate func deviceMap(_ device: AVCaptureDevice) -> [String: Any] {
    [
      "id": device.uniqueID,
      "name": device.localizedName,
      "isExternal": device.deviceType != .builtInWideAngleCamera,
    ]
  }

  private func stop(result: @escaping FlutterResult) {
    captureQueue.async { [weak self] in
      if self?.captureSession.isRunning == true {
        self?.captureSession.stopRunning()
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let now = CFAbsoluteTimeGetCurrent()
    if lastAnalysisTime > 0, now - lastAnalysisTime < 1.0 / 15.0 {
      droppedFrames += 1
      return
    }
    lastAnalysisTime = now
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      droppedFrames += 1
      return
    }
    emitPreview(pixelBuffer, now: now)

    let request = VNDetectFaceLandmarksRequest()
    request.revision = VNDetectFaceLandmarksRequestRevision3
    let handler = VNImageRequestHandler(
      cvPixelBuffer: pixelBuffer,
      orientation: .up,
      options: [:]
    )
    do {
      try handler.perform([request])
      processedFrames += 1
      guard let face = request.results?.max(by: {
        $0.boundingBox.width * $0.boundingBox.height
          < $1.boundingBox.width * $1.boundingBox.height
      }) else {
        emit(stats(type: "noFace", now: now))
        return
      }
      emit(faceEvent(face, now: now))
    } catch {
      emit(["type": "error", "message": error.localizedDescription])
    }
  }

  private func faceEvent(_ face: VNFaceObservation, now: Double) -> [String: Any] {
    let toDegrees = 180.0 / Double.pi
    var pitch = 0.0
    if #available(macOS 13.0, *) {
      pitch = face.pitch?.doubleValue ?? 0
    }
    var event = stats(type: "face", now: now)
    event["yawDegrees"] = (face.yaw?.doubleValue ?? 0) * toDegrees
    event["pitchDegrees"] = pitch * toDegrees
    event["rollDegrees"] = (face.roll?.doubleValue ?? 0) * toDegrees
    event["leftEyeOpen"] = eyeOpenness(face.landmarks?.leftEye)
    event["rightEyeOpen"] = eyeOpenness(face.landmarks?.rightEye)
    event["mouthOpen"] = mouthOpenness(
      face.landmarks?.innerLips ?? face.landmarks?.outerLips
    )
    event["confidence"] = Double(face.confidence)
    let bounds = face.boundingBox
    event["faceBounds"] = [
      Double(bounds.minX),
      Double(1 - bounds.maxY),
      Double(bounds.width),
      Double(bounds.height),
    ]
    event["landmarks"] = landmarkMap(face)
    return event
  }

  private func emitPreview(_ pixelBuffer: CVPixelBuffer, now: Double) {
    guard lastPreviewTime == 0 || now - lastPreviewTime >= 1.0 / 8.0 else {
      return
    }
    lastPreviewTime = now
    let image = CIImage(cvPixelBuffer: pixelBuffer)
    guard let cgImage = previewContext.createCGImage(image, from: image.extent) else {
      return
    }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let data = bitmap.representation(
      using: .jpeg,
      properties: [.compressionFactor: 0.5]
    ) else {
      return
    }
    emit([
      "type": "preview",
      "imageBytes": FlutterStandardTypedData(bytes: data),
    ])
  }

  private func landmarkMap(_ face: VNFaceObservation) -> [String: Any] {
    guard let landmarks = face.landmarks else { return [:] }
    let regions: [(String, VNFaceLandmarkRegion2D?)] = [
      ("contour", landmarks.faceContour),
      ("leftEyebrow", landmarks.leftEyebrow),
      ("rightEyebrow", landmarks.rightEyebrow),
      ("leftEye", landmarks.leftEye),
      ("rightEye", landmarks.rightEye),
      ("nose", landmarks.nose),
      ("noseCrest", landmarks.noseCrest),
      ("outerLips", landmarks.outerLips),
      ("innerLips", landmarks.innerLips),
    ]
    var mapped: [String: Any] = [:]
    for (name, region) in regions {
      guard let region else { continue }
      mapped[name] = normalizedPoints(region, in: face.boundingBox)
    }
    return mapped
  }

  private func normalizedPoints(
    _ region: VNFaceLandmarkRegion2D,
    in faceBounds: CGRect
  ) -> [[Double]] {
    region.normalizedPoints.map { point in
      let x = faceBounds.minX + point.x * faceBounds.width
      let visionY = faceBounds.minY + point.y * faceBounds.height
      return [Double(x), Double(1 - visionY)]
    }
  }

  private func stats(type: String, now: Double) -> [String: Any] {
    let elapsed = max(now - startedAt, 0.001)
    var values: [String: Any] = [
      "type": type,
      "fps": Double(processedFrames) / elapsed,
      "processedFrames": processedFrames,
      "droppedFrames": droppedFrames,
    ]
    if let device = activeDevice() {
      values["deviceId"] = device.uniqueID
      values["deviceName"] = device.localizedName
    }
    return values
  }

  private func activeDevice() -> AVCaptureDevice? {
    guard let configuredDeviceID else { return nil }
    return videoDevices().first { $0.uniqueID == configuredDeviceID }
  }

  private func emitDeviceEvent(type: String) {
    var event: [String: Any] = ["type": type]
    if let device = activeDevice() {
      event["deviceId"] = device.uniqueID
      event["deviceName"] = device.localizedName
    }
    emit(event)
  }

  private func eyeOpenness(_ region: VNFaceLandmarkRegion2D?) -> Double {
    guard let bounds = bounds(of: region), bounds.width > 0 else { return 1 }
    let aspect = bounds.height / bounds.width
    return clamp((aspect - 0.07) / 0.17)
  }

  private func mouthOpenness(_ region: VNFaceLandmarkRegion2D?) -> Double {
    guard let bounds = bounds(of: region), bounds.width > 0 else { return 0 }
    let aspect = bounds.height / bounds.width
    return clamp((aspect - 0.08) / 0.30)
  }

  private func bounds(of region: VNFaceLandmarkRegion2D?) -> CGRect? {
    guard let region, region.pointCount > 1 else { return nil }
    let points = region.normalizedPoints
    var minX = CGFloat.greatestFiniteMagnitude
    var minY = CGFloat.greatestFiniteMagnitude
    var maxX = -CGFloat.greatestFiniteMagnitude
    var maxY = -CGFloat.greatestFiniteMagnitude
    for index in 0..<region.pointCount {
      let point = points[index]
      minX = min(minX, point.x)
      minY = min(minY, point.y)
      maxX = max(maxX, point.x)
      maxY = max(maxY, point.y)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(event)
    }
  }
}
