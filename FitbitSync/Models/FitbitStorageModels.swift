//
//  FitbitStorageModels.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import SwiftData

// MARK: - SwiftData Models for Temporary Storage

@Model
class StoredFitbitData {
    @Attribute(.unique) var id: String
    var date: Date
    var fetchTimestamp: Date
    var verificationStatusRaw: String // Store as raw string for SwiftData predicates
    var lastVerificationAttempt: Date?
    var syncedToHealthKit: Bool
    var retryCount: Int
    
    // Computed property for easy enum access
    var verificationStatus: VerificationStatus {
        get {
            return VerificationStatus(rawValue: verificationStatusRaw) ?? .pending
        }
        set {
            verificationStatusRaw = newValue.rawValue
        }
    }
    
    // JSON storage for actual data
    var stepsDataJSON: Data?
    var heartRateDataJSON: Data?
    var sleepDataJSON: Data?
    var distanceDataJSON: Data?
    
    init(date: Date) {
        self.id = Self.generateID(for: date)
        self.date = date
        self.fetchTimestamp = Date()
        self.verificationStatusRaw = VerificationStatus.pending.rawValue
        self.syncedToHealthKit = false
        self.retryCount = 0
    }
    
    static func generateID(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "fitbit-\(formatter.string(from: date))"
    }
    
    // MARK: - Convenience Methods for Data Storage/Retrieval
    
    func setStepsData(_ data: [StepData]) {
        stepsDataJSON = try? JSONEncoder().encode(data)
    }
    
    func getStepsData() -> [StepData]? {
        guard let data = stepsDataJSON else { return nil }
        return try? JSONDecoder().decode([StepData].self, from: data)
    }
    
    func setHeartRateData(_ data: [HeartRateData]) {
        heartRateDataJSON = try? JSONEncoder().encode(data)
    }
    
    func getHeartRateData() -> [HeartRateData]? {
        guard let data = heartRateDataJSON else { return nil }
        return try? JSONDecoder().decode([HeartRateData].self, from: data)
    }
    
    func setSleepData(_ data: [SleepData]) {
        sleepDataJSON = try? JSONEncoder().encode(data)
    }
    
    func getSleepData() -> [SleepData]? {
        guard let data = sleepDataJSON else { return nil }
        return try? JSONDecoder().decode([SleepData].self, from: data)
    }
    
    func setDistanceData(_ data: [DistanceData]) {
        distanceDataJSON = try? JSONEncoder().encode(data)
    }
    
    func getDistanceData() -> [DistanceData]? {
        guard let data = distanceDataJSON else { return nil }
        return try? JSONDecoder().decode([DistanceData].self, from: data)
    }
    
    func getFitbitData() -> FitbitData {
        return FitbitData(
            stepsData: getStepsData() ?? [],
            heartRateData: getHeartRateData() ?? [],
            sleepData: getSleepData() ?? [],
            distanceData: getDistanceData() ?? []
        )
    }
    
    func setFitbitData(_ fitbitData: FitbitData) {
        setStepsData(fitbitData.stepsData)
        setHeartRateData(fitbitData.heartRateData)
        setSleepData(fitbitData.sleepData)
        setDistanceData(fitbitData.distanceData)
    }
}


// MARK: - Codable conformance is added directly to struct definitions in FitbitDataModels.swift

// MARK: - Verification Result Model

struct VerificationResult {
    let dataType: DataType
    let isVerified: Bool
    let expectedCount: Int
    let actualCount: Int
    let details: String?
    
    var summary: String {
        if isVerified {
            return "\(dataType.displayName): ✅ Verified (\(actualCount)/\(expectedCount))"
        } else {
            return "\(dataType.displayName): ❌ Failed (\(actualCount)/\(expectedCount)) - \(details ?? "Unknown error")"
        }
    }
}

struct ComprehensiveVerificationResult {
    let storageId: String
    let date: Date
    let results: [VerificationResult]
    let overallStatus: VerificationStatus
    let verifiedAt: Date
    
    var isFullyVerified: Bool {
        return results.allSatisfy { $0.isVerified }
    }
    
    var isPartiallyVerified: Bool {
        return results.contains { $0.isVerified } && !isFullyVerified
    }
    
    var summary: String {
        let successCount = results.filter { $0.isVerified }.count
        let totalCount = results.count
        return "Verification: \(successCount)/\(totalCount) data types verified"
    }
}