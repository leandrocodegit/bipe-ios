//
//  BipeAlertActivityAttributes.swift
//  OwnTracks
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct BipeAlertActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var address: String
        public var iconUrl: String?
        public var iconLocalPath: String?
        public var nickname: String
        public var status: String
        public var timestamp: Date
        
        public init(
            address: String,
            iconUrl: String? = nil,
            iconLocalPath: String? = nil,
            nickname: String,
            status: String = "emergency",
            timestamp: Date = Date()
        ) {
            self.address = address
            self.iconUrl = iconUrl
            self.iconLocalPath = iconLocalPath
            self.nickname = nickname
            self.status = status
            self.timestamp = timestamp
        }
    }
    
    public var alertId: String
    
    public init(alertId: String = UUID().uuidString) {
        self.alertId = alertId
    }
}
#endif
