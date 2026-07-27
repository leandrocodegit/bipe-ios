import Foundation

@objc
public class MessageRTC: NSObject {
    @objc public var subtype: String?
    @objc public var sdp: String?
    @objc public var candidate: String?
    @objc public var sdpMid: String?
    @objc public var sdpMLineIndex: NSNumber?
    @objc public var sessionId: String?
    @objc public var userName: String?
    @objc public var clienteId: String?
    @objc public var token: String?
    @objc public var status: String?

    @objc public init(dictionary: [String: Any]) {
        self.subtype = dictionary["subtype"] as? String
        self.sdp = dictionary["sdp"] as? String
        self.candidate = dictionary["candidate"] as? String
        self.sdpMid = dictionary["sdpMid"] as? String
        self.sdpMLineIndex = dictionary["sdpMLineIndex"] as? NSNumber
        self.sessionId = dictionary["sessionId"] as? String
        self.userName = dictionary["userName"] as? String
        self.clienteId = dictionary["clienteId"] as? String
        self.token = dictionary["token"] as? String
        self.status = dictionary["status"] as? String
    }
}
