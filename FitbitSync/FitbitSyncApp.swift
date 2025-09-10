//
//  FitbitSyncApp.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import SwiftUI
import SwiftData

@main
struct FitbitSyncApp: App {
    @StateObject private var syncViewModel = SyncViewModel()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StoredFitbitData.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncViewModel)
                .modelContainer(sharedModelContainer)
        }
    }
}
