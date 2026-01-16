import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SaleTab()
                .tabItem {
                    Label("Sale", systemImage: "creditcard")
                }
                .tag(0)

            HistoryView()
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
    }
}

struct SaleTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewSale = false
    @State private var dailySummary: DailySummary = .empty
    @State private var isLoadingSummary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Daily Summary Card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Today's Revenue")
                                .font(.headline)
                            Spacer()
                            if isLoadingSummary {
                                ProgressView()
                            }
                        }

                        VStack(spacing: 8) {
                            Text(dailySummary.totalRevenue.formatted(as: appState.settings.currency))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.accent)

                            Text("\(dailySummary.transactionCount) transaction\(dailySummary.transactionCount == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // New Sale Button
                    Button {
                        showNewSale = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("New Sale")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                    }

                    // Quick Info
                    HStack(spacing: 16) {
                        InfoCard(
                            icon: "percent",
                            title: "Tax Rate",
                            value: appState.settings.taxRate.asPercentage
                        )

                        InfoCard(
                            icon: "dollarsign.circle",
                            title: "Currency",
                            value: appState.settings.currency.rawValue
                        )
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Point of Sale")
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
                await loadDailySummary()
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

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accent)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
