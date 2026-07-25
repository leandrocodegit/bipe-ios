//
//  SetupService.swift
//  OwnTracks
//
//  Realiza o setup do dispositivo chamando a API BIPE e persistindo as
//  configurações MQTT no CoreData (equivalente ao SetupService.kt Android).
//

import Foundation

/// Resposta da API de setup do dispositivo.
struct DeviceSetupResponse: Codable {
    let clientId: String
    let username: String
    let password: String
    let deviceId: String
    let tid: String?
}

class SetupService {

    // MARK: - Singleton

    static let shared = SetupService()

    // MARK: - Constantes

    private static let setupURL = "https://dev.simodapp.com:2087/bipe/devices/setup"

    // MARK: - Init

    private init() {}

    // MARK: - API Pública

    /// Realiza o setup do dispositivo:
    /// 1. Obtém o Bearer token via AuthManager
    /// 2. Chama a API /bipe/devices/setup
    /// 3. Persiste as configurações MQTT no CoreData
    /// 4. Marca setupCompleted = true no UserDefaults
    func performSetup(completion: @escaping (Bool) -> Void) {
        AuthManager.shared.getBearerToken { [weak self] bearerToken in
            guard let self = self, let bearerToken = bearerToken else {
                print("[SetupService] Falha ao obter Bearer token")
                DispatchQueue.main.async { completion(false) }
                return
            }

            guard let url = URL(string: SetupService.setupURL) else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")

            // Payload: indica o SO (sem FCM token, pois iOS não usa Firebase)
            let payload: [String: String] = ["os": "ios"]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }

                if let error = error {
                    print("[SetupService] Erro na requisição: \(error)")
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                guard httpResponse.statusCode == 200, let data = data else {
                    print("[SetupService] Setup falhou com status: \(httpResponse.statusCode)")
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                do {
                    let setupData = try JSONDecoder().decode(DeviceSetupResponse.self, from: data)
                    self.persistSetup(setupData)
                    DispatchQueue.main.async { completion(true) }
                } catch {
                    print("[SetupService] Falha ao decodificar resposta: \(error)")
                    DispatchQueue.main.async { completion(false) }
                }

            }.resume()
        }
    }

    // MARK: - Persistência

    /// Persiste as configurações recebidas da API no CoreData (via Settings)
    /// e salva setupCompleted no UserDefaults.
    private func persistSetup(_ data: DeviceSetupResponse) {
        guard let moc = CoreData.sharedInstance().mainMOC else {
            print("[SetupService] MainMOC indisponível")
            return
        }

        // Credenciais MQTT retornadas pela API
        Settings.setString(data.username, forKey: "user_preference",     inMOC: moc)
        Settings.setString(data.password, forKey: "pass_preference",     inMOC: moc)
        Settings.setString(data.clientId, forKey: "clientid_preference", inMOC: moc)
        Settings.setString(data.deviceId, forKey: "deviceid_preference", inMOC: moc)

        if let tid = data.tid, !tid.isEmpty {
            Settings.setString(tid, forKey: "trackerid_preference", inMOC: moc)
        }

        // Configurações do broker (espelha os defaults do Android DefaultsProvider.kt)
        Settings.setString("broker.simodapp.com", forKey: "host_preference", inMOC: moc)
        Settings.setInt(8884,  forKey: "port_preference",        inMOC: moc)
        Settings.setInt(0,     forKey: "mode",                   inMOC: moc)  // CONNECTION_MODE_MQTT = 0
        Settings.setBool(true, forKey: "tls_preference",         inMOC: moc)
        Settings.setBool(true, forKey: "auth_preference",        inMOC: moc)
        Settings.setBool(true, forKey: "usepassword_preference", inMOC: moc)

        // Persiste no banco CoreData
        CoreData.sharedInstance().sync(moc)

        // Marca setup como concluído
        UserDefaults.standard.set(true, forKey: "setupCompleted")
        UserDefaults.standard.synchronize()

        print("[SetupService] Setup concluído — deviceId: \(data.deviceId), tid: \(data.tid ?? "n/a")")
    }
}
