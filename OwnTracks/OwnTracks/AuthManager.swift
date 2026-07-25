//
//  AuthManager.swift
//  OwnTracks
//
//  Gerencia autenticação OAuth2/OIDC com Keycloak usando ASWebAuthenticationSession
//  (framework nativo do iOS — sem dependências externas).
//
//  Implementa PKCE (Proof Key for Code Exchange) para segurança máxima.
//  Equivalente ao AuthManager.kt do projeto Android (bipe-android).
//

import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

@objc(AuthManager)
class AuthManager: NSObject {

    // MARK: - Singleton

    @objc static let shared = AuthManager()

    // MARK: - Constantes Keycloak

    private static let authEndpoint  = "https://auth.simodapp.com:8443/realms/sincroled/protocol/openid-connect/auth"
    private static let tokenEndpoint = "https://auth.simodapp.com:8443/realms/sincroled/protocol/openid-connect/token"
    private static let clientID      = "sincroled"
    private static let redirectURI   = "owntracks://auth"
    private static let scopes        = "openid profile email"

    // MARK: - Chaves de armazenamento

    private static let accessTokenKey  = "bipe_access_token"
    private static let refreshTokenKey = "bipe_refresh_token"
    private static let idTokenKey      = "bipe_id_token"
    private static let expiryKey       = "bipe_token_expiry"

    // MARK: - Estado interno

    private var accessToken:  String?
    private var refreshToken: String?
    private var idToken:      String?
    private var tokenExpiry:  Date?

    private var codeVerifier: String?
    private var webSession:   ASWebAuthenticationSession?

    // MARK: - Init

    private override init() {
        super.init()
        loadTokens()
    }

    // MARK: - API Pública

    /// Retorna true se há token de acesso ou refresh token disponível.
    @objc var isAuthorized: Bool {
        let hasRefresh = !(refreshToken ?? "").isEmpty
        let hasValidAccess = accessToken != nil && (tokenExpiry.map { Date() < $0 } ?? false)
        return hasValidAccess || hasRefresh
    }

    /// Inicia o fluxo de login OAuth com PKCE via ASWebAuthenticationSession.
    /// O resultado é retornado no completion handler (na main thread).
    func startLogin(presenting viewController: UIViewController,
                    completion: @escaping (Bool, Error?) -> Void) {

        // 1. Gerar code verifier + challenge (PKCE)
        let verifier   = generateCodeVerifier()
        let challenge  = generateCodeChallenge(from: verifier)
        let state      = UUID().uuidString
        self.codeVerifier = verifier

        // 2. Montar URL de autorização
        var components = URLComponents(string: AuthManager.authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "response_type",          value: "code"),
            URLQueryItem(name: "client_id",              value: AuthManager.clientID),
            URLQueryItem(name: "redirect_uri",           value: AuthManager.redirectURI),
            URLQueryItem(name: "scope",                  value: AuthManager.scopes),
            URLQueryItem(name: "state",                  value: state),
            URLQueryItem(name: "code_challenge",         value: challenge),
            URLQueryItem(name: "code_challenge_method",  value: "S256"),
        ]

        guard let authURL = components.url,
              let callbackScheme = URL(string: AuthManager.redirectURI)?.scheme else {
            completion(false, makeError("URL de autorização inválida"))
            return
        }

