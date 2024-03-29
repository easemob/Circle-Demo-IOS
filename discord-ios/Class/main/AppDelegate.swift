//
//  AppDelegate.swift
//  circle-ios
//
//  Created by 冯钊 on 2022/6/7.
//

import UIKit
import HyphenateChat
import Bugly
import AgoraRtcKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
//        let emOptions = EMOptions(appkey: "easemob-demo#circle")
        let emOptions = EMOptions(appkey: "")
        #if DEBUG
        emOptions.enableConsoleLog = true
        #else
        emOptions.enableConsoleLog = false
        Bugly.start(withAppId: "")
        #endif
        emOptions.isAutoLogin = true
        EMClient.shared().initializeSDK(with: emOptions)
        
        UITextField.appearance().tintColor = UIColor(named: ColorName_27AE60)
        UITextView.appearance().tintColor = UIColor(named: ColorName_27AE60)
        
        self.window = UIWindow()
        if EMClient.shared().isLoggedIn {
            self.switchToMain()
        } else {
            self.switchToLogin()
        }
        self.window?.makeKeyAndVisible()
        UserOnlineManager.shared.addDelegate()
        ServerRoleManager.shared.addDelegate()
        ServerChannelMapManager.shared.addDelegate()
        return true
    }

    public func switchToMain() {
        let mainVc = MainViewController()
        self.window?.rootViewController = mainVc
        if let userId = EMClient.shared().currentUsername {
            Bugly.setUserIdentifier(userId)
        }
    }
    
    public func switchToLogin() {
        let vc = LoginViewController()
        self.window?.rootViewController = vc
    }
}
