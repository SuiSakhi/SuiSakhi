import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Earliest hook so native Firebase (Storage, Auth, etc.) never runs before `configure()`.
  override init() {
    super.init()
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
  }

  /// Runs before `didFinishLaunching` — reduces races where Firebase Core logs I-COR000005 before the default app exists.
  override func application(
    _ application: UIApplication,
    willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    return super.application(application, willFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase docs reference this hook; keeps I-COR000003 rare if willFinish order differs per iOS version.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    // Register for remote notifications — needed for Firebase Phone Auth silent push
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Forward APNs device token to Firebase (used for silent push OTP verification)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Let Firebase infer sandbox vs production from the embedded provisioning profile.
    // A hard-coded #if DEBUG split breaks Profile / ad-hoc builds (non-DEBUG but still sandbox APNs).
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Forward remote notifications to Firebase (phone auth callback)
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }

  // Handle reCAPTCHA URL (fallback when APNs not available)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) { return true }
    return super.application(app, open: url, options: options)
  }
}
