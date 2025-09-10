//
//  FitbitAPIManager.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

class FitbitAPIManager: NSObject, ObservableObject {
    private let clientId = Constants.fitbitClientID
    private let redirectURI = Constants.fitbitRedirectURI
    private let fitbitAuthURL = Constants.fitbitAuthURL
    private let tokenURL = Constants.fitbitTokenURL
    private let scopes = Constants.fitbitScopes

    private var accessToken: String?
    private var refreshToken: String?
    private var codeVerifier: String?

    func isAuthenticated() -> Bool {
        // Load token from keychain if not in memory
        if accessToken == nil {
            loadTokensFromKeychain()
        }
        return accessToken != nil
    }

    func authenticate(completion: @escaping (Bool) -> Void) {
        // Generate code verifier and challenge for PKCE
        let pkce = PKCEGenerator()
        codeVerifier = pkce.codeVerifier
        let codeChallenge = pkce.codeChallenge

        // Build the authorization URL
        var components = URLComponents(string: fitbitAuthURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            completion(false)
            return
        }

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "fitsync") { callbackURL, error in
            guard let callbackURL = callbackURL, error == nil else {
                completion(false)
                return
            }

            // Parse authorization code from callbackURL
            let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            let code = urlComponents?.queryItems?.first(where: { $0.name == "code" })?.value
            
            guard let authCode = code, !authCode.isEmpty else {
                print("❌ No authorization code received")
                completion(false)
                return
            }
            
            print("✅ Authorization code received, exchanging for token...")
            
            // Exchange authorization code for access token
            self.exchangeCodeForToken(code: authCode) { success in
                print("🔄 Token exchange result: \(success)")
                completion(success)
            }
        }

