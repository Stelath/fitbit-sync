//
//  HealthKitManager.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import HealthKit

class HealthKitManager {
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            completion(false, nil)
            return
        }

        let healthDataToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        healthStore.requestAuthorization(toShare: healthDataToWrite, read: nil) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit authorization granted")
                } else {
                    print("❌ HealthKit authorization denied: \(error?.localizedDescription ?? "Unknown error")")
                }
                completion(success, error)
            }
        }
    }

    func saveData(fitbitData: FitbitData, selectedDataTypes: Set<DataType>, syncTracker: SyncTrackingManager, completion: @escaping (Bool, Error?) -> Void) {
        // Build date lists per data type
        let stepDates = Set(fitbitData.stepsData.map { Calendar.current.startOfDay(for: $0.date) })
        let distanceDates = Set(fitbitData.distanceData.map { Calendar.current.startOfDay(for: $0.date) })
        let heartRateDates = Set(fitbitData.heartRateData.map { Calendar.current.startOfDay(for: $0.date) })
        let sleepDates = Set(fitbitData.sleepData.map { Calendar.current.startOfDay(for: $0.date) })

        // Query HealthKit to detect existing samples written by this app for each date/type
        let group = DispatchGroup()
        var existingStepDates = Set<Date>()
        var existingDistanceDates = Set<Date>()
        var existingHeartRateDates = Set<Date>()
        var existingSleepDates = Set<Date>()

        // Check for existing data for each selected data type
        if selectedDataTypes.contains(.steps) {
            for date in stepDates {
                group.enter()
                self.checkExistingHealthKitData(for: date, dataType: .steps) { exists in
                    if exists { existingStepDates.insert(date) }
                    group.leave()
                }
            }
        }
        
        if selectedDataTypes.contains(.distance) {
            for date in distanceDates {
                group.enter()
                self.checkExistingHealthKitData(for: date, dataType: .distance) { exists in
                    if exists { existingDistanceDates.insert(date) }
                    group.leave()
                }
            }
        }
        
        if selectedDataTypes.contains(.heartRate) {
            for date in heartRateDates {
                group.enter()
                self.checkExistingHealthKitData(for: date, dataType: .heartRate) { exists in
                    if exists { existingHeartRateDates.insert(date) }
                    group.leave()
                }
            }
        }
        
        if selectedDataTypes.contains(.sleep) {
            for date in sleepDates {
                group.enter()
                self.checkExistingHealthKitData(for: date, dataType: .sleep) { exists in
                    if exists { existingSleepDates.insert(date) }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            var allSamples: [HKSample] = []

            // Steps
            if selectedDataTypes.contains(.steps) {
                let filteredSteps = fitbitData.stepsData.filter { !existingStepDates.contains(Calendar.current.startOfDay(for: $0.date)) }
                let stepSamples = self.createStepSamples(from: filteredSteps)
                allSamples.append(contentsOf: stepSamples)
                print("📊 Steps: \(fitbitData.stepsData.count) total, \(filteredSteps.count) new, \(stepSamples.count) samples created (skipped \(existingStepDates.count) days)")
            }

            // Distance
            if selectedDataTypes.contains(.distance) {
                let filteredDistance = fitbitData.distanceData.filter { !existingDistanceDates.contains(Calendar.current.startOfDay(for: $0.date)) }
                let distanceSamples = self.createDistanceSamples(from: filteredDistance)
                allSamples.append(contentsOf: distanceSamples)
                print("📊 Distance: \(fitbitData.distanceData.count) total, \(filteredDistance.count) new, \(distanceSamples.count) samples created (skipped \(existingDistanceDates.count) days)")
            }

            // Heart Rate (resting per day currently)
            if selectedDataTypes.contains(.heartRate) {
                let filteredHeartRate = fitbitData.heartRateData.filter { !existingHeartRateDates.contains(Calendar.current.startOfDay(for: $0.date)) }
                let heartRateSamples = self.createHeartRateSamples(from: filteredHeartRate)
                allSamples.append(contentsOf: heartRateSamples)
                print("📊 Heart Rate: \(fitbitData.heartRateData.count) total, \(filteredHeartRate.count) new, \(heartRateSamples.count) samples created (skipped \(existingHeartRateDates.count) days)")
            }

            // Sleep
            if selectedDataTypes.contains(.sleep) {
                let filteredSleep = fitbitData.sleepData.filter { !existingSleepDates.contains(Calendar.current.startOfDay(for: $0.date)) }
                let sleepSamples = self.createSleepSamples(from: filteredSleep)
                allSamples.append(contentsOf: sleepSamples)
                print("📊 Sleep: \(fitbitData.sleepData.count) total, \(filteredSleep.count) new, \(sleepSamples.count) samples created (skipped \(existingSleepDates.count) days)")
            }

            guard !allSamples.isEmpty else {
                print("⚠️ No new samples to save (all data already present in Health)")
                completion(true, nil)
                return
            }
        
        print("💾 Saving \(allSamples.count) samples to HealthKit...")
        
        // Debug: Print details of samples being saved
        for sample in allSamples {
            if let quantitySample = sample as? HKQuantitySample {
                print("📊 Saving \(quantitySample.quantityType.identifier): \(quantitySample.quantity) from \(quantitySample.startDate) to \(quantitySample.endDate)")
            } else if let categorySample = sample as? HKCategorySample {
                print("📊 Saving \(categorySample.categoryType.identifier): value \(categorySample.value) from \(categorySample.startDate) to \(categorySample.endDate)")
            }
        }
        
        self.healthStore.save(allSamples) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully saved \(allSamples.count) samples to HealthKit")
                    print("💡 Check the Health app -> Browse -> Activity/Heart/Sleep sections")
                    print("💡 Make sure to look at the correct date range and data source")
                } else {
                    print("❌ Failed to save samples: \(error?.localizedDescription ?? "Unknown error")")
                }
            completion(success, error)
            }
        }
        }
    }
    
    // MARK: - Sample Creation Methods
    
    private func createStepSamples(from stepsData: [StepData]) -> [HKQuantitySample] {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("❌ Could not create step count type")
            return []
        }
        
        return stepsData.compactMap { stepData in
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(stepData.steps))
            
            // Create a sample for the entire day
            let startOfDay = Calendar.current.startOfDay(for: stepData.date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? stepData.date
            
            return HKQuantitySample(
                    type: stepCountType,
                    quantity: quantity,
                start: startOfDay,
                end: endOfDay
            )
        }
    }
    
    private func createDistanceSamples(from distanceData: [DistanceData]) -> [HKQuantitySample] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            print("❌ Could not create distance type")
            return []
        }
        
        return distanceData.compactMap { distanceData in
            let quantity = HKQuantity(unit: .meter(), doubleValue: distanceData.distance * 1000) // Convert km to meters
            
            // Create a sample for the entire day
            let startOfDay = Calendar.current.startOfDay(for: distanceData.date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? distanceData.date
            
            return HKQuantitySample(
                type: distanceType,
                quantity: quantity,
                start: startOfDay,
                end: endOfDay
            )
        }
    }
    
    private func createHeartRateSamples(from heartRateData: [HeartRateData]) -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Could not create heart rate type")
            return []
        }
        
        var allSamples: [HKQuantitySample] = []
        
        for heartRateData in heartRateData {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: heartRateData.date)
            
            // Create samples from intraday readings (minute-by-minute data)
            for intradayReading in heartRateData.intradayReadings {
                guard let sampleTime = parseIntradayTime(intradayReading.time, baseDate: startOfDay) else {
                    continue
                }
                
                let quantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), 
                                        doubleValue: Double(intradayReading.value))
                
                // Create a 1-minute sample
                let endTime = calendar.date(byAdding: .minute, value: 1, to: sampleTime) ?? sampleTime
                
                let sample = HKQuantitySample(
                    type: heartRateType,
                    quantity: quantity,
                    start: sampleTime,
                    end: endTime
                )
                allSamples.append(sample)
            }
            
            // If no intraday data but we have resting heart rate, create a single sample
            if heartRateData.intradayReadings.isEmpty, let restingHeartRate = heartRateData.restingHeartRate {
                let quantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), 
                                        doubleValue: Double(restingHeartRate))
                
                let sampleTime = calendar.date(byAdding: .minute, value: 1, to: startOfDay) ?? heartRateData.date
                
                let sample = HKQuantitySample(
                    type: heartRateType,
                    quantity: quantity,
                    start: startOfDay,
                    end: sampleTime
                )
                allSamples.append(sample)
            }
        }
        
        print("✅ Created \(allSamples.count) heart rate samples from intraday data")
        return allSamples
    }
    
    private func parseIntradayTime(_ timeString: String, baseDate: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        guard let timeComponents = formatter.date(from: timeString) else {
            print("❌ Failed to parse intraday time: \(timeString)")
            return nil
        }
        
        let calendar = Calendar.current
        let timeComps = calendar.dateComponents([.hour, .minute, .second], from: timeComponents)
        
        return calendar.date(bySettingHour: timeComps.hour ?? 0, 
                           minute: timeComps.minute ?? 0, 
                           second: timeComps.second ?? 0, 
                           of: baseDate)
    }
    
    private func createSleepSamples(from sleepData: [SleepData]) -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("❌ Could not create sleep analysis type")
            return []
        }
        
        var samples: [HKCategorySample] = []
        
        print("🛏️ Processing \(sleepData.count) sleep records")
        
        for sleep in sleepData {
            print("🛏️ Sleep record: \(sleep.startTime) to \(sleep.endTime), duration: \(sleep.duration/3600) hours")
            
            // Main sleep sample - this represents the overall sleep period
            let mainSleepSample = HKCategorySample(
                type: sleepType,
                value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                start: sleep.startTime,
                end: sleep.endTime
            )
            samples.append(mainSleepSample)
            print("🛏️ Added main sleep sample: inBed from \(sleep.startTime) to \(sleep.endTime)")
            
            // Add sleep stage samples if available
            if let stages = sleep.stages {
                print("🛏️ Sleep stages available: deep=\(stages.deep)min, light=\(stages.light)min, rem=\(stages.rem)min, wake=\(stages.wake)min")
                
                let totalMinutes = stages.deep + stages.light + stages.rem + stages.wake
                guard totalMinutes > 0 else { 
                    print("⚠️ No sleep stage data available")
                    continue 
                }
                
                var currentTime = sleep.startTime
                let totalDuration = sleep.endTime.timeIntervalSince(sleep.startTime)
                
                // Deep sleep
                if stages.deep > 0 {
                    let deepDuration = totalDuration * (Double(stages.deep) / Double(totalMinutes))
                    let deepEndTime = currentTime.addingTimeInterval(deepDuration)
                    
                    let deepSample = HKCategorySample(
                        type: sleepType,
                        value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        start: currentTime,
                        end: deepEndTime
                    )
                    samples.append(deepSample)
                    print("🛏️ Added deep sleep: \(currentTime) to \(deepEndTime)")
                    currentTime = deepEndTime
                }
                
                // Light sleep
                if stages.light > 0 {
                    let lightDuration = totalDuration * (Double(stages.light) / Double(totalMinutes))
                    let lightEndTime = currentTime.addingTimeInterval(lightDuration)
                    
                    let lightSample = HKCategorySample(
                        type: sleepType,
                        value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        start: currentTime,
                        end: lightEndTime
                    )
                    samples.append(lightSample)
                    print("🛏️ Added light sleep: \(currentTime) to \(lightEndTime)")
                    currentTime = lightEndTime
                }
                
                // REM sleep
                if stages.rem > 0 {
                    let remDuration = totalDuration * (Double(stages.rem) / Double(totalMinutes))
                    let remEndTime = currentTime.addingTimeInterval(remDuration)
                    
                    let remSample = HKCategorySample(
                        type: sleepType,
                        value: HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                        start: currentTime,
                        end: remEndTime
                    )
                    samples.append(remSample)
                    print("🛏️ Added REM sleep: \(currentTime) to \(remEndTime)")
                    currentTime = remEndTime
                }
            } else {
                print("⚠️ No sleep stages available for this record")
            }
        }
        
        print("🛏️ Created \(samples.count) total sleep samples")
        return samples
    }
    
    // MARK: - Duplicate Detection (HealthKit lookup)
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
        
        // Restrict to samples written by this app
        // Get our app's bundle identifier for more precise filtering
        let bundleId = Bundle.main.bundleIdentifier ?? "com.yourcompany.FitbitSync"
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        
        print("🔍 Checking for existing \(dataType.displayName) data on \(date) from app: \(bundleId)")
        
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: combinedPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error checking existing HealthKit data for \(dataType.displayName) on \(date): \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                let hasExistingData = !(samples?.isEmpty ?? true)
                print("🔍 Checking \(dataType.displayName) on \(date): Found \(samples?.count ?? 0) existing samples from our app")
                
                // Debug: Print source info for existing samples
                if let samples = samples, !samples.isEmpty {
                    for sample in samples.prefix(3) { // Just first few for debugging
                        print("📱 Existing sample source: \(sample.sourceRevision.source.name) - \(sample.sourceRevision.source.bundleIdentifier)")
                    }
                }
                
                completion(hasExistingData)
            }
        }
        
        healthStore.execute(query)
    }
}

// MARK: - Data Types Enum
enum DataType: String, CaseIterable {
    case steps = "Steps"
    case distance = "Distance"
    case heartRate = "Heart Rate"
    case sleep = "Sleep"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .steps:
            return "figure.walk"
        case .distance:
            return "location"
        case .heartRate:
            return "heart.fill"
        case .sleep:
            return "bed.double.fill"
        }
    }
}
