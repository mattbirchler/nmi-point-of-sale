import SwiftUI
import Charts

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var historyDateRange: HistoryDateRange? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            SaleTab(onTodayRevenueTapped: {
                historyDateRange = .today
                selectedTab = 1
            })
                .tabItem {
                    Label("Sale", systemImage: "creditcard")
                }
                .tag(0)

            HistoryView(initialDateRange: historyDateRange)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newTab in
            // Reset to default when switching away from history
            if newTab != 1 {
                historyDateRange = nil
            }
        }
    }
}

struct SaleTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewSale = false
    @State private var dailySummary: DailySummary = .empty
    @State private var isLoadingSummary = false
    @State private var hasLoadedOnce = false
    @State private var weeklyData: [DailyVolumeData] = []
    @State private var isLoadingWeekly = false

    var onTodayRevenueTapped: () -> Void

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 8)

                    // Weekly Volume Chart
                    if !weeklyData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last 7 Days")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)

                            Chart(weeklyData) { day in
                                BarMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Revenue", day.revenue)
                                )
                                .foregroundStyle(Color.accentColor.gradient)
                                .cornerRadius(4)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { value in
                                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                                        .font(.caption2)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                                    AxisGridLine()
                                        .foregroundStyle(Color(.systemGray5))
                                    AxisValueLabel {
                                        if let revenue = value.as(Double.self) {
                                            Text(formatChartValue(revenue))
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .frame(height: 100)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    } else if isLoadingWeekly && !hasLoadedOnce {
                        VStack {
                            ProgressView()
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }

                    // Hero Revenue Display
                    VStack(spacing: 12) {
                        Text("Today's Revenue")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        if isLoadingSummary && !hasLoadedOnce {
                            ProgressView()
                                .scaleEffect(1.2)
                                .frame(height: 60)
                        } else {
                            Button {
                                onTodayRevenueTapped()
                            } label: {
                                Text(dailySummary.totalRevenue.formatted(as: appState.settings.currency))
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundStyle(.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            onTodayRevenueTapped()
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(dailySummary.transactionCount) transaction\(dailySummary.transactionCount == 1 ? "" : "s") today")
                                    .font(.callout)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)

                    // New Sale Button - Big & Bold
                    Button {
                        showNewSale = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                            Text("New Sale")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(20)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 4)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(greeting)
            .refreshable {
                await loadAllData()
            }
            .sheet(isPresented: $showNewSale) {
                NewSaleView(onComplete: {
                    Task {
                        await loadAllData()
                    }
                })
            }
            .task {
                if !hasLoadedOnce {
                    await loadAllData()
                    hasLoadedOnce = true
                }
            }
        }
    }

    private func loadAllData() async {
        async let summaryTask: () = loadDailySummary()
        async let weeklyTask: () = loadWeeklyData()
        _ = await (summaryTask, weeklyTask)
    }

    private func loadDailySummary() async {
        isLoadingSummary = true
        do {
            dailySummary = try await NMIService.shared.getDailySummary(securityKey: appState.securityKey)
        } catch {
            // Silently fail - just show zero
            dailySummary = .empty
        }
        isLoadingSummary = false
    }

    private func loadWeeklyData() async {
        isLoadingWeekly = true

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        do {
            let transactions = try await NMIService.shared.getTransactions(
                securityKey: appState.securityKey,
                startDate: sevenDaysAgo,
                endDate: tomorrow,
                adjustForTimezone: true
            )

            // Group transactions by day and sum revenue
            let successfulTransactions = transactions.filter { $0.status.isSuccessful }
            let grouped = Dictionary(grouping: successfulTransactions) { transaction in
                calendar.startOfDay(for: transaction.date)
            }

            // Create data points for all 7 days (including days with no transactions)
            var data: [DailyVolumeData] = []
            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: sevenDaysAgo)!
                let dayStart = calendar.startOfDay(for: date)
                let revenue = grouped[dayStart]?.reduce(0) { $0 + $1.total } ?? 0
                data.append(DailyVolumeData(date: dayStart, revenue: revenue))
            }

            weeklyData = data
        } catch {
            // Silently fail - just show empty chart
            weeklyData = []
        }

        isLoadingWeekly = false
    }

    private func formatChartValue(_ value: Double) -> String {
        let symbol = appState.settings.currency.symbol
        if value >= 1000 {
            return "\(symbol)\(Int(value / 1000))k"
        }
        return "\(symbol)\(Int(value))"
    }
}

// MARK: - Daily Volume Data

struct DailyVolumeData: Identifiable {
    let id = UUID()
    let date: Date
    let revenue: Double
}

#Preview {
    MainView()
        .environmentObject(AppState())
}

#Preview("Sale Tab") {
    SaleTab(onTodayRevenueTapped: {})
        .environmentObject(AppState())
}
