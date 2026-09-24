//
//  SentinelAcousticMonitor.swift
//  OwnTracks
//
//  Modo Sentinela / Monitor Acústico Passivo On-Device para Segurança Preventiva.
//  Processamento 100% em RAM (zero persistência ou streaming de áudio bruto).
//

import Foundation
import AVFoundation
import UIKit
import CoreLocation
import SoundAnalysis
import Speech

@objc enum SentinelState: Int {
    case idle
    case listening
    case attentionMode
    case gracePeriod
    case emergencyDispatched
    case batteryCritical
    case permissionDenied
    case error
    
    var description: String {
        switch self {
        case .idle: return "Inativo"
        case .listening: return "Monitorando"
        case .attentionMode: return "Modo de Atenção"
        case .gracePeriod: return "Contagem Regressiva (Grace Period)"
        case .emergencyDispatched: return "Emergência Disparada"
        case .batteryCritical: return "Bateria Crítica"
        case .permissionDenied: return "Permissão Negada"
        case .error: return "Erro"
        }
    }
}

struct DistressPhrase {
    let normalized: String
    let display: String
    let lang: String
}

@objc class SentinelAcousticMonitor: NSObject {
    
    @objc static let shared = SentinelAcousticMonitor()
    
    // MARK: - Objective-C Class Methods
    
    @objc class func sharedMonitor() -> SentinelAcousticMonitor {
        return shared
    }
    
    @objc class func startMonitoring() {
        shared.startMonitoring()
    }
    
    @objc class func stopMonitoring() {
        shared.stopMonitoring()
    }
    
    @objc class func cancelGracePeriod() {
        shared.cancelGracePeriod()
    }
    
    // MARK: - Configurações
    
    /// Limiar em dB SPL digital para ativação da contagem regressiva
    @objc var thresholdDB: Float = 75.0
    
