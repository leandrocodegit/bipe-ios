//
//  BipeAlertActivityAttributes.swift
//  BipeWidgetExtension
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct BipeAlertActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var address: String
        public var way: String?
        public var event: String?
        public var devices: [String]?
        public var activityType: String?
        public var nickname: String
        public var status: String
        public var iconUrl: String?
        public var iconLocalPath: String?
        public var icon: String?
        public var timestamp: Double?
        public var target: String?
        public var alvo: String?
        public var distancia: String?
        public var sound: String?
        public var execucaoId: String?
        
        public init(
            address: String = "Localização atual",
            way: String? = nil,
            event: String? = nil,
            devices: [String]? = nil,
            activityType: String? = nil,
            nickname: String = "Bipe.me",
            status: String = "transition",
            iconUrl: String? = nil,
            iconLocalPath: String? = nil,
            icon: String? = nil,
            timestamp: Double? = Date().timeIntervalSince1970,
            target: String? = nil,
            alvo: String? = nil,
            distancia: String? = nil,
            sound: String? = nil,
            execucaoId: String? = nil
        ) {
            self.address = address
            self.way = way
            self.event = event
            self.devices = devices
            self.activityType = activityType
            self.nickname = nickname
            self.status = status
            self.iconUrl = iconUrl
            self.iconLocalPath = iconLocalPath
            self.icon = icon
            self.timestamp = timestamp
            self.target = target
            self.alvo = alvo
            self.distancia = distancia
            self.sound = sound
            self.execucaoId = execucaoId
        }

        private enum CodingKeys: String, CodingKey {
            case address, way, event, devices, activityType, nickname, status
            case iconUrl, iconLocalPath, icon, timestamp, target, alvo, distancia, sound, execucaoId
        }

        private enum AltCodingKeys: String, CodingKey {
            case execucao_id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let altContainer = try? decoder.container(keyedBy: AltCodingKeys.self)
            
            self.address = (try? container.decode(String.self, forKey: .address)) ?? "Localização atual"
            self.nickname = (try? container.decode(String.self, forKey: .nickname)) ?? "Bipe.me"
            self.status = (try? container.decode(String.self, forKey: .status)) ?? "transition"
            
            self.way = try? container.decode(String.self, forKey: .way)
            self.event = try? container.decode(String.self, forKey: .event)
            self.activityType = try? container.decode(String.self, forKey: .activityType)
            self.iconUrl = try? container.decode(String.self, forKey: .iconUrl)
            self.iconLocalPath = try? container.decode(String.self, forKey: .iconLocalPath)
            self.icon = try? container.decode(String.self, forKey: .icon)
            self.target = try? container.decode(String.self, forKey: .target)
            self.alvo = try? container.decode(String.self, forKey: .alvo)
            self.distancia = try? container.decode(String.self, forKey: .distancia)
            self.sound = try? container.decode(String.self, forKey: .sound)
            self.execucaoId = (try? container.decode(String.self, forKey: .execucaoId)) ?? (try? altContainer?.decode(String.self, forKey: .execucao_id))
            
            // Decodificação flexível para timestamp (Double ou String)
            if let doubleVal = try? container.decode(Double.self, forKey: .timestamp) {
                self.timestamp = doubleVal
            } else if let strVal = try? container.decode(String.self, forKey: .timestamp), let doubleConv = Double(strVal) {
                self.timestamp = doubleConv
            } else {
                self.timestamp = Date().timeIntervalSince1970
            }
            
            // Decodificação flexível para devices ([String] ou String única)
            if let arrayVal = try? container.decode([String].self, forKey: .devices) {
                self.devices = arrayVal
            } else if let singleString = try? container.decode(String.self, forKey: .devices) {
                let trimmed = singleString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.devices = [trimmed]
                } else {
                    self.devices = nil
                }
            } else {
                self.devices = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(address, forKey: .address)
            try container.encodeIfPresent(way, forKey: .way)
            try container.encodeIfPresent(event, forKey: .event)
            try container.encodeIfPresent(devices, forKey: .devices)
            try container.encodeIfPresent(activityType, forKey: .activityType)
            try container.encode(nickname, forKey: .nickname)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(iconUrl, forKey: .iconUrl)
            try container.encodeIfPresent(iconLocalPath, forKey: .iconLocalPath)
            try container.encodeIfPresent(icon, forKey: .icon)
            try container.encodeIfPresent(timestamp, forKey: .timestamp)
            try container.encodeIfPresent(target, forKey: .target)
            try container.encodeIfPresent(alvo, forKey: .alvo)
            try container.encodeIfPresent(distancia, forKey: .distancia)
            try container.encodeIfPresent(sound, forKey: .sound)
            try container.encodeIfPresent(execucaoId, forKey: .execucaoId)
        }
    }

    public var alertId: String
    
    public init(alertId: String = UUID().uuidString) {
        self.alertId = alertId
    }
}
#endif
