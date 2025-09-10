//
//  SyncViewModel.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import Combine
import SwiftData

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
    private let verificationManager = DataVerificationManager()
    private var modelContext: ModelContext?

    init() {
        checkAuthentication()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        verificationManager.setModelContext(context)
    }

    func checkAuthentication() {
        isAuthenticated = fitbitAPIManager.isAuthenticated()
        if isAuthenticated {
            fitbitAPIManager.fetchUserProfile { profile in
                DispatchQueue.main.async {
                    self.userProfile = profile
                }
            }
            // Removed automatic HealthKit scanning for performance
            // Now only runs when manually triggered
        }
    }
    
    func scanHealthKitForSyncStatus() {
        print("🔍 Scanning HealthKit for existing sync data (last 7 days)...")
        
        // Reduced scan to last 7 days for performance (was 30 days = 120 queries)
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        let group = DispatchGroup()
        
        // Generate all dates in range
        var currentDate = startDate
        var datesToCheck: [Date] = []
        while currentDate <= endDate {
            datesToCheck.append(calendar.startOfDay(for: currentDate))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        // Check each data type for each date
        for date in datesToCheck {
            for dataType in DataType.allCases {
                group.enter()
                healthKitManager.checkExistingHealthKitData(for: date, dataType: dataType) { exists in
                    if exists {
                        // Update sync tracker to mark this data as synced
                        self.syncTracker.updateSyncStatus(for: date, dataType: dataType, status: .synced)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Completed HealthKit scan for sync status (scanned 7 days, ~28 queries)")
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
        guard let context = modelContext else {
            DispatchQueue.main.async {
                self.syncStatus = "❌ Model context not available"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncStatus = "Requesting HealthKit authorization..."
        }
        
        healthKitManager.requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                self.performEnhancedSync()
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
    
    private func performEnhancedSync() {
        // Phase 1: Fetch and Store Data Locally
        DispatchQueue.main.async {
            self.syncStatus = "📦 Fetching data from Fitbit..."
        }
        
        fitbitAPIManager.fetchAllData { [weak self] fitbitData in
            guard let self = self, let fitbitData = fitbitData else {
                DispatchQueue.main.async {
                    self?.syncStatus = "❌ Failed to fetch data from Fitbit"
                    self?.isSyncing = false
                }
                return
            }
            
            self.storeDataLocally(fitbitData: fitbitData)
        }
    }
    
    private func storeDataLocally(fitbitData: FitbitData) {
        guard let context = modelContext else { return }
        
        DispatchQueue.main.async {
            self.syncStatus = "💾 Storing data locally for verification..."
        }
        
        let today = Date()
        let storedData = StoredFitbitData(date: today)
        storedData.setFitbitData(fitbitData)
        
        context.insert(storedData)
        
        do {
            try context.save()
            print("✅ Stored Fitbit data locally for verification")
            
            // Phase 2: Sync to HealthKit
            self.syncToHealthKit(fitbitData: fitbitData, storedData: storedData)
        } catch {
            print("❌ Failed to store data locally: \(error)")
            DispatchQueue.main.async {
                self.syncStatus = "❌ Failed to store data locally"
                self.isSyncing = false
            }
        }
    }
    
    private func syncToHealthKit(fitbitData: FitbitData, storedData: StoredFitbitData) {
        DispatchQueue.main.async {
            self.syncStatus = "🏥 Syncing to Apple Health..."
        }
        
        healthKitManager.saveData(
            fitbitData: fitbitData,
            selectedDataTypes: selectedDataTypes,
            syncTracker: syncTracker
        ) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                // Phase 3: Verify Data
                DispatchQueue.main.async {
                    self.syncStatus = "🔍 Verifying sync integrity..."
                }
                
                self.verifySync(storedData: storedData)
            } else {
                DispatchQueue.main.async {
                    self.syncStatus = "❌ Failed to sync to Apple Health"
                    self.isSyncing = false
                }
                
                // Mark as failed in storage
                storedData.verificationStatus = .failed
                storedData.retryCount += 1
                
                do {
                    try self.modelContext?.save()
                } catch {
                    print("❌ Failed to update storage status: \(error)")
                }
                
                if let error = error {
                    print("Sync error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func verifySync(storedData: StoredFitbitData) {
        verificationManager.verifyStoredData(storedData) { [weak self] verificationResult in
            guard let self = self else { return }
            
            // Update stored data with verification result
            self.verificationManager.updateStoredDataStatus(storedData, result: verificationResult)
            
            DispatchQueue.main.async {
                self.isSyncing = false
                
                switch verificationResult.overallStatus {
                case .verified:
                    self.syncStatus = "✅ Sync completed and verified!"
                    self.lastSyncDate = Date()
                    
                    // Schedule cleanup of verified data
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        self.verificationManager.cleanupVerifiedData()
                    }
                    
                case .partiallyVerified:
                    self.syncStatus = "⚠️ Sync partially verified (\(verificationResult.results.filter { $0.isVerified }.count)/\(verificationResult.results.count))"
                    
                case .failed:
                    self.syncStatus = "❌ Sync verification failed"
                    
                case .pending:
                    self.syncStatus = "🔍 Verification in progress..."
                }
                
                // Clear status after delay
                if verificationResult.overallStatus != .pending {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.syncStatus = ""
                    }
                }
            }
            
            // Print detailed verification results
            print("🔍 Verification Summary: \(verificationResult.summary)")
            for result in verificationResult.results {
                print("🔍   \(result.summary)")
            }
        }
    }
    
    // MARK: - Retry Mechanisms
    
    func retryFailedSyncs() {
        guard let context = modelContext else {
            DispatchQueue.main.async {
                self.syncStatus = "❌ Model context not available"
            }
            return
        }
        
        // Query for failed syncs with retry count < 3
        let fetchRequest = FetchDescriptor<StoredFitbitData>(
            predicate: #Predicate<StoredFitbitData> { 
                $0.verificationStatusRaw == "failed" && $0.retryCount < 3 
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let failedSyncs = try context.fetch(fetchRequest)
            
            if failedSyncs.isEmpty {
                DispatchQueue.main.async {
                    self.syncStatus = "ℹ️ No failed syncs to retry"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.syncStatus = ""
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                self.syncStatus = "🔄 Retrying \(failedSyncs.count) failed syncs..."
            }
            
            let group = DispatchGroup()
            var successCount = 0
            
            for storedData in failedSyncs {
                group.enter()
                
                storedData.retryCount += 1
                let fitbitData = storedData.getFitbitData()
                
                // Retry sync to HealthKit
                self.healthKitManager.saveData(
                    fitbitData: fitbitData,
                    selectedDataTypes: self.selectedDataTypes,
                    syncTracker: self.syncTracker
                ) { [weak self] success, error in
                    if success {
                        // Retry verification
                        self?.verificationManager.verifyStoredData(storedData) { verificationResult in
                            self?.verificationManager.updateStoredDataStatus(storedData, result: verificationResult)
                            
                            if verificationResult.overallStatus == .verified {
                                successCount += 1
                            }
                            
                            group.leave()
                        }
                    } else {
                        // Mark as failed again
                        storedData.verificationStatus = .failed
                        do {
                            try context.save()
                        } catch {
                            print("❌ Failed to update retry count: \(error)")
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.syncStatus = successCount > 0 ? 
                    "✅ Retry completed: \(successCount)/\(failedSyncs.count) successful" : 
                    "❌ All retries failed"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.syncStatus = ""
                }
                
                // Clean up successful retries
                if successCount > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        self.verificationManager.cleanupVerifiedData()
                    }
                }
            }
            
        } catch {
            print("❌ Error fetching failed syncs: \(error)")
            DispatchQueue.main.async {
                self.syncStatus = "❌ Error fetching failed syncs"
            }
        }
    }
    
    func getUnverifiedSyncsCount() -> Int {
        guard let context = modelContext else { return 0 }
        
        let fetchRequest = FetchDescriptor<StoredFitbitData>(
            predicate: #Predicate<StoredFitbitData> { 
                $0.verificationStatusRaw != "verified" 
            }
        )
        
        do {
            let unverifiedSyncs = try context.fetch(fetchRequest)
            return unverifiedSyncs.count
        } catch {
            print("❌ Error counting unverified syncs: \(error)")
            return 0
        }
    }
    
    // MARK: - Data Management & Recovery
    
    func clearAllStoredData() {
        // Clear SwiftData
        guard let context = modelContext else { return }
        
        do {
            let allData = try context.fetch(FetchDescriptor<StoredFitbitData>())
            for data in allData {
                context.delete(data)
            }
            try context.save()
            print("✅ Cleared all SwiftData storage")
        } catch {
            print("❌ Error clearing SwiftData: \(error)")
        }
        
        // Clear sync tracking data
        syncTracker.clearAllStoredData()
        
        DispatchQueue.main.async {
            self.syncStatus = "✅ All stored data cleared"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.syncStatus = ""
            }
        }
    }
}
