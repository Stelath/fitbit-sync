//
//  FitbitDataModels.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation

// MARK: - Main Data Container
struct FitbitData {
    var stepsData: [StepData]
    var heartRateData: [HeartRateData]
    var sleepData: [SleepData]
    var distanceData: [DistanceData]
}

// MARK: - Steps Data
struct StepsResponse: Codable {
    let activities_steps: [StepDataPoint]
    
    enum CodingKeys: String, CodingKey {
        case activities_steps = "activities-steps"
    }
}

struct StepDataPoint: Codable {
    let dateTime: String
    let value: String
}

struct StepData {
    let date: Date
    let steps: Int
}

// MARK: - Heart Rate Data
struct HeartRateResponse: Codable {
    let activities_heart: [HeartRateDataPoint]
    
    enum CodingKeys: String, CodingKey {
        case activities_heart = "activities-heart"
    }
}

struct HeartRateDataPoint: Codable {
    let dateTime: String
    let value: HeartRateValue
}

struct HeartRateValue: Codable {
    let customHeartRateZones: [HeartRateZone]?
    let heartRateZones: [HeartRateZone]?
    let restingHeartRate: Int?
}

struct HeartRateZone: Codable {
    let caloriesOut: Double?
    let max: Int
    let min: Int
    let minutes: Int
    let name: String
}

struct HeartRateData {
    let date: Date
    let restingHeartRate: Int?
    let zones: [HeartRateZone]
}

// MARK: - Sleep Data
struct SleepResponse: Codable {
    let sleep: [SleepLog]
}

struct SleepLog: Codable {
    let dateOfSleep: String
    let duration: Int
    let efficiency: Int?
    let endTime: String
    let infoCode: Int?
    let isMainSleep: Bool
    let levels: SleepLevels?
    let logId: Int
    let minutesAfterWakeup: Int?
    let minutesAsleep: Int?
    let minutesAwake: Int?
    let minutesToFallAsleep: Int?
    let startTime: String
    let timeInBed: Int?
    let type: String
}

struct SleepLevels: Codable {
    let data: [SleepLevelData]?
    let shortData: [SleepLevelData]?
    let summary: SleepSummary?
}

struct SleepLevelData: Codable {
    let dateTime: String
    let level: String
    let seconds: Int
}

struct SleepSummary: Codable {
    let deep: SleepStageInfo?
    let light: SleepStageInfo?
    let rem: SleepStageInfo?
    let wake: SleepStageInfo?
}

struct SleepStageInfo: Codable {
    let count: Int
    let minutes: Int
    let thirtyDayAvgMinutes: Int?
}

struct SleepData {
    let date: Date
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let minutesAsleep: Int?
    let minutesAwake: Int?
    let efficiency: Int?
    let stages: SleepStages?
}

struct SleepStages {
    let deep: Int
    let light: Int
    let rem: Int
    let wake: Int
}

// MARK: - Distance Data
struct DistanceResponse: Codable {
    let activities_distance: [DistanceDataPoint]
    
    enum CodingKeys: String, CodingKey {
        case activities_distance = "activities-distance"
    }
}

struct DistanceDataPoint: Codable {
    let dateTime: String
    let value: String
}

struct DistanceData {
    let date: Date
    let distance: Double // in kilometers
}

// MARK: - User Profile
struct UserProfileResponse: Codable {
    let user: UserProfile
}

struct UserProfile: Codable {
    let fullName: String
    let age: Int
    let gender: String
    let timezone: String
    
    enum CodingKeys: String, CodingKey {
        case fullName = "fullName"
        case age = "age"
        case gender = "gender"
        case timezone = "timezone"
    }
}

// MARK: - OAuth Token Response
struct TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String
    let scope: String
    let token_type: String
    let user_id: String
}
