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

@objc enum SentinelState: Int {
    case idle
    case listening
    case gracePeriod
    case emergencyDispatched
    case batteryCritical
    case permissionDenied
    case error
    
    var description: String {
        switch self {
        case .idle: return "Inativo"
        case .listening: return "Monitorando"
        case .gracePeriod: return "Contagem Regressiva (Grace Period)"
        case .emergencyDispatched: return "Emergência Disparada"
        case .batteryCritical: return "Bateria Crítica"
        case .permissionDenied: return "Permissão Negada"
        case .error: return "Erro"
        }
    }
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
    
    /// Duração do Grace Period em segundos antes do disparo do alarme
    @objc var gracePeriodDuration: TimeInterval = 10.0
    
    /// Tempo restante no Grace Period atual (segundos)
    @objc private(set) var gracePeriodRemainingSeconds: Int = 10
    
    // MARK: - Estado
    
    @objc private(set) var currentState: SentinelState = .idle
    
    @objc var isMonitoring: Bool {
        return currentState == .listening || currentState == .gracePeriod
    }
    
    // MARK: - Callbacks
    
    var onStateChange: ((SentinelState) -> Void)?
    var onGracePeriodTick: ((Int) -> Void)?
    var onDecibelUpdate: ((Float) -> Void)?
    
    // MARK: - Propriedades Privadas
    
    private let audioEngine = AVAudioEngine()
    private var gracePeriodTimer: Timer?
    private var wasListeningBeforeInterruption: Bool = false
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Inicializador
    
    private override init() {
        super.init()
        setupNotifications()
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
    
    /// Inicia o monitoramento acústico passivo on-device
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
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("[SentinelAcousticMonitor] Erro ao desativar AVAudioSession: %@", error.localizedDescription)
        }
        
        transition(to: .idle)
        NSLog("[SentinelAcousticMonitor] Monitoramento acústico encerrado.")
    }
    
    // MARK: - Configuração da Engine de Áudio
    
    private func activateAudioEngine() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord com mode .measurement garante calibração linear sem AGC (Automatic Gain Control)
            // .mixWithOthers permite que músicas continuem tocando em segundo plano
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                NSLog("[SentinelAcousticMonitor] Formato de microfone inválido: %@", recordingFormat.description)
                transition(to: .error)
                return
            }
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                self?.processAudioBuffer(buffer: buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            transition(to: .listening)
            NSLog("[SentinelAcousticMonitor] Escuta passiva iniciada com sucesso (SampleRate: %.0f Hz).", recordingFormat.sampleRate)
            
        } catch {
            NSLog("[SentinelAcousticMonitor] Falha ao iniciar AVAudioEngine: %@", error.localizedDescription)
            transition(to: .error)
        }
    }
    
    // MARK: - Processamento Acústico On-Device (RAM Apenas)
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard currentState == .listening else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        // Cálculo de RMS: raiz quadrada da média dos quadrados das amostras
        var sumSquares: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameLength))
        
        // Conversão para dB SPL digital (calibração linear on-device)
        // 1e-7 previne log10 de zero
        let clampedRMS = max(rms, 1e-7)
        let db = max(0.0, 20.0 * log10(clampedRMS) + 120.0)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onDecibelUpdate?(db)
            
            if db >= self.thresholdDB && self.currentState == .listening {
                NSLog("[SentinelAcousticMonitor] Limiar excedido: %.1f dB >= %.1f dB", db, self.thresholdDB)
                self.triggerGracePeriod()
            }
        }
    }
    
    // MARK: - Grace Period & Prevenção de Falso Positivo
    
    private func triggerGracePeriod() {
        guard currentState == .listening else { return }
        
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
    
    /// Cancela o Grace Period caso tenha sido um falso alarme (toque na tela, cancelamento do usuário)
    @objc public func cancelGracePeriod() {
        guard currentState == .gracePeriod else { return }
        
        stopGracePeriodTimers()
        feedbackGenerator.notificationOccurred(.success)
        NSLog("[SentinelAcousticMonitor] Grace Period cancelado pelo usuário. Retomando escuta passiva.")
        
        transition(to: .listening)
    }
    
    private func stopGracePeriodTimers() {
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil
    }
    
    // MARK: - Despacho de Emergência
    
    private func dispatchEmergencyProtocol() {
        stopGracePeriodTimers()
        transition(to: .emergencyDispatched)
        
        NSLog("[SentinelAcousticMonitor] DISPARO DE EMERGÊNCIA ATIVADO! Sem intervenção durante o Grace Period.")
        
        // 1. Despacho pelo canal de emergência Bipe (MQTT /bipe)
        BipeEmergencyHelper.sendEmergencyAlert { success in
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
        // level < 0 indica que o monitoramento de bateria não pôde ser determinado (simulador etc.)
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
        // Se foi conectado ao carregador e estava em bateria crítica, pode voltar a monitorar se desejado
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
            NSLog("[SentinelAcousticMonitor] Interrupção de áudio iniciada (ex: chamada telefônica).")
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
                    NSLog("[SentinelAcousticMonitor] Escuta retomada com sucesso após interrupção.")
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
            // Fone de ouvido desconectado, reiniciar engine suavemente
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isMonitoring else { return }
                self.activateAudioEngine()
            }
        }
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
