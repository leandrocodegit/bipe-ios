//
//  LoginViewController.swift
//  OwnTracks
//
//  Tela de login apresentada na inicialização do app quando o setup ainda não
//  foi realizado. Equivalente ao LoginActivity.kt do projeto Android (bipe-android).
//
//  Fluxo:
//   1. Usuário toca "Entrar com BIPE"
//   2. AuthManager abre o Keycloak no browser
//   3. Após autenticação, SetupService chama a API /bipe/devices/setup
//   4. Configurações MQTT são salvas e o app inicia o monitoramento
//

import UIKit

@objc(LoginViewController)
class LoginViewController: UIViewController {

    // MARK: - Elementos de UI

    private let backgroundView   = UIView()
    private let logoContainer    = UIView()
    private let logoImageView    = UIImageView()
    private let titleLabel       = UILabel()
    private let subtitleLabel    = UILabel()
    private let loginButton      = UIButton(type: .system)
    private let activityContainer = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let activityLabel    = UILabel()
    private let errorLabel       = UILabel()

    // MARK: - Ciclo de Vida

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Se já autenticado:
        // • setup concluído → vai direto pro app
        // • autenticado mas sem setup → tenta o setup
        if AuthManager.shared.isAuthorized {
            if UserDefaults.standard.bool(forKey: "setupCompleted") {
                proceedToApp()
            } else {
                setLoading(true, message: "Configurando dispositivo…")
                performSetup()
            }
        }
    }

    // MARK: - Ações

    @objc private func loginTapped() {
        setLoading(true, message: "Autenticando…")
        errorLabel.isHidden = true

        AuthManager.shared.startLogin(presenting: self) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.setLoading(true, message: "Configurando dispositivo…")
                    self.performSetup()
                } else {
                    self.setLoading(false)
                    let msg = error?.localizedDescription ?? "Erro desconhecido"
                    self.showError("Falha na autenticação: \(msg)")
                }
            }
        }
    }

    // MARK: - Setup

    private func performSetup() {
        SetupService.shared.performSetup { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                if success {
                    self.proceedToApp()
                } else {
                    self.showError("Erro ao configurar o dispositivo.\nVerifique a conexão e tente novamente.")
                }
            }
        }
    }

    private func proceedToApp() {
        guard let appDelegate = UIApplication.shared.delegate as? OwnTracksAppDelegate else { return }
        appDelegate.startOwnTracksMonitoring()
        dismiss(animated: true)
    }

    // MARK: - Estado de UI

    private func setLoading(_ loading: Bool, message: String = "") {
        loginButton.isEnabled = !loading
        loginButton.alpha = loading ? 0.5 : 1.0

        if loading {
            activityContainer.isHidden = false
            activityLabel.text = message
            activityIndicator.startAnimating()
        } else {
            activityContainer.isHidden = true
            activityIndicator.stopAnimating()
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        // Pequena animação de shake para chamar atenção
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -10, 10, -5, 5, 0]
        errorLabel.layer.add(animation, forKey: "shake")
    }

    // MARK: - Construção da UI (programática)

    private func buildUI() {
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)

        // ----- Background gradient overlay -----
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor
        ]
        gradientLayer.frame = UIScreen.main.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)

        // ----- Logo Container -----
        logoContainer.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.15)
        logoContainer.layer.cornerRadius = 32
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoContainer)

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(systemName: "location.circle.fill")
        logoImageView.tintColor = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.addSubview(logoImageView)

        // ----- Labels -----
        titleLabel.text = "BIPE"
        titleLabel.font = UIFont.systemFont(ofSize: 48, weight: .black)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        subtitleLabel.text = "Monitoramento de dispositivos"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // ----- Botão de Login -----
        var config = UIButton.Configuration.filled()
        config.title = "Entrar com BIPE"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1.0)
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            return updated
        }
        // Ícone de pessoa
        config.image = UIImage(systemName: "person.fill")
        config.imagePlacement = .leading
        config.imagePadding = 10

        loginButton.configuration = config
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        // Efeito de sombra no botão
        loginButton.layer.shadowColor = UIColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1.0).cgColor
        loginButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        loginButton.layer.shadowOpacity = 0.4
        loginButton.layer.shadowRadius = 12
        view.addSubview(loginButton)

        // ----- Activity indicator -----
        activityContainer.isHidden = true
        activityContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityContainer)

        activityIndicator.color = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityContainer.addSubview(activityIndicator)

        activityLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        activityLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        activityLabel.textAlignment = .center
        activityLabel.translatesAutoresizingMaskIntoConstraints = false
        activityContainer.addSubview(activityLabel)

        // ----- Error label -----
        errorLabel.textColor = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        errorLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)

        // ----- Constraints -----
        NSLayoutConstraint.activate([
            // Logo container
            logoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -160),
            logoContainer.widthAnchor.constraint(equalToConstant: 100),
            logoContainer.heightAnchor.constraint(equalToConstant: 100),

            // Logo image
            logoImageView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),

            // Title
            titleLabel.topAnchor.constraint(equalTo: logoContainer.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Login button
            loginButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // Activity container
            activityContainer.bottomAnchor.constraint(equalTo: loginButton.topAnchor, constant: -24),
            activityContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityContainer.widthAnchor.constraint(equalTo: view.widthAnchor),

            // Activity indicator (dentro do container)
            activityIndicator.topAnchor.constraint(equalTo: activityContainer.topAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: activityContainer.centerXAnchor),

            // Activity label
            activityLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            activityLabel.centerXAnchor.constraint(equalTo: activityContainer.centerXAnchor),
            activityLabel.bottomAnchor.constraint(equalTo: activityContainer.bottomAnchor),

            // Error label
            errorLabel.bottomAnchor.constraint(equalTo: activityContainer.topAnchor, constant: -16),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Barra de status

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
