//
//  ViewController.swift
//  OwnTracks
//
//  Created by Christoph Krey on 19.03.26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import WebKit
import AppIntents
import AudioToolbox
#if canImport(ActivityKit)
import ActivityKit
#endif

@objc class ViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var mapView: MKMapView!;
    @IBOutlet weak var actionButton: UIBarButtonItem!;
    @IBOutlet weak var privacyButton: UIBarButtonItem!;
    @IBOutlet weak var askForMapButton: UIBarButtonItem!;
    @IBOutlet weak var accuracyButton: UIBarButtonItem!;
    
    var webView: WKWebView!
    var trackingButton: MKUserTrackingButton? = nil;
    var modes: UISegmentedControl? = nil;
    var mapMode: UISegmentedControl? = nil;
    var scaleView: MKScaleView? = nil;
    
    var osmRenderer: MKTileOverlayRenderer? = nil;
    var osmCopyright: UITextField? = nil;
    var osmOverlay: MKTileOverlay? = nil;
    
    var suspendAutomaticTrackingOfChangesInManagedObjectContext: Bool = false;
    var warningShown: Bool = false;
    var initialCenter: Bool = false;
    
    var frcFriends: NSFetchedResultsController<Friend>? = nil;
    var frcRegions: NSFetchedResultsController<Region>? = nil;
    var frcWaypoints: NSFetchedResultsController<Waypoint>? = nil;
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        navigationController?.setNavigationBarHidden(true, animated: false);
        navigationController?.setToolbarHidden(true, animated: false);
        tabBarController?.tabBar.isHidden = true;
        mapView?.removeFromSuperview();

        setupWebView();
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(loadActivityHistoryRoute), name: NSNotification.Name("LoadActivityHistory"), object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        if BiometricAuthManager.shared.isBiometricsEnabled && BiometricAuthManager.shared.isBiometricsAvailable {
            isBiometricUnlocked = false
            showBiometricOverlay()
        }
    }
    
    @objc private func appWillEnterForeground() {
        checkAndApplyBiometricLock()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        navigationController?.setNavigationBarHidden(true, animated: false);
        navigationController?.setToolbarHidden(true, animated: false);
        tabBarController?.tabBar.isHidden = true;
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        navigationController?.setNavigationBarHidden(true, animated: false);
        navigationController?.setToolbarHidden(true, animated: false);

        if webView != nil {
            view.bringSubviewToFront(webView);
        }
        notifyWebviewSession()
        checkAndApplyBiometricLock()
    }

    // MARK: - Biometric Lock Overlay

    private var biometricOverlayView: UIView?
    private var isBiometricUnlocked = false
    private var isAuthenticating = false

    @objc func checkAndApplyBiometricLock() {
        guard BiometricAuthManager.shared.isBiometricsEnabled && BiometricAuthManager.shared.isBiometricsAvailable else {
            removeBiometricOverlay()
            return
        }

        if isBiometricUnlocked || isAuthenticating {
            return
        }

        showBiometricOverlay()
        evaluateBiometricsForLock()
    }

    private func showBiometricOverlay() {
        if biometricOverlayView != nil { return }

        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor(red: 11.0/255.0, green: 18.0/255.0, blue: 20.0/255.0, alpha: 0.95)

        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = overlay.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(blurView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconImageView = UIImageView(image: UIImage(systemName: BiometricAuthManager.shared.biometricIconName))
        iconImageView.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Aplicativo Bloqueado"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Desbloqueie com \(BiometricAuthManager.shared.biometricName) para acessar o Bipe.me"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.title = "Desbloquear com \(BiometricAuthManager.shared.biometricName)"
        config.image = UIImage(systemName: BiometricAuthManager.shared.biometricIconName)
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .large

        let unlockButton = UIButton(configuration: config)
        unlockButton.translatesAutoresizingMaskIntoConstraints = false
        unlockButton.addTarget(self, action: #selector(unlockButtonTapped), for: .touchUpInside)

        stack.addArrangedSubview(iconImageView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(unlockButton)

        overlay.addSubview(stack)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),
            unlockButton.heightAnchor.constraint(equalToConstant: 50),
            unlockButton.widthAnchor.constraint(equalToConstant: 280),
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32)
        ])

        view.addSubview(overlay)
        view.bringSubviewToFront(overlay)
        biometricOverlayView = overlay
    }

    @objc private func unlockButtonTapped() {
        evaluateBiometricsForLock()
    }

    private func evaluateBiometricsForLock() {
        if isAuthenticating || BiometricAuthManager.shared.isAuthenticating { return }
        isAuthenticating = true
        
        BiometricAuthManager.shared.authenticate { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.isBiometricUnlocked = true
                self.removeBiometricOverlay()
                self.notifyWebviewSession()
                
                // Renova o token de acesso com o Keycloak usando o Refresh Token salvo
                AuthManager.shared.loginWithRefreshToken { [weak self] authSuccess, authError in
                    guard let self = self else { return }
                    self.isAuthenticating = false
                    if authSuccess {
                        self.notifyWebviewSession()
                    } else {
                        NSLog("[ViewController] Falha ao renovar token na biometria: %@", authError?.localizedDescription ?? "")
                        
                        if !AuthManager.shared.isAuthorized {
                            DispatchQueue.main.async {
                                let loginVC = LoginViewController()
                                loginVC.managedObjectContext = CoreData.sharedInstance().mainMOC
                                loginVC.setCompletionHandler { [weak self] in
                                    self?.notifyWebviewSession()
                                    self?.isBiometricUnlocked = true
                                    self?.removeBiometricOverlay()
                                }
                                
                                let nav = UINavigationController(rootViewController: loginVC)
                                nav.modalPresentationStyle = .fullScreen
                                self.present(nav, animated: true, completion: nil)
                            }
                        }
                    }
                }
            } else {
                self.isAuthenticating = false
                NSLog("[ViewController] Autenticação biométrica no bloqueio não concluída: %@", error?.localizedDescription ?? "")
            }
        }
    }

    private func removeBiometricOverlay() {
        UIView.animate(withDuration: 0.25, animations: {
            self.biometricOverlayView?.alpha = 0.0
        }) { _ in
            self.biometricOverlayView?.removeFromSuperview()
            self.biometricOverlayView = nil
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "monitoring" {
            updateMoveButton();
        }
        if keyPath == "userLocation" || keyPath == "userLocation.location" {
            updateAccuracyButton();
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showWaypointFromMap" {
            if segue.destination is WaypointTVC {
                let waypointTVC = segue.destination as! WaypointTVC;
                if sender is MKAnnotationView {
                    let view = sender as! MKAnnotationView;
                    if view.annotation is Friend {
                        let friend = view.annotation as! Friend;
                        let waypoint = friend.newestWaypoint;
                        if waypoint != nil {
                            waypointTVC.waypoint = waypoint;
                        }
                    } else if view.annotation is Waypoint {
                        let waypoint = view.annotation as! Waypoint;
                        waypointTVC.waypoint = waypoint;
                    }
                }
            }
        } else if segue.identifier == "showRegionFromMap" {
            if segue.destination is RegionTVC {
                let regionTVC = segue.destination as! RegionTVC;
                let view = sender as! MKAnnotationView;
                let region = view.annotation as! Region;
                regionTVC.region = region;
                regionTVC.editAllowed = false;
            }
        }
    }
    
    func setupModes() {
        modes = UISegmentedControl(items: [NSLocalizedString("Quiet", comment: "Quiet"),
                                           NSLocalizedString("Manual", comment: "Manual"),
                                           NSLocalizedString("Significant", comment: "Significant"),
                                           NSLocalizedString("Move", comment: "Move")
                                          ]);
        modes!.apportionsSegmentWidthsByContent = true;
        modes!.translatesAutoresizingMaskIntoConstraints = false;
        modes!.backgroundColor = UIColor(named: "modesColor");
        modes!.addTarget(self, action: #selector(modesChanged(_:)), for: .valueChanged);
        view.addSubview(modes!);
        let topModes = NSLayoutConstraint(item: modes!,
                                          attribute: .top,
                                          relatedBy: .equal,
                                          toItem: mapView,
                                          attribute: .top,
                                          multiplier: 1,
                                          constant: 10);
        let leadingModes = NSLayoutConstraint(item: modes!,
                                              attribute: .leading,
                                              relatedBy: .equal,
                                              toItem: mapView,
                                              attribute: .leading,
                                              multiplier: 1,
                                              constant: 10);
        NSLayoutConstraint.activate([topModes, leadingModes]);
    }
    
    func setupMapMode() {
        mapMode = UISegmentedControl(items: [NSLocalizedString("Std", comment: "Std"),
                                             NSLocalizedString("Sat", comment: "Sat"),
                                             NSLocalizedString("Hyb", comment: "Hyb"),
                                             NSLocalizedString("Fly", comment: "Fly"),
                                             NSLocalizedString("HybFly", comment: "HybFly"),
                                             NSLocalizedString("Mute", comment: "Mute"),
                                             NSLocalizedString("OSM", comment: "OSM")
                                            ]);
        mapMode!.apportionsSegmentWidthsByContent = true;
        mapMode!.translatesAutoresizingMaskIntoConstraints = false;
        mapMode!.backgroundColor = UIColor(named: "modesColor");
        mapMode!.addTarget(self, action: #selector(mapModeChanged(_:)), for: .valueChanged);
        view.addSubview(mapMode!);
        let selected = UserDefaults.standard.integer(forKey: "mapMode");
        if mapMode!.numberOfSegments > selected && selected >= 0 {
            mapMode!.selectedSegmentIndex = selected;
        } else {
            mapMode!.selectedSegmentIndex = 0;
        }
        
        let bottomMapMode = NSLayoutConstraint(item: mapMode!,
                                               attribute: .bottom,
                                               relatedBy: .equal,
                                               toItem: mapView,
                                               attribute: .bottomMargin,
                                               multiplier: 1,
                                               constant: -30);
        let leadingMapMode = NSLayoutConstraint(item: mapMode!,
                                                attribute: .leading,
                                                relatedBy: .equal,
                                                toItem: mapView,
                                                attribute: .leading,
                                                multiplier: 1,
                                                constant: 10);
        NSLayoutConstraint.activate([bottomMapMode, leadingMapMode]);
    }
    
    func setupScaleView() {
        scaleView = MKScaleView(mapView: mapView);
        scaleView!.translatesAutoresizingMaskIntoConstraints = false;
        view.addSubview(scaleView!);
        
        let bottomScale = NSLayoutConstraint(item: scaleView!,
                                             attribute: .bottom,
                                             relatedBy: .equal,
                                             toItem: mapView,
                                             attribute: .bottomMargin,
                                             multiplier: 1,
                                             constant: -10);
        let leadingScale = NSLayoutConstraint(item: scaleView!,
                                              attribute: .centerXWithinMargins,
                                              relatedBy: .equal,
                                              toItem: mapView,
                                              attribute: .centerXWithinMargins,
                                              multiplier: 1,
                                              constant: 0);
        NSLayoutConstraint.activate([bottomScale, leadingScale]);
    }
    
    func updateMoveButton() {
        let locked = Settings.theLocked(inMOC: CoreData.sharedInstance().mainMOC);
        modes!.isEnabled = !locked;
        
        switch LocationManager.sharedInstance().monitoring {
        case .move: modes!.selectedSegmentIndex = 3;
        case .significant: modes!.selectedSegmentIndex = 2;
        case .manual: modes!.selectedSegmentIndex = 1;
        case .quiet: modes!.selectedSegmentIndex = 0;
        default: modes!.selectedSegmentIndex = 0;
        }
        
        for index in 0...modes!.numberOfSegments - 1  {
            var title = modes!.titleForSegment(at: index);
            if title != nil {
                if title!.hasSuffix("#") {
                    title!.remove(at: title!.index(before: title!.endIndex));
                }
                if title!.hasSuffix("!") {
                    title!.remove(at: title!.index(before: title!.endIndex));
                }
                modes!.setTitle(title!, forSegmentAt: index);
            }
        }
        
        let index = modes!.selectedSegmentIndex;
        var title = modes!.titleForSegment(at: index);
        if title != nil {
            if UserDefaults.standard.bool(forKey: "downgraded") {
                if title!.hasSuffix("!") {
                    title = title!.appending("!");
                }
            }
            if UserDefaults.standard.bool(forKey: "adapted") {
                if title!.hasSuffix("#") {
                    title = title!.appending("#");
                }
            }
            modes!.setTitle(title, forSegmentAt: index);
        }
    }
    
    func updateAccuracyButton() {
        guard let location = mapView?.userLocation.location else {
            accuracyButton?.title = "-";
            actionButton?.isEnabled = false;
            return;
        }
        accuracyButton?.title = OwnTracksFormatter.accuracy(from: location.horizontalAccuracy);
        actionButton?.isEnabled = accuracyButton?.title != "-";
    }
    
    func reloaded() {
        guard let mapView = mapView else { return };
        mapView.removeAnnotations(mapView.annotations);
        mapView.removeOverlays(mapView.overlays);

        let moc = CoreData.sharedInstance().mainMOC;
        let frFriends = Friend.fetchRequestAllNonStale(moc);
        frcFriends = NSFetchedResultsController(fetchRequest: frFriends,
                                                managedObjectContext: moc,
                                                sectionNameKeyPath: nil,
                                                cacheName: nil);
        frcFriends!.delegate = self;
        do {
            try frcFriends!.performFetch();
        } catch {
        }
        
        mapView.addAnnotations(frcFriends!.fetchedObjects!);
        
        let frRegions = NSFetchRequest<Region>(entityName: "Region");
        frRegions.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)];
        frcRegions = NSFetchedResultsController(fetchRequest: frRegions,
                                                managedObjectContext: moc,
                                                sectionNameKeyPath: nil,
                                                cacheName: nil);
        frcRegions!.delegate = self;
        do {
            try frcRegions!.performFetch();
        } catch {
        }
        
        let myself = Friend(topic: Settings.theGeneralTopic(inMOC: moc), in: moc);
        var regions: [Region] = [];
        for region in myself.hasRegions! {
            regions.append(region);
            if region.cLregion != nil {
                LocationManager.sharedInstance().start(region.cLregion!);
            }
        }
        mapView.addOverlays(regions);
        mapView.addAnnotations(regions);
        
        let frWaypoints = NSFetchRequest<Waypoint>(entityName: "Waypoint");
        frWaypoints.predicate = NSPredicate(format: "poi <> NULL");
        frWaypoints.sortDescriptors = [NSSortDescriptor(key: "tst", ascending: true)];
        frcWaypoints = NSFetchedResultsController(fetchRequest: frWaypoints,
                                                  managedObjectContext: moc,
                                                  sectionNameKeyPath: nil,
                                                  cacheName: nil);
        frcWaypoints!.delegate = self;
        do {
            try frcWaypoints!.performFetch();
        } catch {
        }
        mapView.addAnnotations(frcWaypoints!.fetchedObjects!);
        
        updateMoveButton();
    }
    
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        DispatchQueue.main.async {
            if anObject is Friend {
                let friend = anObject as! Friend;
                let waypoint = friend.newestWaypoint;
                if waypoint != nil {
                    switch type {
                    case .insert:
                        if waypoint!.lat?.doubleValue != 0.0 && waypoint!.lon?.doubleValue != 0.0 {
                            self.mapView.addAnnotation(friend);
                        }
                    case .delete:
                        self.mapView.removeOverlay(friend);
                        self.mapView.removeAnnotation(friend);
                    case .update, .move:
                        self.mapView.removeOverlay(friend);
                        self.mapView.removeAnnotation(friend);
                        if waypoint!.lat?.doubleValue != 0.0 && waypoint!.lon?.doubleValue != 0.0 {
                            self.mapView.addAnnotation(friend);
                        }
                    @unknown default:
                        let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                        logger.error("default case frcFriends");
                    }
                }
            } else if anObject is Region {
                let region = anObject as! Region;
                switch type {
                case .insert:
                    self.mapView.addAnnotation(region);
                    self.mapView.addOverlay(region);
                case .delete:
                    self.mapView.removeAnnotation(region);
                    self.mapView.removeOverlay(region);
                case .update, .move:
                    self.mapView.removeAnnotation(region);
                    self.mapView.removeOverlay(region);
                    self.mapView.addAnnotation(region);
                    self.mapView.addOverlay(region);
                @unknown default:
                    let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                    logger.error("default case frcRegions");
                    
                }
            } else if anObject is Waypoint {
                let waypoint = anObject as! Waypoint;
                switch type {
                case .insert:
                    self.mapView.addAnnotation(waypoint);
                case .delete:
                    self.mapView.removeAnnotation(waypoint);
                case .update, .move:
                    self.mapView.removeAnnotation(waypoint);
                    self.mapView.addAnnotation(waypoint);
                @unknown default:
                    let logger = Logger(subsystem: "org.mqttitude", category: "MQTTitude");
                    logger.error("default case frcWaypoints");
                }
            }
        }
    }
    
    @discardableResult
    func noMap() -> Int {
        let locked = Settings.theLocked(inMOC: CoreData.sharedInstance().mainMOC);
        askForMapButton.isEnabled = !locked;
        
        let noMap = UserDefaults.standard.integer(forKey: "noMap");
        if noMap > 0 {
            mapView.showsUserLocation = true;
            mapView.isZoomEnabled = true;
            mapView.isScrollEnabled = true;
            mapView.isPitchEnabled = true;
            mapView.isRotateEnabled = true;
            
            if trackingButton == nil {
                trackingButton = MKUserTrackingButton(mapView: mapView);
                trackingButton!.translatesAutoresizingMaskIntoConstraints = false;
                view.addSubview(trackingButton!);
                let topTracking = NSLayoutConstraint(item: trackingButton!,
                                                     attribute: .top,
                                                     relatedBy: .equal,
                                                     toItem: modes!,
                                                     attribute: .bottom,
                                                     multiplier: 1,
                                                     constant: 8);
                let leadingTracking = NSLayoutConstraint(item: trackingButton!,
                                                         attribute: .leading,
                                                         relatedBy: .equal,
                                                         toItem: mapView,
                                                         attribute: .leading,
                                                         multiplier: 1,
                                                         constant: 10);
                NSLayoutConstraint.activate([topTracking, leadingTracking]);
            }
            
            if #available(iOS 26.0, *) {
                privacyButton.badge = nil
            } else {
                // Fallback on earlier versions
            }
        } else {
            mapView.showsUserLocation = true;
            mapView.isZoomEnabled = false;
            mapView.isScrollEnabled = false;
            mapView.isPitchEnabled = false;
            mapView.isRotateEnabled = false;
            
            if trackingButton != nil {
                trackingButton!.removeFromSuperview();
                trackingButton = nil;
            }
            
            if #available(iOS 26.0, *) {
                privacyButton.badge = UIBarButtonItem.Badge.indicator();
            } else {
                // Fallback on earlier versions
            }
            
        }
        
        return noMap;
    }
    
    func setCenter(annotation: MKAnnotation) {
        if noMap() > 0 {
            let coordinate = annotation.coordinate;
            mapView.setVisibleMapRect(centeredRect(for: coordinate), animated: true);
            mapView.userTrackingMode = .none;
        }
    }
    
    func centeredRect(for coordinate: CLLocationCoordinate2D) -> MKMapRect {
        let initialRadius = 600.0;
        let r = initialRadius * MKMapPointsPerMeterAtLatitude(coordinate.latitude);
        var rect : MKMapRect = .null;
        rect.origin = MKMapPoint(coordinate);
        rect.origin.x -= r;
        rect.origin.y -= r;
        rect.size.width = r * 2.0;
        rect.size.height = r * 2.0;
        return rect;
    }
    
    @IBAction func modesChanged(_ sender: UISegmentedControl) {
        var monitoring: LocationMonitoring = .quiet;
        
        switch sender.selectedSegmentIndex {
        case 3: monitoring = .move;
        case 2: monitoring = .significant;
        case 1: monitoring = .manual
        case 0: monitoring = .quiet;
        default: monitoring = .quiet;
        }
        
        if monitoring != LocationManager.sharedInstance().monitoring {
            LocationManager.sharedInstance().monitoring = monitoring;
            UserDefaults.standard.set(false, forKey: "downgraded");
            UserDefaults.standard.set(false, forKey: "adapted");
            Settings.setInt(Int32(monitoring.rawValue),
                            forKey: "monitoring_preference",
                            inMOC: CoreData.sharedInstance().mainMOC);
            CoreData.sharedInstance().sync(CoreData.sharedInstance().mainMOC);
            updateMoveButton();
        }
    }
    
    @IBAction func mapModeChanged(_ sender: UISegmentedControl) {
        if osmOverlay != nil {
            mapView.removeOverlay(osmOverlay!);
            osmOverlay = nil;
        }
        if osmCopyright != nil {
            osmCopyright!.removeFromSuperview();
            osmCopyright = nil;
        }
        for view in mapView.subviews {
            if NSStringFromClass(type(of: view)) == "MKAttributionLabel" {
                view.isHidden = false;
            }
        }
        
        switch sender.selectedSegmentIndex {
        case 6:
            mapView.mapType = .standard;
            var osmTemplateString = Settings.string(forKey: "osmtemplate_preference",
                                                    inMOC: CoreData.sharedInstance().mainMOC);
            if osmTemplateString == nil || osmTemplateString!.isEmpty {
                osmTemplateString = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
            }
            
            var osmCopyrightString = Settings.string(forKey: "osmcopyright_preference",
                                                     inMOC: CoreData.sharedInstance().mainMOC);
            if osmCopyrightString == nil || osmCopyrightString!.isEmpty {
                osmCopyrightString = "© OpenStreetMap contributors";
            }
            
            osmOverlay = MKTileOverlay(urlTemplate: osmTemplateString);
            osmOverlay!.canReplaceMapContent = true;
            osmRenderer = MKTileOverlayRenderer(tileOverlay: osmOverlay!);
            mapView.insertOverlay(osmOverlay!, at: 0);
            
            for view in mapView.subviews {
                if NSStringFromClass(type(of: view)) == "MKAttributionLabel" {
                    view.isHidden = true;
                }
            }
            
            osmCopyright = UITextField();
            osmCopyright!.text = osmCopyrightString!;
            osmCopyright!.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize);
            osmCopyright!.isEnabled = false;
            osmCopyright!.translatesAutoresizingMaskIntoConstraints = false;
            view.addSubview(osmCopyright!);
            
            let bottomCopyright = NSLayoutConstraint(item: osmCopyright!,
                                                     attribute: .bottom,
                                                     relatedBy: .equal,
                                                     toItem: mapView,
                                                     attribute: .bottomMargin,
                                                     multiplier: 1,
                                                     constant: 0);
            let trailingCopyright = NSLayoutConstraint(item: osmCopyright!,
                                                       attribute: .trailing,
                                                       relatedBy: .equal,
                                                       toItem: mapView,
                                                       attribute: .trailingMargin,
                                                       multiplier: 1,
                                                       constant: 0);
            NSLayoutConstraint.activate([bottomCopyright, trailingCopyright]);
            
        case 5: mapView.mapType = .mutedStandard;
        case 4: mapView.mapType = .hybridFlyover;
        case 3: mapView.mapType = .satelliteFlyover;
        case 2: mapView.mapType = .hybrid;
        case 1: mapView.mapType = .satellite;
        case 0: mapView.mapType = .standard;
        default: mapView.mapType = .standard;
        }
        
        mapView.setNeedsLayout();
        mapView.setNeedsDisplay();
        
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: "mapMode");
    }
    
    @IBAction func askForMap(_ sender: UIBarButtonItem) {
        let ac = UIAlertController(title: NSLocalizedString("Map Interaction",
                                                            comment: "Title map interaction"),
                                   message: NSLocalizedString("Do you want the map to allow interaction? If you choose yes, the map provider may analyze your tile requests",
                                                              comment: "Message map interaction"),
                                   preferredStyle: .alert);
        let yes = UIAlertAction(title: NSLocalizedString("Yes",
                                                         comment: "Yes button title"),
                                style: .default) { _ in
            UserDefaults.standard.set(1, forKey: "noMap");
            self.noMap();
            self.askForRevgeo();
        }
        let no = UIAlertAction(title: NSLocalizedString("No",
                                                        comment: "No button title"),
                               style: .destructive) { _ in
            UserDefaults.standard.set(-1, forKey: "noMap");
            self.noMap();
            self.askForRevgeo();
        }
        
        ac.addAction(yes);
        ac.addAction(no);
        present(ac, animated: true);
    }
    
    func askForRevgeo() {
        let ac = UIAlertController(title: NSLocalizedString("Reverse Geocoding Address Resolution",
                                                            comment: "Title Revgeo"),
                                   message: NSLocalizedString("Do you want to resolve adresses? If you choose yes, the geocoding provider may analyze your requests",
                                                              comment: "Message Revgeo"),
                                   preferredStyle: .alert);
        
        let yes = UIAlertAction(title: NSLocalizedString("Yes",
                                                         comment: "Yes button title"),
                                style: .default) { _ in
            UserDefaults.standard.set(1, forKey: "noRevgeo");
        }
        let no = UIAlertAction(title: NSLocalizedString("No",
                                                        comment: "No button title"),
                               style: .destructive) { _ in
            UserDefaults.standard.set(-1, forKey: "noRevGeo");
        }
        
        ac.addAction(yes);
        ac.addAction(no);
        present(ac, animated: true);
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        if Settings.theLocked(inMOC: CoreData.sharedInstance().mainMOC) {
            return;
        }
        
        if sender.state == .began {
            let myself = Friend(topic: Settings.theGeneralTopic(inMOC: CoreData.sharedInstance().mainMOC),
                                in: CoreData.sharedInstance().mainMOC);
            let rid = Region.newRid();
            OwnTracking.sharedInstance().addRegion(for: rid,
                                                   friend: myself,
                                                   name: "Center-\(rid)",
                                                   tst: Date.now,
                                                   uuid: nil,
                                                   major: 0,
                                                   minor: 0,
                                                   radius: 0,
                                                   lat: mapView.centerCoordinate.latitude,
                                                   lon: mapView.centerCoordinate.longitude);
            NavigationController.alert(title: NSLocalizedString("Region",
                                                                comment: "Header of an alert message regarding circular region"),
                                       message: NSLocalizedString("created at center of map",
                                                                  comment: "content of an alert message regarding circular region"),
                                       dismissAfter: 1);
        }
    }
    
    @IBAction func actionPressed(_ sender: UIBarButtonItem) {
        let ac = UIAlertController(title: NSLocalizedString("Choose action", comment: "Choose action title"),
                                   message: nil,
                                   preferredStyle: .alert);
        let sendNow = UIAlertAction(title: NSLocalizedString("Send location now",
                                                             comment: "Send location now"),
                                    style: .default) { _ in
            self.sendNow(poi: nil, image: nil, imageName: nil);
        }
        let setPoi = UIAlertAction(title: NSLocalizedString("Set POI", comment: "Set POI button"),
                                   style: .default) { _ in
            self.setPOI();
        }
        let setPoiWithImage = UIAlertAction(title: NSLocalizedString("Set POI with image",
                                                                     comment: "Set POI with image button"),
                                            style: .default) { _ in
            self.setPOIWithImage();
        }
        let setTag = UIAlertAction(title: NSLocalizedString("Set tag", comment: "Set tag button"),
                                   style: .default) { _ in
            self.setTag();
        }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button title"),
                                   style: .cancel, handler: nil);
        ac.addAction(sendNow);
        ac.addAction(setPoi);
        ac.addAction(setPoiWithImage);
        ac.addAction(setTag);
        ac.addAction(cancel);
        present(ac, animated: true, completion: nil);
    }
    
    func sendNow(poi: String?, image: Data?, imageName: String?) {
        if !Settings.validIds(inMOC: CoreData.sharedInstance().mainMOC) {
            NavigationController.alert(title: "Settings",
                                       message: NSLocalizedString("To publish your location userID and deviceID must be set",
                                                                  comment: "Warning displayed if necessary settings are missing"));
            return;
        }

        let location = mapView.userLocation.location;
        if location == nil ||
            !CLLocationCoordinate2DIsValid(location!.coordinate) ||
            (location!.coordinate.latitude == 0.0 && location!.coordinate.longitude == 0.0) {
            NavigationController.alert(title: NSLocalizedString("Location",
                                                                comment: "Header of an alert message regarding a location"),
                                       message: NSLocalizedString("No location available",
                                                                  comment: "Warning displayed if not location available"));
            return;
        }
        
        let ignoreInaccurateLocations = Settings.int(forKey: "ignoreinaccuratelocations_preference",
                                                     inMOC: CoreData.sharedInstance().mainMOC);
        if ignoreInaccurateLocations != 0 && Int32(location!.horizontalAccuracy) > ignoreInaccurateLocations {
            NavigationController.alert(title: NSLocalizedString("Location",
                                                                comment: "Header of an alert message regarding a location"),
                                       message: NSLocalizedString("Inaccurate or old location information",
                                                                  comment: "Warning displayed if location is inaccurate or old"));
            return;
        }
        
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        if ad.sendNow(location!, withPOI: poi, withImage: image, withImageName: imageName) {
            NavigationController.alert(title: NSLocalizedString("Location",
                                                                comment: "Header of an alert message regarding a location"),
                                       message: NSLocalizedString("publish queued on user request",
                                                                  comment: "content of an alert message regarding user publish"),
                                       dismissAfter: 1);

        } else {
            NavigationController.alert(title: NSLocalizedString("Location",
                                                                comment: "Header of an alert message regarding a location"),
                                       message: NSLocalizedString("publish queued on user request",
                                                                  comment: "content of an alert message regarding user publish"));

        }

    }
    
    func setPOI() {
        let ac = UIAlertController(title: NSLocalizedString("Set POI", comment: "Set POI title"),
                                   message: nil,
                                   preferredStyle: .alert);
        let send = UIAlertAction(title: NSLocalizedString("Send",
                                                          comment: "Send button title"),
                                 style: .default) { _ in
            self.sendNow(poi: ac.textFields![0].text, image: nil, imageName: nil);
        }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button title"),
                                   style: .cancel, handler: nil);
        ac.addTextField { textField in
            textField.text = nil;
        }
        ac.addAction(send);
        ac.addAction(cancel);
        present(ac, animated: true);
    }
    
    func setPOIWithImage() {
        performSegue(withIdentifier: "AttachPhotoSegue", sender: nil);
    }
    
    func setTag() {
        let ac = UIAlertController(title: NSLocalizedString("Set Tag", comment: "Set Tag title"),
                                   message: nil,
                                   preferredStyle: .alert);
        let send = UIAlertAction(title: NSLocalizedString("Send",
                                                          comment: "Send button title"),
                                 style: .default) { _ in
            if ac.textFields![0].text == nil || ac.textFields![0].text!.isEmpty {
                UserDefaults.standard.set(nil, forKey: "tag");
            } else {
                UserDefaults.standard.set(ac.textFields![0].text, forKey: "tag");
            }
            self.sendNow(poi: nil, image: nil, imageName: nil);
        }
        let remove = UIAlertAction(title: NSLocalizedString("Remove", comment: "Remove button title"),
                                   style: .default) { _ in
            UserDefaults.standard.set(nil, forKey: "tag");
        }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button title"),
                                   style: .cancel, handler: nil);
        ac.addTextField { textField in
            textField.text = UserDefaults.standard.string(forKey: "tag");
        }
        ac.addAction(send);
        ac.addAction(remove);
        ac.addAction(cancel);
        present(ac, animated: true);

    }
    
    @IBAction func attachPhoto(_ segue: UIStoryboardSegue) {
        if segue.source is AttachPhotoTVC {
            let attachPhotoTVC = segue.source as! AttachPhotoTVC;
            let poi = attachPhotoTVC.poi;
            let photo = attachPhotoTVC.photo;
            let imageName = attachPhotoTVC.imageName;
            let jpg = photo?.image?.jpegData(compressionQuality: 0.9);
            sendNow(poi: poi!.text, image: jpg!, imageName: imageName);
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        if overlay is Friend {
            let friend = overlay as! Friend;
            let renderer = MKPolylineRenderer(polyline: friend.polyLine);
            renderer.lineWidth = 3;
            renderer.strokeColor = UIColor(named: "trackColor");
            return renderer;
        } else if overlay is Region {
            let region = overlay as! Region;
            if region.cLregion != nil && region.cLregion is CLCircularRegion {
                let renderer = MKCircleRenderer(circle: region.circle);
                if region.cLregion != nil && region.cLregion!.isFollow() {
                    renderer.fillColor = UIColor(named: "followColor");
                } else {
                    if LocationManager.sharedInstance().insideCircularRegion(region.name ?? "") {
                        renderer.fillColor = UIColor(named: "insideColor");
                    } else {
                        renderer.fillColor = UIColor(named: "outsideColor");
                    }
                }
                return renderer;
            } else {
                return MKOverlayRenderer(overlay: overlay);
            }
        } else if overlay is MKTileOverlay {
            return self.osmRenderer!
        } else {
            return MKOverlayRenderer(overlay: overlay);
        }
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        if newState == .none {
            let annotations = mapView.annotations;
            mapView.removeAnnotations(annotations);
            mapView.addAnnotations(annotations);
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !initialCenter {
            initialCenter = true;
            if userLocation.location != nil {
                mapView.setCenter(userLocation.location!.coordinate, animated: true);
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil;
        } else if annotation is Friend {
            let friendReuse = "Annotation_picture";
            let friend = annotation as! Friend;
            let waypoint = friend.newestWaypoint;
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: friendReuse);
            var friendAnnotationV: FriendAnnotationV;
            if annotationView != nil {
                friendAnnotationV = annotationView as! FriendAnnotationV;
            } else {
                friendAnnotationV = FriendAnnotationV(annotation: friend, reuseIdentifier: friendReuse)
            }
            friendAnnotationV.displayPriority = .required;
            friendAnnotationV.zPriority = .defaultSelected;
            friendAnnotationV.canShowCallout = true;
            friendAnnotationV.rightCalloutAccessoryView = UIButton(type: .detailDisclosure);
            
            friendAnnotationV.personImage = UIImage(data: friend.image ?? Data());
            friendAnnotationV.tid = friend.effectiveTid;
            friendAnnotationV.speed = waypoint?.vel?.doubleValue ?? 0;
            friendAnnotationV.course = waypoint?.cog?.doubleValue ?? 0;
            friendAnnotationV.me = friend.topic == Settings.theGeneralTopic(inMOC: CoreData.sharedInstance().mainMOC);
            
            friendAnnotationV.setNeedsDisplay();
            return friendAnnotationV;
        } else if annotation is Waypoint {
            let waypoint = annotation as! Waypoint;
            var annotationView: MKAnnotationView?;
            if waypoint.image != nil {
                let waypointImageReuse = "Annotation_image";
                annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: waypointImageReuse);
                var pAV: PhotoAnnotationV;
                if annotationView != nil {
                    pAV = annotationView as! PhotoAnnotationV;
                } else {
                    pAV = PhotoAnnotationV(annotation: waypoint, reuseIdentifier: waypointImageReuse);
                }
                pAV.displayPriority = .required;
                pAV.poiImage = UIImage(data: waypoint.image ?? Data());
                pAV.canShowCallout = true;
                pAV.rightCalloutAccessoryView = UIButton(type: .detailDisclosure);
                annotationView = pAV;
            } else {
                let waypointPoiReuse = "Annotation_poi";
                annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: waypointPoiReuse);
                var mAV: MKMarkerAnnotationView;
                if annotationView != nil {
                    mAV = annotationView as! MKMarkerAnnotationView;
                } else {
                    mAV = MKMarkerAnnotationView(annotation: waypoint, reuseIdentifier: waypointPoiReuse);
                }
                mAV.displayPriority = .required;
                mAV.canShowCallout = true;
                mAV.rightCalloutAccessoryView = UIButton(type: .detailDisclosure);
                annotationView = mAV;
            }
            annotationView?.setNeedsDisplay();
            return annotationView;
        } else if annotation is Region {
            let region = annotation as! Region;
            if region.cLregion is CLBeaconRegion {
                let regionBeaconReuse = "Annotation_Beacon";
                let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: regionBeaconReuse);
                var mAV: MKMarkerAnnotationView;
                if annotationView != nil {
                    mAV = annotationView as! MKMarkerAnnotationView;
                } else {
                    mAV = MKMarkerAnnotationView(annotation: region, reuseIdentifier: regionBeaconReuse);
                }
                mAV.displayPriority = .required;
                if LocationManager.sharedInstance().insideBeaconRegion(region.name ?? "") {
                    mAV.markerTintColor = UIColor(named: "beaconHotColor");
                    mAV.glyphImage = UIImage(named: "iBeaconHot");
                } else {
                    mAV.markerTintColor = UIColor(named: "beaconColdColor");
                    mAV.glyphImage = UIImage(named: "iBeaconCold");
                }
                mAV.isDraggable = true;
                mAV.canShowCallout = true;
                mAV.rightCalloutAccessoryView = UIButton(type: .detailDisclosure);
                mAV.setNeedsDisplay();
                return mAV;
            } else {
                if region.cLregion != nil && region.cLregion!.isFollow() {
                    return nil;
                }
                let regionCircleReuse = "Annotation_circle";
                let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: regionCircleReuse);
                var mAV: MKMarkerAnnotationView;
                if annotationView != nil {
                    mAV = annotationView as! MKMarkerAnnotationView;
                } else {
                    mAV = MKMarkerAnnotationView(annotation: region, reuseIdentifier: regionCircleReuse);
                }
                mAV.displayPriority = .required;
                mAV.markerTintColor = UIColor(named: "pinColor");
                mAV.isDraggable = true;
                mAV.canShowCallout = true;
                mAV.rightCalloutAccessoryView = UIButton(type: .detailDisclosure);
                mAV.setNeedsDisplay();
                return mAV;
            }
        }
        return nil;
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == view.rightCalloutAccessoryView {
            if view.annotation is Friend {
                performSegue(withIdentifier: "showWaypointFromMap", sender: view);
            } else if view.annotation is Region {
                performSegue(withIdentifier: "showRegionFromMap", sender: view);
            } else if view.annotation is Waypoint {
                performSegue(withIdentifier: "showWaypointFromMap", sender: view);
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if view.annotation is Friend {
            let friend = view.annotation as! Friend;
            mapView.addOverlay(friend);
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if view.annotation is Friend {
            let friend = view.annotation as! Friend;
            mapView.removeOverlay(friend);
        }
    }

    // MARK: - WebView Setup
    private func setupWebView() {
        let moc = CoreData.sharedInstance().mainMOC
        let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? ""
        let username = Settings.string(forKey: "user_preference", inMOC: moc) ?? ""
        let color = Settings.string(forKey: "color_preference", inMOC: moc) ?? "#000000"
        let face = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
        let token = AuthManager.shared.getAccessToken() ?? ""
        let langCode = Locale.current.languageCode ?? "pt"

        let scriptSource = """
        window.Android = {
            getDeviceId: function() { return "\(deviceId)"; },
            getFcmToken: function() { return window.prompt("get_fcm_token", ""); },
            getLanguage: function() { return "\(langCode)"; },
            getFace: function() { return window.prompt("get_face", "") || "\(face)"; },
            getColor: function() { return "\(color)"; },
            getUserConfig: function() {
                return window.prompt("get_user_config", "");
            },
            getConfig: function() {
                return window.prompt("get_config", "");
            },
            getLocation: function() {
                return window.prompt("get_location", "");
            },
            getAlarm: function() {
                return window.prompt("get_alarm", "");
            },
            getSession: function() {
                return window.prompt("get_user_config", "");
            },
            openSettings: function() { if (window.webkit && window.webkit.messageHandlers.openSettings) window.webkit.messageHandlers.openSettings.postMessage({}); },
            openPermissions: function() { if (window.webkit && window.webkit.messageHandlers.openPermissions) window.webkit.messageHandlers.openPermissions.postMessage({}); },
            openWaypoints: function() { if (window.webkit && window.webkit.messageHandlers.openWaypoints) window.webkit.messageHandlers.openWaypoints.postMessage({}); },
            openAccountManagement: function() { if (window.webkit && window.webkit.messageHandlers.openAccountManagement) window.webkit.messageHandlers.openAccountManagement.postMessage({}); },
            logout: function() { if (window.webkit && window.webkit.messageHandlers.logout) window.webkit.messageHandlers.logout.postMessage({}); },
            startVoiceCall: function() { if (window.webkit && window.webkit.messageHandlers.startVoiceCall) window.webkit.messageHandlers.startVoiceCall.postMessage({}); },
            stopVoiceCall: function() { if (window.webkit && window.webkit.messageHandlers.stopVoiceCall) window.webkit.messageHandlers.stopVoiceCall.postMessage({}); },
            saveConfig: function(json) { if (window.webkit && window.webkit.messageHandlers.saveConfig) window.webkit.messageHandlers.saveConfig.postMessage(json); },
            saveWaypoints: function(json) { if (window.webkit && window.webkit.messageHandlers.saveWaypoints) window.webkit.messageHandlers.saveWaypoints.postMessage(typeof json === 'object' ? JSON.stringify(json) : json); },
            setWaypoints: function(json) { if (window.webkit && window.webkit.messageHandlers.saveWaypoints) window.webkit.messageHandlers.saveWaypoints.postMessage(typeof json === 'object' ? JSON.stringify(json) : json); },
            canUseBiometrics: function() { return window.prompt("can_use_biometrics", "") === "true"; },
            isBiometricsEnabled: function() { return window.prompt("is_biometrics_enabled", "") === "true"; },
            getBiometricName: function() { return window.prompt("get_biometric_name", ""); },
            enableBiometrics: function() { if (window.webkit && window.webkit.messageHandlers.enableBiometrics) window.webkit.messageHandlers.enableBiometrics.postMessage({}); },
            disableBiometrics: function() { if (window.webkit && window.webkit.messageHandlers.disableBiometrics) window.webkit.messageHandlers.disableBiometrics.postMessage({}); },
            openQRScanner: function() { if (window.webkit && window.webkit.messageHandlers.openQRScanner) window.webkit.messageHandlers.openQRScanner.postMessage({}); else window.prompt("open_qr_scanner", ""); },
            scanQRCode: function() { if (window.webkit && window.webkit.messageHandlers.scanQRCode) window.webkit.messageHandlers.scanQRCode.postMessage({}); else window.prompt("open_qr_scanner", ""); }
        };
        """

        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)

        let handlers = ["openSettings", "openPermissions", "openWaypoints", "openAccountManagement", "logout", "startVoiceCall", "stopVoiceCall", "saveConfig", "saveWaypoints", "enableBiometrics", "disableBiometrics", "openQRScanner", "scanQRCode"]
        for handler in handlers {
            userContentController.add(self, name: handler)
        }

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.allowsInlineMediaPlayback = true

        let webPreferences = WKPreferences()
        webPreferences.javaScriptEnabled = true
        config.preferences = webPreferences

        let topBar = UIView()
        // Cor igual ao tema do webview: #0B1214
        let bgColor = UIColor(red: 11.0/255.0, green: 18.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        topBar.backgroundColor = bgColor
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = bgColor
        view.addSubview(topBar)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = bgColor
        webView.scrollView.backgroundColor = bgColor
        webView.isOpaque = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Se o safeArea topAnchor falhar por algum motivo, usamos 50 como fallback (usando max para garantir o maior)
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            
            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        view.bringSubviewToFront(topBar)
        view.bringSubviewToFront(webView)

        if let url = URL(string: "https://bipe.simodapp.com/android-setup") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc func loadAndroidSetupRoute() {
        guard let webView = webView, let url = URL(string: "https://bipe.simodapp.com/android-setup") else { return }
        DispatchQueue.main.async {
            webView.load(URLRequest(url: url))
        }
    }

    @objc func loadActivityHistoryRoute() {
        guard let webView = webView, let url = URL(string: "https://bipe.simodapp.com/activity-history") else { return }
        DispatchQueue.main.async {
            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - WKWebView Delegates
extension ViewController: WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        notifyWebviewSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.notifyWebviewSession()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "bipe" || url.scheme == "bipe.me" || url.scheme == "bipe.ia" {
                if url.host == "scan-qr" || url.host == "scan-qrcode" || url.host == "qrcode" || url.path.contains("scan-qr") || url.path.contains("scan-qrcode") {
                    decisionHandler(.cancel)
                    openNativeQRScanner()
                    return
                }
                if url.host == "login" || url.host == "auth" {
                    decisionHandler(.cancel)
                    
                    // Se o aplicativo já estiver mostrando o LoginViewController (ou qualquer outra modal),
                    // ou se já houver fluxo de autenticação rodando, ignora chamadas duplicadas.
                    if self.presentedViewController != nil || self.isAuthenticating || BiometricAuthManager.shared.isAuthenticating {
                        NSLog("[ViewController] WebView tentou pedir login, mas já há uma tela modal ou autenticação em andamento. Ignorando.")
                        return
                    }
                    
                    // Se a biometria não estiver ativada, ou se o app já foi desbloqueado pelo usuário nesta sessão, entrega as credenciais para a WebView
                    let isUnlockedOrNoBiometrics = !BiometricAuthManager.shared.isBiometricsEnabled || self.isBiometricUnlocked
                    if isUnlockedOrNoBiometrics && AuthManager.shared.isAuthorized {
                        NSLog("[ViewController] WebView pediu login, mas o app já está desbloqueado/autorizado. Notificando sessão...")
                        self.notifyWebviewSession()
                        return
                    }

                    self.isAuthenticating = true
                    
                    let handleAuthSuccess: (Bool, Error?) -> Void = { [weak self] success, error in
                        guard let self = self else { return }
                        self.isAuthenticating = false
                        if success {
                            self.isBiometricUnlocked = true
                            self.removeBiometricOverlay()
                            self.notifyWebviewSession()
                        } else {
                            NSLog("[ViewController] Falha na autenticação nativa via interceptador: %@", error?.localizedDescription ?? "")
                        }
                    }
                    
                    // Se houver refresh token salvo, tenta primeiro a renovação silenciosa em background sem exibir Face ID
                    if AuthManager.shared.getRefreshToken() != nil {
                        AuthManager.shared.loginWithRefreshToken { [weak self] authSuccess, authError in
                            guard let self = self else { return }
                            if authSuccess {
                                handleAuthSuccess(true, nil)
                            } else {
                                // Se a renovação silenciosa falhou, chama biometria ou login manual
                                if BiometricAuthManager.shared.canLoginWithBiometrics {
                                    BiometricAuthManager.shared.authenticate { success, error in
                                        if success {
                                            AuthManager.shared.loginWithRefreshToken(completion: handleAuthSuccess)
                                        } else {
                                            DispatchQueue.main.async {
                                                AuthManager.shared.startLogin(presenting: self, completion: handleAuthSuccess)
                                            }
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        AuthManager.shared.startLogin(presenting: self, completion: handleAuthSuccess)
                                    }
                                }
                            }
                        }
                    } else if BiometricAuthManager.shared.canLoginWithBiometrics {
                        BiometricAuthManager.shared.authenticate { [weak self] success, error in
                            guard let self = self else { return }
                            if success {
                                AuthManager.shared.loginWithRefreshToken(completion: handleAuthSuccess)
                            } else {
                                DispatchQueue.main.async {
                                    AuthManager.shared.startLogin(presenting: self, completion: handleAuthSuccess)
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            AuthManager.shared.startLogin(presenting: self, completion: handleAuthSuccess)
                        }
                    }
                    return
                }
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let moc = CoreData.sharedInstance().mainMOC
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
                configDict["username"] = Settings.string(forKey: "user_preference", inMOC: moc) ?? ""
                configDict["color"] = Settings.string(forKey: "color_preference", inMOC: moc) ?? "#000000"
                configDict["icon"] = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
                configDict["locked"] = locked
                configDict["opMode"] = Settings.int(forKey: "custom_opmode", inMOC: moc)
            }
            let token = AuthManager.shared.getAccessToken() ?? ""
            let refreshToken = AuthManager.shared.getRefreshToken() ?? ""
            configDict["token"] = token
            configDict["accessToken"] = token
            configDict["refreshToken"] = refreshToken
            configDict["idToken"] = AuthManager.shared.getIdToken() ?? token

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
            }
            let token = AuthManager.shared.getAccessToken() ?? ""
            let refreshToken = AuthManager.shared.getRefreshToken() ?? ""
            configDict["token"] = token
            configDict["accessToken"] = token
            configDict["refreshToken"] = refreshToken
            configDict["idToken"] = AuthManager.shared.getIdToken() ?? token

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
            let loc = LocationManager.sharedInstance().location
            let locDict: [String: Any] = [
                "lat": loc.coordinate.latitude,
                "lon": loc.coordinate.longitude,
                "tst": Int64(loc.timestamp.timeIntervalSince1970),
                "acc": loc.horizontalAccuracy
            ]
            if let data = try? JSONSerialization.data(withJSONObject: locDict, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                completionHandler(jsonString)
                return
            }
            completionHandler("{}")
            return
        } else if prompt == "get_alarm" {
            completionHandler("{}")
            return
        } else if prompt == "get_face" {
            if locked {
                completionHandler("")
                return
            }
            var faceStr = ""
            moc.performAndWait {
                faceStr = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
            }
            completionHandler(faceStr)
            return
        } else if prompt == "get_fcm_token" {
            let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
            completionHandler(fcmToken)
            return
        } else if prompt == "can_use_biometrics" {
            completionHandler(BiometricAuthManager.shared.isBiometricsAvailable ? "true" : "false")
            return
        } else if prompt == "is_biometrics_enabled" {
            completionHandler(BiometricAuthManager.shared.isBiometricsEnabled ? "true" : "false")
            return
        } else if prompt == "get_biometric_name" {
            completionHandler(BiometricAuthManager.shared.biometricName)
            return
        } else if prompt == "start_live_activity" || prompt == "trigger_live_activity" || prompt == "live_activity" {
            if let text = defaultText, let data = text.data(using: .utf8),
               let jsonDict = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary {
                BipeLiveActivityManager.processBipePushNotificationPayload(jsonDict)
                completionHandler("{\"success\": true}")
                return
            }
            completionHandler("{\"error\": \"invalid_payload\"}")
            return
        } else if prompt == "open_qr_scanner" || prompt == "scan_qr" || prompt == "scan_qrcode" || prompt == "qrcode" {
            openNativeQRScanner()
            completionHandler("{\"status\": \"opened\"}")
            return
        }

        completionHandler(nil)
    }

    @objc func notifyWebviewSession() {
        guard let webView = webView else { return }
        let moc = CoreData.sharedInstance().mainMOC
        var configDict: [String: Any] = [:]
        moc.performAndWait {
            configDict["deviceId"] = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? ""
            configDict["username"] = Settings.string(forKey: "user_preference", inMOC: moc) ?? ""
            configDict["color"] = Settings.string(forKey: "color_preference", inMOC: moc) ?? "#000000"
            configDict["icon"] = Settings.string(forKey: "icon", inMOC: moc) ?? Settings.string(forKey: "face_preference", inMOC: moc) ?? ""
        }
        let token = AuthManager.shared.getAccessToken() ?? ""
        let refreshToken = AuthManager.shared.getRefreshToken() ?? ""
        configDict["token"] = token
        configDict["accessToken"] = token
        configDict["refreshToken"] = refreshToken
        configDict["idToken"] = AuthManager.shared.getIdToken() ?? token

        if let data = try? JSONSerialization.data(withJSONObject: configDict, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            let script = "window.dispatchEvent(new CustomEvent('androidSessionReady', { detail: \(jsonString) }));"
            DispatchQueue.main.async {
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "logout":
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isBiometricUnlocked = false
                self.isAuthenticating = false
                self.removeBiometricOverlay()
                
                // Limpa completamente os dados armazenados na WKWebView (cookies, localStorage, sessão)
                let dataStore = WKWebsiteDataStore.default()
                let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {}
                
                AuthManager.shared.logout()
                SetupService.shared.resetSetup()
                
                if let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate {
                    delegate.presentLoginViewController()
                }
            }
        case "openPermissions":
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let permissionsVC = PermissionsViewController()
                let navController = UINavigationController(rootViewController: permissionsVC)
                navController.modalPresentationStyle = .fullScreen
                self.present(navController, animated: true, completion: nil)
            }
        case "openWaypoints":
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let storyboard = UIStoryboard(name: "Storyboard", bundle: nil)
                var targetNav: UINavigationController?
                
                if let nav = storyboard.instantiateViewController(withIdentifier: "RegionsNavController") as? UINavigationController {
                    targetNav = nav
                } else if let vc = storyboard.instantiateViewController(withIdentifier: "RegionsTVC") as? UIViewController {
                    targetNav = UINavigationController(rootViewController: vc)
                }
                
                if let navController = targetNav {
                    if let rootVC = navController.viewControllers.first {
                        let closeBtn = UIBarButtonItem(title: NSLocalizedString("Fechar", comment: ""), style: .done, target: self, action: #selector(self.dismissModalViewController))
                        closeBtn.tintColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
                        rootVC.navigationItem.leftBarButtonItem = closeBtn
                    }
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true, completion: nil)
                }
            } 
        case "openAccountManagement":
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                AuthManager.shared.openAccountManagement(presenting: self)
            }
        case "saveWaypoints":
            if let jsonString = message.body as? String {
                processSaveWaypoints(jsonString: jsonString)
            }
        case "enableBiometrics":
            BiometricAuthManager.shared.isBiometricsEnabled = true
            if let token = AuthManager.shared.getRefreshToken() {
                BiometricAuthManager.shared.saveRefreshToken(token)
            }
        case "disableBiometrics":
            BiometricAuthManager.shared.isBiometricsEnabled = false
        case "openQRScanner", "scanQRCode":
            openNativeQRScanner()
        case "startVoiceCall":
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let moc = CoreData.sharedInstance().mainMOC
                let opMode = Settings.int(forKey: "custom_opmode", inMOC: moc)
                if opMode == 2 || opMode == 3 {
                    let alert = UIAlertController(title: "Chamada Não Permitida", message: "O modo de operação atual não permite chamadas de áudio.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    return
                }
            }
        case "saveConfig":
            if let jsonString = message.body as? String,
               let data = jsonString.data(using: .utf8),
               let config = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                DispatchQueue.main.async {
                    let moc = CoreData.sharedInstance().mainMOC
                    moc.performAndWait {
                        let isLocked = Settings.bool(forKey: "locked", inMOC: moc)
                        let newLocked = config["locked"] as? Bool
                        
                        // If it's currently locked, only allow unlocking.
                        if isLocked && newLocked == false {
                            Settings.setBool(false, forKey: "locked", inMOC: moc)
                            print("Device UNLOCKED via saveConfig")
                        } else if isLocked {
                            print("Device is LOCKED. Action denied.")
                            return
                        }

                        if let apelido = config["apelido"] as? String {
                            Settings.setString(apelido as NSString, forKey: "device_name_preference", inMOC: moc)
                        }
                        if let tempoRetencao = config["tempoRetencao"] as? Int32 {
                            Settings.setInt(tempoRetencao, forKey: "discardNetworkLocationThresholdSeconds", inMOC: moc)
                        }
                        if let icon = config["icon"] as? String {
                            Settings.setString(icon as NSString, forKey: "icon", inMOC: moc)
                            Settings.setString(icon as NSString, forKey: "face_preference", inMOC: moc)
                        }
                        if let displacement = config["locatorDisplacement"] as? Int32 {
                            Settings.setInt(displacement, forKey: "displacement_preference", inMOC: moc)
                        }
                        if let interval = config["locatorInterval"] as? Int32 {
                            Settings.setInt(interval, forKey: "interval_preference", inMOC: moc)
                        }
                        if let ping = config["ping"] as? Int32 {
                            Settings.setInt(ping, forKey: "keepalive_preference", inMOC: moc)
                        }
                        if let pubRetain = config["pubRetain"] as? Bool {
                            Settings.setBool(pubRetain, forKey: "retain_preference", inMOC: moc)
                        }
                        if let onlyVibrate = config["onlyVibrateEmergency"] as? Bool {
                            Settings.setBool(onlyVibrate, forKey: "onlyVibrateEmergency", inMOC: moc)
                        }
                        if let enableEmergency = config["enableEmergency"] as? Bool {
                            Settings.setBool(enableEmergency, forKey: "enableEmergency", inMOC: moc)
                        }
                        if let locked = config["locked"] as? Bool {
                            Settings.setBool(locked, forKey: "locked", inMOC: moc)
                        }
                        if let opMode = config["opMode"] as? Int {
                            Settings.setInt(Int32(opMode), forKey: "custom_opmode", inMOC: moc)
                            
                            // Map to OwnTracks monitoring mode
                            var monitoringMode = 2
                            switch opMode {
                            case 1, 2: monitoringMode = 0
                            case 3: monitoringMode = -1
                            default: monitoringMode = 2
                            }
                            
                            if let locked = config["locked"] as? Bool, locked == true {
                                monitoringMode = -1 // Total privacy if locked
                            }
                            
                            Settings.setInt(Int32(monitoringMode), forKey: "monitoring_preference", inMOC: moc)
                            if let monitorEnum = LocationMonitoring(rawValue: monitoringMode) {
                                LocationManager.sharedInstance().monitoring = monitorEnum
                            }
                        }
                        if moc.hasChanges {
                            try? moc.save()
                        }
                    }
                    NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("reload"), object: nil) // To force LocationManager refresh
                    
                    if let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate {
                        delegate.sendCard()
                    }
                    
                    let alert = UIAlertController(title: nil, message: "Configurações salvas", preferredStyle: .alert)
                    self.present(alert, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        alert.dismiss(animated: true)
                    }
                }
            }
        default:
            break
        }
    }

    @objc private func dismissModalViewController() {
        dismiss(animated: true, completion: nil)
    }

    func processSaveWaypoints(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        var waypoints: [[String: Any]]? = nil
        if let array = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            waypoints = array
        } else if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let array = dict["waypoints"] as? [[String: Any]] {
                waypoints = array
            } else if let array = dict["data"] as? [[String: Any]] {
                waypoints = array
            } else {
                waypoints = [dict]
            }
        }
        
        guard let list = waypoints, !list.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.performWaypointsSave(list: list)
        }
    }

    private func performWaypointsSave(list: [[String: Any]]) {
        let moc = CoreData.sharedInstance().mainMOC
        moc.performAndWait {
            let generalTopic = Settings.theGeneralTopic(inMOC: moc)
            let myself = Friend(topic: generalTopic, in: moc)
            
            for wp in list {
                let name = (wp["name"] as? String) ?? (wp["label"] as? String) ?? (wp["descricao"] as? String) ?? "Waypoint"
                let lat = (wp["lat"] as? Double) ?? (wp["latitude"] as? Double) ?? 0.0
                let lon = (wp["lon"] as? Double) ?? (wp["lng"] as? Double) ?? (wp["longitude"] as? Double) ?? 0.0
                let rad = (wp["radius"] as? Double) ?? (wp["rad"] as? Double) ?? (wp["raio"] as? Double) ?? 100.0
                
                let wpIdRaw = wp["waypointId"] ?? wp["id"] ?? wp["uuid"] ?? wp["rid"]
                let wpId = "\(wpIdRaw ?? Region.newRid())"
                
                let major = (wp["major"] as? Int32) ?? 0
                let minor = (wp["minor"] as? Int32) ?? 0
                let uuid = (wp["uuid"] as? String) ?? wpId
                
                let fetchRequest = NSFetchRequest<Region>(entityName: "Region")
                fetchRequest.predicate = NSPredicate(format: "belongsTo == %@ AND (rid == %@ OR uuid == %@ OR name == %@)", myself, wpId, wpId, name)
                
                let existing = (try? moc.fetch(fetchRequest))?.first
                if let region = existing {
                    region.lat = NSNumber(value: lat)
                    region.lon = NSNumber(value: lon)
                    region.radius = NSNumber(value: rad)
                    region.name = name
                    region.rid = wpId
                    region.uuid = uuid
                    region.major = NSNumber(value: major)
                    region.minor = NSNumber(value: minor)
                } else {
                    let newRegion = OwnTracking.sharedInstance().addRegion(for: wpId,
                                                                           friend: myself,
                                                                           name: name,
                                                                           tst: Date(),
                                                                           uuid: uuid,
                                                                           major: UInt32(major),
                                                                           minor: UInt32(minor),
                                                                           radius: rad,
                                                                           lat: lat,
                                                                           lon: lon)
                    newRegion?.rid = wpId
                    newRegion?.uuid = uuid
                }
            }
            
            if moc.hasChanges {
                try? moc.save()
            }
        }
        
        LocationManager.sharedInstance().resetRegions()
        NotificationCenter.default.post(name: NSNotification.Name("reload"), object: nil)
    }
}

