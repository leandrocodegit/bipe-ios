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
        
        public init(
            address: String,
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
            distancia: String? = nil
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
        }
    }

    public var alertId: String
    
    public init(alertId: String = UUID().uuidString) {
        self.alertId = alertId
    }
}
#endif
