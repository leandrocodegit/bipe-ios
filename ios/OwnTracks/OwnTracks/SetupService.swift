//
//  SetupService.swift
//  OwnTracks
//
//  Equivalente ao SetupService.kt do Android.
//  Chama o endpoint /bipe/devices/setup com o Bearer token do Keycloak
//  e persiste as configurações no CoreData via Settings.
//

import Foundation

// MARK: - DTO de resposta

struct DeviceSetupResponseDto: Codable {
    let clientId: String
    let username: String
    let password: String
    let deviceId: String
    let tid: String?
}

// MARK: - Erros

enum SetupError: LocalizedError {
    case notAuthorized
    case noToken
    case networkError(Error)
    case invalidResponse(Int)
    case emptyBody
    case decodingError(Error)
    case coreDataUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:        return "Usuário não autorizado. Faça login primeiro."
        case .noToken:              return "Token de acesso indisponível."
        case .networkError(let e): return "Erro de rede: \(e.localizedDescription)"
        case .invalidResponse(let c): return "Resposta inválida do servidor (HTTP \(c))."
        case .emptyBody:            return "Resposta vazia do servidor."
        case .decodingError(let e): return "Erro ao interpretar resposta: \(e.localizedDescription)"
        case .coreDataUnavailable:  return "CoreData indisponível."
        }
    }
}

// MARK: - SetupService

@objc class SetupService: NSObject {

    // MARK: - Constantes
    private static let setupURL = "https://dev.simodapp.com:2087/bipe/devices/setup"

    /// Host MQTT a persistir (hardcoded, igual ao Android)
    private static let mqttHost = "broker.simodapp.com"
    private static let mqttPort = 8884

    // MARK: - Singleton
    @objc static let shared = SetupService()

    private override init() { super.init() }

    // MARK: - Verificação de setup

    @objc static let setupCompletedKey = "setupCompleted"

    @objc var isSetupCompleted: Bool {
        return UserDefaults.standard.bool(forKey: SetupService.setupCompletedKey)
    }

    @objc func markSetupCompleted() {
        UserDefaults.standard.set(true, forKey: SetupService.setupCompletedKey)
    }

    @objc func resetSetup() {
        UserDefaults.standard.removeObject(forKey: SetupService.setupCompletedKey)
        AuthManager.shared.logout()
    }

    // MARK: - Fluxo principal

    /// Executa o setup do device: obtém token, chama API, persiste configurações.
    /// - Parameters:
    ///   - context: NSManagedObjectContext para persistir via Settings
    ///   - completion: chamado na main thread com `true` em caso de sucesso ou `error` em caso de falha
    func performDeviceSetup(
        context: NSManagedObjectContext,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        AuthManager.shared.getBearerToken { [weak self] token in
            guard let self = self else { return }
            guard let token = token else {
                DispatchQueue.main.async { completion(false, SetupError.noToken) }
                return
            }

            self.callSetupAPI(bearerToken: token) { result in
                switch result {
                case .success(let dto):
                    self.persistSetup(dto: dto, context: context)
                    DispatchQueue.main.async { completion(true, nil) }
                case .failure(let error):
                    DispatchQueue.main.async { completion(false, error) }
                }
            }
        }
    }

    // MARK: - Chamada de rede

    private func callSetupAPI(
        bearerToken: String,
        completion: @escaping (Result<DeviceSetupResponseDto, SetupError>) -> Void
    ) {
        guard let url = URL(string: SetupService.setupURL) else {
            completion(.failure(.networkError(NSError(domain: "SetupService", code: -1))))
            return
        }

        let payload = #"{"os":"ios"}"#
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        request.httpBody = payload.data(using: .utf8)

        // Usa sessão com validação TLS relaxada somente para o endpoint interno (dev)
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse(0)))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse(httpResponse.statusCode)))
                return
            }

            guard let data = data, !data.isEmpty else {
                completion(.failure(.emptyBody))
                return
            }

            do {
                let dto = try JSONDecoder().decode(DeviceSetupResponseDto.self, from: data)
                completion(.success(dto))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

    // MARK: - Persistência

    private func persistSetup(dto: DeviceSetupResponseDto, context: NSManagedObjectContext) {
        context.performAndWait {
            // Credenciais MQTT
            Settings.setString(dto.username as NSString, forKey: "user_preference", inMOC: context)
            Settings.setString(dto.password as NSString, forKey: "pass_preference", inMOC: context)
            Settings.setString(dto.clientId as NSString, forKey: "clientid_preference", inMOC: context)
            Settings.setString(dto.deviceId as NSString, forKey: "deviceid_preference", inMOC: context)

            if let tid = dto.tid {
                Settings.setString(tid as NSString, forKey: "trackerid_preference", inMOC: context)
            }

            // Broker MQTT
            Settings.setString(SetupService.mqttHost as NSString, forKey: "host_preference", inMOC: context)
            Settings.setInt(Int32(SetupService.mqttPort), forKey: "port_preference", inMOC: context)

            // Flags TLS e autenticação
            Settings.setBool(true, forKey: "tls_preference", inMOC: context)
            Settings.setBool(true, forKey: "auth_preference", inMOC: context)
            Settings.setBool(true, forKey: "usepassword_preference", inMOC: context)

            // Modo MQTT (CONNECTION_MODE_MQTT = 0)
            // CONNECTION_MODE_MQTT = 0 (definido em Settings.h)
            Settings.setMode(ConnectionMode(rawValue: 0), inMOC: context)

            // Salva no CoreData
            if context.hasChanges {
                try? context.save()
            }
        }

        // Marca o setup como concluído no UserDefaults
        markSetupCompleted()
    }
}
