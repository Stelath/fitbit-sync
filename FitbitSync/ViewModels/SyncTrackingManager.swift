//
//  SyncTrackingManager.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import HealthKit

class SyncTrackingManager: ObservableObject {
    @Published var syncStatuses: [String: SyncStatus] = [:] // Date string -> SyncStatus
    @Published var statistics = SyncStatistics()
    
    private let userDefaults = UserDefaults.standard
    private let syncStatusKey = "FitbitSync_SyncStatuses"
    private let healthStore = HKHealthStore()
    
    init() {
        loadSyncStatuses()
        updateStatistics()
    }
    
    // MARK: - Duplicate Prevention
    
    func isDuplicateData(for date: Date, dataType: DataType) -> Bool {
        let dateKey = formatDateKey(date)
        guard let status = syncStatuses[dateKey] else { return false }
        
        switch dataType {
        case .steps:
            return status.steps == .synced
        case .heartRate:
            return status.heartRate == .synced
        case .sleep:
            return status.sleep == .synced
        case .distance:
            return status.distance == .synced
        }
    }
    
    func getUnsyncedDates(for dataType: DataType, in dateRange: ClosedRange<Date>) -> [Date] {
        var unsyncedDates: [Date] = []
        var currentDate = dateRange.lowerBound
        
        while currentDate <= dateRange.upperBound {
            if !isDuplicateData(for: currentDate, dataType: dataType) {
                unsyncedDates.append(currentDate)
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return unsyncedDates
    }
    
    func filterNonDuplicateData<T>(_ data: [T], dataType: DataType, dateExtractor: (T) -> Date) -> [T] {
        return data.filter { item in
            let date = dateExtractor(item)
            return !isDuplicateData(for: date, dataType: dataType)
        }
    }
    
    // MARK: - Sync Status Management
    
    func markSyncStarted(for date: Date, dataType: DataType) {
        let dateKey = formatDateKey(date)
        var status = syncStatuses[dateKey] ?? SyncStatus(date: date)
        
        switch dataType {
        case .steps:
            status.steps = .syncing
        case .heartRate:
            status.heartRate = .syncing
        case .sleep:
            status.sleep = .syncing
        case .distance:
            status.distance = .syncing
        }
        
        status.lastSyncAttempt = Date()
        syncStatuses[dateKey] = status
        saveSyncStatuses()
        updateStatistics()
    }
    
    func markSyncCompleted(for date: Date, dataType: DataType, hasData: Bool = true) {
        let dateKey = formatDateKey(date)
        var status = syncStatuses[dateKey] ?? SyncStatus(date: date)
        
        let newState: SyncState = hasData ? .synced : .noData
        
        switch dataType {
        case .steps:
            status.steps = newState
        case .heartRate:
            status.heartRate = newState
        case .sleep:
            status.sleep = newState
        case .distance:
            status.distance = newState
        }
        
        if hasData {
            status.lastSuccessfulSync = Date()
        }
        
        syncStatuses[dateKey] = status
        saveSyncStatuses()
        updateStatistics()
    }
    
    func markSyncFailed(for date: Date, dataType: DataType) {
        let dateKey = formatDateKey(date)
        var status = syncStatuses[dateKey] ?? SyncStatus(date: date)
        
        switch dataType {
        case .steps:
            status.steps = .failed
        case .heartRate:
            status.heartRate = .failed
        case .sleep:
            status.sleep = .failed
        case .distance:
            status.distance = .failed
        }
        
        syncStatuses[dateKey] = status
        saveSyncStatuses()
        updateStatistics()
    }
    
    func updateSyncStatus(for date: Date, dataType: DataType, status: SyncState) {
        let dateKey = formatDateKey(date)
        var syncStatus = syncStatuses[dateKey] ?? SyncStatus(date: date)
        
        switch dataType {
        case .steps:
            syncStatus.steps = status
        case .heartRate:
            syncStatus.heartRate = status
        case .sleep:
            syncStatus.sleep = status
        case .distance:
            syncStatus.distance = status
        }
        
        if status == .synced {
            syncStatus.lastSuccessfulSync = Date()
        }
        
        syncStatuses[dateKey] = syncStatus
        saveSyncStatuses()
        updateStatistics()
    }
    
    func getSyncStatus(for date: Date) -> SyncStatus {
        let dateKey = formatDateKey(date)
        return syncStatuses[dateKey] ?? SyncStatus(date: date)
    }
    
    func getAllSyncStatuses() -> [SyncStatus] {
        return Array(syncStatuses.values).sorted { $0.date > $1.date }
    }
    
    // MARK: - Calendar View Support
    
    func getSyncStatusesForMonth(_ date: Date) -> [SyncStatus] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date
        
        return syncStatuses.values.filter { status in
            status.date >= startOfMonth && status.date <= endOfMonth
        }.sorted { $0.date < $1.date }
    }
    
    func getDaysWithIssues() -> [SyncStatus] {
        return syncStatuses.values.filter { status in
            status.steps == .failed || status.heartRate == .failed || 
            status.sleep == .failed || status.distance == .failed
        }.sorted { $0.date > $1.date }
    }
    
    func getDaysNeedingSync() -> [SyncStatus] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        return syncStatuses.values.filter { status in
            status.date >= thirtyDaysAgo && !status.allDataSynced && status.hasAnyData
        }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Bulk Operations
    
    func clearSyncHistory() {
        syncStatuses.removeAll()
        saveSyncStatuses()
        updateStatistics()
        print("✅ Cleared all sync history data")
    }
    
    func clearAllStoredData() {
        // Clear UserDefaults sync data
        userDefaults.removeObject(forKey: syncStatusKey)
        syncStatuses.removeAll()
        updateStatistics()
        print("✅ Cleared all stored sync tracking data")
    }
    
    func resetFailedSyncs() {
        for (key, var status) in syncStatuses {
            var updated = false
            
            if status.steps == .failed {
                status.steps = .notSynced
                updated = true
            }
            if status.heartRate == .failed {
                status.heartRate = .notSynced
                updated = true
            }
            if status.sleep == .failed {
                status.sleep = .notSynced
                updated = true
            }
            if status.distance == .failed {
                status.distance = .notSynced
                updated = true
            }
            
            if updated {
                syncStatuses[key] = status
            }
        }
        
        saveSyncStatuses()
        updateStatistics()
    }
    
    // MARK: - Statistics
    
    private func updateStatistics() {
        let allStatuses = Array(syncStatuses.values)
        
        statistics.totalDays = allStatuses.count
        statistics.syncedDays = allStatuses.filter { $0.allDataSynced }.count
        statistics.failedDays = allStatuses.filter { status in
            status.steps == .failed || status.heartRate == .failed || 
            status.sleep == .failed || status.distance == .failed
        }.count
        statistics.daysWithNoData = allStatuses.filter { status in
            status.steps == .noData && status.heartRate == .noData && 
            status.sleep == .noData && status.distance == .noData
        }.count
        
        statistics.lastSyncDate = allStatuses.compactMap { $0.lastSuccessfulSync }.max()
        statistics.oldestSyncedDate = allStatuses.filter { $0.allDataSynced }.map { $0.date }.min()
        statistics.newestSyncedDate = allStatuses.filter { $0.allDataSynced }.map { $0.date }.max()
    }
    
    // MARK: - Persistence
    
    private func saveSyncStatuses() {
        do {
            let data = try JSONEncoder().encode(syncStatuses)
            userDefaults.set(data, forKey: syncStatusKey)
        } catch {
            print("❌ Failed to save sync statuses: \(error)")
        }
    }
    
    private func loadSyncStatuses() {
        guard let data = userDefaults.data(forKey: syncStatusKey) else { return }
        
        do {
            syncStatuses = try JSONDecoder().decode([String: SyncStatus].self, from: data)
            print("✅ Successfully loaded \(syncStatuses.count) sync statuses")
        } catch {
            print("❌ Failed to load sync statuses: \(error)")
            print("🔄 Clearing corrupt sync status data and starting fresh")
            
            // Clear the corrupt data and start fresh
            userDefaults.removeObject(forKey: syncStatusKey)
            syncStatuses = [:]
            
            // Optionally trigger a fresh scan to rebuild the data
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // This will be called from SyncViewModel if needed
                print("💡 Consider running a fresh HealthKit scan to rebuild sync status data")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - HealthKit Integration for Duplicate Detection
    
    func checkExistingHealthKitData(for date: Date, dataType: DataType, completion: @escaping (Bool) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let sampleType: HKSampleType
        switch dataType {
        case .steps:
            sampleType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        case .distance:
            sampleType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case .heartRate:
            sampleType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        case .sleep:
            sampleType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        }
        
        // Check for samples from our app
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: combinedPredicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, _ in
            DispatchQueue.main.async {
                completion(!(samples?.isEmpty ?? true))
            }
        }
        
        healthStore.execute(query)
    }
}
