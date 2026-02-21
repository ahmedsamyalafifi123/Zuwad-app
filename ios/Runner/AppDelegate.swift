import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure Firebase if GoogleService-Info.plist exists
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       FileManager.default.fileExists(atPath: path) {
      // Firebase will be configured automatically by the Flutter plugin
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
