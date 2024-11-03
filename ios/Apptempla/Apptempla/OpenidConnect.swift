
import Foundation

struct OpenidConnectConfig: Decodable, Encodable {
    var authorization_endpoint: String
    var end_session_endpoint: String
    var issuer: String
    var id_token_signing_alg_values_supported: [String]
    var jwks_uri: String
    var response_types_supported: [String]
    var revocation_endpoint: String
    var scopes_supported: [String]
    var subject_types_supported: [String]
    var token_endpoint: String
    var token_endpoint_auth_methods_supported: [String]
    var userinfo_endpoint: String
}

struct TokenLifetimes: Decodable, Encodable {
    var idTokenLifetime: Int
    var accessTokenLifetime: Int
    var refreshTokenLifetime: Int
}

struct CodeExchangeResponse: Decodable, Encodable, Equatable {
    var id_token: String
    var refresh_token: String
    var access_token: String
}

struct RefreshTokensResponse: Decodable, Encodable, Equatable {
    var id_token: String
    var access_token: String
    var token_type: String
    var expires_in: Int
}

struct OidcTokens: Equatable, Encodable {
    var idToken: String
    var idTokenLastUse: Date
    var refreshToken: String
    var refreshTokenLastUse: Date
    var accessToken: String
    var accessTokenLastUse: Date
}

enum OidcStatus {
    case loadingConfiguration
    case ready(config: OpenidConnectConfig, tokenLifetimes: TokenLifetimes)
    case failed(message: String)
}

enum OidcLoginStatus: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn(tokens: OidcTokens)
}

let defaultTokenLifetimes = TokenLifetimes(idTokenLifetime: 60 * 60,
                                           accessTokenLifetime: 60 * 60,
                                           refreshTokenLifetime: 30 * 24 * 60 * 60)

let clientId = "57p1kaoktimu0ssk51gthm6j4m"
let configEndpoint = "http://localhost:3000/auth/.well-known/openid-configuration"
let redirectUrl = "pktestpool:"

protocol OpenidConnect: ObservableObject {
    var status: OidcStatus { get set }
    var loginStatus: OidcLoginStatus { get set }

    func setup()

    func startLogin() -> String?
    func logout()
    func refreshTokens()
}

class OpenidConnectImpl: OpenidConnect {
    @Published
    var status: OidcStatus = .loadingConfiguration

    @Published
    var loginStatus: OidcLoginStatus = .loggedOut

    init() {
        setup()
    }

