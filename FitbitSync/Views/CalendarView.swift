//
//  CalendarView.swift
//  FitbitSync
//
//  Created by Alexander Korte on 10/8/24.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var syncViewModel: SyncViewModel
    @State private var selectedMonth = Date()
    @State private var showingLongSync = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Month Navigation
                    MonthNavigationView(selectedMonth: $selectedMonth)
                    
                    // Calendar Grid
                    CalendarGridView(
                        selectedMonth: selectedMonth,
                        syncStatuses: syncViewModel.syncTracker.getSyncStatusesForMonth(selectedMonth)
                    )
                    
                    // Sync Statistics
                    SyncStatisticsCard(statistics: syncViewModel.syncTracker.statistics)
                    
                    // Quick Actions
                    QuickActionsCard(
                        onLongSync: { showingLongSync = true },
                        onResetFailed: { syncViewModel.syncTracker.resetFailedSyncs() },
                        syncTracker: syncViewModel.syncTracker
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Sync Calendar")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingLongSync) {
                LongSyncView()
                    .environmentObject(syncViewModel)
            }
        }
    }
}

struct MonthNavigationView: View {
    @Binding var selectedMonth: Date
    private let calendar = Calendar.current
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(monthFormatter.string(from: selectedMonth))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

struct CalendarGridView: View {
    let selectedMonth: Date
    let syncStatuses: [SyncStatus]
    private let calendar = Calendar.current
    
    private var days: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else {
            return []
        }
        
        let monthFirstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysToSubtract = monthFirstWeekday - calendar.firstWeekday
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: monthInterval.start) else {
            return []
        }
        
        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
    }
    
    private var statusLookup: [String: SyncStatus] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var lookup: [String: SyncStatus] = [:]
        for status in syncStatuses {
            lookup[formatter.string(from: status.date)] = status
        }
        return lookup
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isCurrentMonth: calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month),
                        syncStatus: getSyncStatus(for: date)
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getSyncStatus(for date: Date) -> SyncStatus? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return statusLookup[formatter.string(from: date)]
    }
}

struct CalendarDayView: View {
    let date: Date
    let isCurrentMonth: Bool
    let syncStatus: SyncStatus?
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var backgroundColor: Color {
        if let status = syncStatus {
            if status.allDataSynced {
                return .green.opacity(0.2)
            } else if status.steps == .failed || status.heartRate == .failed || 
                     status.sleep == .failed || status.distance == .failed {
                return .red.opacity(0.2)
            } else if status.hasAnyData {
                return .orange.opacity(0.2)
            }
        }
        return Color.clear
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isCurrentMonth ? .primary : .secondary)
            
            // Sync status indicators
            if let status = syncStatus, isCurrentMonth {
                HStack(spacing: 1) {
                    SyncStatusDot(state: status.steps)
                    SyncStatusDot(state: status.heartRate)
                    SyncStatusDot(state: status.sleep)
                    SyncStatusDot(state: status.distance)
                }
            }
        }
        .frame(width: 40, height: 40)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
        )
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
}

struct SyncStatusDot: View {
    let state: SyncState
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
    }
    
    private var color: Color {
        switch state {
        case .synced:
            return .green
        case .notSynced:
            return .orange
        case .syncing:
            return .blue
        case .failed:
            return .red
        case .noData:
            return .gray
        }
    }
}

struct SyncStatisticsCard: View {
    let statistics: SyncStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Sync Statistics")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatisticItem(title: "Total Days", value: "\(statistics.totalDays)")
                StatisticItem(title: "Synced", value: "\(statistics.syncedDays)")
                StatisticItem(title: "Failed", value: "\(statistics.failedDays)")
                StatisticItem(title: "Pending", value: "\(statistics.pendingDays)")
            }
            
            if statistics.totalDays > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Completion")
                        Spacer()
                        Text("\(Int(statistics.syncPercentage))%")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    ProgressView(value: statistics.syncPercentage / 100)
                        .tint(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuickActionsCard: View {
    let onLongSync: () -> Void
    let onResetFailed: () -> Void
    let syncTracker: SyncTrackingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.blue)
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: onLongSync) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Long Sync (Historical Data)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .foregroundColor(.blue)
                
                Button(action: onResetFailed) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry Failed Syncs")
                        Spacer()
                        Text("\(syncTracker.getDaysWithIssues().count)")
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
