import UIKit
import WebKit
import CoreData

class ConfigWebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {

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
        contentController.add(self, name: "openUrl")
        contentController.add(self, name: "openExternalUrl")
        
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
                getFace: function() {
                    return window.prompt("get_face", "");
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
                },
                openUrl: function(url) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openUrl) {
                        window.webkit.messageHandlers.openUrl.postMessage(url);
                    } else {
                        window.prompt("open_url", url);
                    }
                },
                openExternalUrl: function(url) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openUrl) {
                        window.webkit.messageHandlers.openUrl.postMessage(url);
                    } else {
                        window.prompt("open_url", url);
                    }
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
        webView.navigationDelegate = self
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
                self.handleSaveConfig(dict)
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
        } else if message.name == "openUrl" || message.name == "openExternalUrl" {
            if let urlString = message.body as? String,
               let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                DispatchQueue.main.async {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }

    private func parseConfigInt(_ value: Any?) -> Int32? {
        if let num = value as? NSNumber {
            return num.int32Value
        } else if let intVal = value as? Int {
            return Int32(intVal)
        } else if let int32Val = value as? Int32 {
            return int32Val
        } else if let str = value as? String, let intVal = Int32(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return intVal
        }
        return nil
    }

    private func parseConfigBool(_ value: Any?) -> Bool? {
        if let b = value as? Bool {
            return b
        } else if let num = value as? NSNumber {
            return num.boolValue
        } else if let str = value as? String {
            let lower = str.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return (lower == "true" || lower == "1")
        }
        return nil
    }

    func handleSaveConfig(_ dict: [String: Any]) {
        moc.performAndWait {
            let apelidoStr = (dict["apelido"] as? String) ?? (dict["name"] as? String) ?? (dict["nickname"] as? String)
            if let apelido = apelidoStr {
                Settings.setString(apelido as NSString, forKey: "device_name_preference", inMOC: moc)
                Settings.setString(apelido as NSString, forKey: "nickname_preference", inMOC: moc)
                UserDefaults.standard.set(apelido, forKey: "apelido")
                UserDefaults.standard.set(apelido, forKey: "device_name_preference")
                UserDefaults.standard.set(apelido, forKey: "nickname_preference")
                UserDefaults.standard.synchronize()
                let shared = UserDefaults(suiteName: "group.br.com.bipe.me")
                shared?.set(apelido, forKey: "apelido")
                shared?.set(apelido, forKey: "nickname")
                shared?.synchronize()
                NSLog("[saveConfig ConfigWeb] apelido salvo como: %@", apelido)
            }
            if let tempoRetencao = self.parseConfigInt(dict["tempoRetencao"]) {
                Settings.setInt(tempoRetencao, forKey: "discardNetworkLocationThresholdSeconds", inMOC: moc)
            }
            if let locatorDisplacement = self.parseConfigInt(dict["locatorDisplacement"]) {
                Settings.setInt(locatorDisplacement, forKey: "mindist_preference", inMOC: moc)
                Settings.setInt(locatorDisplacement, forKey: "displacement_preference", inMOC: moc)
                LocationManager.sharedInstance().minDist = Double(locatorDisplacement)
            }
            if let locatorInterval = self.parseConfigInt(dict["locatorInterval"]) {
                Settings.setInt(locatorInterval, forKey: "mintime_preference", inMOC: moc)
                Settings.setInt(locatorInterval, forKey: "interval_preference", inMOC: moc)
                LocationManager.sharedInstance().minTime = Double(locatorInterval)
            }
            if let ping = self.parseConfigInt(dict["ping"]) ?? self.parseConfigInt(dict["keepalive"]) {
                Settings.setInt(ping, forKey: "keepalive_preference", inMOC: moc)
            }
            if let pubRetain = self.parseConfigBool(dict["pubRetain"]) {
                Settings.setBool(pubRetain, forKey: "retain_preference", inMOC: moc)
            }
            if let locked = self.parseConfigBool(dict["locked"]) {
                Settings.setBool(locked, forKey: "locked", inMOC: moc)
                UserDefaults.standard.set(locked, forKey: "locked")
                UserDefaults.standard.synchronize()
            }
            if let opModeVal = self.parseConfigInt(dict["opMode"]) {
                Settings.setInt(opModeVal, forKey: "custom_opmode", inMOC: moc)
            }
            let iconStr = (dict["icon"] as? String) ?? (dict["face"] as? String)
            if let icon = iconStr, !icon.isEmpty {
                Settings.setString(icon as NSString, forKey: "icon", inMOC: moc)
                Settings.setString(icon as NSString, forKey: "face_preference", inMOC: moc)
                UserDefaults.standard.set(icon, forKey: "icon")
                UserDefaults.standard.set(icon, forKey: "face_preference")
                UserDefaults.standard.synchronize()
                let shared = UserDefaults(suiteName: "group.br.com.bipe.me")
                shared?.set(icon, forKey: "icon")
                shared?.set(icon, forKey: "face")
                shared?.synchronize()
                NSLog("[saveConfig ConfigWeb] icon salvo como: %@", icon)
            }
            if let ee = self.parseConfigBool(dict["enableEmergency"]) {
                Settings.setBool(ee, forKey: "enableEmergency", inMOC: moc)
                UserDefaults.standard.set(ee, forKey: "enableEmergency")
                UserDefaults.standard.synchronize()
                let shared = UserDefaults(suiteName: "group.br.com.bipe.me")
                shared?.set(ee, forKey: "enableEmergency")
                shared?.synchronize()
                if !ee {
                    BipeEmergencyHelper.clearEmergency()
                }
            }
            if let ov = self.parseConfigBool(dict["onlyVibrateEmergency"]) {
                Settings.setBool(ov, forKey: "onlyVibrateEmergency", inMOC: moc)
                UserDefaults.standard.set(ov, forKey: "onlyVibrateEmergency")
                UserDefaults.standard.synchronize()
            }
            if let soundWaypoint = self.parseConfigBool(dict["soundWaypoint"]) {
                Settings.setBool(soundWaypoint, forKey: "soundWaypoint", inMOC: moc)
                UserDefaults.standard.set(soundWaypoint, forKey: "soundWaypoint")
                UserDefaults.standard.synchronize()
            }
            if let mute = self.parseConfigBool(dict["mute"]) {
                Settings.setBool(mute, forKey: "mute", inMOC: moc)
                UserDefaults.standard.set(mute, forKey: "mute")
                UserDefaults.standard.synchronize()
            }
            
            do {
                if moc.hasChanges {
                    try moc.save()
                }
            } catch {
                NSLog("[saveConfig ConfigWeb] Erro ao salvar moc: %@", error.localizedDescription)
            }
            CoreData.sharedInstance().sync(moc)
        }
        
        let iconStr = (dict["icon"] as? String) ?? (dict["face"] as? String)
        if let icon = iconStr, !icon.isEmpty {
            let script = """
            window.__currentFace = '\(icon)';
            if (window.Android) { window.Android.face = '\(icon)'; }
            window.dispatchEvent(new CustomEvent('onIconChanged', { detail: { icon: '\(icon)' } }));
            """
            self.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
        if let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate {
            delegate.sendCard()
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
            var configDict: [String: Any] = [:]
            moc.performAndWait {
                configDict["deviceId"] = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? ""
                configDict["username"] = Settings.string(forKey: "username_preference", inMOC: moc) ?? ""
                configDict["color"] = Settings.string(forKey: "markerColor", inMOC: moc) ?? ""
                let currentIcon = UserDefaults.standard.string(forKey: "icon") ?? Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
                configDict["icon"] = currentIcon
                configDict["face"] = currentIcon
                let apelido = Settings.string(forKey: "device_name_preference", inMOC: moc) ?? Settings.string(forKey: "nickname_preference", inMOC: moc) ?? UserDefaults.standard.string(forKey: "apelido") ?? ""
                configDict["apelido"] = apelido
                configDict["nickname"] = apelido
                configDict["name"] = apelido
                configDict["locked"] = locked
                let isEnableEmergency = UserDefaults.standard.object(forKey: "enableEmergency") != nil ? UserDefaults.standard.bool(forKey: "enableEmergency") : Settings.bool(forKey: "enableEmergency", inMOC: moc)
                configDict["enableEmergency"] = isEnableEmergency
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
            var configDict: [String: Any] = [:]
            
            moc.performAndWait {
                let apelido = UserDefaults.standard.string(forKey: "apelido") ?? Settings.string(forKey: "device_name_preference", inMOC: moc) ?? Settings.string(forKey: "nickname_preference", inMOC: moc) ?? ""
                configDict["apelido"] = apelido
                configDict["nickname"] = apelido
                configDict["name"] = apelido
                let tempo = Settings.int(forKey: "discardNetworkLocationThresholdSeconds", inMOC: moc)
                configDict["tempoRetencao"] = tempo > 0 ? tempo : 30
                let dispPref = Settings.int(forKey: "mindist_preference", inMOC: moc)
                let dispLegacy = Settings.int(forKey: "displacement_preference", inMOC: moc)
                configDict["locatorDisplacement"] = dispPref > 0 ? dispPref : (dispLegacy > 0 ? dispLegacy : 50)
                let intPref = Settings.int(forKey: "mintime_preference", inMOC: moc)
                let intLegacy = Settings.int(forKey: "interval_preference", inMOC: moc)
                configDict["locatorInterval"] = intPref > 0 ? intPref : (intLegacy > 0 ? intLegacy : 60)
                let pingPref = Settings.int(forKey: "keepalive_preference", inMOC: moc)
                configDict["ping"] = pingPref > 0 ? pingPref : 300
                configDict["keepalive"] = configDict["ping"]
                configDict["pubRetain"] = Settings.bool(forKey: "retain_preference", inMOC: moc)
                configDict["locked"] = locked
                configDict["opMode"] = Settings.int(forKey: "custom_opmode", inMOC: moc)
                let currentIcon = UserDefaults.standard.string(forKey: "icon") ?? Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
                configDict["icon"] = currentIcon
                configDict["face"] = currentIcon
                let isEnableEmergency = UserDefaults.standard.object(forKey: "enableEmergency") != nil ? UserDefaults.standard.bool(forKey: "enableEmergency") : Settings.bool(forKey: "enableEmergency", inMOC: moc)
                configDict["enableEmergency"] = isEnableEmergency
                let isOnlyVibrate = UserDefaults.standard.object(forKey: "onlyVibrateEmergency") != nil ? UserDefaults.standard.bool(forKey: "onlyVibrateEmergency") : Settings.bool(forKey: "onlyVibrateEmergency", inMOC: moc)
                configDict["onlyVibrateEmergency"] = isOnlyVibrate
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
        } else if prompt == "get_face" {
            var faceStr = UserDefaults.standard.string(forKey: "icon") ?? UserDefaults.standard.string(forKey: "face_preference") ?? ""
            if faceStr.isEmpty {
                moc.performAndWait {
                    faceStr = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
                }
            }
            completionHandler(faceStr)
            return
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
        } else if prompt == "open_url" || prompt == "open_external_url" {
            if let urlString = defaultText,
               let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                DispatchQueue.main.async {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
                completionHandler("{\"success\": true}")
                return
            }
            completionHandler("{\"error\": \"invalid_url\"}")
            return
        }
        
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
        return nil
    }
}

extension ConfigWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "tel" || scheme == "sms" || scheme == "mailto" || scheme == "whatsapp" || scheme == "itms-apps" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
            }
            if navigationAction.targetFrame == nil {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        decisionHandler(.allow)
    }
}
