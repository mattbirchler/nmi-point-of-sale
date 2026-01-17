import SwiftUI

enum SaleFormField: Hashable {
    case amount
    case cardNumber
    case expirationMonth
    case expirationYear
    case cvv
    case firstName
    case lastName
    case email
    case address
    case city
    case state
    case postalCode
    case country
}

struct NewSaleView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let onComplete: () -> Void

    // Focus state
    @FocusState private var focusedField: SaleFormField?

    // Amount
    @State private var amountString = ""

    // Card Info
    @State private var cardNumber = ""
    @State private var expirationMonth = ""
    @State private var expirationYear = ""
    @State private var cvv = ""

    // Customer Info
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postalCode = ""
    @State private var country = "US"

    // State
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var transactionResult: NMITransactionResponse?
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    private var amount: Double {
        Double(amountString) ?? 0
    }

    private var taxAmount: Double {
        amount * (appState.settings.taxRate / 100)
    }

    private var totalAmount: Double {
        amount + taxAmount
    }

    // Card number without spaces for validation
    private var cardNumberDigits: String {
        cardNumber.filter { $0.isNumber }
    }

    private var isFormValid: Bool {
        amount > 0 &&
        cardNumberDigits.isValidCardNumber &&
        expirationMonth.count == 2 &&
        expirationYear.count == 2 &&
        cvv.isValidCVV &&
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        email.isValidEmail
    }

    var body: some View {
        NavigationStack {
            if showResult {
                resultView
            } else {
                formView
            }
        }
    }

    // MARK: - Form View

    private var formView: some View {
        Form {
            // Amount Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sale Amount")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(appState.settings.currency.symbol)
                            .font(.title)
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .focused($focusedField, equals: .amount)
                    }
                }
                .padding(.vertical, 8)

                if amount > 0 {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(amount.formatted(as: appState.settings.currency))
                    }

                    if appState.settings.taxRate > 0 {
                        HStack {
                            Text("Tax (\(appState.settings.taxRate.asPercentage))")
                            Spacer()
                            Text(taxAmount.formatted(as: appState.settings.currency))
                        }
                    }

                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(totalAmount.formatted(as: appState.settings.currency))
                            .fontWeight(.semibold)
                            .foregroundStyle(.accent)
                    }
                }
            } header: {
                Text("Amount")
            }

            // Card Section
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card Number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("4111 1111 1111 1111", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                        .focused($focusedField, equals: .cardNumber)
                        .onChange(of: cardNumber) { oldValue, newValue in
                            cardNumber = formatCardNumber(newValue)
                        }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exp Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("MM", text: $expirationMonth)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .focused($focusedField, equals: .expirationMonth)
                            .onChange(of: expirationMonth) { oldValue, newValue in
                                // Only allow digits
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count <= 2 {
                                    expirationMonth = filtered
                                } else {
                                    expirationMonth = String(filtered.prefix(2))
                                }
                                // Auto-advance to year when 2 digits entered
                                if expirationMonth.count == 2 {
                                    focusedField = .expirationYear
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exp Year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("YY", text: $expirationYear)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .focused($focusedField, equals: .expirationYear)
                            .onChange(of: expirationYear) { oldValue, newValue in
                                // Only allow digits
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count <= 2 {
                                    expirationYear = filtered
                                } else {
                                    expirationYear = String(filtered.prefix(2))
                                }
                                // Auto-advance to CVV when 2 digits entered
                                if expirationYear.count == 2 {
                                    focusedField = .cvv
                                }
                            }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("123", text: $cvv)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .focused($focusedField, equals: .cvv)
                            .onChange(of: cvv) { oldValue, newValue in
                                // Only allow digits, max 4
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count <= 4 {
                                    cvv = filtered
                                } else {
                                    cvv = String(filtered.prefix(4))
                                }
                            }
                    }
                }
            } header: {
                Text("Card Information")
            }

            // Customer Section
            Section {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("John", text: $firstName)
                            .textContentType(.givenName)
                            .focused($focusedField, equals: .firstName)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Doe", text: $lastName)
                            .textContentType(.familyName)
                            .focused($focusedField, equals: .lastName)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("john@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                }
            } header: {
                Text("Customer Information")
            }

            // Address Section
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Street Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("123 Main St", text: $address)
                        .textContentType(.streetAddressLine1)
                        .focused($focusedField, equals: .address)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("City")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("City", text: $city)
                            .textContentType(.addressCity)
                            .focused($focusedField, equals: .city)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("State")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("ST", text: $state)
                            .textContentType(.addressState)
                            .frame(width: 60)
                            .focused($focusedField, equals: .state)
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Postal Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("12345", text: $postalCode)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                            .focused($focusedField, equals: .postalCode)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("US", text: $country)
                            .textContentType(.countryName)
                            .frame(width: 60)
                            .focused($focusedField, equals: .country)
                    }
                }
            } header: {
                Text("Billing Address")
            }

            // Error Message
            if let error = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Process Button
            Section {
                Button {
                    Task {
                        await processTransaction()
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "creditcard")
                            Text("Process \(totalAmount.formatted(as: appState.settings.currency))")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(!isFormValid || isProcessing)
                .listRowBackground(isFormValid && !isProcessing ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
            }
        }
        .navigationTitle("New Sale")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            // Focus the amount field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .amount
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let result = transactionResult {
                if result.isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)

                    Text("Payment Approved")
                        .font(.title)
                        .fontWeight(.bold)

                    VStack(spacing: 8) {
                        Text("Transaction ID")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(result.transactionId ?? "N/A")
                            .font(.headline)
                            .monospaced()
                    }

                    if let authCode = result.authCode {
                        VStack(spacing: 8) {
                            Text("Auth Code")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(authCode)
                                .font(.headline)
                                .monospaced()
                        }
                    }

                    VStack(spacing: 4) {
                        Text("Amount Charged")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(totalAmount.formatted(as: appState.settings.currency))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.accent)
                    }
                    .padding(.top)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)

                    Text("Payment Declined")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(result.responseText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if transactionResult?.isSuccess == true {
                    Button {
                        shareReceipt()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Receipt")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                    }
                }

                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Card Number Formatting

    private func formatCardNumber(_ input: String) -> String {
        // Remove all non-digits
        let digits = input.filter { $0.isNumber }

        // Limit to 19 digits (longest card numbers)
        let limited = String(digits.prefix(19))

        // Add space every 4 digits
        var formatted = ""
        for (index, char) in limited.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(char)
        }

        return formatted
    }

    // MARK: - Share Receipt

    private func shareReceipt() {
        guard let result = transactionResult else { return }

        let receiptView = ReceiptView(
            transactionId: result.transactionId ?? "N/A",
            authCode: result.authCode,
            amount: totalAmount,
            tax: taxAmount,
            subtotal: amount,
            currency: appState.settings.currency,
            cardType: detectCardType(cardNumberDigits),
            lastFour: String(cardNumberDigits.suffix(4)),
            customerName: "\(firstName) \(lastName)",
            date: Date(),
            merchantName: appState.merchantProfile?.displayName ?? "Merchant"
        )

        let renderer = ImageRenderer(content: receiptView)
        renderer.scale = 3.0 // High quality

        if let uiImage = renderer.uiImage {
            let activityVC = UIActivityViewController(
                activityItems: [uiImage],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(activityVC, animated: true)
            }
        }
    }

    private func detectCardType(_ number: String) -> String {
        if number.hasPrefix("4") {
            return "Visa"
        } else if number.hasPrefix("5") || number.hasPrefix("2") {
            return "Mastercard"
        } else if number.hasPrefix("3") {
            return "Amex"
        } else if number.hasPrefix("6") {
            return "Discover"
        }
        return "Card"
    }

    // MARK: - Actions

    private func processTransaction() async {
        isProcessing = true
        errorMessage = nil

        let saleRequest = SaleRequest(
            amount: amount,
            tax: taxAmount,
            cardNumber: cardNumberDigits,
            expirationMonth: expirationMonth,
            expirationYear: expirationYear,
            cvv: cvv,
            firstName: firstName,
            lastName: lastName,
            address1: address,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country,
            email: email
        )

        do {
            let result = try await NMIService.shared.processSale(
                securityKey: appState.securityKey,
                sale: saleRequest
            )

            transactionResult = result
            showResult = true
        } catch let error as NMIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Transaction failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }
}

