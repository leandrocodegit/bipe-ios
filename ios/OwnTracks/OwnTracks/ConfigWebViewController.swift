import UIKit
import WebKit
import CoreData

class ConfigWebViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!
    var moc: NSManagedObjectContext!

    // TODO: Ajuste esta URL para a rota correta do Angular onde está o configuracao-usuario.component.html
    let webAppUrl = "https://app.simodapp.com/device/configuracao"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        let appBgColor = UIColor(named: "primaryBackgroundColor") ?? UIColor(red: 11.0/255.0, green: 18.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        self.view.backgroundColor = appBgColor
        self.title = NSLocalizedString("Configurações Avançadas", comment: "Web Config Title")
        moc = CoreData.sharedInstance().mainMOC

        let contentController = WKUserContentController()
        contentController.add(self, name: "saveConfig")
        contentController.add(self, name: "openPermissions")
        contentController.add(self, name: "saveWaypoints")
        contentController.add(self, name: "enableBiometrics")
        contentController.add(self, name: "disableBiometrics")
        contentController.add(self, name: "startSentinel")
        contentController.add(self, name: "stopSentinel")
        contentController.add(self, name: "cancelSentinelGracePeriod")
        contentController.add(self, name: "openSentinel")
        contentController.add(self, name: "openSentinela")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        // Script to emulate window.Android
        let userScriptSource = """
            window.Android = {
                getUserConfig: function() {
                    return window.prompt("get_user_config", "");
                },
                getConfig: function() {
                    return window.prompt("get_config", "");
                },
                getLocation: function() {
                    return window.prompt("get_location", "");
                },
                saveConfig: function(json) {
                    window.webkit.messageHandlers.saveConfig.postMessage(json);
                },
                openPermissions: function() {
                    window.webkit.messageHandlers.openPermissions.postMessage("");
                },
                openSentinel: function() {
                    window.webkit.messageHandlers.openSentinel.postMessage("");
                },
                openSentinela: function() {
                    window.webkit.messageHandlers.openSentinela.postMessage("");
                },
                openWaypoints: function() {
                    window.webkit.messageHandlers.openWaypoints.postMessage("");
                },
                openAccountManagement: function() {
                    window.webkit.messageHandlers.openAccountManagement.postMessage("");
                },
                saveWaypoints: function(json) {
                    window.webkit.messageHandlers.saveWaypoints.postMessage(typeof json === 'object' ? JSON.stringify(json) : json);
                },
                setWaypoints: function(json) {
                    window.webkit.messageHandlers.saveWaypoints.postMessage(typeof json === 'object' ? JSON.stringify(json) : json);
                },
                canUseBiometrics: function() {
                    return "\(BiometricAuthManager.shared.isBiometricsAvailable)";
                },
                isBiometricsEnabled: function() {
                    return "\(BiometricAuthManager.shared.isBiometricsEnabled)";
                },
                getBiometricName: function() {
                    return "\(BiometricAuthManager.shared.biometricName)";
                },
                enableBiometrics: function() {
                    window.webkit.messageHandlers.enableBiometrics.postMessage("");
                },
                disableBiometrics: function() {
                    window.webkit.messageHandlers.disableBiometrics.postMessage("");
                },
                getDeviceId: function() {
                    return "\(Settings.string(forKey: "deviceid_preference", inMOC: self.moc) ?? "")";
                },
                startSentinel: function() {
                    window.webkit.messageHandlers.startSentinel.postMessage("");
                },
                stopSentinel: function() {
                    window.webkit.messageHandlers.stopSentinel.postMessage("");
                },
                cancelSentinelGracePeriod: function() {
                    window.webkit.messageHandlers.cancelSentinelGracePeriod.postMessage("");
                },
                isSentinelMonitoring: function() {
                    return "\(SentinelAcousticMonitor.shared.isMonitoring)";
                }
            };
        """
        
        let userScript = WKUserScript(source: userScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        let navItem = UINavigationItem(title: NSLocalizedString("Configurações Avançadas", comment: ""))
        let closeBtn = UIBarButtonItem(title: NSLocalizedString("Fechar", comment: ""), style: .done, target: self, action: #selector(closeTapped))
        closeBtn.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        navItem.rightBarButtonItem = closeBtn
        navBar.setItems([navItem], animated: false)
        self.view.addSubview(navBar)
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = appBgColor
        webView.scrollView.backgroundColor = appBgColor
        webView.isOpaque = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        self.view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            // Barra de navegação presa ao topo e à área segura
            navBar.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            
            // WebView logo abaixo da barra de navegação
            webView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        if let url = URL(string: webAppUrl) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "saveConfig" {
            let configDict: [String: Any]?
            if let dict = message.body as? [String: Any] {
                configDict = dict
            } else if let jsonString = message.body as? String,
                      let data = jsonString.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                configDict = dict
            } else {
                configDict = nil
            }
            if let dict = configDict {
                moc.performAndWait {
                    if let apelido = dict["apelido"] as? String {
                        Settings.setString(apelido as NSString, forKey: "device_name_preference", inMOC: moc)
                        Settings.setString(apelido as NSString, forKey: "nickname_preference", inMOC: moc)
                    }
                    if let tempoRetencao = dict["tempoRetencao"] as? Int {
                        Settings.setInt(Int32(tempoRetencao), forKey: "discardNetworkLocationThresholdSeconds", inMOC: moc)
                    } else if let tempoRetencao = dict["tempoRetencao"] as? Int32 {
                        Settings.setInt(tempoRetencao, forKey: "discardNetworkLocationThresholdSeconds", inMOC: moc)
                    }
                    if let locatorDisplacement = dict["locatorDisplacement"] as? Int {
                        Settings.setInt(Int32(locatorDisplacement), forKey: "displacement_preference", inMOC: moc)
                    } else if let locatorDisplacement = dict["locatorDisplacement"] as? Int32 {
                        Settings.setInt(locatorDisplacement, forKey: "displacement_preference", inMOC: moc)
                    }
                    if let locatorInterval = dict["locatorInterval"] as? Int {
                        Settings.setInt(Int32(locatorInterval), forKey: "interval_preference", inMOC: moc)
                    } else if let locatorInterval = dict["locatorInterval"] as? Int32 {
                        Settings.setInt(locatorInterval, forKey: "interval_preference", inMOC: moc)
                    }
                    if let ping = dict["ping"] as? Int {
                        Settings.setInt(Int32(ping), forKey: "keepalive_preference", inMOC: moc)
                    } else if let ping = dict["ping"] as? Int32 {
                        Settings.setInt(ping, forKey: "keepalive_preference", inMOC: moc)
                    }
                    if let pubRetain = dict["pubRetain"] as? Bool {
                        Settings.setBool(pubRetain, forKey: "retain_preference", inMOC: moc)
                    }
                    if let locked = dict["locked"] as? Bool {
                        Settings.setBool(locked, forKey: "locked", inMOC: moc)
                    }
                    if let opMode = dict["opMode"] as? Int {
                        Settings.setInt(Int32(opMode), forKey: "custom_opmode", inMOC: moc)
                    } else if let opMode = dict["opMode"] as? Int32 {
                        Settings.setInt(opMode, forKey: "custom_opmode", inMOC: moc)
                    }
                    if let icon = dict["icon"] as? String {
                        Settings.setString(icon as NSString, forKey: "icon", inMOC: moc)
                        Settings.setString(icon as NSString, forKey: "face_preference", inMOC: moc)
                    }
                    if let enableEmergency = dict["enableEmergency"] as? Bool {
                        Settings.setBool(enableEmergency, forKey: "enableEmergency", inMOC: moc)
                    }
                    if let onlyVibrateEmergency = dict["onlyVibrateEmergency"] as? Bool {
                        Settings.setBool(onlyVibrateEmergency, forKey: "onlyVibrateEmergency", inMOC: moc)
                    }
                    if let soundWaypoint = dict["soundWaypoint"] as? Bool {
                        Settings.setBool(soundWaypoint, forKey: "soundWaypoint", inMOC: moc)
                        UserDefaults.standard.set(soundWaypoint, forKey: "soundWaypoint")
                        UserDefaults.standard.synchronize()
                    }
                    if let mute = dict["mute"] as? Bool {
                        Settings.setBool(mute, forKey: "mute", inMOC: moc)
                        UserDefaults.standard.set(mute, forKey: "mute")
                        UserDefaults.standard.synchronize()
                    } else if let muteNum = dict["mute"] as? NSNumber {
                        Settings.setBool(muteNum.boolValue, forKey: "mute", inMOC: moc)
                        UserDefaults.standard.set(muteNum.boolValue, forKey: "mute")
                        UserDefaults.standard.synchronize()
                    } else if let muteStr = dict["mute"] as? String {
                        let isMute = (muteStr.lowercased() == "true" || muteStr == "1")
                        Settings.setBool(isMute, forKey: "mute", inMOC: moc)
                        UserDefaults.standard.set(isMute, forKey: "mute")
                        UserDefaults.standard.synchronize()
                    }
                    
                    if moc.hasChanges {
                        try? moc.save()
                    }
                }
            }
        } else if message.name == "openPermissions" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let permissionsVC = PermissionsViewController()
                let navController = UINavigationController(rootViewController: permissionsVC)
                navController.modalPresentationStyle = .fullScreen
                self.present(navController, animated: true, completion: nil)
            }
        } else if message.name == "openSentinel" || message.name == "openSentinela" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let sentinelVC = SentinelViewController()
                let navController = UINavigationController(rootViewController: sentinelVC)
                navController.modalPresentationStyle = .fullScreen
                self.present(navController, animated: true, completion: nil)
            }
        } else if message.name == "openWaypoints" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let storyboard = UIStoryboard(name: "Storyboard", bundle: nil)
                if let regionsNav = storyboard.instantiateViewController(withIdentifier: "RegionsNavController") as? UINavigationController {
                    if let regionsVC = regionsNav.viewControllers.first {
                        let closeBtn = UIBarButtonItem(title: NSLocalizedString("Fechar", comment: ""), style: .done, target: self, action: #selector(self.closeTapped))
                        closeBtn.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
                        regionsVC.navigationItem.leftBarButtonItem = closeBtn
                    }
                    regionsNav.modalPresentationStyle = .fullScreen
                    self.present(regionsNav, animated: true, completion: nil)
                }
            }
        } /* else if message.name == "openSettings" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let configVC = ConfigWebViewController()
                configVC.modalPresentationStyle = .fullScreen
                self.present(configVC, animated: true, completion: nil)
            }
        }  */else if message.name == "openAccountManagement" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                AuthManager.shared.openAccountManagement(presenting: self)
            }
        } else if message.name == "saveWaypoints", let jsonString = message.body as? String {
            if let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate,
               let rootVC = delegate.window?.rootViewController as? ViewController {
                rootVC.processSaveWaypoints(jsonString: jsonString)
            }
        } else if message.name == "enableBiometrics" {
            BiometricAuthManager.shared.isBiometricsEnabled = true
            if let token = AuthManager.shared.getRefreshToken() {
                BiometricAuthManager.shared.saveRefreshToken(token)
            }
        } else if message.name == "disableBiometrics" {
            BiometricAuthManager.shared.isBiometricsEnabled = false
            BiometricAuthManager.shared.clearBiometricData()
        } else if message.name == "startSentinel" {
            DispatchQueue.main.async {
                SentinelAcousticMonitor.shared.startMonitoring()
            }
        } else if message.name == "stopSentinel" {
            DispatchQueue.main.async {
                SentinelAcousticMonitor.shared.stopMonitoring()
            }
        } else if message.name == "cancelSentinelGracePeriod" {
            DispatchQueue.main.async {
                SentinelAcousticMonitor.shared.cancelGracePeriod()
            }
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
}

