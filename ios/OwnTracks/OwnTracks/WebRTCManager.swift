import Foundation
import AVFoundation
import WebRTC
import CoreData

@objc
public class WebRTCManager: NSObject {
    @objc public static let shared = WebRTCManager()

    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var localAudioSource: RTCAudioSource?
    private var localAudioTrack: RTCAudioTrack?

    private var isCallInProgress = false
    private var currentSessionId: String?
    private var currentUserName: String?
    private var currentClienteId: String?

    private var processedMessageIds = Set<String>()
    private var connectionTimeoutTimer: Timer?

    private override init() {
        super.init()
        initPeerConnectionFactory()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReceiveRTCMessage(_:)),
            name: NSNotification.Name("ReceiveRTCMessage"),
            object: nil
        )
    }

    @objc private func handleReceiveRTCMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let messageDict = userInfo["message"] as? [String: Any] else { return }
        
        let message = MessageRTC(dictionary: messageDict)
        // Precisamos do messageId. No OwnTracking.m, não é sempre enviado junto da mensagem para o observer?
        // Vamos usar um UUID temporário se não houver. O Android recebe messageId na mensagem push.
        // Como o MQTT não provê messageId no payload, geramos um UUID aleatório temporário
        let messageId = UUID().uuidString
        
        handleIncomingSignaling(message: message, messageId: messageId)
    }

    private func initPeerConnectionFactory() {
        // Inicialização do SSL e FieldTrials é feita automaticamente nas versões mais recentes do WebRTC.
        
        let factoryOptions = RTCPeerConnectionFactoryOptions()
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
        peerConnectionFactory?.setOptions(factoryOptions)
    }

    @objc
    public func startCall(messageId: String? = nil, sessionId: String? = nil, userName: String? = nil, clienteId: String? = nil, incomingToken: String? = nil) {
        // Obter modo de operacao e token se necessario
        // Ignorando restrições de permissão por simplicidade
        DispatchQueue.main.async {
            self.actuallyStartCall(messageId: messageId, sessionId: sessionId, userName: userName, clienteId: clienteId)
        }
    }

    private func actuallyStartCall(messageId: String?, sessionId: String?, userName: String?, clienteId: String?) {
        if let msgId = messageId {
            if processedMessageIds.contains(msgId) { return }
            processedMessageIds.insert(msgId)
        }

        if isCallInProgress {
            sendBusyMessage(sessionId: sessionId, userName: userName, clienteId: clienteId)
            return
        }

        playCustomBeep()

        isCallInProgress = true
        currentSessionId = sessionId
        currentUserName = userName
        currentClienteId = clienteId

        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            if self?.isCallInProgress == true {
                self?.stopCall()
            }
        }

        setupAudioMode(on: true)
        createPeerConnection()

        let mandatoryConstraints = [
            "OfferToReceiveAudio": "false",
            "OfferToReceiveVideo": "false"
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else { return }
            self.peerConnection?.setLocalDescription(sdp) { error in
                if error == nil {
                    self.sendSignalingMessage(subtype: "offer", sdp: sdp.sdp)
                }
            }
        }
    }

    private func playCustomBeep() {
        // AudioServicesPlaySystemSound(1005) // Example system sound
        // To be replaced with freesound if added to project
    }

    private func setupAudioMode(on: Bool) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if on {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true)
            } else {
                try audioSession.setActive(false)
                try audioSession.setCategory(.ambient, mode: .default)
            }
        } catch {
            print("WebRTC AVAudioSession error: \(error)")
        }
    }

    private func createPeerConnection() {
        if peerConnection != nil {
            peerConnection?.close()
        }

        let iceServer = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        let config = RTCConfiguration()
        config.iceServers = [iceServer]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = peerConnectionFactory?.peerConnection(with: config, constraints: constraints, delegate: self)

        addAudioTrack()
    }

    private func addAudioTrack() {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: ["googAutoGainControl": "true"], optionalConstraints: nil)
        localAudioSource = peerConnectionFactory?.audioSource(with: audioConstraints)
        localAudioTrack = peerConnectionFactory?.audioTrack(with: localAudioSource!, trackId: "ARDAMSa0")
        localAudioTrack?.isEnabled = true
        if let track = localAudioTrack {
            peerConnection?.add(track, streamIds: ["ARDAMS"])
        }
    }

    @objc
    public func handleIncomingSignaling(message: MessageRTC, messageId: String) {
        if processedMessageIds.contains(messageId) { return }
        processedMessageIds.insert(messageId)

        if currentUserName == nil { currentUserName = message.userName }
        if currentClienteId == nil { currentClienteId = message.clienteId }

        if let subtype = message.subtype {
            switch subtype {
            case "offer":
                handleOffer(sdp: message.sdp ?? "", sessionId: message.sessionId, userName: message.userName, clienteId: message.clienteId, incomingToken: message.token)
            case "answer":
                handleAnswer(sdp: message.sdp ?? "")
            case "candidate":
                handleCandidate(message: message)
            default:
                break
            }
        } else if message.status == "IDLE" {
            initiateCall(sessionId: message.sessionId, userName: message.userName, clienteId: message.clienteId)
        }
    }

    private func initiateCall(sessionId: String?, userName: String?, clienteId: String?) {
        DispatchQueue.main.async {
            self.actuallyInitiateCall(sessionId: sessionId, userName: userName, clienteId: clienteId)
        }
    }

    private func actuallyInitiateCall(sessionId: String?, userName: String?, clienteId: String?) {
        if isCallInProgress {
            sendBusyMessage(sessionId: sessionId, userName: userName, clienteId: clienteId)
            return
        }

        playCustomBeep()

        isCallInProgress = true
        currentSessionId = sessionId
        currentUserName = userName
        currentClienteId = clienteId

        setupAudioMode(on: true)
        createPeerConnection()

        let mandatoryConstraints = [
            "OfferToReceiveAudio": "true",
            "OfferToReceiveVideo": "false"
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self else { return }
            if let err = error {
                print("Failed to create offer: \(err)")
                return
            }
            guard let offerSdp = sdp else { return }
            self.peerConnection?.setLocalDescription(offerSdp) { error in
                if let err = error {
                    print("Failed to set local description: \(err)")
                } else {
                    print("Successfully created offer and set local description")
                    self.sendSignalingMessage(subtype: "offer", sdp: offerSdp.sdp)
                }
            }
        }
    }

    private func handleOffer(sdp: String, sessionId: String?, userName: String?, clienteId: String?, incomingToken: String?) {
        DispatchQueue.main.async {
            self.actuallyHandleOffer(sdp: sdp, sessionId: sessionId, userName: userName, clienteId: clienteId)
        }
    }

    private func actuallyHandleOffer(sdp: String, sessionId: String?, userName: String?, clienteId: String?) {
        if isCallInProgress {
            sendBusyMessage(sessionId: sessionId, userName: userName, clienteId: clienteId)
            return
        }

        playCustomBeep()

        isCallInProgress = true
        currentSessionId = sessionId
        currentUserName = userName
        currentClienteId = clienteId

        setupAudioMode(on: true)
        createPeerConnection()

        let mandatoryConstraints = [
            "OfferToReceiveAudio": "true",
            "OfferToReceiveVideo": "false"
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)

        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            guard let self = self else { return }
            if let err = error {
                print("Failed to set remote description: \(err)")
                return
            }
            self.peerConnection?.answer(for: constraints) { sdp, error in
                if let err = error {
                    print("Failed to create answer: \(err)")
                    return
                }
                guard let answerSdp = sdp else { return }
                self.peerConnection?.setLocalDescription(answerSdp) { error in
                    if let err = error {
                        print("Failed to set local description: \(err)")
                    } else {
                        print("Successfully created answer and set local description")
                        self.sendSignalingMessage(subtype: "answer", sdp: answerSdp.sdp)
                    }
                }
            }
        }
    }

    private func handleAnswer(sdp: String) {
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
        peerConnection?.setRemoteDescription(sessionDescription, completionHandler: { error in
            if let err = error {
                print("Failed to set remote description: \(err)")
            }
        })
    }

    private func handleCandidate(message: MessageRTC) {
        if let sdp = message.candidate, let sdpMid = message.sdpMid, let sdpMLineIndex = message.sdpMLineIndex {
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: Int32(truncating: sdpMLineIndex), sdpMid: sdpMid)
            peerConnection?.add(candidate)
        }
    }

    private func sendBusyMessage(sessionId: String?, userName: String?, clienteId: String?) {
        // Implementar envio de mensagem via MQTT (bridge)
        let json: [String: Any] = [
            "_type": "call",
            "subtype": "busy",
            "sessionId": sessionId ?? "",
            "userName": userName ?? "",
            "clienteId": clienteId ?? ""
        ]
        sendMqttMessage(json: json)
    }

    private func sendSignalingMessage(subtype: String, sdp: String) {
        let json: [String: Any] = [
            "_type": "call",
            "subtype": subtype,
            "sdp": sdp,
            "sessionId": currentSessionId ?? "",
            "userName": currentUserName ?? "",
            "clienteId": currentClienteId ?? ""
        ]
        sendMqttMessage(json: json)
    }

    private func sendIceCandidate(candidate: RTCIceCandidate) {
        let json: [String: Any] = [
            "_type": "call",
            "subtype": "candidate",
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": NSNumber(value: candidate.sdpMLineIndex),
            "sessionId": currentSessionId ?? "",
            "userName": currentUserName ?? "",
            "clienteId": currentClienteId ?? ""
        ]
        sendMqttMessage(json: json)
    }

    private func sendMqttMessage(json: [String: Any]) {
        // The topic must be "owntracks/\(username)/\(deviceId)/rtc/send"
        // We can post a Notification, or call AppDelegate
        NotificationCenter.default.post(name: NSNotification.Name("SendRTCMQTTMessage"), object: nil, userInfo: json)
    }

    @objc
    public func stopCall() {
        connectionTimeoutTimer?.invalidate()
        isCallInProgress = false
        currentSessionId = nil
        currentUserName = nil
        currentClienteId = nil
        processedMessageIds.removeAll()
        setupAudioMode(on: false)
        peerConnection?.close()
        peerConnection = nil
        localAudioSource = nil
        localAudioTrack = nil
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DispatchQueue.main.async {
            if newState == .connected {
                self.connectionTimeoutTimer?.invalidate()
            }
            if newState == .disconnected || newState == .failed || newState == .closed {
                if self.isCallInProgress {
                    self.stopCall()
                }
            }
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        sendIceCandidate(candidate: candidate)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