        // 3. Abrir browser de autenticação
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            // Cancelamento pelo usuário
            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                DispatchQueue.main.async { completion(false, self.makeError("Login cancelado")) }
                return
            }

            if let error = error {
                DispatchQueue.main.async { completion(false, error) }
                return
            }

            // Extrair código de autorização do callback URL
            guard let callbackURL = callbackURL,
                  let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
                DispatchQueue.main.async {
                    completion(false, self.makeError("Código de autorização não encontrado"))
                }
                return
            }

            // 4. Trocar o código pelo access token
            self.exchangeCode(code) { success, error in
                DispatchQueue.main.async { completion(success, error) }
            }
        }

        // Contexto de apresentação (LoginViewController deve conformar ao protocolo)
        if let provider = viewController as? ASWebAuthenticationPresentationContextProviding {
            session.presentationContextProvider = provider
        }
        session.prefersEphemeralWebBrowserSession = false
        self.webSession = session

        DispatchQueue.main.async { session.start() }
    }

    /// Compatibilidade com o handler de openURL do AppDelegate.
    /// Com ASWebAuthenticationSession o redirect é interceptado pelo OS — não é necessário.
    @objc func handleRedirectURL(_ url: URL) -> Bool {
        return false
    }

    /// Retorna um Bearer token válido (faz refresh automaticamente se necessário).
    func getBearerToken(completion: @escaping (String?) -> Void) {
        // Token ainda válido
        if let token = accessToken, !token.isEmpty,
           let expiry = tokenExpiry, Date() < expiry {
            completion("Bearer \(token)")
            return
        }

        // Tentar refresh
        guard let refresh = refreshToken, !refresh.isEmpty else {
            completion(nil)
            return
        }

        refreshAccessToken(using: refresh) { [weak self] success in
            if success, let token = self?.accessToken {
                completion("Bearer \(token)")
            } else {
                completion(nil)
            }
        }
    }

    /// Extrai o userId (`sub`) do ID token JWT.
    @objc func getUserId() -> String? {
        guard let idToken = idToken else { return nil }
        return parseSubFromJWT(idToken)
    }

    /// Limpa todos os tokens e marca setup como incompleto.
    @objc func logout() {
        accessToken  = nil
        refreshToken = nil
        idToken      = nil
        tokenExpiry  = nil
        UserDefaults.standard.removeObject(forKey: AuthManager.accessTokenKey)
        UserDefaults.standard.removeObject(forKey: AuthManager.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: AuthManager.idTokenKey)
        UserDefaults.standard.removeObject(forKey: AuthManager.expiryKey)
        UserDefaults.standard.set(false, forKey: "setupCompleted")
        UserDefaults.standard.synchronize()
    }

    // MARK: - Troca de código por token (OAuth Authorization Code + PKCE)

    private func exchangeCode(_ code: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let verifier = codeVerifier,
              let url = URL(string: AuthManager.tokenEndpoint) else {
            completion(false, makeError("Estado inválido para troca de token"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type":    "authorization_code",
            "client_id":     AuthManager.clientID,
            "code":          code,
            "redirect_uri":  AuthManager.redirectURI,
            "code_verifier": verifier,
        ]
        request.httpBody = urlEncode(params)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.codeVerifier = nil

            if let error = error {
                completion(false, error)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String else {
                completion(false, self.makeError("Resposta de token inválida"))
                return
            }

            self.saveTokens(from: json, accessToken: access)
            completion(true, nil)
        }.resume()
    }

    // MARK: - Refresh de token

    private func refreshAccessToken(using refreshToken: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: AuthManager.tokenEndpoint) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type":    "refresh_token",
            "client_id":     AuthManager.clientID,
            "refresh_token": refreshToken,
        ]
        request.httpBody = urlEncode(params)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.saveTokens(from: json, accessToken: access)
            DispatchQueue.main.async { completion(true) }
        }.resume()
    }

    // MARK: - Persistência de tokens

    private func saveTokens(from json: [String: Any], accessToken: String) {
        self.accessToken  = accessToken
        self.refreshToken = (json["refresh_token"] as? String) ?? self.refreshToken
        self.idToken      = json["id_token"] as? String
        let expiresIn     = json["expires_in"] as? TimeInterval ?? 300
        self.tokenExpiry  = Date().addingTimeInterval(expiresIn)
        persistTokens()
    }

    private func persistTokens() {
        UserDefaults.standard.set(accessToken,  forKey: AuthManager.accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: AuthManager.refreshTokenKey)
        UserDefaults.standard.set(idToken,      forKey: AuthManager.idTokenKey)
        UserDefaults.standard.set(tokenExpiry,  forKey: AuthManager.expiryKey)
    }

    private func loadTokens() {
        accessToken  = UserDefaults.standard.string(forKey: AuthManager.accessTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: AuthManager.refreshTokenKey)
        idToken      = UserDefaults.standard.string(forKey: AuthManager.idTokenKey)
        tokenExpiry  = UserDefaults.standard.object(forKey: AuthManager.expiryKey) as? Date
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Utilitários

    private func urlEncode(_ params: [String: String]) -> Data? {
        return params
            .map { key, val in
                let encodedVal = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? val
                return "\(key)=\(encodedVal)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    private func parseSubFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
        let rem = base64.count % 4
        if rem > 0 { base64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub  = json["sub"] as? String else { return nil }
        return sub
    }

    private func makeError(_ message: String) -> NSError {
        return NSError(domain: "AuthManager", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: message])
    }
}
