//
//  AppDelegate.swift
//  Skii
//
//  Placeholder orientation delegate.
//

#if os(iOS)
import UIKit

enum OrientationPreference {
    static let useLandscapeKey = "com.lz.skii.PreferredOrientationIsLandscape"

    static var mask: UIInterfaceOrientationMask {
        .landscape
    }

    static func setLandscape(_ useLandscape: Bool) {
        UserDefaults.standard.set(useLandscape, forKey: useLandscapeKey)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationPreference.mask
    }
}
#endif
