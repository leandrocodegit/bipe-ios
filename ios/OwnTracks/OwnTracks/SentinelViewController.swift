//
//  SentinelViewController.swift
//  OwnTracks
//
//  Tela nativa do Modo Sentinela (Monitor Acústico Passivo On-Device)
//  Segurança preventiva com privacidade total (RAM apenas) e tolerância zero a falso positivo.
//

import UIKit
import AVFoundation

@objc class SentinelViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Header Shield Icon
    private let shieldImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "shield.lefthalf.filled") {
            iv.image = img
        } else {
            iv.image = UIImage(named: "OwnTracks-320.png")
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Modo Sentinela", comment: "")
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Monitoramento acústico preventivo on-device. Identifica ruídos anormais de impacto ou emergência sem gravar ou transmitir áudio.", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // Status & Switch Card
    private let statusCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let statusDotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 6
        view.backgroundColor = .gray
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Monitoramento Inativo", comment: "")
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let toggleSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.onTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return sw
    }()

    // Live Decibel VU Meter Card
    private let meterCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let meterTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Nível Acústico em Tempo Real", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let dbValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "-- dB"
        label.font = .systemFont(ofSize: 28, weight: .heavy)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return label
    }()

    private let progressTrackView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private let progressBarView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        view.layer.cornerRadius = 6
        return view
    }()
    private var progressBarWidthConstraint: NSLayoutConstraint?

    private let thresholdMarkerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Limiar de Gatilho: 75 dB"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        return label
    }()

    // Grace Period Countdown Alert Card (Visible when in countdown)
    private let gracePeriodCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 70/255, green: 20/255, blue: 25/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0).cgColor
        view.isHidden = true
        return view
    }()

    private let graceCountdownLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "10s"
        label.font = .systemFont(ofSize: 42, weight: .black)
        label.textColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()

    private let graceDescriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("RUÍDO FORTE DETECTADO!\nAlerta de emergência e localização serão enviados se não houver cancelamento.", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let cancelGraceButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("Falso Alarme (Cancelar)", comment: ""), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        btn.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        btn.layer.cornerRadius = 12
        return btn
    }()

    // Threshold Slider Card
    private let sliderCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let sliderTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Sensibilidade do Limiar (dB)", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let sliderCurrentValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "75 dB"
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return label
    }()

    private let thresholdSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 60.0
        slider.maximumValue = 95.0
        slider.value = 75.0
        slider.minimumTrackTintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        slider.maximumTrackTintColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0)
        return slider
    }()

    // Privacy Banner Card
    private let privacyCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 17/255, green: 27/255, blue: 30/255, alpha: 1.0)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 28/255, green: 44/255, blue: 49/255, alpha: 1.0).cgColor
        return view
    }()

    private let privacyIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "lock.shield.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let privacyTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Zero Cloud Audio: Toda a análise acústica ocorre 100% na memória RAM local do aparelho. Nenhum áudio bruto é gravado em disco ou transmitido para servidores.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupUI()
        setupActions()
        configureCallbacks()
        syncStateWithMonitor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncStateWithMonitor()
    }

    deinit {
        SentinelAcousticMonitor.shared.onStateChange = nil
        SentinelAcousticMonitor.shared.onDecibelUpdate = nil
        SentinelAcousticMonitor.shared.onGracePeriodTick = nil
    }

    // MARK: - Setup Navigation

    private func setupNavigation() {
        title = NSLocalizedString("Modo Sentinela", comment: "")
        navigationController?.navigationBar.barTintColor = UIColor(red: 11/255, green: 18/255, blue: 20/255, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        let closeBtn = UIBarButtonItem(title: NSLocalizedString("Fechar", comment: ""), style: .done, target: self, action: #selector(closeTapped))
        closeBtn.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        navigationItem.rightBarButtonItem = closeBtn
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UI Layout

    private func setupUI() {
        view.backgroundColor = UIColor(red: 11/255, green: 18/255, blue: 20/255, alpha: 1.0)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(shieldImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(statusCardView)
        contentView.addSubview(meterCardView)
        contentView.addSubview(gracePeriodCardView)
        contentView.addSubview(sliderCardView)
        contentView.addSubview(privacyCardView)

        // Status Card Subviews
        statusCardView.addSubview(statusDotView)
        statusCardView.addSubview(statusLabel)
        statusCardView.addSubview(toggleSwitch)

        // Meter Card Subviews
        meterCardView.addSubview(meterTitleLabel)
        meterCardView.addSubview(dbValueLabel)
        meterCardView.addSubview(progressTrackView)
        progressTrackView.addSubview(progressBarView)
        meterCardView.addSubview(thresholdMarkerLabel)

        // Grace Period Card Subviews
        gracePeriodCardView.addSubview(graceCountdownLabel)
        gracePeriodCardView.addSubview(graceDescriptionLabel)
        gracePeriodCardView.addSubview(cancelGraceButton)

        // Slider Card Subviews
        sliderCardView.addSubview(sliderTitleLabel)
        sliderCardView.addSubview(sliderCurrentValueLabel)
        sliderCardView.addSubview(thresholdSlider)

        // Privacy Card Subviews
        privacyCardView.addSubview(privacyIconView)
        privacyCardView.addSubview(privacyTextLabel)

        // Layout Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Shield & Headers
            shieldImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            shieldImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shieldImageView.widthAnchor.constraint(equalToConstant: 64),
            shieldImageView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: shieldImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            // Status Card
            statusCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            statusCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusCardView.heightAnchor.constraint(equalToConstant: 68),

            statusDotView.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 18),
            statusDotView.centerYAnchor.constraint(equalTo: statusCardView.centerYAnchor),
            statusDotView.widthAnchor.constraint(equalToConstant: 12),
            statusDotView.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.leadingAnchor.constraint(equalTo: statusDotView.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusCardView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -12),

            toggleSwitch.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -18),
            toggleSwitch.centerYAnchor.constraint(equalTo: statusCardView.centerYAnchor),

            // Meter Card
            meterCardView.topAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: 16),
            meterCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            meterCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            meterTitleLabel.topAnchor.constraint(equalTo: meterCardView.topAnchor, constant: 16),
            meterTitleLabel.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),

            dbValueLabel.topAnchor.constraint(equalTo: meterTitleLabel.bottomAnchor, constant: 6),
            dbValueLabel.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),

            progressTrackView.topAnchor.constraint(equalTo: dbValueLabel.bottomAnchor, constant: 14),
            progressTrackView.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),
            progressTrackView.trailingAnchor.constraint(equalTo: meterCardView.trailingAnchor, constant: -18),
            progressTrackView.heightAnchor.constraint(equalToConstant: 12),

            progressBarView.topAnchor.constraint(equalTo: progressTrackView.topAnchor),
            progressBarView.leadingAnchor.constraint(equalTo: progressTrackView.leadingAnchor),
            progressBarView.bottomAnchor.constraint(equalTo: progressTrackView.bottomAnchor),

            thresholdMarkerLabel.topAnchor.constraint(equalTo: progressTrackView.bottomAnchor, constant: 10),
            thresholdMarkerLabel.leadingAnchor.constraint(equalTo: meterCardView.leadingAnchor, constant: 18),
            thresholdMarkerLabel.trailingAnchor.constraint(equalTo: meterCardView.trailingAnchor, constant: -18),
            thresholdMarkerLabel.bottomAnchor.constraint(equalTo: meterCardView.bottomAnchor, constant: -16),

            // Grace Period Countdown Alert Card
            gracePeriodCardView.topAnchor.constraint(equalTo: meterCardView.bottomAnchor, constant: 16),
            gracePeriodCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            gracePeriodCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            graceCountdownLabel.topAnchor.constraint(equalTo: gracePeriodCardView.topAnchor, constant: 18),
            graceCountdownLabel.centerXAnchor.constraint(equalTo: gracePeriodCardView.centerXAnchor),

            graceDescriptionLabel.topAnchor.constraint(equalTo: graceCountdownLabel.bottomAnchor, constant: 8),
            graceDescriptionLabel.leadingAnchor.constraint(equalTo: gracePeriodCardView.leadingAnchor, constant: 16),
            graceDescriptionLabel.trailingAnchor.constraint(equalTo: gracePeriodCardView.trailingAnchor, constant: -16),

            cancelGraceButton.topAnchor.constraint(equalTo: graceDescriptionLabel.bottomAnchor, constant: 16),
            cancelGraceButton.leadingAnchor.constraint(equalTo: gracePeriodCardView.leadingAnchor, constant: 18),
            cancelGraceButton.trailingAnchor.constraint(equalTo: gracePeriodCardView.trailingAnchor, constant: -18),
            cancelGraceButton.heightAnchor.constraint(equalToConstant: 46),
            cancelGraceButton.bottomAnchor.constraint(equalTo: gracePeriodCardView.bottomAnchor, constant: -18),

            // Slider Card
            sliderCardView.topAnchor.constraint(equalTo: gracePeriodCardView.bottomAnchor, constant: 16),
            sliderCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sliderCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            sliderTitleLabel.topAnchor.constraint(equalTo: sliderCardView.topAnchor, constant: 16),
            sliderTitleLabel.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),

            sliderCurrentValueLabel.centerYAnchor.constraint(equalTo: sliderTitleLabel.centerYAnchor),
            sliderCurrentValueLabel.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),

            thresholdSlider.topAnchor.constraint(equalTo: sliderTitleLabel.bottomAnchor, constant: 14),
            thresholdSlider.leadingAnchor.constraint(equalTo: sliderCardView.leadingAnchor, constant: 18),
            thresholdSlider.trailingAnchor.constraint(equalTo: sliderCardView.trailingAnchor, constant: -18),
            thresholdSlider.bottomAnchor.constraint(equalTo: sliderCardView.bottomAnchor, constant: -16),

            // Privacy Card
            privacyCardView.topAnchor.constraint(equalTo: sliderCardView.bottomAnchor, constant: 16),
            privacyCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            privacyCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            privacyCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            privacyIconView.leadingAnchor.constraint(equalTo: privacyCardView.leadingAnchor, constant: 14),
            privacyIconView.topAnchor.constraint(equalTo: privacyCardView.topAnchor, constant: 14),
            privacyIconView.widthAnchor.constraint(equalToConstant: 24),
            privacyIconView.heightAnchor.constraint(equalToConstant: 24),

            privacyTextLabel.leadingAnchor.constraint(equalTo: privacyIconView.trailingAnchor, constant: 12),
            privacyTextLabel.topAnchor.constraint(equalTo: privacyCardView.topAnchor, constant: 14),
            privacyTextLabel.trailingAnchor.constraint(equalTo: privacyCardView.trailingAnchor, constant: -14),
            privacyTextLabel.bottomAnchor.constraint(equalTo: privacyCardView.bottomAnchor, constant: -14)
        ])

        progressBarWidthConstraint = progressBarView.widthAnchor.constraint(equalToConstant: 0)
        progressBarWidthConstraint?.isActive = true
    }

    // MARK: - Actions & Callbacks

    private func setupActions() {
        toggleSwitch.addTarget(self, action: #selector(toggleSwitchChanged(_:)), for: .valueChanged)
        thresholdSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        cancelGraceButton.addTarget(self, action: #selector(cancelGraceTapped), for: .touchUpInside)
    }

    @objc private func toggleSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            SentinelAcousticMonitor.shared.startMonitoring()
        } else {
            SentinelAcousticMonitor.shared.stopMonitoring()
        }
        syncStateWithMonitor()
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        let rounded = round(sender.value)
        sender.value = rounded
        SentinelAcousticMonitor.shared.thresholdDB = rounded
        sliderCurrentValueLabel.text = String(format: "%.0f dB", rounded)
        thresholdMarkerLabel.text = String(format: "Limiar de Gatilho: %.0f dB", rounded)
    }

    @objc private func cancelGraceTapped() {
        SentinelAcousticMonitor.shared.cancelGracePeriod()
        syncStateWithMonitor()
    }

    private func configureCallbacks() {
        SentinelAcousticMonitor.shared.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateChange(state)
            }
        }

        SentinelAcousticMonitor.shared.onDecibelUpdate = { [weak self] db in
            DispatchQueue.main.async {
                self?.updateMeter(db: db)
            }
        }

        SentinelAcousticMonitor.shared.onGracePeriodTick = { [weak self] remaining in
            DispatchQueue.main.async {
                self?.graceCountdownLabel.text = "\(remaining)s"
            }
        }
    }

    // MARK: - State Sync

    private func syncStateWithMonitor() {
        let monitor = SentinelAcousticMonitor.shared
        toggleSwitch.isOn = monitor.isMonitoring
        thresholdSlider.value = monitor.thresholdDB
        sliderCurrentValueLabel.text = String(format: "%.0f dB", monitor.thresholdDB)
        thresholdMarkerLabel.text = String(format: "Limiar de Gatilho: %.0f dB", monitor.thresholdDB)
        handleStateChange(monitor.currentState)
    }

    private func handleStateChange(_ state: SentinelState) {
        switch state {
        case .idle:
            statusLabel.text = NSLocalizedString("Monitoramento Inativo", comment: "")
            statusDotView.backgroundColor = .systemGray
            shieldImageView.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            toggleSwitch.isOn = false
            gracePeriodCardView.isHidden = true
            updateMeter(db: 0)

        case .listening:
            statusLabel.text = NSLocalizedString("Escuta Passiva Ativa", comment: "")
            statusDotView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            shieldImageView.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            toggleSwitch.isOn = true
            gracePeriodCardView.isHidden = true

        case .gracePeriod:
            statusLabel.text = NSLocalizedString("Atenção: Ruído Detectado!", comment: "")
            statusDotView.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            shieldImageView.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            toggleSwitch.isOn = true
            gracePeriodCardView.isHidden = false
            graceCountdownLabel.text = "\(SentinelAcousticMonitor.shared.gracePeriodRemainingSeconds)s"

        case .emergencyDispatched:
            statusLabel.text = NSLocalizedString("Alerta de Emergência Disparado", comment: "")
            statusDotView.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            gracePeriodCardView.isHidden = true

        case .batteryCritical:
            statusLabel.text = NSLocalizedString("Pausado: Bateria Crítica (<= 15%)", comment: "")
            statusDotView.backgroundColor = .systemOrange
            shieldImageView.tintColor = .systemOrange
            toggleSwitch.isOn = false
            gracePeriodCardView.isHidden = true

        case .permissionDenied:
            statusLabel.text = NSLocalizedString("Permissão de Microfone Negada", comment: "")
            statusDotView.backgroundColor = .systemRed
            toggleSwitch.isOn = false
            gracePeriodCardView.isHidden = true

        case .error:
            statusLabel.text = NSLocalizedString("Falha ao Iniciar Microfone", comment: "")
            statusDotView.backgroundColor = .systemRed
            toggleSwitch.isOn = false
            gracePeriodCardView.isHidden = true
        }
    }

    private func updateMeter(db: Float) {
        guard SentinelAcousticMonitor.shared.isMonitoring else {
            dbValueLabel.text = "-- dB"
            progressBarWidthConstraint?.constant = 0
            view.layoutIfNeeded()
            return
        }

        dbValueLabel.text = String(format: "%.1f dB", db)

        // Progress bar (0 dB a 100 dB)
        let totalWidth = progressTrackView.frame.width
        if totalWidth > 0 {
            let percentage = CGFloat(min(max(db, 0), 100) / 100.0)
            progressBarWidthConstraint?.constant = totalWidth * percentage

            if db >= SentinelAcousticMonitor.shared.thresholdDB {
                progressBarView.backgroundColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
                dbValueLabel.textColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            } else if db >= (SentinelAcousticMonitor.shared.thresholdDB - 10.0) {
                progressBarView.backgroundColor = UIColor.systemOrange
                dbValueLabel.textColor = UIColor.systemOrange
            } else {
                progressBarView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
                dbValueLabel.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            }
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
        }
    }
}
