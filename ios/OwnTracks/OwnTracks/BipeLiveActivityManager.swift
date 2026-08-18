//
//  BipeLiveActivityManager.swift
//  OwnTracks
//

import Foundation
import CoreData
import UIKit

#if canImport(ActivityKit)
import ActivityKit
#endif

@objc(BipeLiveActivityManager)
@objcMembers
public class BipeLiveActivityManager: NSObject {
    
    private static let tokenEndpoint = "https://dev.simodapp.com:2087/bipe/live-activity/token"
    private static let activityEndpointPrefix = "https://dev.simodapp.com:2087/bipe/live-activity/activity/"
    private static let appGroupSuite = "group.br.com.bipe.me"

    @objc public static func processBipePushNotificationPayload(_ userInfo: NSDictionary) {
        let type = (userInfo["type"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["type"] as? String)
            ?? (userInfo["_type"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["_type"] as? String)
        
        let status = (userInfo["status"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["status"] as? String)
        
        guard let typeStr = type, typeStr.caseInsensitiveCompare("bipe_alert") == .orderedSame,
              let statusStr = status, statusStr.caseInsensitiveCompare("emergency") == .orderedSame else {
            return
        }
        
        guard #available(iOS 16.1, *) else {
            NSLog("[BipeLiveActivityManager] Live Activities não suportadas nesta versão do iOS.")
            return
        }
        
        let moc = CoreData.sharedInstance().mainMOC
        let nickname = (userInfo["nickname"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["nickname"] as? String)
            ?? (userInfo["name"] as? String)
            ?? (userInfo["userName"] as? String)
            ?? Settings.string(forKey: "user_preference", inMOC: moc)
            ?? "Bipe.me"
        
        var address = (userInfo["address"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["address"] as? String)
            ?? (userInfo["endereco"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["endereco"] as? String)
            ?? (userInfo["locationName"] as? String)
            ?? (userInfo["desc"] as? String)
            ?? (userInfo["text"] as? String)
        
        if address == nil || address?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            address = "Localização atual"
        }
        
        let iconUrl = (userInfo["icon"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["icon"] as? String)
            ?? (userInfo["iconUrl"] as? String)
            ?? (userInfo["image"] as? String)
            ?? (userInfo["imageUrl"] as? String)
            ?? (userInfo["avatar"] as? String)
        
        downloadIconAndStartLiveActivity(
            nickname: nickname,
            address: address ?? "Localização atual",
            iconUrl: iconUrl,
            status: statusStr
        )
    }

    @available(iOS 16.1, *)
    private static func downloadIconAndStartLiveActivity(
        nickname: String,
        address: String,
        iconUrl: String?,
        status: String
    ) {
        guard let urlString = iconUrl, let url = URL(string: urlString) else {
            startLiveActivity(nickname: nickname, address: address, iconLocalPath: nil, iconUrl: iconUrl, status: status)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            var localPath: String? = nil
            if let data = data, error == nil {
                localPath = saveImageDataToContainer(data: data)
            }
            
            DispatchQueue.main.async {
                startLiveActivity(
                    nickname: nickname,
                    address: address,
                    iconLocalPath: localPath,
                    iconUrl: iconUrl,
                    status: status
                )
            }
        }.resume()
    }
    
    private static func saveImageDataToContainer(data: Data) -> String? {
        let fileManager = FileManager.default
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite)
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        guard let targetFolder = containerURL else { return nil }
        let fileURL = targetFolder.appendingPathComponent("bipe_alert_icon.png")
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            NSLog("[BipeLiveActivityManager] Erro ao salvar imagem no App Group container: %@", error.localizedDescription)
            return nil
        }
    }

    @available(iOS 16.1, *)
    private static func startLiveActivity(
        nickname: String,
        address: String,
        iconLocalPath: String?,
        iconUrl: String?,
        status: String
    ) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("[BipeLiveActivityManager] Live Activities desabilitadas pelo usuário.")
            return
        }
        
        endEmergencyLiveActivityInternal()
        
        let attributes = BipeAlertActivityAttributes()
        let state = BipeAlertActivityAttributes.ContentState(
            address: address,
            iconUrl: iconUrl,
            iconLocalPath: iconLocalPath,
            nickname: nickname,
            status: status
        )
        let content = ActivityContent(state: state, staleDate: nil)
        
        do {
            let activity = try Activity<BipeAlertActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            NSLog("[BipeLiveActivityManager] Live Activity iniciada com sucesso. ID: %@", activity.id)
            
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
            NSLog("[BipeLiveActivityManager] Erro ao iniciar Live Activity: %@", error.localizedDescription)
        }
        #endif
    }

    @objc public static func endEmergencyLiveActivity() {
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
                await activity.end(dismissalPolicy: .immediate)
                removeLiveActivityTokenFromServer(activityId: activityId)
            }
        }
        #endif
    }

    private static func sendLiveActivityTokenToServer(token: String, activityId: String) {
        AuthManager.shared.getBearerToken { bearerToken in
            guard let bearerToken = bearerToken else {
                NSLog("[BipeLiveActivityManager] Impossível registrar token: Bearer token ausente.")
                return
            }
            
            let moc = CoreData.sharedInstance().mainMOC
            let clientId = Settings.string(forKey: "clientid_preference", inMOC: moc)
            let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc)
            
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
            
            guard let url = URL(string: tokenEndpoint) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payloadDict)
            } catch {
                NSLog("[BipeLiveActivityManager] Erro ao serializar payload do token: %@", error.localizedDescription)
                return
            }
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    NSLog("[BipeLiveActivityManager] Erro ao enviar token para servidor: %@", error.localizedDescription)
                } else if let httpResp = response as? HTTPURLResponse {
                    NSLog("[BipeLiveActivityManager] Token enviado para o servidor. Status HTTP: %d", httpResp.statusCode)
                }
            }.resume()
        }
    }

    private static func removeLiveActivityTokenFromServer(activityId: String) {
        AuthManager.shared.getBearerToken { bearerToken in
            guard let bearerToken = bearerToken else { return }
            guard let url = URL(string: "\(activityEndpointPrefix)\(activityId)") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    NSLog("[BipeLiveActivityManager] Erro ao remover token do servidor: %@", error.localizedDescription)
                } else if let httpResp = response as? HTTPURLResponse {
                    NSLog("[BipeLiveActivityManager] Token da Live Activity removido do servidor. Status HTTP: %d", httpResp.statusCode)
                }
            }.resume()
        }
    }
}
