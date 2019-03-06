//
//  AppDelegate.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 29/11/2017.
//  Copyright © 2017 AssistiveTech KTH. All rights reserved.
//

import UIKit
import UserNotifications
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow? = {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.clipsToBounds = true
        w.layer.cornerRadius = 7
        w.backgroundColor = .clear
        return w
    }()

    let overlayView: UIView = {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "OverlayViewControllerID")
        return vc.view
    }()

    func applicationDidFinishLaunching(_ application: UIApplication) {

        DeviceManager.main.setup()
        StressModel.main.setup()
        EnergyModel.main.setup()
        SignalAcquisition.setup()
        FirebaseApp.configure()
        AutoLogger.activate()

        let options: UNAuthorizationOptions  = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: options) { success, _ in
            // ...
        }

        window?.makeKeyAndVisible()
        let vc = window?.rootViewController
        AccountManager.shared.tryToLogin(on: vc!)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        DeviceManager.main.prepareForBackground()
        toggleAppSwitcherOverlay(show: true, animated: false)
        Coach.activate()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        toggleAppSwitcherOverlay(show: false, animated: false)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        DeviceManager.main.prepareForResume()
        Coach.deactivate()
    }
}

extension AppDelegate {

    func toggleAppSwitcherOverlay(show: Bool, animated: Bool) {
        guard let window = window else { return }
        if show {
            overlayView.frame = window.frame
            overlayView.alpha = 0.0
            window.addSubview(overlayView)
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.overlayView.alpha = 1.0
                })
            } else {
                overlayView.alpha = 1.0
            }
        } else {
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.overlayView.alpha = 0.0
                }, completion: { _ in
                    self.overlayView.removeFromSuperview()
                })
            } else {
                overlayView.removeFromSuperview()
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Received notif")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Received notif response")
    }
}