    /// Habilita ou desabilita a detecção de impactos físicos e limiar de volume (para ambientes com ruído)
    @objc public var detectImpacts: Bool {
        get {
            if UserDefaults.standard.object(forKey: "sentinel_detect_impacts") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "sentinel_detect_impacts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sentinel_detect_impacts")
        }
    }
    
    /// Duração do Grace Period em segundos antes do disparo do alarme
    @objc var gracePeriodDuration: TimeInterval = 10.0
    
    /// Tempo restante no Grace Period atual (segundos)
    @objc private(set) var gracePeriodRemainingSeconds: Int = 10
    
    /// Causa detalhada do último disparo inteligente (ex: "Grito detectado", "Frase: 'não me bate'")
    @objc public private(set) var lastTriggerReason: String = ""
    
    // MARK: - Estado
    
    @objc private(set) var currentState: SentinelState = .idle
    
    @objc var isMonitoring: Bool {
        return currentState == .listening || currentState == .attentionMode || currentState == .gracePeriod
    }
    
    // MARK: - Callbacks
    
    var onStateChange: ((SentinelState) -> Void)?
    var onGracePeriodTick: ((Int) -> Void)?
    var onDecibelUpdate: ((Float) -> Void)?
    var onIntelligentDetection: ((String) -> Void)?
    
    // MARK: - Propriedades Privadas de Áudio e IA
    
    private let audioEngine = AVAudioEngine()
    private var attentionTimer: Timer?
    private var gracePeriodTimer: Timer?
    private var wasListeningBeforeInterruption: Bool = false
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // SoundAnalysis (Apple CoreML On-Device Sound Classifier)
    private var soundAnalyzer: SNAudioStreamAnalyzer?
    private var soundClassifyRequest: SNClassifySoundRequest?
    
    // Speech Recognition (Apple On-Device Speech Recognizer)
    private var speechRecognizer: SFSpeechRecognizer?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private var isRestartingSpeech: Bool = false
    private var recordingFormat: AVAudioFormat?
    
    // MARK: - Dicionário Multilíngue de Frases Nativas (PT, EN, ES)
    
    private let defaultDistressPhrases: [DistressPhrase] = [
        // Português (PT)
        DistressPhrase(normalized: "nao me bate", display: "Não me bate", lang: "PT"),
        DistressPhrase(normalized: "nao me machuca", display: "Não me machuca", lang: "PT"),
        DistressPhrase(normalized: "nao me agrida", display: "Não me agrida", lang: "PT"),
        DistressPhrase(normalized: "socorro me ajuda", display: "Socorro, me ajuda", lang: "PT"),
        DistressPhrase(normalized: "socorro", display: "Socorro", lang: "PT"),
        DistressPhrase(normalized: "me ajuda", display: "Me ajuda", lang: "PT"),
        DistressPhrase(normalized: "ajuda por favor", display: "Ajuda por favor", lang: "PT"),
        DistressPhrase(normalized: "para com isso", display: "Para com isso", lang: "PT"),
        DistressPhrase(normalized: "para por favor", display: "Para, por favor", lang: "PT"),
        DistressPhrase(normalized: "chama a policia", display: "Chama a polícia", lang: "PT"),
        DistressPhrase(normalized: "policia", display: "Polícia", lang: "PT"),
        DistressPhrase(normalized: "sai daqui", display: "Sai daqui", lang: "PT"),
        
        // English (EN)
        DistressPhrase(normalized: "dont hit me", display: "Don't hit me", lang: "EN"),
        DistressPhrase(normalized: "dont hurt me", display: "Don't hurt me", lang: "EN"),
        DistressPhrase(normalized: "help me", display: "Help me", lang: "EN"),
        DistressPhrase(normalized: "help", display: "Help", lang: "EN"),
        DistressPhrase(normalized: "please stop", display: "Please stop", lang: "EN"),
        DistressPhrase(normalized: "stop it", display: "Stop it", lang: "EN"),
        DistressPhrase(normalized: "call the police", display: "Call the police", lang: "EN"),
        DistressPhrase(normalized: "leave me alone", display: "Leave me alone", lang: "EN"),
        DistressPhrase(normalized: "get away from me", display: "Get away from me", lang: "EN"),
        
        // Español (ES)
        DistressPhrase(normalized: "no me pegues", display: "No me pegues", lang: "ES"),
        DistressPhrase(normalized: "no me hagas dano", display: "No me hagas daño", lang: "ES"),
        DistressPhrase(normalized: "no me toques", display: "No me toques", lang: "ES"),
        DistressPhrase(normalized: "ayudame", display: "Ayúdame", lang: "ES"),
        DistressPhrase(normalized: "ayuda", display: "Ayuda", lang: "ES"),
        DistressPhrase(normalized: "socorro", display: "Socorro", lang: "ES"),
        DistressPhrase(normalized: "para por favor", display: "Para, por favor", lang: "ES"),
        DistressPhrase(normalized: "basta ya", display: "Basta ya", lang: "ES"),
        DistressPhrase(normalized: "llama a la policia", display: "Llama a la policía", lang: "ES"),
        DistressPhrase(normalized: "dejame en paz", display: "Déjame en paz", lang: "ES"),
        DistressPhrase(normalized: "vete de aqui", display: "Vete de aquí", lang: "ES")
    ]
    
    // MARK: - Inicializador
    
    private override init() {
        super.init()
        setupNotifications()
        setupSpeechRecognizer()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopMonitoring()
    }
    
    // MARK: - Notificações do Sistema (Bateria e Áudio)
    
    private func setupNotifications() {
        // Monitoramento de Bateria
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // Interrupções de Áudio (ex: ligação recebida)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Mudança de Rota de Áudio (ex: fones de ouvido desconectados)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Controle de Monitoramento
    
    /// Inicia o monitoramento acústico passivo e inteligente on-device
    @objc public func startMonitoring() {
        guard !isMonitoring else {
            NSLog("[SentinelAcousticMonitor] Monitoramento já está em execução.")
            return
        }
        
        // Salvaguarda: Verificar nível de bateria antes de iniciar
        if isBatteryCritical() {
            NSLog("[SentinelAcousticMonitor] Nível de bateria crítico (<= 15%%). Início abortado.")
            transition(to: .batteryCritical)
            return
        }
        
        // Verificar permissão de microfone
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            activateAudioEngine()
        case .denied:
            NSLog("[SentinelAcousticMonitor] Permissão de gravação de áudio negada.")
            transition(to: .permissionDenied)
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.activateAudioEngine()
                    } else {
                        self?.transition(to: .permissionDenied)
                    }
                }
            }
        @unknown default:
            transition(to: .error)
        }
    }
    
    /// Encerra o monitoramento acústico
    @objc public func stopMonitoring() {
        stopGracePeriodTimers()
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        soundAnalyzer = nil
        soundClassifyRequest = nil
        speechTask?.cancel()
        speechTask = nil
        speechRequest?.endAudio()
        speechRequest = nil
        isRestartingSpeech = false
        lastTriggerReason = ""
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("[SentinelAcousticMonitor] Erro ao desativar AVAudioSession: %@", error.localizedDescription)
        }
        
        transition(to: .idle)
        NSLog("[SentinelAcousticMonitor] Monitoramento acústico encerrado.")
    }
    
    // MARK: - Configuração da Engine de Áudio e IA
    
    private func activateAudioEngine() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let recFormat = inputNode.outputFormat(forBus: 0)
            self.recordingFormat = recFormat
            
            guard recFormat.sampleRate > 0 && recFormat.channelCount > 0 else {
                NSLog("[SentinelAcousticMonitor] Formato de microfone inválido: %@", recFormat.description)
                transition(to: .error)
                return
            }
            
            // 1. Configurar SoundAnalysis (Detecção de gritos e vidro quebrando)
            setupSoundAnalysis(format: recFormat)
            
            // 2. Configurar Reconhecimento de Fala On-Device
            startSpeechSession(format: recFormat)
            
            // 3. Instalar Tap de Áudio em RAM
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recFormat) { [weak self] (buffer, time) in
                self?.processAudioBuffer(buffer: buffer, time: time)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            transition(to: .listening)
            NSLog("[SentinelAcousticMonitor] Escuta inteligente iniciada com sucesso (SampleRate: %.0f Hz).", recFormat.sampleRate)
            
        } catch {
            NSLog("[SentinelAcousticMonitor] Falha ao iniciar AVAudioEngine: %@", error.localizedDescription)
            transition(to: .error)
        }
    }
    
    // MARK: - SoundAnalysis Setup
    
    private func setupSoundAnalysis(format: AVAudioFormat) {
        if #available(iOS 14.0, *) {
            do {
                let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                request.overlapFactor = 0.5
                soundClassifyRequest = request
                
                let analyzer = SNAudioStreamAnalyzer(format: format)
                try analyzer.add(request, withObserver: self)
                self.soundAnalyzer = analyzer
                NSLog("[SentinelAcousticMonitor] SoundAnalysis (.version1) configurado.")
            } catch {
                NSLog("[SentinelAcousticMonitor] Falha ao inicializar SoundAnalysis: %@", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Speech Recognition Setup (On-Device)
    
    private func setupSpeechRecognizer() {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        let locale: Locale
        if preferred.hasPrefix("en") {
            locale = Locale(identifier: "en-US")
        } else if preferred.hasPrefix("es") {
            locale = Locale(identifier: "es-ES")
        } else {
            locale = Locale(identifier: "pt-BR")
        }
        speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    }
    
    private func startSpeechSession(format: AVAudioFormat) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                NSLog("[SentinelAcousticMonitor] Reconhecimento de fala não autorizado (%ld).", status.rawValue)
                return
            }
            DispatchQueue.main.async {
                self?.launchSpeechTask(format: format)
            }
        }
    }
    
    private func launchSpeechTask(format: AVAudioFormat) {
        guard currentState == .listening else { return }
        speechTask?.cancel()
        speechTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *), speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        self.speechRequest = request
        
        speechTask = speechRecognizer?.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                self.evaluateSpeechTranscription(transcription)
            }
            if error != nil || (result?.isFinal ?? false) {
                if self.isMonitoring && self.currentState == .listening {
                    self.restartSpeechSessionAfterDelay(format: format)
                }
            }
        }
    }
    
    private func restartSpeechSessionAfterDelay(format: AVAudioFormat) {
        guard !isRestartingSpeech else { return }
        isRestartingSpeech = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isRestartingSpeech = false
            if self.isMonitoring && self.currentState == .listening {
                self.launchSpeechTask(format: format)
            }
        }
    }
    
    private func evaluateSpeechTranscription(_ text: String) {
        guard currentState == .listening || currentState == .attentionMode else { return }
        let normalized = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        
        // 1. Verifica Frases Personalizadas do Usuário (até 3)
        for custom in getCustomKeywords() {
            let normCustom = custom.folding(options: .diacriticInsensitive, locale: .current).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !normCustom.isEmpty && normalized.contains(normCustom) {
                let reason = String(format: NSLocalizedString("Frase personalizada detectada: \"%@\"", comment: ""), custom)
                NSLog("[SentinelAcousticMonitor] MATCH PERSONALIZADO: %@", reason)
                triggerIntelligentEmergency(reason: reason)
                return
            }
        }
        
        // 2. Verifica Frases de Socorro Nativas (PT, EN, ES)
        for phrase in defaultDistressPhrases {
            if normalized.contains(phrase.normalized) {
                let reason = String(format: NSLocalizedString("Frase de socorro detectada (%@): \"%@\"", comment: ""), phrase.lang, phrase.display)
                NSLog("[SentinelAcousticMonitor] MATCH NATIVO: %@", reason)
                triggerIntelligentEmergency(reason: reason)
                return
            }
        }
    }
    
    // MARK: - Processamento Acústico On-Device (RAM Apenas)
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard currentState == .listening || currentState == .attentionMode else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        // 1. Cálculo de RMS e dB
        var sumSquares: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameLength))
        let clampedRMS = max(rms, 1e-7)
        let db = max(0.0, 20.0 * log10(clampedRMS) + 120.0)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onDecibelUpdate?(db)
            
            if self.detectImpacts && db >= self.thresholdDB && self.currentState == .listening {
                NSLog("[SentinelAcousticMonitor] Limiar acústico excedido: %.1f dB >= %.1f dB", db, self.thresholdDB)
                self.triggerAttentionMode(reason: String(format: NSLocalizedString("Limiar acústico excedido: %.0f dB", comment: ""), db))
            }
        }
        
        // 2. Alimentar SoundAnalysis (Classificação Neural On-Device)
        if #available(iOS 14.0, *), let analyzer = soundAnalyzer, time.isSampleTimeValid {
            analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }
        
        // 3. Alimentar Reconhecimento de Fala On-Device
        speechRequest?.append(buffer)
    }
    
    // MARK: - Gatilho Inteligente & Grace Period
    
    private func triggerAttentionMode(reason: String) {
        guard currentState == .listening else { return }
        
        transition(to: .attentionMode)
        NSLog("[SentinelAcousticMonitor] MODO DE ATENÇÃO INICIADO: %@", reason)
        
        // Aguarda 60 segundos por um grito ou frase. Se nada acontecer, cancela.
        stopGracePeriodTimers()
        attentionTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.currentState == .attentionMode {
                NSLog("[SentinelAcousticMonitor] Modo de Atenção expirou sem confirmação. Cancelando falso alarme.")
                self.transition(to: .listening)
            }
        }
    }
    
    @objc public func triggerIntelligentEmergency(reason: String) {
        guard currentState == .listening || currentState == .attentionMode else { return }
        
        let wasInAttentionMode = (currentState == .attentionMode)
        lastTriggerReason = reason
        NSLog("[SentinelAcousticMonitor] GATILHO INTELIGENTE DISPARADO: %@", reason)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onIntelligentDetection?(reason)
            
            // Se já estava no Modo de Atenção (pós-impacto) e detectou voz/grito, pula o Grace Period e despacha!
            if wasInAttentionMode {
                NSLog("[SentinelAcousticMonitor] Bypass de Grace Period ativado devido a Confirmação de Ameaça no Modo de Atenção!")
                self.dispatchEmergencyProtocol()
            } else {
                self.triggerGracePeriod()
            }
        }
    }
    
    private func triggerGracePeriod() {
        guard currentState == .listening || currentState == .attentionMode else { return }
        
        transition(to: .gracePeriod)
        gracePeriodRemainingSeconds = Int(gracePeriodDuration)
        
        // Vibração háptica de aviso inicial
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(.warning)
        onGracePeriodTick?(gracePeriodRemainingSeconds)
        
        stopGracePeriodTimers()
        
        // Timer de 1 em 1 segundo para contagem regressiva e feedback tátil
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.gracePeriodRemainingSeconds -= 1
            self.onGracePeriodTick?(self.gracePeriodRemainingSeconds)
            
            // Pulso háptico a cada segundo
            self.feedbackGenerator.notificationOccurred(.warning)
            
            if self.gracePeriodRemainingSeconds <= 0 {
                self.dispatchEmergencyProtocol()
            }
        }
    }
    
    /// Cancela o Grace Period caso tenha sido um falso alarme
    @objc public func cancelGracePeriod() {
        guard currentState == .gracePeriod else { return }
        
        stopGracePeriodTimers()
        feedbackGenerator.notificationOccurred(.success)
        lastTriggerReason = ""
        NSLog("[SentinelAcousticMonitor] Grace Period cancelado pelo usuário. Retomando escuta passiva.")
        
        transition(to: .listening)
    }
    
    private func stopGracePeriodTimers() {
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil
        attentionTimer?.invalidate()
        attentionTimer = nil
    }
    
    // MARK: - Despacho de Emergência
    
    private func dispatchEmergencyProtocol() {
        stopGracePeriodTimers()
        transition(to: .emergencyDispatched)
        
        NSLog("[SentinelAcousticMonitor] DISPARO DE EMERGÊNCIA ATIVADO! Motivo: %@", lastTriggerReason)
        
        // 1. Despacho pelo canal de emergência Bipe (MQTT /bipe)
        BipeEmergencyHelper.sendEmergencyAlert(type: "sentinela") { success in
            NSLog("[SentinelAcousticMonitor] BipeEmergencyHelper dispatch finalizado: %d", success)
        }
        
        // 2. Envio forçado de localização imediata para o servidor
        DispatchQueue.main.async {
            if let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate {
                let location = LocationManager.sharedInstance().location
                delegate.sendNow(location, withPOI: "SENTINEL_EMERGENCY", withImage: nil, withImageName: nil)
                NSLog("[SentinelAcousticMonitor] Localização de emergência enviada via sendNow: %@", location.description)
            }
        }
        
        // 3. Após despacho e confirmação, retomar escuta passiva automaticamente após 10 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            if self.currentState == .emergencyDispatched {
                NSLog("[SentinelAcousticMonitor] Retomando escuta passiva pós-emergência.")
                self.transition(to: .listening)
            }
        }
    }
    
    // MARK: - Salvaguarda de Bateria (<= 15%)
    
    private func isBatteryCritical() -> Bool {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        if level >= 0.0 && level <= 0.15 && state != .charging && state != .full {
            return true
        }
        return false
    }
    
    @objc private func batteryLevelDidChange() {
        if isBatteryCritical() && isMonitoring {
            NSLog("[SentinelAcousticMonitor] Bateria atingiu nível crítico (<= 15%%). Interrompendo escuta preventiva.")
            stopMonitoring()
            transition(to: .batteryCritical)
        }
    }
    
    @objc private func batteryStateDidChange() {
        if !isBatteryCritical() && currentState == .batteryCritical {
            NSLog("[SentinelAcousticMonitor] Aparelho conectado à energia. Pronto para retomar.")
            transition(to: .idle)
        }
    }
    
    // MARK: - Tratamento de Interrupções de Áudio
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            NSLog("[SentinelAcousticMonitor] Interrupção de áudio iniciada (ex: chamada).")
            wasListeningBeforeInterruption = isMonitoring
            if isMonitoring {
                audioEngine.pause()
            }
            
        case .ended:
            NSLog("[SentinelAcousticMonitor] Interrupção de áudio finalizada.")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasListeningBeforeInterruption {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    try audioEngine.start()
                    NSLog("[SentinelAcousticMonitor] Escuta retomada após interrupção.")
                } catch {
                    NSLog("[SentinelAcousticMonitor] Erro ao retomar após interrupção: %@", error.localizedDescription)
                }
            }
            wasListeningBeforeInterruption = false
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        if reason == .oldDeviceUnavailable && isMonitoring {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isMonitoring else { return }
                self.activateAudioEngine()
            }
        }
    }
    
    // MARK: - Gestão de Palavras-Chave Personalizadas (Até 3)
    
    private let customKeywordsKey = "sentinel_custom_keywords"
    
    @objc func getCustomKeywords() -> [String] {
        return UserDefaults.standard.stringArray(forKey: customKeywordsKey) ?? []
    }
    
    @objc func addCustomKeyword(_ keyword: String) -> Bool {
        var list = getCustomKeywords()
        guard list.count < 10 else { return false }
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = trimmed.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if list.contains(where: { $0.folding(options: .diacriticInsensitive, locale: .current).lowercased() == normalized }) {
            return false
        }
        list.append(trimmed)
        UserDefaults.standard.set(Array(list.prefix(10)), forKey: customKeywordsKey)
        return true
    }
    
    @objc func removeCustomKeyword(at index: Int) {
        var list = getCustomKeywords()
        guard index >= 0 && index < list.count else { return }
        list.remove(at: index)
        UserDefaults.standard.set(list, forKey: customKeywordsKey)
    }
    
    // MARK: - Gestão de Contatos de Confiança (Máximo: 3)
    
    private let trustedContactsKey = "sentinel_trusted_contacts"
    
    @objc func getTrustedContacts() -> [TrustedContact] {
        guard let data = UserDefaults.standard.data(forKey: trustedContactsKey),
              let contacts = try? JSONDecoder().decode([TrustedContact].self, from: data) else {
            return []
        }
        return contacts
    }
    
    @objc func saveTrustedContacts(_ contacts: [TrustedContact]) {
        let limited = Array(contacts.prefix(3))
        if let data = try? JSONEncoder().encode(limited) {
            UserDefaults.standard.set(data, forKey: trustedContactsKey)
        }
    }
    
    @objc func addTrustedContact(name: String, phoneNumber: String, avatarData: Data? = nil) -> Bool {
        var contacts = getTrustedContacts()
        guard contacts.count < 3 else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !digits.isEmpty else { return false }
        
        let formattedPhone: String
        if trimmedPhone.hasPrefix("+") {
            formattedPhone = "+" + digits
        } else if digits.count == 10 || digits.count == 11 {
            formattedPhone = "+55" + digits
        } else if digits.count >= 12 {
            formattedPhone = "+" + digits
        } else {
            formattedPhone = digits
        }
        
        let newContact = TrustedContact(name: trimmedName, phoneNumber: formattedPhone, avatarData: avatarData)
        contacts.append(newContact)
        saveTrustedContacts(contacts)
        return true
    }
    
    @objc func removeTrustedContact(at index: Int) {
        var contacts = getTrustedContacts()
        guard index >= 0 && index < contacts.count else { return }
        contacts.remove(at: index)
        saveTrustedContacts(contacts)
    }

    // MARK: - Transição de Estado
    
    private func transition(to newState: SentinelState) {
        guard currentState != newState else { return }
        currentState = newState
        NSLog("[SentinelAcousticMonitor] Estado alterado para: %@", newState.description)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChange?(self.currentState)
        }
    }
}

