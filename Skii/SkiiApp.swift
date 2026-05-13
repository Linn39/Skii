//
//  SkiiApp.swift
//  Skii
//
//  Placeholder app entry point.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct SkiiApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
