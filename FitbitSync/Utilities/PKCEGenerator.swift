//
//  Untitled.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import Foundation
import CryptoKit

class PKCEGenerator {
    let codeVerifier: String
    let codeChallenge: String

    init() {
        codeVerifier = PKCEGenerator.generateCodeVerifier()
        codeChallenge = PKCEGenerator.generateCodeChallenge(codeVerifier: codeVerifier)
    }

    private static func generateCodeVerifier() -> String {
        let length = 128
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        var result = ""
        for _ in 0..<length {
            if let randomChar = characters.randomElement() {
                result.append(randomChar)
            }
        }
        return result
    }

    private static func generateCodeChallenge(codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else { return "" }
        let hashed = SHA256.hash(data: data)
        let hashString = Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return hashString
    }
}
