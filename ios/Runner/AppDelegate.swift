import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Start after super so Flutter engine + Keychain are fully available.
    BluetoothPrewarm.shared.start()   // triggers BT permission dialog on first launch
    ChipClient.shared.start()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: any FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    MatterBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}
