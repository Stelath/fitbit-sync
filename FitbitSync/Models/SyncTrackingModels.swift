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
    var verificationStatus: VerificationStatus = .pending
    var lastVerificationAttempt: Date?
    var retryCount: Int = 0
    
    // Custom initializer for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        date = try container.decode(Date.self, forKey: .date)
        steps = try container.decodeIfPresent(SyncState.self, forKey: .steps) ?? .notSynced
        heartRate = try container.decodeIfPresent(SyncState.self, forKey: .heartRate) ?? .notSynced
        sleep = try container.decodeIfPresent(SyncState.self, forKey: .sleep) ?? .notSynced
        distance = try container.decodeIfPresent(SyncState.self, forKey: .distance) ?? .notSynced
        lastSyncAttempt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAttempt)
        lastSuccessfulSync = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulSync)
        
        // New fields with default values for backward compatibility
        verificationStatus = try container.decodeIfPresent(VerificationStatus.self, forKey: .verificationStatus) ?? .pending
        lastVerificationAttempt = try container.decodeIfPresent(Date.self, forKey: .lastVerificationAttempt)
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
    }
    
    // Regular initializer for new objects
    init(date: Date) {
        self.date = date
        self.steps = .notSynced
        self.heartRate = .notSynced
        self.sleep = .notSynced
        self.distance = .notSynced
        self.lastSyncAttempt = nil
        self.lastSuccessfulSync = nil
        self.verificationStatus = .pending
        self.lastVerificationAttempt = nil
        self.retryCount = 0
    }
    
    private enum CodingKeys: String, CodingKey {
        case date, steps, heartRate, sleep, distance
        case lastSyncAttempt, lastSuccessfulSync
        case verificationStatus, lastVerificationAttempt, retryCount
    }
    
    var allDataSynced: Bool {
        return steps == .synced && heartRate == .synced && sleep == .synced && distance == .synced
    }
    
    var allDataVerified: Bool {
        return allDataSynced && verificationStatus == .verified
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
    case verifying = "verifying"
    case verified = "verified"
    case verificationFailed = "verification_failed"
    
    var displayName: String {
        switch self {
        case .notSynced: return "Not Synced"
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .failed: return "Failed"
        case .noData: return "No Data"
        case .verifying: return "Verifying..."
        case .verified: return "Verified"
        case .verificationFailed: return "Verification Failed"
        }
    }
    
    var color: String {
        switch self {
        case .notSynced: return "orange"
        case .synced: return "yellow"
        case .syncing: return "blue"
        case .failed: return "red"
        case .noData: return "gray"
        case .verifying: return "purple"
        case .verified: return "green"
        case .verificationFailed: return "red"
        }
    }
}

enum VerificationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case verified = "verified"
    case failed = "failed"
    case partiallyVerified = "partially_verified"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Verification"
        case .verified: return "Verified"
        case .failed: return "Verification Failed"
        case .partiallyVerified: return "Partially Verified"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "blue"
        case .verified: return "green"
        case .failed: return "red"
        case .partiallyVerified: return "orange"
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
