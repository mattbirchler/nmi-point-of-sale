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
    @State private var isAmountExpanded = true
    @State private var receiptAppeared = false

    // Surcharge state
    @State private var cardFundingType: CardFundingType?
    @State private var isCheckingCardType = false

    private var amount: Double {
        Double(amountString) ?? 0
    }

    // Surcharge applies only to credit cards when enabled
    private var surchargeApplies: Bool {
        appState.settings.surchargeEnabled &&
        appState.settings.surchargeRate > 0 &&
        cardFundingType == .credit
    }

    private var surchargeAmount: Double {
        guard surchargeApplies else { return 0 }
        return amount * (appState.settings.surchargeRate / 100)
    }

    // Taxable base = subtotal + surcharge
    private var taxableAmount: Double {
        amount + surchargeAmount
    }

    private var taxAmount: Double {
        taxableAmount * (appState.settings.taxRate / 100)
    }

    private var totalAmount: Double {
        amount + surchargeAmount + taxAmount
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
        cvv.isValidCVV
    }

    var body: some View {
        NavigationStack {
            if showResult {
                resultView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                formView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showResult)
    }

    // MARK: - Form View

    private var formView: some View {
        Form {
            // Amount Section
            Section {
                if isAmountExpanded || amount == 0 {
                    // Expanded view when focused or no amount entered
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

                        if surchargeApplies {
                            HStack {
                                Text("Surcharge (\(appState.settings.surchargeRate.asPercentage))")
                                Spacer()
                                Text(surchargeAmount.formatted(as: appState.settings.currency))
                            }
                            .foregroundStyle(.orange)
                        } else if appState.settings.surchargeEnabled && cardFundingType != nil && cardFundingType != .credit {
                            HStack {
                                Text("Surcharge")
                                Spacer()
                                Text("N/A (\(cardFundingType?.displayName ?? "Non-credit") card)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
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
                } else {
                    // Compact view when not focused and amount is set
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isAmountExpanded = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .amount
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(totalAmount.formatted(as: appState.settings.currency))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Amount")
            }
            .onChange(of: focusedField) { oldValue, newValue in
                // Collapse when focus moves away from amount field
                if oldValue == .amount && newValue != .amount && amount > 0 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isAmountExpanded = false
                    }
                }

                // Check card type when focus leaves card number field (for surcharging)
                if oldValue == .cardNumber && newValue != .cardNumber {
                    Task {
                        await checkCardType()
                    }
                }
            }

            // Card Section
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Card Number")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Show card type status when surcharging is enabled
                        if appState.settings.surchargeEnabled {
                            if isCheckingCardType {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Checking...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let fundingType = cardFundingType {
                                HStack(spacing: 4) {
                                    Image(systemName: fundingType.isCreditCard ? "creditcard.fill" : "creditcard")
                                        .font(.caption)
                                    Text(fundingType.displayName)
                                        .font(.caption)
                                }
                                .foregroundStyle(fundingType.isCreditCard ? .orange : .secondary)
                            }
                        }
                    }
                    TextField("4111 1111 1111 1111", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                        .focused($focusedField, equals: .cardNumber)
                        .onChange(of: cardNumber) { oldValue, newValue in
                            cardNumber = formatCardNumber(newValue)
                            // Reset card type when card number changes significantly
                            let oldDigits = oldValue.filter { $0.isNumber }
                            let newDigits = newValue.filter { $0.isNumber }
                            if oldDigits.prefix(6) != newDigits.prefix(6) {
                                cardFundingType = nil
                            }
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
        ZStack(alignment: .topTrailing) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    if let result = transactionResult {
                        if result.isSuccess {
                            successReceiptView(result)
                        } else {
                            declinedView(result)
                        }
                    }
                }
                .padding(.top, 60)
            }

            // Close button
            Button {
                onComplete()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 12)
            .opacity(receiptAppeared ? 1 : 0)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                receiptAppeared = true
            }
        }
        .onDisappear {
            receiptAppeared = false
        }
    }

    private func successReceiptView(_ result: NMITransactionResponse) -> some View {
        VStack(spacing: 24) {
            // Receipt icon with checkmark badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 70, height: 80)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)

                // Checkmark badge
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
                    .background(Circle().fill(Color(.systemGroupedBackground)).padding(-2))
                    .offset(x: 28, y: 28)
            }
            .scaleEffect(receiptAppeared ? 1 : 0.5)
            .opacity(receiptAppeared ? 1 : 0)

            // Title
            Text("Transaction Receipt")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .opacity(receiptAppeared ? 1 : 0)
                .offset(y: receiptAppeared ? 0 : 20)

            // Receipt card
            VStack(spacing: 0) {
                // Transaction details header
                HStack {
                    Text("Transaction details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Details rows
                VStack(spacing: 14) {
                    receiptDetailRow("Customer", value: "\(firstName) \(lastName)")
                    receiptDetailRow("Subtotal", value: amount.formatted(as: appState.settings.currency))

                    if surchargeAmount > 0 {
                        receiptDetailRow("Surcharge (\(appState.settings.surchargeRate.asPercentage))", value: surchargeAmount.formatted(as: appState.settings.currency))
                    }

                    if taxAmount > 0 {
                        receiptDetailRow("Tax", value: taxAmount.formatted(as: appState.settings.currency))
                    }

                    receiptDetailRow("Method", value: detectCardType(cardNumberDigits))
                    receiptDetailRow("Card", value: "•••• •••• •••• \(String(cardNumberDigits.suffix(4)))")
                    receiptDetailRow("Date", value: Date().formattedDateTime)
                    receiptDetailRow("Transaction ID", value: result.transactionId ?? "N/A")

                    if let authCode = result.authCode {
                        receiptDetailRow("Auth Code", value: authCode)
                    }
                }
                .padding(.horizontal, 20)

                // Divider
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                // Total row
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(totalAmount.formatted(as: appState.settings.currency))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .opacity(receiptAppeared ? 1 : 0)
            .offset(y: receiptAppeared ? 0 : 30)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    shareReceipt()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Share Receipt")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
                }

                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .opacity(receiptAppeared ? 1 : 0)
            .offset(y: receiptAppeared ? 0 : 40)
        }
    }

    private func declinedView(_ result: NMITransactionResponse) -> some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .scaleEffect(receiptAppeared ? 1 : 0.5)
                .opacity(receiptAppeared ? 1 : 0)

            Text("Payment Declined")
                .font(.title)
                .fontWeight(.bold)
                .opacity(receiptAppeared ? 1 : 0)
                .offset(y: receiptAppeared ? 0 : 20)

            Text(result.responseText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(receiptAppeared ? 1 : 0)
                .offset(y: receiptAppeared ? 0 : 20)

            Spacer()

            Button {
                showResult = false
                errorMessage = result.responseText
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .opacity(receiptAppeared ? 1 : 0)
            .offset(y: receiptAppeared ? 0 : 40)
        }
    }

    private func receiptDetailRow(_ label: String, value: String) -> some View {
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
            surcharge: surchargeAmount,
            surchargeRate: appState.settings.surchargeRate,
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

    // MARK: - Card Type Check

    private func checkCardType() async {
        // Only check if surcharging is enabled and we have enough digits
        guard appState.settings.surchargeEnabled,
              cardNumberDigits.count >= 6 else {
            cardFundingType = nil
            return
        }

        isCheckingCardType = true

        do {
            let fundingType = try await NMIService.shared.lookupCardType(cardNumber: cardNumberDigits)
            cardFundingType = fundingType
        } catch {
            // On error, assume unknown (no surcharge applied)
            cardFundingType = .unknown
        }

        isCheckingCardType = false
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

// MARK: - Receipt View (for sharing)

struct ReceiptView: View {
    let transactionId: String
    let authCode: String?
    let amount: Double
    let tax: Double
    let subtotal: Double
    let surcharge: Double
    let surchargeRate: Double
    let currency: Currency
    let cardType: String
    let lastFour: String
    let customerName: String
    let date: Date
    let merchantName: String

    var body: some View {
        VStack(spacing: 0) {
            // Header area
            VStack(spacing: 16) {
                // Receipt icon with checkmark badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 60, height: 70)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.green)

                    // Checkmark badge
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                        .background(Circle().fill(Color(.systemGray6)).padding(-2))
                        .offset(x: 24, y: 24)
                }

                Text("Transaction Receipt")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text(merchantName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Receipt card
            VStack(spacing: 0) {
                // Transaction details header
                HStack {
                    Text("Transaction details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Details rows
                VStack(spacing: 12) {
                    shareReceiptRow("Customer", value: customerName)
                    shareReceiptRow("Subtotal", value: subtotal.formatted(as: currency))

                    if surcharge > 0 {
                        shareReceiptRow("Surcharge (\(surchargeRate.asPercentage))", value: surcharge.formatted(as: currency))
                    }

                    if tax > 0 {
                        shareReceiptRow("Tax", value: tax.formatted(as: currency))
                    }

                    shareReceiptRow("Method", value: cardType)
                    shareReceiptRow("Card", value: "•••• •••• •••• \(lastFour)")
                    shareReceiptRow("Date", value: date.formattedDateTime)
                    shareReceiptRow("Transaction ID", value: transactionId)

                    if let authCode = authCode {
                        shareReceiptRow("Auth Code", value: authCode)
                    }
                }
                .padding(.horizontal, 20)

                // Divider
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                // Total row
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(amount.formatted(as: currency))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // Footer
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
        .frame(width: 380)
        .background(Color(.systemGray6))
    }

    private func shareReceiptRow(_ label: String, value: String) -> some View {
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
        subtotal: 112.00,
        surcharge: 3.00,
        surchargeRate: 2.68,
        currency: .usd,
        cardType: "Visa",
        lastFour: "4242",
        customerName: "John Doe",
        date: Date(),
        merchantName: "Coffee Shop"
    )
}
