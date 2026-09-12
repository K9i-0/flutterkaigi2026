import Flutter
import UIKit
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceDiagnosticsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.applicationRegistrar
    let channel = FlutterMethodChannel(
      name: "com.madogiwa.hazard/deviceDiagnostics",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getThermalState" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let processInfo = ProcessInfo.processInfo
      let thermalState: String
      switch processInfo.thermalState {
      case .nominal: thermalState = "nominal"
      case .fair: thermalState = "fair"
      case .serious: thermalState = "serious"
      case .critical: thermalState = "critical"
      @unknown default: thermalState = "unknown"
      }
      #if targetEnvironment(simulator)
        let isSimulator = true
      #else
        let isSimulator = false
      #endif
      let isIOSAppOnMac: Bool
      if #available(iOS 14.0, *) {
        isIOSAppOnMac = processInfo.isiOSAppOnMac
      } else {
        isIOSAppOnMac = false
      }

      // On demand only: no observer, polling timer or OS-setting change.
      // Battery observation is enabled locally when diagnostics is first read.
      result([
        "thermalState": thermalState,
        "isLowPowerModeEnabled": processInfo.isLowPowerModeEnabled,
        "systemUptime": processInfo.systemUptime,
        "isSimulator": isSimulator,
        "isIOSAppOnMac": isIOSAppOnMac,
        "metrics": [
          "processCpu": Self.processCpuSnapshot(),
          "activeProcessorCount": [
            "status": "available",
            "available": true,
            "source": "ProcessInfo.activeProcessorCount",
            "count": processInfo.activeProcessorCount,
          ],
          "memory": Self.memorySnapshot(),
          "battery": Self.batterySnapshot(),
          "screenBrightness": Self.screenBrightnessSnapshot(),
        ],
      ])
    }
    deviceDiagnosticsChannel = channel
  }

  private static func unavailable(_ reason: String, source: String) -> [String: Any] {
    ["status": "unavailable", "available": false, "reason": reason, "source": source]
  }

  private static func processCpuSnapshot() -> [String: Any] {
    // Public Darwin <sys/resource.h>: cumulative CPU time for this process,
    // including every thread. No system-wide utilization or GPU measurement.
    // https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getrusage.2.html
    let source = "getrusage(RUSAGE_SELF)"
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
      return unavailable("getrusageFailed", source: source)
    }
    let sampledAt = ProcessInfo.processInfo.systemUptime
    let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
    let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    return [
      "status": "available", "available": true, "source": source,
      "scope": "processAllThreads", "usageConvention": "oneCore100Percent",
      "userSeconds": user, "systemSeconds": system, "totalSeconds": user + system,
      "sampleSystemUptimeSeconds": sampledAt,
    ]
  }

  private static func memorySnapshot() -> [String: Any] {
    // Public Darwin <mach/task_info.h>, using the revision-length check from
    // Apple DTS: https://developer.apple.com/forums/thread/105088
    // Footprint is a memory-impact metric, not an exact Xcode gauge/GPU total.
    let source = "task_info(TASK_VM_INFO).phys_footprint"
    var info = task_vm_info_data_t()
    let capacity = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    var count = mach_msg_type_number_t(capacity)
    guard let revisionOffset = MemoryLayout.offset(of: \task_vm_info_data_t.min_address) else {
      return unavailable("taskInfoVersionUnavailable", source: source)
    }
    let minimumCount = mach_msg_type_number_t(revisionOffset / MemoryLayout<integer_t>.size)
    let code = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { integers in
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), integers, &count)
      }
    }
    guard code == KERN_SUCCESS else {
      return unavailable("taskInfoFailed", source: source)
    }
    guard count >= minimumCount else {
      return unavailable("taskInfoVersionUnavailable", source: source)
    }
    guard info.phys_footprint <= UInt64(Int64.max) else {
      return unavailable("invalidMetric", source: source)
    }
    return [
      "status": "available", "available": true, "source": source,
      "physicalFootprintBytes": Int64(info.phys_footprint),
    ]
  }

  private static func batterySnapshot() -> [String: Any] {
    // Reading UIDevice charge/state requires enabling local observation.
    // No notification subscription or power-mode change is made.
    // https://developer.apple.com/documentation/uikit/uidevice/isbatterymonitoringenabled
    let device = UIDevice.current
    if !device.isBatteryMonitoringEnabled { device.isBatteryMonitoringEnabled = true }
    let state: String
    switch device.batteryState {
    case .unknown: state = "unknown"
    case .unplugged: state = "unplugged"
    case .charging: state = "charging"
    case .full: state = "full"
    @unknown default: state = "unknown"
    }
    let level = Double(device.batteryLevel)
    let validLevel = level.isFinite && level >= 0 && level <= 1
    var snapshot: [String: Any] = [
      "status": "available", "available": true, "source": "UIDevice",
      "state": state, "monitoringEnabled": device.isBatteryMonitoringEnabled,
    ]
    if validLevel { snapshot["level"] = level }
    if state == "unknown" || !validLevel {
      snapshot["status"] = "unavailable"
      snapshot["available"] = false
      snapshot["reason"] = state == "unknown" ? "batteryStateUnknown" : "batteryLevelUnknown"
    }
    return snapshot
  }

  private static func screenBrightnessSnapshot() -> [String: Any] {
    let source = "UIWindowScene.screen.brightness"
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }) else {
      return unavailable("noForegroundScreen", source: source)
    }
    let value = Double(scene.screen.brightness)
    guard value.isFinite && value >= 0 && value <= 1 else {
      return unavailable("invalidScreenBrightness", source: source)
    }
    return ["status": "available", "available": true, "source": source, "value": value]
  }
}