    func setup() {
        let url = URL(string: configEndpoint)!
        let task = URLSession.shared.dataTask(with: url) {[weak self] (data, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("Getting OpenID config failed: \(error)")
                    self?.status = .failed(message: "Getting OpenID configuration failed")
                }

                guard let data = data else {
                    NSLog("Getting OpenID config failed: no data found")
                    self?.status = .failed(message: "Getting OpeNID configuration failed, no data received")
                    return
                }

                do {
                    let config = try JSONDecoder().decode(OpenidConnectConfig.self, from: data)
                    self?.status = .ready(config: config, tokenLifetimes: defaultTokenLifetimes)
                    NSLog("OpenID configuration fetched successfully")
                } catch let error {
                    NSLog("Parsing response failed: \(error.localizedDescription)")
                    self?.status = .failed(message: "Got invalid response from server")
                }
            }
        }
        task.resume()
    }

    func startLogin() -> String? {
        if case let .ready(config, _) = status {
            let authUrl = config.authorization_endpoint
            return "\(authUrl)?client_id=\(clientId)&response_type=code&scope=email+openid+profile&redirect_uri=\(redirectUrl)"
        }

        return nil
    }

    func logout() {
        guard case let .ready(config, _) = status,
              case let .loggedIn(tokens) = loginStatus else {
            return
        }

        var request = URLRequest(url: URL(string: config.revocation_endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = "token=\(tokens.refreshToken)&redirect_uri=\(redirectUrl)&client_id=\(clientId)".data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    NSLog("Logging out failed due to error: \(error)")
                    // Perhaps not so great, should the user be able to try again?
                    self?.status = .failed(message: "Logout failed")
                    self?.loginStatus = .loggedOut
                    return
                }

                self?.loginStatus = .loggedOut
                NSLog("Logged out successfully")

                if let data = data {
                    let s = String(decoding: data, as: UTF8.self)
                    NSLog("Received response, body body \(s)")
                }
            }
        }
        task.resume()
    }


    func handleCallback(url: URL) {
        let absoluteUrl = url.absoluteString
        guard absoluteUrl.hasPrefix(redirectUrl) else {
            NSLog("Callback URL is incorrect \(absoluteUrl)")
            status = .failed(message: "Login failed due to bad data received")
            return
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
            status = .failed(message: "Login failed due to bad data received")
            return
        }

        NSLog("Got code \(code)")
        exchangeCodeToTokens(code: code)
    }

    func exchangeCodeToTokens(code: String) {
        guard case let .ready(config, _) = status else {
            return
        }

        var request = URLRequest(url: URL(string: config.token_endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = "code=\(code)&grant_type=authorization_code&redirect_uri=\(redirectUrl)&client_id=\(clientId)".data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    NSLog("Getting tokens failed due to error: \(error)")
                    self?.status = .failed(message: "Login failed due to error when getting tokens")
                    return
                }

                guard let data else {
                    NSLog("Getting tokens failed: no data received")
                    self?.status = .failed(message: "Login failed due to no data found when getting tokens")
                    return
                }

                do {
                    let receivedTokens = try JSONDecoder().decode(CodeExchangeResponse.self, from: data)
                    let tokens = Self.mapCodeExchangeTokens(receivedTokens, defaultTokenLifetimes)
                    self?.loginStatus = .loggedIn(tokens: tokens)
                    NSLog("Logged in successfully")
                } catch let error {
                    NSLog("Parsing response failed: \(error.localizedDescription)")
                    self?.status = .failed(message: "Got invalid response from server")
                }
            }
        }
        task.resume()
    }

    func refreshTokens() {
        guard case let .ready(config, tokenLifetimes) = status,
              case let .loggedIn(tokens) = loginStatus else {
            return
        }

        var request = URLRequest(url: URL(string: config.token_endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = "grant_type=refresh_token&refresh_token=\(tokens.refreshToken)&redirect_uri=\(redirectUrl)&client_id=\(clientId)".data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    NSLog("Getting tokens failed due to error: \(error)")
                    self?.status = .failed(message: "Updating tokens failed due to error")
                    self?.loginStatus = .loggedOut
                    return
                }

                guard let data else {
                    NSLog("Getting tokens failed: no data received")
                    self?.status = .failed(message: "Updating token failed, no data received")
                    self?.loginStatus = .loggedOut
                    return
                }

                do {
                    let receivedTokens = try JSONDecoder().decode(RefreshTokensResponse.self, from: data)
                    let tokens = Self.mapTokenRefreshTokens(tokens, receivedTokens, tokenLifetimes)
                    print("Access token: \(receivedTokens.access_token)")
                    self?.loginStatus = .loggedIn(tokens: tokens)
                    NSLog("Tokens refreshed successfully")
                } catch let error {
                    NSLog("Parsing response failed: \(error.localizedDescription)")
                    self?.status = .failed(message: "Got invalid response from server")
                }
            }
        }
        task.resume()

    }

    private static func mapCodeExchangeTokens(_ receivedTokens: CodeExchangeResponse, _ lifetimes: TokenLifetimes) -> OidcTokens {
        return OidcTokens(idToken: receivedTokens.id_token,
                          idTokenLastUse: tokenLastUse(lifetimes.idTokenLifetime),
                          refreshToken: receivedTokens.refresh_token,
                          refreshTokenLastUse: tokenLastUse(lifetimes.refreshTokenLifetime),
                          accessToken: receivedTokens.access_token,
                          accessTokenLastUse: tokenLastUse(lifetimes.accessTokenLifetime))
    }

    private static func mapTokenRefreshTokens(_ tokens: OidcTokens,
                                              _ receivedTokens: RefreshTokensResponse,
                                              _ lifetimes: TokenLifetimes) -> OidcTokens {
        return OidcTokens(idToken: receivedTokens.id_token,
                                    idTokenLastUse: tokenLastUse(receivedTokens.expires_in),
                                    refreshToken: tokens.refreshToken,
                                    refreshTokenLastUse: tokens.refreshTokenLastUse,
                                    accessToken: receivedTokens.access_token,
                                    accessTokenLastUse: tokenLastUse(lifetimes.idTokenLifetime))
    }

    private static func tokenLastUse(_ lifetime: Int) -> Date {
        Date(timeIntervalSinceNow: Double(lifetime - 60))
    }
}

class OpenidConnectMock: OpenidConnect {

    var status: OidcStatus = .failed(message: "It's not working!")
    var loginStatus: OidcLoginStatus = .loggedOut

    func setup() { }

    func startLogin() -> String? { nil }
    func logout() { }
    func refreshTokens() { }
}
