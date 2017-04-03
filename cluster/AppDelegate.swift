//
//  AppDelegate.swift
//  cluster
//
//  Created by Jeff Jackson on 12/28/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import ArcGIS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        try! AGSArcGISRuntimeEnvironment.setLicenseKey("runtimeadvanced,1000,rud324301898,none,GB10F7PZBSBJ5G7XE053")
        
        return true
    }

}

