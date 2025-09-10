//
//  DataVerificationManager.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import SwiftData
import HealthKit

class DataVerificationManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var modelContext: ModelContext?
    
    init() {
        print("🔍 DataVerificationManager initialized")
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Main Verification Process
    
    func verifyStoredData(_ storedData: StoredFitbitData, completion: @escaping (ComprehensiveVerificationResult) -> Void) {
        print("🔍 Starting verification for data from \(storedData.date)")
        
        let group = DispatchGroup()
        var verificationResults: [VerificationResult] = []
        
        let fitbitData = storedData.getFitbitData()
        
        // Verify Steps
        if !fitbitData.stepsData.isEmpty {
            group.enter()
            verifyStepsData(fitbitData.stepsData, for: storedData.date) { result in
                verificationResults.append(result)
                group.leave()
            }
        }
        
        // Verify Heart Rate
        if !fitbitData.heartRateData.isEmpty {
            group.enter()
            verifyHeartRateData(fitbitData.heartRateData, for: storedData.date) { result in
                verificationResults.append(result)
                group.leave()
            }
        }
        
        // Verify Sleep
        if !fitbitData.sleepData.isEmpty {
            group.enter()
            verifySleepData(fitbitData.sleepData, for: storedData.date) { result in
                verificationResults.append(result)
                group.leave()
            }
        }
        
        // Verify Distance
        if !fitbitData.distanceData.isEmpty {
            group.enter()
            verifyDistanceData(fitbitData.distanceData, for: storedData.date) { result in
                verificationResults.append(result)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let overallStatus = self.determineOverallStatus(from: verificationResults)
            let result = ComprehensiveVerificationResult(
                storageId: storedData.id,
                date: storedData.date,
                results: verificationResults,
                overallStatus: overallStatus,
                verifiedAt: Date()
            )
            
            print("🔍 Verification completed: \(result.summary)")
            for verResult in verificationResults {
                print("🔍   \(verResult.summary)")
            }
            
            completion(result)
        }
    }
    
    // MARK: - Individual Data Type Verification
    
    private func verifyStepsData(_ stepsData: [StepData], for date: Date, completion: @escaping (VerificationResult) -> Void) {
        let expectedCount = stepsData.count
        
        queryHealthKitSteps(for: date) { healthKitSteps in
            let isVerified = self.compareStepsData(expected: stepsData, actual: healthKitSteps)
            let result = VerificationResult(
                dataType: .steps,
                isVerified: isVerified,
                expectedCount: expectedCount,
                actualCount: healthKitSteps.count,
                details: isVerified ? nil : "Step counts don't match expected values"
            )
            completion(result)
        }
    }
    
    private func verifyHeartRateData(_ heartRateData: [HeartRateData], for date: Date, completion: @escaping (VerificationResult) -> Void) {
        let expectedCount = heartRateData.count
        
        queryHealthKitHeartRate(for: date) { healthKitHeartRate in
            let isVerified = self.compareHeartRateData(expected: heartRateData, actual: healthKitHeartRate)
            let result = VerificationResult(
                dataType: .heartRate,
                isVerified: isVerified,
                expectedCount: expectedCount,
                actualCount: healthKitHeartRate.count,
                details: isVerified ? nil : "Heart rate values don't match expected values"
            )
            completion(result)
        }
    }
    
    private func verifySleepData(_ sleepData: [SleepData], for date: Date, completion: @escaping (VerificationResult) -> Void) {
        let expectedCount = sleepData.count
        
        queryHealthKitSleep(for: date) { healthKitSleep in
            let isVerified = self.compareSleepData(expected: sleepData, actual: healthKitSleep)
            let result = VerificationResult(
                dataType: .sleep,
                isVerified: isVerified,
                expectedCount: expectedCount,
                actualCount: healthKitSleep.count,
                details: isVerified ? nil : "Sleep data doesn't match expected values"
            )
            completion(result)
        }
    }
    
    private func verifyDistanceData(_ distanceData: [DistanceData], for date: Date, completion: @escaping (VerificationResult) -> Void) {
        let expectedCount = distanceData.count
        
        queryHealthKitDistance(for: date) { healthKitDistance in
            let isVerified = self.compareDistanceData(expected: distanceData, actual: healthKitDistance)
            let result = VerificationResult(
                dataType: .distance,
                isVerified: isVerified,
                expectedCount: expectedCount,
                actualCount: healthKitDistance.count,
                details: isVerified ? nil : "Distance values don't match expected values"
            )
            completion(result)
        }
    }
    
    // MARK: - HealthKit Queries
    
    private func queryHealthKitSteps(for date: Date, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion([])
            return
        }
        
        let predicate = createDatePredicate(for: date)
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        
        let query = HKSampleQuery(
            sampleType: stepType,
            predicate: combinedPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                completion(samples as? [HKQuantitySample] ?? [])
            }
        }
        
        healthStore.execute(query)
    }
    
    private func queryHealthKitHeartRate(for date: Date, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        
        let predicate = createDatePredicate(for: date)
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: combinedPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                completion(samples as? [HKQuantitySample] ?? [])
            }
        }
        
        healthStore.execute(query)
    }
    
    private func queryHealthKitSleep(for date: Date, completion: @escaping ([HKCategorySample]) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }
        
        let predicate = createDatePredicate(for: date)
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: combinedPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                completion(samples as? [HKCategorySample] ?? [])
            }
        }
        
        healthStore.execute(query)
    }
    
    private func queryHealthKitDistance(for date: Date, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            completion([])
            return
        }
        
        let predicate = createDatePredicate(for: date)
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        
        let query = HKSampleQuery(
            sampleType: distanceType,
            predicate: combinedPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                completion(samples as? [HKQuantitySample] ?? [])
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Data Comparison Methods
    
    private func compareStepsData(expected: [StepData], actual: [HKQuantitySample]) -> Bool {
        guard !expected.isEmpty else { return actual.isEmpty }
        
        let expectedTotal = expected.reduce(0) { $0 + $1.steps }
        let actualTotal = actual.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) }
        
        let tolerance = max(1.0, Double(expectedTotal) * 0.01) // 1% tolerance or minimum 1 step
        let difference = abs(Double(expectedTotal) - actualTotal)
        
        print("🔍 Steps verification: Expected=\(expectedTotal), Actual=\(Int(actualTotal)), Difference=\(Int(difference)), Tolerance=\(Int(tolerance))")
        return difference <= tolerance
    }
    
    private func compareHeartRateData(expected: [HeartRateData], actual: [HKQuantitySample]) -> Bool {
        guard !expected.isEmpty else { return actual.isEmpty }
        
        // For heart rate, we compare the count since we store resting heart rate once per day
        let expectedCount = expected.compactMap { $0.restingHeartRate }.count
        let actualCount = actual.count
        
        print("🔍 Heart Rate verification: Expected=\(expectedCount), Actual=\(actualCount)")
        return expectedCount == actualCount
    }
    
    private func compareSleepData(expected: [SleepData], actual: [HKCategorySample]) -> Bool {
        guard !expected.isEmpty else { return actual.isEmpty }
        
        // Group actual samples by sleep period (inBed samples)
        let inBedSamples = actual.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        
        print("🔍 Sleep verification: Expected=\(expected.count), Actual inBed samples=\(inBedSamples.count)")
        return expected.count == inBedSamples.count
    }
    
    private func compareDistanceData(expected: [DistanceData], actual: [HKQuantitySample]) -> Bool {
        guard !expected.isEmpty else { return actual.isEmpty }
        
        let expectedTotal = expected.reduce(0.0) { $0 + $1.distance }
        let actualTotal = actual.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .meter()) / 1000 } // Convert to km
        
        let tolerance = max(0.01, expectedTotal * 0.05) // 5% tolerance or minimum 0.01 km
        let difference = abs(expectedTotal - actualTotal)
        
        print("🔍 Distance verification: Expected=\(expectedTotal)km, Actual=\(actualTotal)km, Difference=\(difference)km, Tolerance=\(tolerance)km")
        return difference <= tolerance
    }
    
    // MARK: - Helper Methods
    
    private func createDatePredicate(for date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
    }
    
    private func determineOverallStatus(from results: [VerificationResult]) -> VerificationStatus {
        if results.isEmpty {
            return .failed
        }
        
        let verifiedCount = results.filter { $0.isVerified }.count
        let totalCount = results.count
        
        if verifiedCount == totalCount {
            return .verified
        } else if verifiedCount > 0 {
            return .partiallyVerified
        } else {
            return .failed
        }
    }
    
    // MARK: - Cleanup Methods
    
    func cleanupVerifiedData() {
        guard let context = modelContext else { return }
        
        let fetchRequest = FetchDescriptor<StoredFitbitData>(
            predicate: #Predicate<StoredFitbitData> { $0.verificationStatusRaw == "verified" }
        )
        
        do {
            let verifiedData = try context.fetch(fetchRequest)
            print("🧹 Cleaning up \(verifiedData.count) verified data entries")
            
            for data in verifiedData {
                context.delete(data)
            }
            
            try context.save()
            print("✅ Cleanup completed successfully")
        } catch {
            print("❌ Error during cleanup: \(error)")
        }
    }
    
    func updateStoredDataStatus(_ storedData: StoredFitbitData, result: ComprehensiveVerificationResult) {
        guard let context = modelContext else { return }
        
        storedData.verificationStatus = result.overallStatus
        storedData.lastVerificationAttempt = result.verifiedAt
        
        if result.overallStatus == .verified {
            storedData.syncedToHealthKit = true
        }
        
        do {
            try context.save()
            print("✅ Updated stored data status to \(result.overallStatus.displayName)")
        } catch {
            print("❌ Error updating stored data status: \(error)")
        }
    }
}