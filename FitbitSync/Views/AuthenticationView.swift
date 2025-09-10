//
//  AuthenticationView.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var syncViewModel: SyncViewModel

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon and Title
            VStack(spacing: 16) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("Fitbit Sync")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sync your Fitbit data to Apple Health")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Features List
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "figure.walk", title: "Steps & Distance", description: "Daily activity tracking")
                FeatureRow(icon: "heart.fill", title: "Heart Rate", description: "Resting heart rate data")
                FeatureRow(icon: "bed.double.fill", title: "Sleep Analysis", description: "Sleep stages and duration")
                FeatureRow(icon: "lock.shield.fill", title: "Secure & Private", description: "Your data stays on your device")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Login Button
            Button(action: {
                syncViewModel.authenticate()
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .font(.title3)
                    
                    Text("Connect with Fitbit")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Privacy Note
            Text("We use secure OAuth 2.0 with PKCE for authentication. Your credentials are never stored on this device.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
