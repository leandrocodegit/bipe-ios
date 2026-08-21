//
//  BipeLiveActivityManager.swift
//  OwnTracks
//
//  Gerenciador Singleton de Live Activity.
//  Garante que exista sempre no máximo UMA Live Activity ativa simultaneamente,
//  reaproveitando e atualizando a mesma atividade para qualquer notificação/evento.
//

import Foundation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

@objc class BipeLiveActivityManager: NSObject {
    
    private static let tokenEndpoint = "https://dev.simodapp.com:2087/bipe/live-activity/token"
    private static let activityEndpointPrefix = "https://dev.simodapp.com:2087/bipe/live-activity/activity/"
    private static let appGroupSuite = "group.br.com.bipe.me"

    // MARK: - Register Push-to-Start & Token Listeners

    @objc static func registerPushToStartListener() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task {
                for await activity in Activity<BipeAlertActivityAttributes>.activityUpdates {
                    NSLog("[BipeLiveActivityManager] Nova atividade detectada via activityUpdates (ID: %@)", activity.id)
                    await sanitizeDuplicateActivities(keeping: activity)
                    observeActivityToken(activity)
                }
            }
            Task { @MainActor in
                let active = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active }
                if let first = active.first {
                    await sanitizeDuplicateActivities(keeping: first)
                }
                for activity in Activity<BipeAlertActivityAttributes>.activities {
                    observeActivityToken(activity)
                }
            }
        }
        if #available(iOS 17.2, *) {
            Task {
                for await tokenData in Activity<BipeAlertActivityAttributes>.pushToStartTokenUpdates {
                    let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                    NSLog("[BipeLiveActivityManager] Push-to-Start Token registrado/atualizado: %@", tokenHex)
                    SetupService.shared.syncPushToStartTokenWithServer(tokenHex)
                }
            }
        }
        #endif
    }

    @available(iOS 16.1, *)
    private static func observeActivityToken(_ activity: Activity<BipeAlertActivityAttributes>) {
        #if canImport(ActivityKit)
        Task {
            if let pushTokenData = activity.pushToken {
                let pushTokenHex = pushTokenData.map { String(format: "%02x", $0) }.joined()
                NSLog("[BipeLiveActivityManager] Push Token inicial para Live Activity %@: %@", activity.id, pushTokenHex)
                sendLiveActivityTokenToServer(token: pushTokenHex, activityId: activity.id)
            }
            for await pushTokenData in activity.pushTokenUpdates {
                let pushTokenHex = pushTokenData.map { String(format: "%02x", $0) }.joined()
                NSLog("[BipeLiveActivityManager] Push Token recebido para Live Activity %@: %@", activity.id, pushTokenHex)
                sendLiveActivityTokenToServer(token: pushTokenHex, activityId: activity.id)
            }
        }
        Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed {
                    NSLog("[BipeLiveActivityManager] Live Activity %@ finalizada. Removendo token do servidor.", activity.id)
                    removeLiveActivityTokenFromServer(activityId: activity.id)
                }
            }
        }
        #endif
    }

    // MARK: - Sanitization (Garantia de Live Activity Única)

    @available(iOS 16.1, *)
    private static func sanitizeDuplicateActivities(keeping primaryActivity: Activity<BipeAlertActivityAttributes>? = nil) async {
        #if canImport(ActivityKit)
        let allActivities = Activity<BipeAlertActivityAttributes>.activities
        let activeActivities = allActivities.filter { $0.activityState == .active }
        
        guard activeActivities.count > 1 else { return }
        
        let targetToKeep = primaryActivity ?? activeActivities.first
        NSLog("[BipeLiveActivityManager] Encontradas %d Live Activities ativas. Mantendo ID %@ e encerrando duplicadas...", activeActivities.count, targetToKeep?.id ?? "")
        
        for activity in activeActivities {
            if let keep = targetToKeep, activity.id == keep.id {
                continue
            }
            NSLog("[BipeLiveActivityManager] Encerrando Live Activity duplicada ID: %@", activity.id)
            let activityId = activity.id
            await activity.end(nil, dismissalPolicy: .immediate)
            removeLiveActivityTokenFromServer(activityId: activityId)
        }
        #endif
    }

    // MARK: - Lifecycle Management

    @objc static func startLiveActivityOnAppLaunch() {
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit)
            Task { @MainActor in
                // 1. Limpa atividades finalizadas/descartadas da memória do ActivityKit
                for activity in Activity<BipeAlertActivityAttributes>.activities {
                    if activity.activityState == .ended || activity.activityState == .dismissed {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        removeLiveActivityTokenFromServer(activityId: activity.id)
                    }
                }
                
                // 2. Garante que exista no máximo 1 ativa
                let activeActivities = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active }
                if activeActivities.count > 1 {
                    await sanitizeDuplicateActivities(keeping: activeActivities.first)
                }
                
                // 3. Se nenhuma estiver ativa, cria a Live Activity padrão inicial
                let remainingActive = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active }
                if remainingActive.isEmpty {
                    NSLog("[BipeLiveActivityManager] Nenhuma Live Activity ativa. Criando Live Activity única inicial...")
                    let moc = CoreData.sharedInstance().mainMOC
                    var nickname: String = "Bipe.me"
                    moc.performAndWait {
                        if let name = Settings.string(forKey: "user_preference", inMOC: moc), !name.isEmpty {
                            nickname = name
                        }
                    }
                    startLiveActivity(
                        nickname: nickname,
                        address: "Monitorando em tempo real",
                        iconLocalPath: nil,
                        iconUrl: nil,
                        status: "transition",
                        way: "Monitoramento Ativo",
                        devices: nil,
                        event: "enter",
                        activityType: "transition"
                    )
                } else {
                    NSLog("[BipeLiveActivityManager] Live Activity única já ativa na tela (ID: %@). Nenhuma nova criação necessária.", remainingActive.first?.id ?? "")
                }
            }
            #endif
        }
    }

    // MARK: - Start / Update Live Activity

    @available(iOS 16.1, *)
    private static func startLiveActivity(
        nickname: String,
        address: String,
        iconLocalPath: String?,
        iconUrl: String?,
        status: String,
        way: String? = nil,
        devices: [String]? = nil,
        event: String? = nil,
        activityType: String? = "emergency",
        target: String? = nil,
        alvo: String? = nil,
        distancia: String? = nil,
        icon: String? = nil
    ) {
        #if canImport(ActivityKit)
        DispatchQueue.main.async {
            let state = BipeAlertActivityAttributes.ContentState(
                address: address,
                way: way,
                event: event,
                devices: devices,
                activityType: activityType,
                nickname: nickname,
                status: status,
                iconUrl: iconUrl,
                iconLocalPath: iconLocalPath,
                icon: icon ?? iconUrl,
                timestamp: Date().timeIntervalSince1970,
                target: target,
                alvo: alvo,
                distancia: distancia
            )
            let content: ActivityContent<BipeAlertActivityAttributes.ContentState>
            if #available(iOS 16.2, *) {
                content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(3600), relevanceScore: 100.0)
            } else {
                content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(3600))
            }
            
            Task { @MainActor in
                let activeActivities = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active }
                
                // Se houver mais de uma atividade ativa, encerra as duplicadas mantendo apenas a primeira
                if activeActivities.count > 1 {
                    await sanitizeDuplicateActivities(keeping: activeActivities.first)
                }
                
                let currentActive = Activity<BipeAlertActivityAttributes>.activities.filter { $0.activityState == .active }
                
                if let singleActiveActivity = currentActive.first {
                    NSLog("[BipeLiveActivityManager] Reutilizando e atualizando Live Activity existente (ID: %@)", singleActiveActivity.id)
                    await singleActiveActivity.update(content)
                    NSLog("[BipeLiveActivityManager] Live Activity %@ atualizada com sucesso!", singleActiveActivity.id)
                } else {
                    NSLog("[BipeLiveActivityManager] Nenhuma Live Activity ativa. Criando nova atividade única...")
                    do {
                        let attributes = BipeAlertActivityAttributes()
                        let activity = try Activity<BipeAlertActivityAttributes>.request(
                            attributes: attributes,
                            content: content,
                            pushType: .token
                        )
                        NSLog("[BipeLiveActivityManager] Nova Live Activity iniciada com sucesso. ID: %@", activity.id)
                        
                        Task {
                            for await pushTokenData in activity.pushTokenUpdates {
                                let pushTokenHex = pushTokenData.map { String(format: "%02x", $0) }.joined()
                                NSLog("[BipeLiveActivityManager] Push Token recebido para Live Activity %@: %@", activity.id, pushTokenHex)
                                sendLiveActivityTokenToServer(token: pushTokenHex, activityId: activity.id)
                            }
                        }
                        
                        Task {
                            for await state in activity.activityStateUpdates {
                                if state == .ended || state == .dismissed {
                                    NSLog("[BipeLiveActivityManager] Live Activity %@ finalizada. Removendo token do servidor.", activity.id)
                                    removeLiveActivityTokenFromServer(activityId: activity.id)
                                }
                            }
                        }
                    } catch {
                        NSLog("[BipeLiveActivityManager] Erro ao iniciar Live Activity: %@ (detalhes: %@)", error.localizedDescription, String(describing: error))
                    }
                }
            }
        }
        #endif
    }

    // MARK: - End Live Activities

    @objc static func endAllLiveActivities() {
        endEmergencyLiveActivity()
    }

    @objc static func endEmergencyLiveActivity() {
        if #available(iOS 16.1, *) {
            endEmergencyLiveActivityInternal()
        }
    }

    @available(iOS 16.1, *)
    private static func endEmergencyLiveActivityInternal() {
        #if canImport(ActivityKit)
        for activity in Activity<BipeAlertActivityAttributes>.activities {
            let activityId = activity.id
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
                removeLiveActivityTokenFromServer(activityId: activityId)
            }
        }
        #endif
    }

    // MARK: - Process Push Notification Payload

    @objc static func testTransitionLiveActivity() {
        if #available(iOS 16.1, *) {
            startLiveActivity(
                nickname: "Bipe.me",
                address: "Região Monitorada",
                iconLocalPath: nil,
                iconUrl: nil,
                status: "transition",
                way: "Casa da Vovó",
                devices: ["iPhone do João", "Carro da Maria"],
                event: "enter",
                activityType: "transition"
            )
        }
    }

    @objc static func processBipePushNotificationPayload(_ userInfo: NSDictionary) {
        NSLog("[BipeLiveActivityManager] Recebido push payload: %@", userInfo)
        
        var dataDict: [String: Any]? = userInfo["data"] as? [String: Any]
        if dataDict == nil, let dataString = userInfo["data"] as? String, let data = dataString.data(using: .utf8) {
            dataDict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        
        let type = extractValue(keys: ["type", "_type", "activityType"], userInfo: userInfo, dataDict: dataDict)
        let status = extractValue(keys: ["status", "_status"], userInfo: userInfo, dataDict: dataDict)
        let eventVal = extractValue(keys: ["event", "transition", "event_type", "eventType", "action"], userInfo: userInfo, dataDict: dataDict)
        let wayVal = extractValue(keys: ["way", "region", "wayName", "locationName"], userInfo: userInfo, dataDict: dataDict)
        let targetVal = extractValue(keys: ["target", "targetDevice", "dispositivo1"], userInfo: userInfo, dataDict: dataDict)
        let alvoVal = extractValue(keys: ["alvo", "targetAlvo", "dispositivo2"], userInfo: userInfo, dataDict: dataDict)
        let distanciaVal = extractValue(keys: ["distancia", "distance"], userInfo: userInfo, dataDict: dataDict)
        
        let typeLower = type?.lowercased() ?? ""
        let statusLower = status?.lowercased() ?? ""
        let eventLower = eventVal?.lowercased() ?? ""
        
        let isEmergency = typeLower.contains("emergency") || statusLower.contains("emergency") || statusLower.contains("emergencia") || statusLower.contains("emergência")
        let isDistance = !isEmergency && (typeLower.contains("distance") || statusLower.contains("distance") || eventLower.contains("aproxim") || eventLower.contains("afast") || statusLower.contains("aproxim") || statusLower.contains("afast") || targetVal != nil || alvoVal != nil || distanciaVal != nil)
        let isTransition = !isEmergency && !isDistance && (typeLower.contains("transition") || statusLower.contains("transition") || eventLower.contains("transition") || wayVal != nil)
        
        guard isDistance || isTransition || isEmergency else {
            NSLog("[BipeLiveActivityManager] Push ignorado (type: '%@', status: '%@', event: '%@'). Não corresponde a distance, transition ou emergency.", typeLower, statusLower, eventLower)
            return
        }
        
        if #available(iOS 16.1, *) {
            let moc = CoreData.sharedInstance().mainMOC
            let nickname = extractValue(keys: ["nickname", "name", "userName"], userInfo: userInfo, dataDict: dataDict)
                ?? Settings.string(forKey: "user_preference", inMOC: moc)
                ?? "Bipe.me"
            
            let address = extractValue(keys: ["address", "endereco", "locationName", "desc", "text", "location"], userInfo: userInfo, dataDict: dataDict)
                ?? "Localização atual"
            
            let iconUrl = extractValue(keys: ["icon", "iconUrl", "image", "imageUrl", "avatar"], userInfo: userInfo, dataDict: dataDict)
            
            if isEmergency {
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para EMERGENCY (nickname: '%@', address: '%@')", nickname, address)
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: "emergency",
                    way: nil,
                    devices: nil,
                    event: nil,
                    activityType: "emergency",
                    icon: iconUrl
                )
            } else if isDistance {
                let eventDisplay = eventVal ?? (statusLower.contains("afast") ? "AFASTAR" : "APROXIMAR")
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para DISTANCE: target='%@', alvo='%@', distancia='%@', event='%@'", targetVal ?? "", alvoVal ?? "", distanciaVal ?? "", eventDisplay)
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: "distance",
                    way: nil,
                    devices: nil,
                    event: eventDisplay,
                    activityType: "distance",
                    target: targetVal,
                    alvo: alvoVal,
                    distancia: distanciaVal
                )
            } else if isTransition {
                let way = wayVal ?? extractValue(keys: ["way", "region", "wayName", "locationName", "desc"], userInfo: userInfo, dataDict: dataDict) ?? "Região Cadastrada"
                let event = eventLower.contains("exit") || eventLower.contains("saida") || eventLower.contains("saída") ? "exit" : "enter"
                let devicesList = extractDevicesArray(userInfo: userInfo, dataDict: dataDict)
                
                NSLog("[BipeLiveActivityManager] Atualizando Live Activity para TRANSITION (way: '%@', event: '%@', devices: %@)", way, event, devicesList)
                
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: nil,
                    iconUrl: iconUrl,
                    status: "transition",
                    way: way,
                    devices: devicesList,
                    event: event,
                    activityType: "transition",
                    icon: iconUrl
                )
            }
        } else {
            NSLog("[BipeLiveActivityManager] Live Activities não suportadas nesta versão do iOS.")
        }
    }

    // MARK: - Data Extraction Helpers

    private static func extractValue(keys: [String], userInfo: NSDictionary, dataDict: [String: Any]?) -> String? {
        let apsDict = (userInfo["aps"] as? NSDictionary) ?? (userInfo["aps"] as? [String: Any]) as NSDictionary?
        let contentState = (apsDict?["content-state"] as? NSDictionary) ?? (apsDict?["content-state"] as? [String: Any]) as NSDictionary?
        
        for key in keys {
            if let val = userInfo[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" { return str }
            }
            if let dataDict = dataDict, let val = dataDict[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" { return str }
            }
            if let contentState = contentState, let val = contentState[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" { return str }
            }
            if let apsDict = apsDict, let val = apsDict[key] {
                let str = String(describing: val).trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty && str != "<null>" && str != "nil" { return str }
            }
        }
        return nil
    }

    private static func extractDevicesArray(userInfo: NSDictionary, dataDict: [String: Any]?) -> [String] {
        let apsDict = (userInfo["aps"] as? NSDictionary) ?? (userInfo["aps"] as? [String: Any]) as NSDictionary?
        let contentState = (apsDict?["content-state"] as? NSDictionary)
            ?? (apsDict?["content-state"] as? [String: Any]) as NSDictionary?
            ?? (apsDict?["contentState"] as? NSDictionary)
            ?? (apsDict?["content_state"] as? NSDictionary)
        
        var rawValue: Any? = userInfo["devices"] ?? userInfo["_devices"]
        if rawValue == nil {
            rawValue = dataDict?["devices"] ?? dataDict?["_devices"]
        }
        if rawValue == nil {
            rawValue = contentState?["devices"] ?? contentState?["_devices"]
        }
        
        guard let raw = rawValue else { return [] }
        
        if let array = raw as? [String] {
            return array
        }
        if let nestedArray = raw as? [[String]] {
            return nestedArray.flatMap { $0 }
        }
        if let nsArray = raw as? NSArray {
            var result: [String] = []
            for item in nsArray {
                if let subArray = item as? NSArray {
                    for sub in subArray {
                        result.append(String(describing: sub))
                    }
                } else if let subStringArray = item as? [String] {
                    result.append(contentsOf: subStringArray)
                } else {
                    result.append(String(describing: item))
                }
            }
            return result
        }
        if let arrayDict = raw as? [[String: Any]] {
            return arrayDict.compactMap { dict in
                dict["name"] as? String ?? dict["nickname"] as? String ?? dict["apelido"] as? String ?? dict["username"] as? String ?? dict["icon"] as? String
            }
        }
        if let str = raw as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                if let data = trimmed.data(using: .utf8) {
                    if let parsedArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                        return parsedArray
                    }
                    if let parsedNested = try? JSONSerialization.jsonObject(with: data) as? [[String]] {
                        return parsedNested.flatMap { $0 }
                    }
                    if let parsedDicts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        return parsedDicts.compactMap { dict in
                            dict["name"] as? String ?? dict["nickname"] as? String ?? dict["apelido"] as? String ?? dict["username"] as? String ?? dict["icon"] as? String
                        }
                    }
                }
            }
            let cleaned = trimmed.replacingOccurrences(of: "[", with: "")
                                 .replacingOccurrences(of: "]", with: "")
                                 .replacingOccurrences(of: "\"", with: "")
                                 .replacingOccurrences(of: "'", with: "")
            return cleaned.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return []
    }

    // MARK: - Server Token Sync

    private static func sendLiveActivityTokenToServer(token: String, activityId: String) {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "SendLiveActivityToken") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        AuthManager.shared.getBearerToken { bearerToken in
            let finishBgTaskIfNeeded = {
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
            
            guard let bearerToken = bearerToken else {
                NSLog("[BipeLiveActivityManager] Impossível registrar token: Bearer token ausente.")
                finishBgTaskIfNeeded()
                return
            }
            
            let moc = CoreData.sharedInstance().mainMOC
            var clientId: String? = nil
            var deviceId: String? = nil
            moc.performAndWait {
                clientId = Settings.string(forKey: "clientid_preference", inMOC: moc)
                deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc)
            }
            
            var payloadDict: [String: Any] = [
                "token": token,
                "activityId": activityId
            ]
            if let clientId = clientId, !clientId.isEmpty {
                payloadDict["clientId"] = clientId
            }
            if let deviceId = deviceId, !deviceId.isEmpty {
                payloadDict["deviceId"] = deviceId
            }
            
            let authHeader = bearerToken.hasPrefix("Bearer ") ? bearerToken : "Bearer \(bearerToken)"
            
            let group = DispatchGroup()
            
            // 1. Registra no endpoint /bipe/live-activity/token
            if let url = URL(string: tokenEndpoint) {
                group.enter()
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: payloadDict)
                
                URLSession.shared.dataTask(with: request) { _, response, error in
                    defer { group.leave() }
                    if let error = error {
                        NSLog("[BipeLiveActivityManager] Erro ao enviar activityToken para servidor: %@", error.localizedDescription)
                    } else if let httpResp = response as? HTTPURLResponse {
                        NSLog("[BipeLiveActivityManager] ActivityToken enviado para /bipe/live-activity/token com sucesso. Status: %d", httpResp.statusCode)
                    }
                }.resume()
            }
            
            // 2. Atualiza no endpoint especifico do dispositivo /bipe/devices/{id}/tokens se o deviceId existir
            if let devId = deviceId, !devId.isEmpty, let patchUrl = URL(string: "https://dev.simodapp.com:2087/bipe/devices/\(devId)/tokens") {
                group.enter()
                var patchReq = URLRequest(url: patchUrl)
                patchReq.httpMethod = "PATCH"
                patchReq.setValue(authHeader, forHTTPHeaderField: "Authorization")
                patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let patchBody: [String: String] = ["token": token]
                patchReq.httpBody = try? JSONSerialization.data(withJSONObject: patchBody)
                
                URLSession.shared.dataTask(with: patchReq) { _, response, error in
                    defer { group.leave() }
                    if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                        NSLog("[BipeLiveActivityManager] ActivityToken sincronizado no dispositivo %@ via PATCH. Status: %d", devId, httpResp.statusCode)
                    }
                }.resume()
            }
            
            group.notify(queue: .main) {
                finishBgTaskIfNeeded()
            }
        }
    }

    private static func removeLiveActivityTokenFromServer(activityId: String) {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemoveLiveActivityToken") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        AuthManager.shared.getBearerToken { bearerToken in
            let finishBgTaskIfNeeded = {
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
            
            guard let bearerToken = bearerToken else {
                finishBgTaskIfNeeded()
                return
            }
            guard let url = URL(string: "\(activityEndpointPrefix)\(activityId)") else {
                finishBgTaskIfNeeded()
                return
            }
            
            let authHeader = bearerToken.hasPrefix("Bearer ") ? bearerToken : "Bearer \(bearerToken)"
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                defer { finishBgTaskIfNeeded() }
                if let error = error {
                    NSLog("[BipeLiveActivityManager] Erro ao remover token do servidor: %@", error.localizedDescription)
                } else if let httpResp = response as? HTTPURLResponse {
                    NSLog("[BipeLiveActivityManager] Token da Live Activity removido do servidor. Status HTTP: %d", httpResp.statusCode)
                }
            }.resume()
        }
    }
}
