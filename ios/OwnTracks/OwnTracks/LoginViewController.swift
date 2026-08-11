//
//  LoginViewController.swift
//  OwnTracks
//
//  Tela de login apresentada modalmente antes do app iniciar o monitoramento.
//  Fluxo: Keycloak OAuth (AppAuth) → /bipe/devices/setup → app normal
//

import UIKit

class LoginViewController: UIViewController {

    // MARK: - UI

    private lazy var logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        let img = UIImage(named: "OwnTracks-320.png") ?? UIImage(named: "OwnTracks-320") ?? UIImage(named: "AppIcon")
        iv.image = img?.withRenderingMode(.alwaysOriginal)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Bipe.me"
        l.font = UIFont.systemFont(ofSize: 42, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Rastreamento inteligente"
        l.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        l.textColor = UIColor(white: 0.8, alpha: 1.0)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var loginButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Entrar com Bipe.me"
        config.image = UIImage(systemName: "person.badge.key.fill")
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return b
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .large)
        a.color = .white
        a.hidesWhenStopped = true
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.text = ""
        l.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        l.textColor = UIColor(white: 0.8, alpha: 1.0)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var errorLabel: UILabel = {
        let l = UILabel()
        l.text = ""
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .systemRed
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Dependências

    private let authManager = AuthManager.shared
    private let setupService = SetupService.shared
    @objc var managedObjectContext: NSManagedObjectContext?

    /// Bloco chamado quando o setup for concluído.
    /// Use `setCompletionHandler(_:)` para definir a partir do Objective-C.
    private var onSetupComplete: (() -> Void)?

    /// Define o handler de conclusão a partir do Objective-C (blocks são bridged automaticamente).
    @objc func setCompletionHandler(_ handler: @escaping () -> Void) {
        onSetupComplete = handler
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "primaryBackgroundColor") ?? UIColor(red: 11.0/255.0, green: 18.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        buildLayout()

        // Se já estiver autorizado e setup concluído, dispensa imediatamente
        if authManager.isAuthorized && setupService.isSetupCompleted {
            DispatchQueue.main.async { [weak self] in
                self?.dismissAndStart()
            }
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        let stack = UIStackView(arrangedSubviews: [
            logoImageView,
            titleLabel,
            subtitleLabel
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(loginButton)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 48),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            loginButton.heightAnchor.constraint(equalToConstant: 52),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 24),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Ações

    @objc private func loginTapped() {
        setLoading(true, status: "Abrindo autenticação…")
        clearError()

        authManager.startLogin(presenting: self) { [weak self] success, error in
            guard let self = self else { return }

            if success {
                self.setStatus("Configurando dispositivo…")
                self.performSetup()
            } else {
                let msg = error?.localizedDescription ?? "Erro desconhecido"
                self.showError("Falha no login: \(msg)")
                self.setLoading(false, status: "")
            }
        }
    }

    private func performSetup() {
        guard let moc = managedObjectContext else {
            showError("CoreData não disponível.")
            setLoading(false, status: "")
            return
        }

        setupService.performDeviceSetup(context: moc) { [weak self] success, error in
            guard let self = self else { return }

            if success {
                self.dismissAndStart()
            } else {
                let msg = error?.localizedDescription ?? "Erro desconhecido"
                self.showError("Falha no setup: \(msg)")
                self.setLoading(false, status: "")
            }
        }
    }

    // MARK: - Helpers de UI

    private func setLoading(_ loading: Bool, status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loginButton.isEnabled = !loading
            self.statusLabel.text = status
            if loading {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = text
        }
    }

    private func showError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.errorLabel.text = msg
            self.errorLabel.isHidden = false
        }
    }

    private func clearError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.errorLabel.text = ""
            self.errorLabel.isHidden = true
        }
    }

    private func dismissAndStart() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // O VC se dispensa e só então chama o handler — sem precisar de referência externa
            self.dismiss(animated: true) {
                self.onSetupComplete?()
            }
        }
    }
}
