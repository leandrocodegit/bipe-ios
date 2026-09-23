//
//  SentinelViewController.swift
//  OwnTracks
//
//  Tela nativa do Modo Sentinela (Monitor Acústico Passivo On-Device)
//  Segurança preventiva com privacidade total (RAM apenas) e tolerância zero a falso positivo.
//  Permite cadastrar até 3 contatos de confiança para notificação em caso de emergência.
//

import UIKit
import AVFoundation
import ContactsUI

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

    // MARK: - Trusted Contacts Card
    private let contactsCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 38/255, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 35/255, green: 53/255, blue: 59/255, alpha: 1.0).cgColor
        return view
    }()

    private let contactsIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *), let img = UIImage(systemName: "person.2.fill") {
            iv.image = img
        }
        iv.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        return iv
    }()

    private let contactsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Contatos de Confiança", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let contactsBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0/3"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        label.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.15)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private let contactsSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Cadastre até 3 contatos para serem notificados com suas coordenadas em caso de incidente.", comment: "")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    private let contactsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()

    private let addContactButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(NSLocalizedString("+ Adicionar Contato de Confiança", comment: ""), for: .normal)
        btn.setTitleColor(UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        btn.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.1)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.3).cgColor
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
        refreshContactsUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncStateWithMonitor()
        refreshContactsUI()
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
        contentView.addSubview(contactsCardView)
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

        // Contacts Card Subviews
        contactsCardView.addSubview(contactsIconView)
        contactsCardView.addSubview(contactsTitleLabel)
        contactsCardView.addSubview(contactsBadgeLabel)
        contactsCardView.addSubview(contactsSubtitleLabel)
        contactsCardView.addSubview(contactsStackView)
        contactsCardView.addSubview(addContactButton)

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

            // Contacts Card
            contactsCardView.topAnchor.constraint(equalTo: gracePeriodCardView.bottomAnchor, constant: 16),
            contactsCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contactsCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            contactsIconView.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            contactsIconView.topAnchor.constraint(equalTo: contactsCardView.topAnchor, constant: 16),
            contactsIconView.widthAnchor.constraint(equalToConstant: 22),
            contactsIconView.heightAnchor.constraint(equalToConstant: 22),

            contactsTitleLabel.leadingAnchor.constraint(equalTo: contactsIconView.trailingAnchor, constant: 10),
            contactsTitleLabel.centerYAnchor.constraint(equalTo: contactsIconView.centerYAnchor),

            contactsBadgeLabel.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),
            contactsBadgeLabel.centerYAnchor.constraint(equalTo: contactsIconView.centerYAnchor),
            contactsBadgeLabel.widthAnchor.constraint(equalToConstant: 36),
            contactsBadgeLabel.heightAnchor.constraint(equalToConstant: 22),

            contactsSubtitleLabel.topAnchor.constraint(equalTo: contactsIconView.bottomAnchor, constant: 8),
            contactsSubtitleLabel.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            contactsSubtitleLabel.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),

            contactsStackView.topAnchor.constraint(equalTo: contactsSubtitleLabel.bottomAnchor, constant: 14),
            contactsStackView.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            contactsStackView.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),

            addContactButton.topAnchor.constraint(equalTo: contactsStackView.bottomAnchor, constant: 12),
            addContactButton.leadingAnchor.constraint(equalTo: contactsCardView.leadingAnchor, constant: 16),
            addContactButton.trailingAnchor.constraint(equalTo: contactsCardView.trailingAnchor, constant: -16),
            addContactButton.heightAnchor.constraint(equalToConstant: 44),
            addContactButton.bottomAnchor.constraint(equalTo: contactsCardView.bottomAnchor, constant: -16),

            // Slider Card
            sliderCardView.topAnchor.constraint(equalTo: contactsCardView.bottomAnchor, constant: 16),
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
        addContactButton.addTarget(self, action: #selector(addContactTapped), for: .touchUpInside)
    }

    @objc private func toggleSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            SentinelAcousticMonitor.startMonitoring()
        } else {
            SentinelAcousticMonitor.stopMonitoring()
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
        SentinelAcousticMonitor.cancelGracePeriod()
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

    // MARK: - Contacts Management UI

    private func refreshContactsUI() {
        for view in contactsStackView.arrangedSubviews {
            contactsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let contacts = SentinelAcousticMonitor.shared.getTrustedContacts()
        contactsBadgeLabel.text = "\(contacts.count)/3"
        addContactButton.isHidden = contacts.count >= 3

        for (index, contact) in contacts.enumerated() {
            let rowView = createContactRowView(contact: contact, index: index)
            contactsStackView.addArrangedSubview(rowView)
        }
    }

    private func createContactRowView(contact: TrustedContact, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 28/255, green: 42/255, blue: 47/255, alpha: 1.0)
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 38/255, green: 56/255, blue: 62/255, alpha: 1.0).cgColor

        // Avatar or initials circle
        let avatarView = UIView()
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.2)
        avatarView.layer.cornerRadius = 18
        avatarView.clipsToBounds = true

        let avatarImageView = UIImageView()
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill

        let initialsLabel = UILabel()
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = .systemFont(ofSize: 13, weight: .bold)
        initialsLabel.textColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        initialsLabel.textAlignment = .center

        if let data = contact.avatarData, let img = UIImage(data: data) {
            avatarImageView.image = img
            avatarImageView.isHidden = false
            initialsLabel.isHidden = true
        } else {
            let initials = contact.name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
            initialsLabel.text = initials.isEmpty ? "C" : initials
            avatarImageView.isHidden = true
            initialsLabel.isHidden = false
        }

        avatarView.addSubview(avatarImageView)
        avatarView.addSubview(initialsLabel)

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = contact.name
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .white

        let phoneLabel = UILabel()
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        phoneLabel.text = contact.phoneNumber.isEmpty ? NSLocalizedString("Sem telefone", comment: "") : contact.phoneNumber
        phoneLabel.font = .systemFont(ofSize: 12, weight: .regular)
        phoneLabel.textColor = UIColor(red: 160/255, green: 175/255, blue: 180/255, alpha: 1.0)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, phoneLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2

        let deleteButton = UIButton(type: .system)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *), let img = UIImage(systemName: "trash") {
            deleteButton.setImage(img, for: .normal)
        } else {
            deleteButton.setTitle("✕", for: .normal)
        }
        deleteButton.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.8)
        deleteButton.tag = index
        deleteButton.addTarget(self, action: #selector(deleteContactTapped(_:)), for: .touchUpInside)

        container.addSubview(avatarView)
        container.addSubview(textStack)
        container.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 54),

            avatarView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            avatarView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),

            avatarImageView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            initialsLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -10),

            deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 30),
            deleteButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        return container
    }

    @objc private func addContactTapped() {
        guard SentinelAcousticMonitor.shared.getTrustedContacts().count < 3 else {
            let alert = UIAlertController(title: NSLocalizedString("Limite Atingido", comment: ""),
                                          message: NSLocalizedString("Você já cadastrou o número máximo de 3 contatos de confiança.", comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }

        let actionSheet = UIAlertController(title: NSLocalizedString("Adicionar Contato de Confiança", comment: ""),
                                            message: NSLocalizedString("Como deseja adicionar o contato de emergência?", comment: ""),
                                            preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Escolher da Agenda do iPhone", comment: ""), style: .default, handler: { [weak self] _ in
            self?.openContactPicker()
        }))

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Digitar Nome e Telefone", comment: ""), style: .default, handler: { [weak self] _ in
            self?.openManualContactAlert()
        }))

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancelar", comment: ""), style: .cancel, handler: nil))

        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = addContactButton
            popover.sourceRect = addContactButton.bounds
        }

        present(actionSheet, animated: true)
    }

    private func openContactPicker() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openManualContactAlert() {
        let alert = UIAlertController(title: NSLocalizedString("Novo Contato de Confiança", comment: ""),
                                      message: NSLocalizedString("Informe o nome e o número de telefone com DDD.", comment: ""),
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = NSLocalizedString("Nome do Contato", comment: "")
            tf.autocapitalizationType = .words
        }
        alert.addTextField { tf in
            tf.placeholder = NSLocalizedString("Telefone (com DDD)", comment: "")
            tf.keyboardType = .phonePad
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancelar", comment: ""), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Adicionar", comment: ""), style: .default, handler: { [weak self] _ in
            let name = alert.textFields?[0].text ?? ""
            let phone = alert.textFields?[1].text ?? ""
            if SentinelAcousticMonitor.shared.addTrustedContact(name: name, phoneNumber: phone) {
                self?.refreshContactsUI()
            }
        }))

        present(alert, animated: true)
    }

    @objc private func deleteContactTapped(_ sender: UIButton) {
        let index = sender.tag
        SentinelAcousticMonitor.shared.removeTrustedContact(at: index)
        refreshContactsUI()
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

// MARK: - CNContactPickerDelegate

extension SentinelViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let displayName = fullName.isEmpty ? (contact.organizationName.isEmpty ? NSLocalizedString("Contato", comment: "") : contact.organizationName) : fullName
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        let avatar = contact.thumbnailImageData

        if SentinelAcousticMonitor.shared.addTrustedContact(name: displayName, phoneNumber: phone, avatarData: avatar) {
            refreshContactsUI()
        }
    }
}