extension ConfigWebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        
        var locked = false
        moc.performAndWait {
            locked = Settings.bool(forKey: "locked", inMOC: moc)
        }
        
        if prompt == "get_user_config" {
            if locked {
                completionHandler("{\"locked\": true}")
                return
            }
            var configDict: [String: Any] = [:]
            moc.performAndWait {
                configDict["deviceId"] = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? ""
                configDict["username"] = Settings.string(forKey: "username_preference", inMOC: moc) ?? ""
                configDict["color"] = Settings.string(forKey: "markerColor", inMOC: moc) ?? ""
                configDict["icon"] = Settings.string(forKey: "icon", inMOC: moc) ?? ""
                configDict["locked"] = locked
                let isMute = UserDefaults.standard.object(forKey: "mute") != nil ? UserDefaults.standard.bool(forKey: "mute") : Settings.bool(forKey: "mute", inMOC: moc)
                configDict["mute"] = isMute
            }
            configDict["token"] = AuthManager.shared.getAccessToken() ?? ""
            
            if let data = try? JSONSerialization.data(withJSONObject: configDict, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                completionHandler(jsonString)
                return
            }
        } else if prompt == "get_config" {
            if locked {
                completionHandler("{\"locked\": true}")
                return
            }
            var configDict: [String: Any] = [:]
            
            moc.performAndWait {
                configDict["apelido"] = Settings.string(forKey: "device_name_preference", inMOC: moc) ?? Settings.string(forKey: "nickname_preference", inMOC: moc) ?? ""
                configDict["tempoRetencao"] = Settings.int(forKey: "discardNetworkLocationThresholdSeconds", inMOC: moc)
                configDict["locatorDisplacement"] = Settings.int(forKey: "displacement_preference", inMOC: moc)
                configDict["locatorInterval"] = Settings.int(forKey: "interval_preference", inMOC: moc)
                configDict["ping"] = Settings.int(forKey: "keepalive_preference", inMOC: moc)
                configDict["pubRetain"] = Settings.bool(forKey: "retain_preference", inMOC: moc)
                configDict["locked"] = locked
                configDict["opMode"] = Settings.int(forKey: "custom_opmode", inMOC: moc)
                configDict["icon"] = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
                configDict["enableEmergency"] = Settings.bool(forKey: "enableEmergency", inMOC: moc)
                configDict["onlyVibrateEmergency"] = Settings.bool(forKey: "onlyVibrateEmergency", inMOC: moc)
                configDict["soundWaypoint"] = UserDefaults.standard.object(forKey: "soundWaypoint") != nil ? Settings.bool(forKey: "soundWaypoint", inMOC: moc) : true
                let isMute = UserDefaults.standard.object(forKey: "mute") != nil ? UserDefaults.standard.bool(forKey: "mute") : Settings.bool(forKey: "mute", inMOC: moc)
                configDict["mute"] = isMute
            }
            let token = AuthManager.shared.getAccessToken() ?? ""
            configDict["token"] = token
            configDict["accessToken"] = token
            
            if let data = try? JSONSerialization.data(withJSONObject: configDict, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                completionHandler(jsonString)
                return
            }
        } else if prompt == "get_location" {
            if locked {
                completionHandler("{\"locked\": true}")
                return
            }
            
            let location = LocationManager.sharedInstance().location
            // In iOS, location is always nonnull, but check coordinate validity or timestamp if needed
            let locationDict: [String: Any] = [
                "lat": location.coordinate.latitude,
                "lon": location.coordinate.longitude,
                "tst": Int(location.timestamp.timeIntervalSince1970),
                "acc": location.horizontalAccuracy
            ]
            if let data = try? JSONSerialization.data(withJSONObject: locationDict, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                completionHandler(jsonString)
                return
            }
            
            completionHandler("{}")
            return
        }
        
        completionHandler(nil)
    }
}
