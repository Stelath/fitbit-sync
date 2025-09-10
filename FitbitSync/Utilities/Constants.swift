//
//  Constants.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation

struct Constants {
    static let fitbitClientID = "23PTK4"
    // NOTE: Temporarily adding client secret for testing - this should be removed for production
    // For now, let's try with the secret to see if that resolves the auth issue
    static let fitbitClientSecret = "8b9f9179e4269088a854e5a05acfebf1"
    static let fitbitRedirectURI = "fitsync://oauth-callback"
    static let fitbitAuthURL = "https://www.fitbit.com/oauth2/authorize"
    static let fitbitTokenURL = "https://api.fitbit.com/oauth2/token"
    
    // Core scopes needed for our app
    static let fitbitScopes = [
        "activity",    // Steps and distance
        "heartrate",   // Heart rate data
        "sleep",       // Sleep data with stages
        "profile"      // User profile info
    ].joined(separator: " ")
    
    // API endpoints
    static let fitbitBaseURL = "https://api.fitbit.com"
    static let fitbitAPIVersion = "1"
    static let fitbitSleepAPIVersion = "1.2"  // Version 1.2 includes sleep stages
}