// MARK: - Receipt View

struct ReceiptView: View {
    let transactionId: String
    let authCode: String?
    let amount: Double
    let tax: Double
    let subtotal: Double
    let currency: Currency
    let cardType: String
    let lastFour: String
    let customerName: String
    let date: Date
    let merchantName: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)

                Text("Payment Successful")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(merchantName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)

            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Amount
            VStack(spacing: 8) {
                Text("Amount")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(amount.formatted(as: currency))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 24)

            // Details
            VStack(spacing: 16) {
                if subtotal != amount {
                    receiptRow("Subtotal", value: subtotal.formatted(as: currency))
                    receiptRow("Tax", value: tax.formatted(as: currency))
                }

                receiptRow("Payment Method", value: "\(cardType) ••••\(lastFour)")
                receiptRow("Customer", value: customerName)
                receiptRow("Date", value: date.formattedDateTime)
                receiptRow("Transaction ID", value: transactionId)

                if let authCode = authCode {
                    receiptRow("Auth Code", value: authCode)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Footer
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Text("Thank you for your payment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Powered by iProcess")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 24)
        }
        .frame(width: 350)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(24)
        .background(Color(.systemGray6))
    }

    private func receiptRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NewSaleView(onComplete: {})
        .environmentObject(AppState())
}

#Preview("Receipt") {
    ReceiptView(
        transactionId: "1234567890",
        authCode: "ABC123",
        amount: 125.50,
        tax: 10.50,
        subtotal: 115.00,
        currency: .usd,
        cardType: "Visa",
        lastFour: "4242",
        customerName: "John Doe",
        date: Date(),
        merchantName: "Coffee Shop"
    )
}
