import SwiftUI

struct ContentView<Oidc: OpenidConnect>: View {

    @ObservedObject
    var oidc: Oidc

    var body: some View {
        let statusText: String? = switch oidc.status {
        case .loadingConfiguration: "Loading configuration ..."
        case .failed(let message): message
        case .ready:
            switch oidc.loginStatus {
            case .loggedIn: "Logged in"
            case .loggedOut: ""
            case .loggingIn: "Logging in ..."
            }
        }

        VStack {
            NavigationStack {
                if case let .ready(config, _) = oidc.status {
                    NavigationLink("OpenID Connect config", destination: OidcConfigDebugView(config: config))
                    if oidc.loginStatus == .loggedOut {
                        Button("Log in", action: { self.login() })
                    }
                    if case .loggedIn = oidc.loginStatus  {
                        Button("Refresh tokens", action: { self.refreshTokens() })
                        Button("Log out", action: { self.logout() })
                    }
                }
            }.padding()
            if let statusText = statusText {
                Text(statusText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding([.bottom], 10)
            }
        }
    }

    private func login() {
        if let url = oidc.startLogin() {
            UIApplication.shared.open(URL(string: url)!)
        }
    }

    private func logout() {
        oidc.logout()
    }

    private func refreshTokens() {
        oidc.refreshTokens()
    }
}

struct OidcConfigDebugView: View {
    var config: OpenidConnectConfig

    var body: some View {
        let text = prettyPrint(config)

        VStack {
            ScrollView {
                Text(text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView(oidc: OpenidConnectMock())
}
