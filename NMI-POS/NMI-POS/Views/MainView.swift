import SwiftUI

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

    var onTodayRevenueTapped: () -> Void

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let profileFirstName = appState.merchantProfile?.firstName ?? ""
        let firstName = profileFirstName.isEmpty ? "Matt" : profileFirstName

        let timeGreeting: String
        switch hour {
        case 0..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Good night"
        }

        return "\(timeGreeting), \(firstName)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 20)

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
                    .padding(.vertical, 40)

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
                await loadDailySummary()
            }
            .sheet(isPresented: $showNewSale) {
                NewSaleView(onComplete: {
                    Task {
                        await loadDailySummary()
                    }
                })
            }
            .task {
                if !hasLoadedOnce {
                    await loadDailySummary()
                    hasLoadedOnce = true
                }
            }
        }
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
}

#Preview {
    MainView()
        .environmentObject(AppState())
}

#Preview("Sale Tab") {
    SaleTab(onTodayRevenueTapped: {})
        .environmentObject(AppState())
}
