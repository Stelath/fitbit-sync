//
//  SyncTrackingModels.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation

// MARK: - Sync Status Tracking
struct SyncStatus: Codable {
    let date: Date
    var steps: SyncState = .notSynced
    var heartRate: SyncState = .notSynced
    var sleep: SyncState = .notSynced
    var distance: SyncState = .notSynced
    var lastSyncAttempt: Date?
    var lastSuccessfulSync: Date?
    
    var allDataSynced: Bool {
        return steps == .synced && heartRate == .synced && sleep == .synced && distance == .synced
    }
    
    var hasAnyData: Bool {
        return steps != .noData || heartRate != .noData || sleep != .noData || distance != .noData
    }
}

enum SyncState: String, Codable, CaseIterable {
    case notSynced = "not_synced"
    case synced = "synced"
    case syncing = "syncing"
    case failed = "failed"
    case noData = "no_data"
    
    var displayName: String {
        switch self {
        case .notSynced: return "Not Synced"
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .failed: return "Failed"
        case .noData: return "No Data"
        }
    }
    
    var color: String {
        switch self {
        case .notSynced: return "orange"
        case .synced: return "green"
        case .syncing: return "blue"
        case .failed: return "red"
        case .noData: return "gray"
        }
    }
}

// MARK: - Long Sync Configuration
struct LongSyncConfig {
    let startDate: Date
    let endDate: Date
    let dataTypes: Set<DataType>
    let batchSize: Int = 30 // Days per batch
    
    var totalDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    var batches: [DateRange] {
        var batches: [DateRange] = []
        var currentDate = startDate
        
        while currentDate < endDate {
            let batchEndDate = min(
                Calendar.current.date(byAdding: .day, value: batchSize, to: currentDate) ?? endDate,
                endDate
            )
            batches.append(DateRange(start: currentDate, end: batchEndDate))
            currentDate = batchEndDate
        }
        
        return batches
    }
}

struct DateRange {
    let start: Date
    let end: Date
}

// MARK: - Sync Statistics
struct SyncStatistics {
    var totalDays: Int = 0
    var syncedDays: Int = 0
    var failedDays: Int = 0
    var daysWithNoData: Int = 0
    var lastSyncDate: Date?
    var oldestSyncedDate: Date?
    var newestSyncedDate: Date?
    
    var syncPercentage: Double {
        guard totalDays > 0 else { return 0 }
        return Double(syncedDays) / Double(totalDays) * 100
    }
    
    var pendingDays: Int {
        return totalDays - syncedDays - failedDays - daysWithNoData
    }
}