// MARK: - BipeEmergencyHelper (Suporte ao Botão de Ação e Deep Links)

@objc class BipeEmergencyHelper: NSObject {
    
    @objc static func sendEmergencyAlert() {
        sendEmergencyAlert(completion: nil)
    }

    @objc static func sendEmergencyAlert(completion: ((Bool) -> Void)?) {
        DispatchQueue.main.async {
            // Feedback tátil ao pressionar o botão de ação / acionar o atalho
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
            guard let delegate = UIApplication.shared.delegate as? OwnTracksAppDelegate else {
                NSLog("[BipeEmergencyHelper] Erro: OwnTracksAppDelegate não disponível")
                completion?(false)
                return
            }
            
            let moc = CoreData.sharedInstance().mainMOC
            let userName = Settings.string(forKey: "user_preference", inMOC: moc) ?? "user"
            let deviceId = Settings.string(forKey: "deviceid_preference", inMOC: moc) ?? "device"
            let bipeTopic = "owntracks/\(userName)/\(deviceId)/bipe"
            
            let nickname = Settings.string(forKey: "device_name_preference", inMOC: moc) ?? ""
            let face = Settings.string(forKey: "icon", inMOC: moc) ?? ""
            let color = Settings.string(forKey: "color", inMOC: moc) ?? ""
            
            var payload: [String: Any] = [
                "_type": "bipe",
                "status": "EMERGENCY",
                "deviceId": deviceId,
                "nickname": nickname,
                "tst": Int64(Date().timeIntervalSince1970)
            ]
            if !face.isEmpty { payload["face"] = face }
            if !color.isEmpty { payload["color"] = color }
            
            // Garante que a conexão MQTT esteja instanciada e conectada
            if delegate.connection == nil {
                delegate.connection = Connection()
                delegate.connection?.delegate = delegate
                delegate.connection?.start()
            }
            delegate.connection?.connectToLast()
            
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                let qos = MQTTQosLevel(rawValue: UInt8(Settings.int(forKey: "qos_preference", inMOC: moc))) ?? .exactlyOnce
                delegate.connection?.send(data, topic: bipeTopic, topicAlias: nil, qos: qos, retain: false)
                NSLog("[BipeEmergencyHelper] Alerta de emergência enviado via MQTT para o tópico: %@", bipeTopic)
                
                // Feedback tátil de confirmação de sucesso
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let successGen = UINotificationFeedbackGenerator()
                    successGen.notificationOccurred(.success)
                }
                completion?(true)
            } else {
                NSLog("[BipeEmergencyHelper] Erro ao serializar o payload JSON de emergência")
                completion?(false)
            }
        }
    }
}

