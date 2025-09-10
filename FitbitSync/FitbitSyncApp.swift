//
//  FitbitSyncApp.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import SwiftUI

@main
struct FitbitSyncApp: App {
    @StateObject private var syncViewModel = SyncViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(syncViewModel)
        }
    }
}
