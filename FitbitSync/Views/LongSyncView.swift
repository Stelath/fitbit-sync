//
//  LongSyncView.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import SwiftUI

struct LongSyncView: View {
    @EnvironmentObject var syncViewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedDataTypes: Set<DataType> = Set(DataType.allCases)
    @State private var isLongSyncing = false
    @State private var syncProgress: Double = 0
    @State private var currentSyncDate: Date?
    @State private var syncedDays = 0
    @State private var totalDays = 0
    @State private var syncStatus = ""
    
    private var longSyncConfig: LongSyncConfig {
        LongSyncConfig(
            startDate: startDate,
            endDate: endDate,
            dataTypes: selectedDataTypes
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Long Sync")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sync historical data from Fitbit to Apple Health")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !isLongSyncing {
                        // Configuration
                        ConfigurationCard()
                        
                        // Data Type Selection
                        DataTypeSelectionCard()
                        
                        // Summary
                        SyncSummaryCard()
                        
                        // Start Button
                        StartSyncButton()
                        
                    } else {
                        // Progress
                        SyncProgressCard()
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Long Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if isLongSyncing {
                            // TODO: Cancel long sync
                        }
                        dismiss()
                    }
                }
                
                if isLongSyncing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Stop") {
                            stopLongSync()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func ConfigurationCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Date Range")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            
            if startDate > endDate {
                Text("Start date must be before end date")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private func DataTypeSelectionCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Data Types")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DataType.allCases, id: \.self) { dataType in
                    LongSyncDataTypeToggle(
                        dataType: dataType,
                        isSelected: selectedDataTypes.contains(dataType)
                    ) {
                        toggleDataType(dataType)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private func SyncSummaryCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Sync Summary")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                SummaryRow(title: "Total Days", value: "\(longSyncConfig.totalDays)")
                SummaryRow(title: "Data Types", value: "\(selectedDataTypes.count)")
                SummaryRow(title: "Estimated Batches", value: "\(longSyncConfig.batches.count)")
                SummaryRow(title: "Estimated Time", value: estimatedTime)
            }
            
            if longSyncConfig.totalDays > 365 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Large sync may take significant time and API calls")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private func StartSyncButton() -> some View {
        Button(action: startLongSync) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Long Sync")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(canStartSync ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canStartSync)
    }
    
    @ViewBuilder
    private func SyncProgressCard() -> some View {
        VStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: syncProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: syncProgress)
                
                VStack {
                    Text("\(Int(syncProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(syncedDays)/\(totalDays)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Current Status
            VStack(spacing: 8) {
                Text(syncStatus)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let currentDate = currentSyncDate {
                    Text("Syncing: \(currentDate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Bar
            ProgressView(value: syncProgress)
                .tint(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Views
    
    private func SummaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
    
    // MARK: - Computed Properties
    
    private var canStartSync: Bool {
        startDate <= endDate && !selectedDataTypes.isEmpty && longSyncConfig.totalDays > 0
    }
    
    private var estimatedTime: String {
        let batches = longSyncConfig.batches.count
        let estimatedMinutes = batches * 2 // Rough estimate: 2 minutes per batch
        
        if estimatedMinutes < 60 {
            return "\(estimatedMinutes) min"
        } else {
            let hours = estimatedMinutes / 60
            let minutes = estimatedMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
    
    // MARK: - Actions
    
    private func toggleDataType(_ dataType: DataType) {
        if selectedDataTypes.contains(dataType) {
            selectedDataTypes.remove(dataType)
        } else {
            selectedDataTypes.insert(dataType)
        }
    }
    
    private func startLongSync() {
        isLongSyncing = true
        totalDays = longSyncConfig.totalDays
        syncedDays = 0
        syncProgress = 0
        syncStatus = "Preparing long sync..."
        
        performLongSync()
    }
    
    private func stopLongSync() {
        isLongSyncing = false
        syncStatus = "Sync stopped by user"
    }
    
    private func performLongSync() {
        let batches = longSyncConfig.batches
        
        func processBatch(index: Int) {
            guard index < batches.count && isLongSyncing else {
                // Sync completed or stopped
                if isLongSyncing {
                    syncStatus = "✅ Long sync completed!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
                return
            }
            
            let batch = batches[index]
            currentSyncDate = batch.start
            syncStatus = "Syncing batch \(index + 1) of \(batches.count)..."
            
            // Sync this batch
            syncBatch(batch) { success in
                DispatchQueue.main.async {
                    if success {
                        syncedDays += longSyncConfig.batchSize
                        syncProgress = Double(syncedDays) / Double(totalDays)
                        
                        // Process next batch after a small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            processBatch(index: index + 1)
                        }
                    } else {
                        syncStatus = "❌ Batch sync failed"
                        isLongSyncing = false
                    }
                }
            }
        }
        
        processBatch(index: 0)
    }
    
    private func syncBatch(_ batch: DateRange, completion: @escaping (Bool) -> Void) {
        // This would sync data for the date range in the batch
        // For now, simulate the sync process
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            completion(true)
        }
        
        // TODO: Implement actual batch syncing
        // 1. Call Fitbit API for date range
        // 2. Filter duplicates using sync tracker
        // 3. Save to HealthKit
        // 4. Update sync tracker
    }
}

struct LongSyncDataTypeToggle: View {
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
