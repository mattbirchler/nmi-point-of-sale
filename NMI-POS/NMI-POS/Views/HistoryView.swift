import SwiftUI
import Charts

enum HistoryViewMode: String, CaseIterable {
    case list = "List"
    case insights = "Insights"
}

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false
    @State private var viewMode: HistoryViewMode = .list

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode toggle
                if !transactions.isEmpty || hasLoadedOnce {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                // Content
                Group {
                    if isLoading && !hasLoadedOnce {
                        loadingView
                    } else if let error = errorMessage, transactions.isEmpty {
                        errorView(error)
                    } else if transactions.isEmpty && hasLoadedOnce {
                        emptyView
                    } else if transactions.isEmpty {
                        loadingView
                    } else {
                        if viewMode == .list {
                            transactionListView
                        } else {
                            insightsView
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(HistoryDateRange.allCases) { range in
                            Button {
                                appState.settings.historyDateRange = range
                                Task {
                                    await loadTransactions()
                                }
                            } label: {
                                HStack {
                                    Text(range.displayName)
                                    if appState.settings.historyDateRange == range {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(appState.settings.historyDateRange.displayName)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .refreshable {
                await loadTransactions()
            }
            .task {
                if !hasLoadedOnce {
                    await loadTransactions()
                    hasLoadedOnce = true
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Unable to Load Transactions")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await loadTransactions()
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Transactions Found")
                .font(.headline)

            Text("No transactions in the \(appState.settings.historyDateRange.displayName.lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Transaction List View

    private var transactionListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(transactions) { transaction in
                    NavigationLink(value: transaction) {
                        TransactionRow(transaction: transaction, currency: appState.settings.currency)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Transaction.self) { transaction in
            TransactionDetailView(transactionId: transaction.transactionId)
        }
    }

    // MARK: - Insights View

    private var insightsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Stats
                summaryStatsView

                // Revenue Chart
                revenueChartView

                // Status Breakdown
                statusBreakdownView

                // Top Transactions
                topTransactionsView
            }
            .padding()
        }
        .navigationDestination(for: Transaction.self) { transaction in
            TransactionDetailView(transactionId: transaction.transactionId)
        }
    }

    // MARK: - Summary Stats

    private var summaryStatsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Total Revenue",
                    value: totalRevenue.formatted(as: appState.settings.currency),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )

                StatCard(
                    title: "Transactions",
                    value: "\(transactions.count)",
                    icon: "creditcard.fill",
                    color: .blue
                )
            }

            HStack(spacing: 12) {
                StatCard(
                    title: "Average",
                    value: averageTransaction.formatted(as: appState.settings.currency),
                    icon: "chart.bar.fill",
                    color: .purple
                )

                StatCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", successRate),
                    icon: "checkmark.circle.fill",
                    color: successRate >= 90 ? .green : (successRate >= 70 ? .orange : .red)
                )
            }
        }
    }

    // MARK: - Revenue Chart

    private var revenueChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue Over Time")
                .font(.headline)

            if dailyRevenue.isEmpty {
                Text("Not enough data to display chart")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(dailyRevenue) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Revenue", day.revenue)
                    )
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let revenue = value.as(Double.self) {
                                Text(formatAxisValue(revenue))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Status Breakdown

    private var statusBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction Status")
                .font(.headline)

            let breakdown = statusBreakdown

            if breakdown.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(breakdown, id: \.status) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: 180)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(breakdown, id: \.status) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.status)
                                .font(.caption)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Top Transactions

    private var topTransactionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Largest Transactions")
                .font(.headline)

            let topTxns = transactions
                .filter { $0.status.isSuccessful }
                .sorted { $0.total > $1.total }
                .prefix(5)

            if topTxns.isEmpty {
                Text("No successful transactions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(topTxns)) { transaction in
                    NavigationLink(value: transaction) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.customerName.isEmpty ? "Customer" : transaction.customerName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(transaction.date.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(transaction.total.formatted(as: appState.settings.currency))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if transaction.id != topTxns.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var totalRevenue: Double {
        transactions
            .filter { $0.status.isSuccessful }
            .reduce(0) { $0 + $1.total }
    }

    private var averageTransaction: Double {
        let successful = transactions.filter { $0.status.isSuccessful }
        guard !successful.isEmpty else { return 0 }
        return totalRevenue / Double(successful.count)
    }

    private var successRate: Double {
        guard !transactions.isEmpty else { return 0 }
        let successful = transactions.filter { $0.status.isSuccessful }.count
        return Double(successful) / Double(transactions.count) * 100
    }

    private var dailyRevenue: [DailyRevenueData] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions.filter { $0.status.isSuccessful }) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        return grouped.map { date, txns in
            DailyRevenueData(date: date, revenue: txns.reduce(0) { $0 + $1.total })
        }
        .sorted { $0.date < $1.date }
    }

    private var xAxisStride: Int {
        let dayCount = dailyRevenue.count
        if dayCount <= 7 { return 1 }
        if dayCount <= 14 { return 2 }
        if dayCount <= 30 { return 5 }
        if dayCount <= 90 { return 10 }
        return 30
    }

    private var statusBreakdown: [StatusBreakdownData] {
        let grouped = Dictionary(grouping: transactions) { $0.status }
        return grouped.map { status, txns in
            StatusBreakdownData(
                status: status.displayName,
                count: txns.count,
                color: colorForStatus(status)
            )
        }
        .sorted { $0.count > $1.count }
    }

    private func colorForStatus(_ status: TransactionStatus) -> Color {
        switch status {
        case .approved: return .green
        case .declined, .error: return .red
        case .pending: return .orange
        case .voided, .refunded: return .blue
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return "$\(Int(value / 1000))k"
        }
        return "$\(Int(value))"
    }

    // MARK: - Actions

    private func loadTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            let endDate = Date()
            let startDate = appState.settings.historyDateRange.startDate

            transactions = try await NMIService.shared.getTransactions(
                securityKey: appState.securityKey,
                startDate: startDate,
                endDate: endDate
            )
        } catch let error as NMIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Supporting Types

struct DailyRevenueData: Identifiable {
    let id = UUID()
    let date: Date
    let revenue: Double
}

struct StatusBreakdownData {
    let status: String
    let count: Int
    let color: Color
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction
    let currency: Currency

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Status Icon
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.customerName.isEmpty ? "Customer" : transaction.customerName)
                        .font(.headline)

                    HStack(spacing: 8) {
                        if !transaction.cardType.isEmpty {
                            Text(transaction.cardType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !transaction.lastFour.isEmpty {
                            Text("****\(transaction.lastFour)")
                                .font(.caption)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.total.formatted(as: currency))
                        .font(.headline)
                        .foregroundStyle(transaction.status.isSuccessful ? .primary : .secondary)

                    Text(transaction.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                }
            }

            HStack {
                Text(transaction.date.formattedDateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(transaction.transactionId)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title2)
            .foregroundStyle(statusColor)
            .frame(width: 40, height: 40)
            .background(statusColor.opacity(0.1))
            .cornerRadius(8)
    }

    private var statusIconName: String {
        switch transaction.status {
        case .approved:
            return "checkmark.circle.fill"
        case .declined:
            return "xmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .voided:
            return "arrow.uturn.backward.circle.fill"
        case .refunded:
            return "arrow.counterclockwise.circle.fill"
        }
    }

    private var statusColor: Color {
        switch transaction.status {
        case .approved:
            return .green
        case .declined, .error:
            return .red
        case .pending:
            return .orange
        case .voided, .refunded:
            return .blue
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
