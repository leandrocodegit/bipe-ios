//
//  AuthManager.swift
//  OwnTracks
//
//  Equivalente ao AuthManager.kt do Android.
//  Gerencia o fluxo OAuth2/OIDC com Keycloak via AppAuth-iOS.
//
//  IMPORTANTE: Adicionar o pacote AppAuth-iOS via Xcode:
//  File > Add Package Dependencies > https://github.com/openid/AppAuth-iOS ~> 2.0
//

import Foundation
import AppAuth

@objc class AuthManager: NSObject {

    // MARK: - Constantes
    private static let issuerURI   = "https://auth.simodapp.com:8443/realms/sincroled"
    private static let clientID    = "sincroled"
    private static let redirectURI = "owntracks://auth"
    private static let scope       = "openid profile email"

    // MARK: - Persistência
    private static let authStateKey = "OIDAuthState"

    // MARK: - Estado
    private var authState: OIDAuthState? {
        didSet { saveAuthState() }
    }

    /// Guarda a sessão em andamento durante o redirect do browser
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    // MARK: - Singleton
    @objc static let shared = AuthManager()

    private override init() {
        super.init()
        loadAuthState()
    }

    // MARK: - Público

    /// Retorna `true` se há um token válido (ou renovável)
    @objc var isAuthorized: Bool {
        return authState?.isAuthorized == true
    }

    /// Inicia o fluxo de login OAuth via SFAuthenticationSession / ASWebAuthenticationSession.
    /// O resultado chega via completion: `(success: Bool, error: Error?) -> Void`
    func startLogin(presenting viewController: UIViewController,
                    completion: @escaping (Bool, Error?) -> Void) {

        guard let issuerURL = URL(string: AuthManager.issuerURI) else {
            completion(false, NSError(domain: "AuthManager", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "ISSUER_URI inválida"]))
            return
        }

        OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { [weak self] config, error in
            guard let self = self, let config = config else {
                completion(false, error)
                return
            }

            let request = OIDAuthorizationRequest(
                configuration: config,
                clientId: AuthManager.clientID,
                clientSecret: nil,
                scopes: [OIDScopeOpenID, OIDScopeProfile, "email"],
                redirectURL: URL(string: AuthManager.redirectURI)!,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )

            DispatchQueue.main.async {
                self.currentAuthorizationFlow = OIDAuthState.authState(
                    byPresenting: request,
                    presenting: viewController
                ) { authState, error in
                    if let authState = authState {
                        self.authState = authState
                        completion(true, nil)
                    } else {
                        completion(false, error)
                    }
                }
            }
        }
    }

    /// Processa o redirect URI vindo do iOS (chamado no AppDelegate / SceneDelegate)
    @objc func handleRedirectURL(_ url: URL) -> Bool {
        if let flow = currentAuthorizationFlow, flow.resumeExternalUserAgentFlow(with: url) {
            currentAuthorizationFlow = nil
            return true
        }
        return false
    }

    /// Retorna o Bearer token atual (com refresh automático se necessário).
    /// Chama o completion na thread que invocar, mas internamente usa background.
    func getBearerToken(completion: @escaping (String?) -> Void) {
        guard let authState = authState else {
            completion(nil)
            return
        }

        authState.performAction { accessToken, _, error in
            if let token = accessToken {
                completion("Bearer \(token)")
            } else {
                completion(nil)
            }
        }
    }

    /// Retorna o Access Token atual de forma síncrona
    @objc func getAccessToken() -> String? {
        return authState?.lastTokenResponse?.accessToken ?? authState?.accessToken
    }

    /// Extrai o `sub` do ID token (userId Keycloak)
    func getUserId() -> String? {
        guard let idToken = authState?.lastTokenResponse?.idToken else { return nil }
        let parts = idToken.components(separatedBy: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: base64Padded(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let sub = json["sub"] as? String
        else { return nil }
        return sub
    }

    /// Remove todos os tokens e estado salvo
    @objc func logout() {
        authState = nil
        UserDefaults.standard.removeObject(forKey: AuthManager.authStateKey)
    }

    // MARK: - Persistência interna

    private func saveAuthState() {
        guard let state = authState else {
            UserDefaults.standard.removeObject(forKey: AuthManager.authStateKey)
            return
        }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: false)
        UserDefaults.standard.set(data, forKey: AuthManager.authStateKey)
    }

    private func loadAuthState() {
        guard let data = UserDefaults.standard.data(forKey: AuthManager.authStateKey),
              let state = try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
        else { return }
        authState = state
    }

    // MARK: - Helpers

    private func base64Padded(_ string: String) -> String {
        var s = string.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return s
    }
}