// MARK: - BipeHapticsHelper (Vibração Prolongada de Chamada de Atenção)

@objc class BipeHapticsHelper: NSObject {
    @objc static func playAttentionVibration() {
        playAttentionVibration(durationSeconds: 6.0)
    }

    @objc static func playAttentionVibration(durationSeconds: Double = 6.0) {
        DispatchQueue.main.async {
            if #available(iOS 13.0, *) {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                
                var elapsed = 0.0
                let interval = 0.35
                
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                    generator.notificationOccurred(.warning)
                    elapsed += interval
                    if elapsed >= durationSeconds {
                        timer.invalidate()
                    }
                }
            } else {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}

// MARK: - BipeLiveActivityManager (Live Activity Única de Emergência e Transição)
// A implementação do BipeLiveActivityManager está no arquivo dedicado BipeLiveActivityManager.swift.


// MARK: - App Intents & Shortcuts (Botão de Ação do iPhone / Siri Shortcuts)
@available(iOS 16.0, *)
struct BipeEmergencyIntent: AppIntent {
    static var title: LocalizedStringResource = "Enviar Bipe de Emergência"
    static var description = IntentDescription("Envia um alerta de emergência instantâneo pelo Bipe.me.")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        await withCheckedContinuation { continuation in
            BipeEmergencyHelper.sendEmergencyAlert { _ in
                continuation.resume()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct BipeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BipeEmergencyIntent(),
            phrases: [
                "Enviar emergência no \(.applicationName)",
                "Alerta de emergência no \(.applicationName)",
                "Socorro no \(.applicationName)"
            ],
            shortTitle: "Bipe de Emergência",
            systemImageName: "exclamationmark.triangle.fill"
        )
    }
}

// MARK: - Native QR Code Scanner Delegate
extension ViewController: QRCodeScannerViewControllerDelegate {
    @objc func openNativeQRScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.presentedViewController is QRCodeScannerViewController { return }
            let scannerVC = QRCodeScannerViewController()
            scannerVC.delegate = self
            scannerVC.modalPresentationStyle = .fullScreen
            self.present(scannerVC, animated: true, completion: nil)
        }
    }
    
    func qrCodeScanner(_ scanner: QRCodeScannerViewController, didScanResult result: String) {
        NSLog("[ViewController] QR Code lido com sucesso: %@", result)
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResult.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let webView = self.webView else { return }
            
            // 1. Injeta callback no WebKit caso a aplicação Angular tenha funções registradas
            let safeResult = trimmedResult.replacingOccurrences(of: "'", with: "\\'")
            let jsScript = """
            if (typeof window.handleQrCodeDecoded === 'function') {
                window.handleQrCodeDecoded('\(safeResult)');
            } else if (typeof window.onQRCodeScanned === 'function') {
                window.onQRCodeScanned('\(safeResult)');
            }
            """
            webView.evaluateJavaScript(jsScript, completionHandler: nil)
            
            // 2. Extrai o token ou URL completa para navegação direta no WebKit
            var targetUrlString: String = ""
            
            if trimmedResult.hasPrefix("http://") || trimmedResult.hasPrefix("https://") {
                targetUrlString = trimmedResult
            } else if trimmedResult.contains("payload=") {
                if let components = URLComponents(string: "http://dummy?\(trimmedResult)"),
                   let payloadItem = components.queryItems?.first(where: { $0.name == "payload" }),
                   let payloadVal = payloadItem.value {
                    targetUrlString = "https://bipe.simodapp.com/share/accept?payload=\(payloadVal)"
                } else {
                    targetUrlString = "https://bipe.simodapp.com/share/accept?\(trimmedResult)"
                }
            } else {
                targetUrlString = "https://bipe.simodapp.com/share/accept?payload=\(trimmedResult)"
            }
            
            if let targetUrl = URL(string: targetUrlString) {
                NSLog("[ViewController] Redirecionando WebKit para a rota de aceite de compartilhamento: %@", targetUrlString)
                webView.load(URLRequest(url: targetUrl))
            }
        }
    }
    
    func qrCodeScannerDidCancel(_ scanner: QRCodeScannerViewController) {
        NSLog("[ViewController] Leitura do QR Code cancelada pelo usuário.")
    }
}

