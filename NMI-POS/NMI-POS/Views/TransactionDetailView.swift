import SwiftUI

struct TransactionDetailView: View {
    @EnvironmentObject var appState: AppState
    let transactionId: String

    @State private var detail: TransactionDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isVoiding = false
    @State private var showVoidConfirmation = false
    @State private var voidError: String?
    @State private var showVoidError = false
    @State private var voidSuccessful = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let detail = detail {
                detailContentView(detail)
            } else {
                loadingView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading transaction...")
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

            Text("Unable to Load Transaction")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await loadDetail()
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

    // MARK: - Detail Content View

    private func detailContentView(_ detail: TransactionDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Colored header section
                headerSection(detail)

                // Info cards
                VStack(spacing: 16) {
                    transactionInfoCard(detail)
                    paymentInfoCard(detail)

                    if detail.hasBillingAddress || !detail.fullName.isEmpty {
                        customerInfoCard(detail)
                    }

                    if !detail.actions.isEmpty {
                        activityCard(detail)
                    }

                    if canVoidTransaction(detail) {
                        actionsCard(detail)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .confirmationDialog(
            "Void Transaction",
            isPresented: $showVoidConfirmation,
            titleVisibility: .visible
        ) {
            Button("Void Transaction", role: .destructive) {
                Task {
                    await voidTransaction()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will cancel the transaction and release the hold on the customer's card. This cannot be undone.")
        }
        .alert("Void Failed", isPresented: $showVoidError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(voidError ?? "An unknown error occurred")
        }
        .alert("Transaction Voided", isPresented: $voidSuccessful) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The transaction has been successfully voided.")
        }
    }

    // MARK: - Header Section

    private func headerSection(_ detail: TransactionDetail) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            // Large icon with payment badge
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)

                Image(systemName: headerIconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(headerIconColor)

                // Payment method badge
                cardBadge(detail.ccType)
                    .offset(x: 28, y: 28)
            }

            // Payment method text
            HStack(spacing: 4) {
                Text("Paid via")
                    .foregroundColor(.secondary)
                Text(detail.ccType.isEmpty ? "Card" : detail.ccType)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            // Large amount
            Text(detail.amount.formatted(as: appState.settings.currency))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Status pill
            statusPill(detail.status)

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [headerColor(for: detail.status), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func cardBadge(_ cardType: String) -> some View {
        Circle()
            .fill(cardBadgeColor(cardType))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            )
    }

    private func statusPill(_ status: TransactionStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Transaction Info Card

    private func transactionInfoCard(_ detail: TransactionDetail) -> some View {
        VStack(spacing: 0) {
            infoRow(label: "Date", value: detail.transactionDate?.formattedDateTime ?? "—")
            Divider().padding(.leading, 16)
            infoRow(label: "Transaction ID", value: detail.transactionId)
            Divider().padding(.leading, 16)
            infoRow(label: "Status", value: detail.condition.capitalized, valueColor: statusColor(for: detail.status))

            if !detail.authorizationCode.isEmpty {
                Divider().padding(.leading, 16)
                infoRow(label: "Auth Code", value: detail.authorizationCode)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Payment Info Card

    private func paymentInfoCard(_ detail: TransactionDetail) -> some View {
        VStack(spacing: 0) {
            if !detail.ccNumber.isEmpty {
                infoRow(label: "Card Number", value: detail.ccNumber)
                Divider().padding(.leading, 16)
            }

            if !detail.ccExp.isEmpty {
                infoRow(label: "Expiration", value: formatExpiration(detail.ccExp))
                Divider().padding(.leading, 16)
            }

            if detail.tax > 0 {
                infoRow(label: "Tax", value: detail.tax.formatted(as: appState.settings.currency))
                Divider().padding(.leading, 16)
            }

            if detail.tip > 0 {
                infoRow(label: "Tip", value: detail.tip.formatted(as: appState.settings.currency))
                Divider().padding(.leading, 16)
            }

            if detail.surcharge > 0 {
                infoRow(label: "Surcharge", value: detail.surcharge.formatted(as: appState.settings.currency))
                Divider().padding(.leading, 16)
            }

            infoRow(label: "AVS Response", value: avsDescription(detail.avsResponse))

            if !detail.cscResponse.isEmpty {
                Divider().padding(.leading, 16)
                infoRow(label: "CVV Response", value: cscDescription(detail.cscResponse))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Customer Info Card

    private func customerInfoCard(_ detail: TransactionDetail) -> some View {
        VStack(spacing: 0) {
            if !detail.fullName.isEmpty {
                infoRow(label: "Customer", value: detail.fullName)
            }

            if !detail.company.isEmpty {
                Divider().padding(.leading, 16)
                infoRow(label: "Company", value: detail.company)
            }

            if !detail.email.isEmpty {
                Divider().padding(.leading, 16)
                infoRow(label: "Email", value: detail.email)
            }

            if !detail.phone.isEmpty {
                Divider().padding(.leading, 16)
                infoRow(label: "Phone", value: detail.phone)
            }

            if detail.hasBillingAddress {
                Divider().padding(.leading, 16)
                infoRow(label: "Address", value: formatAddress(detail))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Activity Card

    private func activityCard(_ detail: TransactionDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ForEach(Array(detail.actions.enumerated()), id: \.offset) { index, action in
                HStack(spacing: 12) {
                    // Timeline indicator
                    VStack(spacing: 0) {
                        Circle()
                            .fill(action.success ? Color.green : Color.red)
                            .frame(width: 10, height: 10)

                        if index < detail.actions.count - 1 {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(action.displayActionType)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(action.amount.formatted(as: appState.settings.currency))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text(action.date.formattedDateTime)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !action.responseText.isEmpty {
                            Text(action.responseText)
                                .font(.caption)
                                .foregroundColor(action.success ? .secondary : .red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Spacer().frame(height: 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Actions Card

    private func actionsCard(_ detail: TransactionDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Button {
                showVoidConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Void Transaction")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Cancel this transaction before settlement")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isVoiding {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .disabled(isVoiding)

            Spacer().frame(height: 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func canVoidTransaction(_ detail: TransactionDetail) -> Bool {
        let condition = detail.condition.lowercased()
        // Can only void transactions that haven't settled yet
        return condition == "pendingsettlement" || condition == "pending_settlement" || condition == "pending"
    }

    private func voidTransaction() async {
        guard let detail = detail else { return }

        isVoiding = true

        do {
            let response = try await NMIService.shared.voidTransaction(
                securityKey: appState.securityKey,
                transactionId: detail.transactionId
            )

            if response.isSuccess {
                voidSuccessful = true
                // Reload the transaction detail to show updated status
                await loadDetail()
            } else {
                voidError = response.responseText
                showVoidError = true
            }
        } catch let error as NMIError {
            voidError = error.localizedDescription
            showVoidError = true
        } catch {
            voidError = error.localizedDescription
            showVoidError = true
        }

        isVoiding = false
    }

    // MARK: - Info Row

    private func infoRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var headerIconName: String {
        "person.fill"
    }

    private var headerIconColor: Color {
        .primary
    }

    private func statusColor(for status: TransactionStatus) -> Color {
        switch status {
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

    private func headerColor(for status: TransactionStatus) -> Color {
        switch status {
        case .approved:
            return Color.green.opacity(0.15)
        case .declined, .error:
            return Color.red.opacity(0.12)
        case .pending:
            return Color.orange.opacity(0.15)
        case .voided, .refunded:
            return Color.blue.opacity(0.12)
        }
    }

    private func cardBadgeColor(_ cardType: String) -> Color {
        switch cardType.lowercased() {
        case "visa":
            return .blue
        case "mastercard":
            return .orange
        case "amex", "american express":
            return .indigo
        case "discover":
            return .orange
        default:
            return .gray
        }
    }

    private func formatExpiration(_ exp: String) -> String {
        if exp.count == 4 {
            let month = String(exp.prefix(2))
            let year = String(exp.suffix(2))
            return "\(month)/\(year)"
        }
        return exp
    }

    private func formatAddress(_ detail: TransactionDetail) -> String {
        var parts: [String] = []
        if !detail.address1.isEmpty { parts.append(detail.address1) }
        if !detail.city.isEmpty || !detail.state.isEmpty {
            let cityState = [detail.city, detail.state].filter { !$0.isEmpty }.joined(separator: ", ")
            if !cityState.isEmpty { parts.append(cityState) }
        }
        if !detail.postalCode.isEmpty { parts.append(detail.postalCode) }
        return parts.joined(separator: "\n")
    }

    private func avsDescription(_ code: String) -> String {
        if code.isEmpty { return "—" }
        switch code.uppercased() {
        case "Y", "X", "D", "F", "M":
            return "Match"
        case "A":
            return "Address Match"
        case "Z", "P", "W":
            return "ZIP Match"
        case "N":
            return "No Match"
        case "U", "S", "R", "E", "G":
            return "Unavailable"
        default:
            return code
        }
    }

    private func cscDescription(_ code: String) -> String {
        switch code.uppercased() {
        case "M":
            return "Match"
        case "N":
            return "No Match"
        case "P", "S", "U":
            return "Not Processed"
        default:
            return code
        }
    }

    // MARK: - Data Loading

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            detail = try await NMIService.shared.getTransactionDetail(
                securityKey: appState.securityKey,
                transactionId: transactionId
            )
        } catch let error as NMIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        TransactionDetailView(transactionId: "12345678")
            .environmentObject(AppState())
    }
}
