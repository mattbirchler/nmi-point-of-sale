import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack {
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
                    transactionListView
                }
            }
            .navigationTitle("Transaction History")
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

                Text("\(String(transaction.transactionId.prefix(12)))...")
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
