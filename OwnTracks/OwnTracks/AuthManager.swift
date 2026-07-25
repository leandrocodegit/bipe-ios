//
//  AuthManager.swift
//  OwnTracks
//
//  Gerencia o estado OAuth2/OIDC com Keycloak usando a biblioteca AppAuth.
//  Equivalente ao AuthManager.kt do projeto Android (bipe-android).
//
//  IMPORTANTE: Antes de compilar, adicione o pacote AppAuth via Xcode:
//  File → Add Package Dependencies → https://github.com/openid/AppAuth-iOS (~> 2.0)
//

import Foundation
import UIKit
import AppAuth

@objc(AuthManager)
class AuthManager: NSObject {

    // MARK: - Singleton

    @objc static let shared = AuthManager()

    // MARK: - Constantes Keycloak (espelha o Android)

    private static let issuerURI     = "https://auth.simodapp.com:8443/realms/sincroled"
    private static let clientID      = "sincroled"
    private static let redirectURI   = "owntracks://auth"       // scheme já registrado no Info.plist
    private static let scopes        = [OIDScopeOpenID, OIDScopeProfile, "email"]

    // MARK: - Storage key

    private static let authStateKey  = "bipe_auth_state"

    // MARK: - Estado interno

    /// Sessão ativa do fluxo de autorização (necessário para processar o redirect URL)
    @objc var currentAuthorizationFlow: OIDExternalUserAgentSession?

    private var authState: OIDAuthState? {
        didSet { persistState() }
    }

    // MARK: - Init

    private override init() {
        super.init()
        loadState()
    }

    // MARK: - API Pública

    /// Retorna true se há um token de acesso válido armazenado.
    @objc var isAuthorized: Bool {
        return authState?.isAuthorized ?? false
    }

    /// Inicia o fluxo de login OAuth via Keycloak.
    /// Abre o browser para autenticação e chama o completion quando concluído.
    func startLogin(presenting viewController: UIViewController,
                    completion: @escaping (Bool, Error?) -> Void) {

        guard let issuerURL = URL(string: AuthManager.issuerURI) else {
            completion(false, makeError("URL do issuer inválida"))
            return
        }

        // 1. Descobrir a configuração OIDC do Keycloak
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { [weak self] config, error in
            guard let self = self else { return }

            if let error = error {
                completion(false, error)
                return
            }
            guard let config = config else {
                completion(false, self.makeError("Configuração OIDC não encontrada"))
                return
            }

            guard let redirectURL = URL(string: AuthManager.redirectURI) else {
                completion(false, self.makeError("Redirect URI inválida"))
                return
            }

            // 2. Construir a requisição de autorização
            let request = OIDAuthorizationRequest(
                configuration: config,
                clientId: AuthManager.clientID,
                scopes: AuthManager.scopes,
                redirectURL: redirectURL,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )

            // 3. Apresentar o browser de login e aguardar o callback
            DispatchQueue.main.async {
                self.currentAuthorizationFlow = OIDAuthState.authState(
                    byPresenting: request,
                    presenting: viewController
                ) { [weak self] authState, error in
                    guard let self = self else { return }
                    if let authState = authState {
                        self.authState = authState
                        self.currentAuthorizationFlow = nil
                        completion(true, nil)
                    } else {
                        self.currentAuthorizationFlow = nil
                        completion(false, error)
                    }
                }
            }
        }
    }

    /// Deve ser chamado no application(_:open:options:) do AppDelegate para processar o redirect.
    /// Retorna true se a URL foi reconhecida como uma resposta OAuth.
    @objc func handleRedirectURL(_ url: URL) -> Bool {
        if let flow = currentAuthorizationFlow,
           flow.resumeExternalUserAgentFlow(with: url) {
            currentAuthorizationFlow = nil
            return true
        }
        return false
    }

    /// Obtém o token de acesso atual, realizando refresh automaticamente se necessário.
    func getBearerToken(completion: @escaping (String?) -> Void) {
        guard let authState = authState else {
            completion(nil)
            return
        }
        authState.performAction { accessToken, _, error in
            if let error = error {
                print("[AuthManager] Erro ao obter token: \(error)")
                completion(nil)
            } else if let token = accessToken {
                completion("Bearer \(token)")
            } else {
                completion(nil)
            }
        }
    }

    /// Extrai o `sub` (subject/userId) do ID token JWT.
    @objc func getUserId() -> String? {
        guard let idToken = authState?.lastTokenResponse?.idToken else { return nil }
        return parseSubFromJWT(idToken)
    }

    /// Limpa o estado de autenticação e marca o setup como incompleto.
    @objc func logout() {
        authState = nil
        UserDefaults.standard.removeObject(forKey: AuthManager.authStateKey)
        UserDefaults.standard.set(false, forKey: "setupCompleted")
        UserDefaults.standard.synchronize()
    }

    // MARK: - Persistência de estado

    private func persistState() {
        guard let authState = authState else {
            UserDefaults.standard.removeObject(forKey: AuthManager.authStateKey)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: authState,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: AuthManager.authStateKey)
        } catch {
            print("[AuthManager] Falha ao persistir estado: \(error)")
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: AuthManager.authStateKey) else { return }
        do {
            authState = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: OIDAuthState.self,
                from: data
            )
        } catch {
            print("[AuthManager] Falha ao carregar estado: \(error)")
            authState = nil
        }
    }

    // MARK: - Utilitários

    private func parseSubFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        // Adiciona padding necessário para decodificação Base64
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }

    private func makeError(_ message: String) -> NSError {
        return NSError(
            domain: "AuthManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
