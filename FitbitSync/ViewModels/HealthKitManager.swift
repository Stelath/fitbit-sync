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

    func saveData(fitbitData: FitbitData, selectedDataTypes: Set<DataType>, completion: @escaping (Bool, Error?) -> Void) {
        var allSamples: [HKSample] = []
        
        // Save steps data
        if selectedDataTypes.contains(.steps) {
            let stepSamples = createStepSamples(from: fitbitData.stepsData)
            allSamples.append(contentsOf: stepSamples)
        }
        
        // Save distance data
        if selectedDataTypes.contains(.distance) {
            let distanceSamples = createDistanceSamples(from: fitbitData.distanceData)
            allSamples.append(contentsOf: distanceSamples)
        }
        
        // Save heart rate data
        if selectedDataTypes.contains(.heartRate) {
            let heartRateSamples = createHeartRateSamples(from: fitbitData.heartRateData)
            allSamples.append(contentsOf: heartRateSamples)
        }
        
        // Save sleep data
        if selectedDataTypes.contains(.sleep) {
            let sleepSamples = createSleepSamples(from: fitbitData.sleepData)
            allSamples.append(contentsOf: sleepSamples)
        }
        
        guard !allSamples.isEmpty else {
            print("⚠️ No samples to save")
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
        
        healthStore.save(allSamples) { success, error in
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
        
        return heartRateData.compactMap { heartRateData in
            guard let restingHeartRate = heartRateData.restingHeartRate else { return nil }
            
            let quantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), 
                                    doubleValue: Double(restingHeartRate))
            
            // Create a sample for the resting heart rate at the start of the day
            let startOfDay = Calendar.current.startOfDay(for: heartRateData.date)
            let sampleTime = Calendar.current.date(byAdding: .minute, value: 1, to: startOfDay) ?? heartRateData.date
            
            return HKQuantitySample(
                type: heartRateType,
                quantity: quantity,
                start: startOfDay,
                end: sampleTime
            )
        }
    }
    
    private func createSleepSamples(from sleepData: [SleepData]) -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("❌ Could not create sleep analysis type")
            return []
        }
        
        var samples: [HKCategorySample] = []
        
        for sleep in sleepData {
            // Main sleep sample
            let mainSleepSample = HKCategorySample(
                type: sleepType,
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: sleep.startTime,
                end: sleep.endTime
            )
            samples.append(mainSleepSample)
            
            // Add sleep stage samples if available
            if let stages = sleep.stages {
                let totalMinutes = stages.deep + stages.light + stages.rem + stages.wake
                guard totalMinutes > 0 else { continue }
                
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
                    currentTime = remEndTime
                }
            }
        }
        
        return samples
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
