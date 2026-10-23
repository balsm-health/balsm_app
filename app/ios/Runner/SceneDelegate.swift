import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  // Under the UIScene lifecycle a link that LAUNCHES the app arrives here, in
  // the connection options — never in the app delegate's launchOptions, which
  // is the only place app_links looks. Hand it over so getInitialLink() sees
  // it. (Links that arrive while running are forwarded by FlutterSceneDelegate.)
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // balsm:// custom scheme
    if let url = connectionOptions.urlContexts.first?.url {
      AppLinks.shared.handleLink(url: url)
    }
    // https Universal Link
    else if let url = connectionOptions.userActivities
      .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL {
      AppLinks.shared.handleLink(url: url)
    }
  }
}