        session.presentationContextProvider = self
        session.start()
    }

    private func exchangeCodeForToken(code: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenURL),
              let codeVerifier = codeVerifier else {
            print("❌ Missing token URL or code verifier")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Try Basic auth with client_id and client_secret for testing
        let clientCredentials = "\(clientId):\(Constants.fitbitClientSecret)"
        let encodedCredentials = Data(clientCredentials.utf8).base64EncodedString()
        request.addValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
        
        print("🔑 Client ID: \(clientId)")
        print("🔑 Client credentials: \(clientCredentials)")
        print("🔑 Encoded credentials: \(encodedCredentials)")
        print("🔑 Authorization header: Basic \(encodedCredentials)")

        let bodyParams = [
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "code": code,
            "code_verifier": codeVerifier
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        print("🔄 Exchanging authorization code for access token...")
        print("📤 Request body: \(bodyString)")
        print("📤 Request headers: \(request.allHTTPHeaderFields ?? [:])")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Network error: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status: \(httpResponse.statusCode)")
                
                // Print response headers for debugging
                print("📡 Response headers: \(httpResponse.allHeaderFields)")
            }

            // Always print the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Raw response: \(responseString)")
            }

            // Try to parse as TokenResponse first
            if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                self.accessToken = tokenResponse.access_token
                self.refreshToken = tokenResponse.refresh_token
                
                // Save tokens securely to Keychain
                self.saveTokensToKeychain(accessToken: tokenResponse.access_token, 
                                        refreshToken: tokenResponse.refresh_token)
                
                print("✅ Successfully obtained access token")
                completion(true)
            } else {
                // Fallback to JSON parsing for debugging
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("❌ Token exchange failed. Response: \(json)")
                } else {
                    print("❌ Failed to parse response as JSON")
                }
                completion(false)
            }
        }.resume()
    }

    func fetchUserProfile(completion: @escaping (UserProfile?) -> Void) {
        guard let accessToken = accessToken else {
            completion(nil)
            return
        }

        let url = URL(string: "https://api.fitbit.com/1/user/-/profile.json")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
               let jsonData = try? JSONSerialization.data(withJSONObject: jsonResponse),
               let profile = try? JSONDecoder().decode(UserProfileResponse.self, from: jsonData) {
                completion(profile.user)
            } else {
                completion(nil)
            }
        }.resume()
    }

    func fetchAllData(for date: Date = Date(), completion: @escaping (FitbitData?) -> Void) {
        guard accessToken != nil else {
            print("❌ No access token available")
            completion(nil)
            return
        }
        
        let group = DispatchGroup()
        var stepsData: [StepData] = []
        var heartRateData: [HeartRateData] = []
        var sleepData: [SleepData] = []
        var distanceData: [DistanceData] = []
        var hasError = false
        
        // Fetch steps data
        group.enter()
        fetchStepsData(for: date) { steps in
            if let steps = steps {
                stepsData = steps
            } else {
                hasError = true
            }
            group.leave()
        }
        
        // Fetch heart rate data
        group.enter()
        fetchHeartRateData(for: date) { heartRate in
            if let heartRate = heartRate {
                heartRateData = heartRate
            } else {
                hasError = true
            }
            group.leave()
        }
        
        // Fetch sleep data
        group.enter()
        fetchSleepData(for: date) { sleep in
            if let sleep = sleep {
                sleepData = sleep
            } else {
                hasError = true
            }
            group.leave()
        }
        
        // Fetch distance data
        group.enter()
        fetchDistanceData(for: date) { distance in
            if let distance = distance {
                distanceData = distance
            } else {
                hasError = true
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if hasError {
                completion(nil)
            } else {
                let fitbitData = FitbitData(
                    stepsData: stepsData,
                    heartRateData: heartRateData,
                    sleepData: sleepData,
                    distanceData: distanceData
                )
            completion(fitbitData)
            }
        }
    }
    
    // MARK: - Individual Data Fetching Methods
    
    private func fetchStepsData(for date: Date, completion: @escaping ([StepData]?) -> Void) {
        let dateString = formatDateForAPI(date)
        let url = "\(Constants.fitbitBaseURL)/\(Constants.fitbitAPIVersion)/user/-/activities/steps/date/\(dateString)/7d.json"
        
        performAPIRequest(url: url, responseType: StepsResponse.self) { response in
            guard let response = response else {
                completion(nil)
                return
            }
            
            let stepData = response.activities_steps.compactMap { dataPoint -> StepData? in
                guard let date = self.parseAPIDate(dataPoint.dateTime),
                      let steps = Int(dataPoint.value) else { return nil }
                return StepData(date: date, steps: steps)
            }
            completion(stepData)
        }
    }
    
    private func fetchHeartRateData(for date: Date, completion: @escaping ([HeartRateData]?) -> Void) {
        let dateString = formatDateForAPI(date)
        let url = "\(Constants.fitbitBaseURL)/\(Constants.fitbitAPIVersion)/user/-/activities/heart/date/\(dateString)/7d.json"
        
        performAPIRequest(url: url, responseType: HeartRateResponse.self) { response in
            guard let response = response else {
                completion(nil)
                return
            }
            
            let heartRateData = response.activities_heart.compactMap { dataPoint -> HeartRateData? in
                guard let date = self.parseAPIDate(dataPoint.dateTime) else { return nil }
                return HeartRateData(
                    date: date,
                    restingHeartRate: dataPoint.value.restingHeartRate,
                    zones: dataPoint.value.heartRateZones ?? []
                )
            }
            completion(heartRateData)
        }
    }
    
    private func fetchSleepData(for date: Date, completion: @escaping ([SleepData]?) -> Void) {
        let dateString = formatDateForAPI(date)
        let url = "\(Constants.fitbitBaseURL)/\(Constants.fitbitSleepAPIVersion)/user/-/sleep/date/\(dateString).json"
        
        performAPIRequest(url: url, responseType: SleepResponse.self) { response in
            guard let response = response else {
                completion(nil)
                return
            }
            
            print("🛏️ Raw sleep response: \(response.sleep.count) sleep logs")
            
            let sleepData = response.sleep.compactMap { sleepLog -> SleepData? in
                print("🛏️ Processing sleep log: \(sleepLog.dateOfSleep), start: \(sleepLog.startTime), end: \(sleepLog.endTime)")
                
                guard let date = self.parseAPIDate(sleepLog.dateOfSleep),
                      let startTime = self.parseAPIDateTime(sleepLog.startTime),
                      let endTime = self.parseAPIDateTime(sleepLog.endTime) else { 
                    print("❌ Failed to parse sleep dates")
                    return nil 
                }
                
                var stages: SleepStages?
                if let summary = sleepLog.levels?.summary {
                    stages = SleepStages(
                        deep: summary.deep?.minutes ?? 0,
                        light: summary.light?.minutes ?? 0,
                        rem: summary.rem?.minutes ?? 0,
                        wake: summary.wake?.minutes ?? 0
                    )
                    print("🛏️ Sleep stages: deep=\(stages?.deep ?? 0), light=\(stages?.light ?? 0), rem=\(stages?.rem ?? 0), wake=\(stages?.wake ?? 0)")
                } else {
                    print("⚠️ No sleep stages available in API response")
                }
                
                let sleepData = SleepData(
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    duration: TimeInterval(sleepLog.duration / 1000), // Convert from ms to seconds
                    minutesAsleep: sleepLog.minutesAsleep,
                    minutesAwake: sleepLog.minutesAwake,
                    efficiency: sleepLog.efficiency,
                    stages: stages
                )
                
                print("✅ Created sleep data: \(sleepData)")
                return sleepData
            }
            
            print("🛏️ Final processed sleep data count: \(sleepData.count)")
            completion(sleepData)
        }
    }
    
    private func fetchDistanceData(for date: Date, completion: @escaping ([DistanceData]?) -> Void) {
        let dateString = formatDateForAPI(date)
        let url = "\(Constants.fitbitBaseURL)/\(Constants.fitbitAPIVersion)/user/-/activities/distance/date/\(dateString)/7d.json"
        
        performAPIRequest(url: url, responseType: DistanceResponse.self) { response in
            guard let response = response else {
                completion(nil)
                return
            }
            
            let distanceData = response.activities_distance.compactMap { dataPoint -> DistanceData? in
                guard let date = self.parseAPIDate(dataPoint.dateTime),
                      let distance = Double(dataPoint.value) else { return nil }
                return DistanceData(date: date, distance: distance)
            }
            completion(distanceData)
        }
    }
    
    // MARK: - Generic API Request Method
    
    private func performAPIRequest<T: Codable>(url: String, responseType: T.Type, completion: @escaping (T?) -> Void) {
        guard let accessToken = accessToken,
              let requestURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ API request failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response status: \(httpResponse.statusCode) for \(url)")
                
                // Handle token expiration
                if httpResponse.statusCode == 401 {
                    print("🔄 Access token expired, attempting refresh...")
                    self.refreshAccessToken { success in
                        if success {
                            // Retry the request
                            self.performAPIRequest(url: url, responseType: responseType, completion: completion)
                        } else {
                            completion(nil)
                        }
                    }
                    return
                }
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(responseType, from: data)
                completion(decodedResponse)
            } catch {
                print("❌ Failed to decode response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - Token Management
    
    private func saveTokensToKeychain(accessToken: String, refreshToken: String) {
        // Save access token
        let accessTokenData = accessToken.data(using: .utf8)!
        let accessTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "fitbit_access_token",
            kSecValueData as String: accessTokenData
        ]
        
        SecItemDelete(accessTokenQuery as CFDictionary)
        SecItemAdd(accessTokenQuery as CFDictionary, nil)
        
        // Save refresh token
        let refreshTokenData = refreshToken.data(using: .utf8)!
        let refreshTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "fitbit_refresh_token",
            kSecValueData as String: refreshTokenData
        ]
        
        SecItemDelete(refreshTokenQuery as CFDictionary)
        SecItemAdd(refreshTokenQuery as CFDictionary, nil)
    }
    
    private func loadTokensFromKeychain() {
        // Load access token
        let accessTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "fitbit_access_token",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var accessTokenItem: CFTypeRef?
        if SecItemCopyMatching(accessTokenQuery as CFDictionary, &accessTokenItem) == errSecSuccess,
           let accessTokenData = accessTokenItem as? Data {
            self.accessToken = String(data: accessTokenData, encoding: .utf8)
        }
        
        // Load refresh token
        let refreshTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "fitbit_refresh_token",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var refreshTokenItem: CFTypeRef?
        if SecItemCopyMatching(refreshTokenQuery as CFDictionary, &refreshTokenItem) == errSecSuccess,
           let refreshTokenData = refreshTokenItem as? Data {
            self.refreshToken = String(data: refreshTokenData, encoding: .utf8)
        }
    }
    
    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = refreshToken,
              let url = URL(string: tokenURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Use Basic auth with client_id and client_secret for refresh token
        let clientCredentials = "\(clientId):\(Constants.fitbitClientSecret)"
        let encodedCredentials = Data(clientCredentials.utf8).base64EncodedString()
        request.addValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                self.accessToken = tokenResponse.access_token
                self.refreshToken = tokenResponse.refresh_token
                
                self.saveTokensToKeychain(accessToken: tokenResponse.access_token,
                                        refreshToken: tokenResponse.refresh_token)
                
                print("✅ Successfully refreshed access token")
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    func logout() {
        // Clear tokens from memory
        accessToken = nil
        refreshToken = nil
        
        // Clear tokens from keychain
        let accessTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "fitbit_access_token"
        ]
        SecItemDelete(accessTokenQuery as CFDictionary)
        
        let refreshTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "fitbit_refresh_token"
        ]
        SecItemDelete(refreshTokenQuery as CFDictionary)
        
        print("✅ Successfully logged out")
    }
    
    // MARK: - Date Formatting Helpers
    
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseAPIDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private func parseAPIDateTime(_ dateTimeString: String) -> Date? {
        let formatter = DateFormatter()
        
        // Try different formats that Fitbit might use
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateTimeString) {
                return date
            }
        }
        
        print("❌ Could not parse datetime: \(dateTimeString)")
        return nil
    }
}

extension FitbitAPIManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the app's main window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