// MARK: - SoundAnalysis Observer (Apple Neural Sound Classifier)

@available(iOS 14.0, *)
extension SentinelAcousticMonitor: SNResultsObserving {
    public func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }
        guard currentState == .listening || currentState == .attentionMode else { return }
        
        for classification in classificationResult.classifications {
            let identifier = classification.identifier.lowercased()
            let confidence = classification.confidence
            
            // Vidro quebrando / Shatter (confiança >= 0.50) - apenas se detecção de impactos estiver ativa
            if detectImpacts && (identifier.contains("shatter") || identifier.contains("glass") || identifier.contains("breaking")) && confidence >= 0.50 {
                let reason = String(format: NSLocalizedString("Vidro quebrando detectado (certeza: %.0f%%)", comment: ""), confidence * 100)
                triggerIntelligentEmergency(reason: reason)
                return
            }
            
            // Gritos / Berros de pânico (confiança >= 0.55)
            if (identifier.contains("screaming") || identifier.contains("shouting") || identifier.contains("groan")) && confidence >= 0.55 {
                let reason = String(format: NSLocalizedString("Grito ou pedido de pânico detectado (certeza: %.0f%%)", comment: ""), confidence * 100)
                triggerIntelligentEmergency(reason: reason)
                return
            }
        }
    }
    
    public func request(_ request: SNRequest, didFailWithError error: Error) {
        NSLog("[SentinelAcousticMonitor] SoundAnalysis falhou: %@", error.localizedDescription)
    }
}

// MARK: - Modelo de Contato de Confiança

@objc class TrustedContact: NSObject, Codable {
    @objc let id: String
    @objc let name: String
    @objc let phoneNumber: String
    let avatarData: Data?

    init(id: String = UUID().uuidString, name: String, phoneNumber: String, avatarData: Data? = nil) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.avatarData = avatarData
        super.init()
    }
}
