//
//  ContentView.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncViewModel: SyncViewModel

    var body: some View {
        NavigationView {
            if syncViewModel.isAuthenticated {
                MainSyncView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            syncViewModel.checkAuthentication()
        }
    }
}

struct MainSyncView: View {
    @EnvironmentObject var syncViewModel: SyncViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // User Profile Section
                if let userProfile = syncViewModel.userProfile {
                    UserProfileCard(userProfile: userProfile)
                }
                
                // Data Selection Section
                DataSelectionCard()
                
                // Sync Status Section
                SyncStatusCard()
                
                // Sync Button
                SyncButton()
                
                // Last Sync Info
                if let lastSync = syncViewModel.lastSyncDate {
                    LastSyncCard(date: lastSync)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Fitbit Sync")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Logout") {
                    syncViewModel.logout()
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct UserProfileCard: View {
    let userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Welcome, \(userProfile.fullName)!")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Label("\(userProfile.age) years", systemImage: "calendar")
                Spacer()
                Label(userProfile.gender.capitalized, systemImage: "person")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DataSelectionCard: View {
    @EnvironmentObject var syncViewModel: SyncViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Select Data to Sync")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DataType.allCases, id: \.self) { dataType in
                    DataTypeToggle(
                        dataType: dataType,
                        isSelected: syncViewModel.selectedDataTypes.contains(dataType)
                    ) {
                        syncViewModel.toggleDataType(dataType)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct DataTypeToggle: View {
    let dataType: DataType
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: dataType.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(dataType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SyncStatusCard: View {
    @EnvironmentObject var syncViewModel: SyncViewModel
    
    var body: some View {
        if !syncViewModel.syncStatus.isEmpty {
            HStack {
                if syncViewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if syncViewModel.syncStatus.contains("✅") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if syncViewModel.syncStatus.contains("❌") {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                
                Text(syncViewModel.syncStatus)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding()
            .background(syncViewModel.syncStatus.contains("✅") ? Color.green.opacity(0.1) :
                       syncViewModel.syncStatus.contains("❌") ? Color.red.opacity(0.1) :
                       Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct SyncButton: View {
    @EnvironmentObject var syncViewModel: SyncViewModel
    
    var body: some View {
        Button(action: {
            syncViewModel.syncData()
        }) {
            HStack {
                if syncViewModel.isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                }
                
                Text(syncViewModel.isSyncing ? "Syncing..." : "Sync to Apple Health")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                syncViewModel.selectedDataTypes.isEmpty ? 
                Color.gray : (syncViewModel.isSyncing ? Color.blue.opacity(0.7) : Color.blue)
            )
            .cornerRadius(12)
        }
        .disabled(syncViewModel.selectedDataTypes.isEmpty || syncViewModel.isSyncing)
    }
}

struct LastSyncCard: View {
    let date: Date
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Sync")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
