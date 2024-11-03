
import SwiftUI

@main
struct ApptemplaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject
    private var oidc = OpenidConnectImpl()

    var body: some Scene {
        WindowGroup {
            ContentView(oidc: oidc)
                .onOpenURL { url in
                    NSLog("Opened with URL \(url.absoluteString)")
                    oidc.handleCallback(url: url)
                }
        }
    }
}
