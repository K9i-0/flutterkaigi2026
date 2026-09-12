import Flutter
import UIKit

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

      // A snapshot only: no observers, polling, identifiers or system changes.
      result([
        "thermalState": thermalState,
        "isLowPowerModeEnabled": processInfo.isLowPowerModeEnabled,
        "systemUptime": processInfo.systemUptime,
        "isSimulator": isSimulator,
        "isIOSAppOnMac": isIOSAppOnMac,
      ])
    }
    deviceDiagnosticsChannel = channel
  }
}
