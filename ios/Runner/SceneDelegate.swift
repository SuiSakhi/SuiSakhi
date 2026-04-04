import Flutter
import UIKit
import FirebaseAuth

class SceneDelegate: FlutterSceneDelegate {
  // Scene-based apps (iOS 13+) receive URLs here, not in AppDelegate.
  // Firebase Phone Auth reCAPTCHA callback must be handled here so it
  // never reaches Flutter / GoRouter.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for urlContext in URLContexts {
      if Auth.auth().canHandle(urlContext.url) {
        return // Firebase handled it — do NOT forward to Flutter
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  /// Some reCAPTCHA / auth returns arrive as universal links (NSUserActivity), not openURLContexts.
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL,
       Auth.auth().canHandle(url) {
      return
    }
    super.scene(scene, continue: userActivity)
  }
}
