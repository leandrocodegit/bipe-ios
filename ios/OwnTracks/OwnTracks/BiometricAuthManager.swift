//
//  BiometricAuthManager.swift
//  OwnTracks
//
//  Gerencia a autenticação biométrica (Face ID / Touch ID) e o armazenamento seguro
//  do Refresh Token no Keychain do iOS para login fluido.
//

import Foundation
import LocalAuthentication
import Security

@objc class BiometricAuthManager: NSObject {

    @objc static let shared = BiometricAuthManager()

    private let keychainService = "br.com.bipe.me.refreshtoken"
    private let keychainAccount = "user_refresh_token"
    private let biometricsEnabledKey = "biometrics_login_enabled"

    private override init() {
        super.init()
    }

    // MARK: - Status e Capacidades

    /// Retorna se a biometria (Face ID / Touch ID) está disponível no dispositivo
    @objc var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Retorna o tipo de biometria suportada pelo aparelho (.faceID, .touchID ou .none)
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    /// Nome amigável do tipo de biometria para a interface (ex: "Face ID" ou "Touch ID")
    @objc var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometria"
        }
    }

    /// Nome do ícone SF Symbols correspondente
    @objc var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.shield.fill"
        }
    }

    /// Flag de habilitação da biometria configurada pelo usuário
    @objc var isBiometricsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: biometricsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: biometricsEnabledKey)
        }
    }

    /// Verifica se uma string de token JWT expirou baseando-se no claim "exp"
    static func isJwtExpired(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return false }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expNumber = json["exp"] as? NSNumber else {
            return false
        }
        let exp = expNumber.doubleValue
        // Se a data atual for maior ou igual ao exp (com margem de 10s)
        return Date().timeIntervalSince1970 >= (exp - 10)
    }

    /// Verifica se há um refresh token salvo no Keychain e a biometria está pronta para uso
    @objc var canLoginWithBiometrics: Bool {
        guard isBiometricsAvailable && isBiometricsEnabled,
              let token = getStoredRefreshToken(), !token.isEmpty else {
            return false
        }

        // Se o token JWT já expirou, limpa o token e retorna false
        if BiometricAuthManager.isJwtExpired(token) {
            NSLog("[BiometricAuthManager] Refresh token expirado. canLoginWithBiometrics = false")
            removeStoredRefreshToken()
            AuthManager.shared.clearAuthState()
            return false
        }

        return true
    }

    private(set) var isAuthenticating = false

    // MARK: - Autenticação Biométrica

    /// Executa a leitura da biometria (Face ID / Touch ID) com fallback automático para a Senha do Dispositivo
    @objc func authenticate(reason: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        if isAuthenticating {
            NSLog("[BiometricAuthManager] Autenticação biométrica já está em andamento. Ignorando chamada duplicada.")
            completion(false, NSError(domain: "BiometricAuthManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Autenticação em andamento"]))
            return
        }

        isAuthenticating = true
        let context = LAContext()
        context.localizedCancelTitle = NSLocalizedString("Cancelar", comment: "")
        context.localizedFallbackTitle = NSLocalizedString("Digite a Senha", comment: "")
        
        let localizedReason = reason ?? String(format: NSLocalizedString("Autentique-se com %@ para acessar o Bipe.me", comment: ""), biometricName)

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: localizedReason) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.isAuthenticating = false
                    completion(true, nil)
                }
            } else if let laError = error as? LAError, laError.code == .userFallback || laError.code == .biometryLockout {
                // Se o usuário clicou em "Digite a Senha" ou se o Face ID foi bloqueado após tentativas incorretas,
                // solicita a senha do dispositivo (.deviceOwnerAuthentication)
                let passcodeContext = LAContext()
                passcodeContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: localizedReason) { passcodeSuccess, passcodeError in
                    DispatchQueue.main.async {
                        self?.isAuthenticating = false
                        completion(passcodeSuccess, passcodeError)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isAuthenticating = false
                    completion(false, error)
                }
            }
        }
    }

    // MARK: - Armazenamento Seguro no Keychain

    /// Salva o Refresh Token de forma criptografada no Keychain
    @objc func saveRefreshToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        // Deleta registro anterior para evitar duplicidade
        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(newQuery as CFDictionary, nil)
    }

    /// Recupera o Refresh Token armazenado no Keychain (com fallback para a sessão atual)
    @objc func getStoredRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty {
            return token
        }
        
        if let currentToken = AuthManager.shared.getRefreshToken(), !currentToken.isEmpty {
            return currentToken
        }
        
        return nil
    }

    /// Remove apenas o Refresh Token do Keychain (por exemplo, quando o token expirar)
    @objc func removeStoredRefreshToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Limpa os dados biométricos e tokens armazenados (chamado no logout)
    @objc func clearBiometricData() {
        removeStoredRefreshToken()
        isBiometricsEnabled = false
    }
}
