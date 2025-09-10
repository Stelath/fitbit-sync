//
//  SyncViewModel.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import Combine

class SyncViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var userProfile: UserProfile?
    @Published var selectedDataTypes: Set<DataType> = Set(DataType.allCases)
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = ""
    @Published var lastSyncDate: Date?

    private let fitbitAPIManager = FitbitAPIManager()
    private let healthKitManager = HealthKitManager()
    let syncTracker = SyncTrackingManager()

    init() {
        checkAuthentication()
    }

    func checkAuthentication() {
        isAuthenticated = fitbitAPIManager.isAuthenticated()
        if isAuthenticated {
            fitbitAPIManager.fetchUserProfile { profile in
                DispatchQueue.main.async {
                    self.userProfile = profile
                }
            }
        }
    }

    func authenticate() {
        fitbitAPIManager.authenticate { success in
            DispatchQueue.main.async {
                self.isAuthenticated = success
                if success {
                    self.fitbitAPIManager.fetchUserProfile { profile in
                        DispatchQueue.main.async {
                            self.userProfile = profile
                        }
                    }
                }
            }
        }
    }
    
    func logout() {
        fitbitAPIManager.logout()
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.userProfile = nil
            self.lastSyncDate = nil
            self.syncStatus = ""
        }
    }
    
    func toggleDataType(_ dataType: DataType) {
        if selectedDataTypes.contains(dataType) {
            selectedDataTypes.remove(dataType)
        } else {
            selectedDataTypes.insert(dataType)
        }
    }

    func syncData() {
        guard !isSyncing else { return }
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncStatus = "Requesting HealthKit authorization..."
        }
        
        healthKitManager.requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.async {
                    self.syncStatus = "Fetching data from Fitbit..."
                }
                
                self.fitbitAPIManager.fetchAllData { fitbitData in
                    DispatchQueue.main.async {
                        if let fitbitData = fitbitData {
                            self.syncStatus = "Syncing to Apple Health..."
                            
                            self.healthKitManager.saveData(
                                fitbitData: fitbitData,
                                selectedDataTypes: self.selectedDataTypes,
                                syncTracker: self.syncTracker
                            ) { success, error in
                                DispatchQueue.main.async {
                                    self.isSyncing = false
                                    
                                    if success {
                                        self.syncStatus = "✅ Sync completed successfully!"
                                        self.lastSyncDate = Date()
                                        
                                        // Clear status after delay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            self.syncStatus = ""
                                        }
                                    } else {
                                        self.syncStatus = "❌ Failed to sync to Apple Health"
                                        if let error = error {
                                            print("Sync error: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }
                        } else {
                            self.syncStatus = "❌ Failed to fetch data from Fitbit"
                            self.isSyncing = false
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.syncStatus = "❌ HealthKit authorization required"
                    self.isSyncing = false
                }
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
}
