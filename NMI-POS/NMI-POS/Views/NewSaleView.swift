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
    @State private var showTipSelection = false
    @State private var showHandoff = false
    @State private var showTipConfirmation = false
    @State private var transactionResult: NMITransactionResponse?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var isAmountExpanded = true
    @State private var receiptAppeared = false

    // Surcharge state
    @State private var cardFundingType: CardFundingType?
    @State private var isCheckingCardType = false

    // Tip state
    @State private var tipAmount: Double = 0

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

    // Taxable base = subtotal + surcharge (tip is typically not taxed)
    private var taxableAmount: Double {
        amount + surchargeAmount
    }

    private var taxAmount: Double {
        taxableAmount * (appState.settings.taxRate / 100)
    }

    // Total before tip (shown on form)
    private var subtotalBeforeTip: Double {
        amount + surchargeAmount + taxAmount
    }

    // Final total including tip
    private var totalAmount: Double {
        subtotalBeforeTip + tipAmount
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
            } else if showTipConfirmation {
                tipConfirmationView
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if showHandoff {
                handoffView
                    .transition(.opacity)
            } else if showTipSelection {
                tipSelectionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                formView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showResult)
        .animation(.easeInOut(duration: 0.4), value: showTipSelection)
        .animation(.easeInOut(duration: 0.5), value: showHandoff)
        .animation(.easeInOut(duration: 0.5), value: showTipConfirmation)
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
                            Text(subtotalBeforeTip.formatted(as: appState.settings.currency))
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
                    TextField("", text: $email)
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
                    if appState.settings.tippingEnabled {
                        // Show tip selection for customer
                        withAnimation {
                            showTipSelection = true
                        }
                    } else {
                        // Process directly
                        Task {
                            await processTransaction()
                        }
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: appState.settings.tippingEnabled ? "arrow.right" : "creditcard")
                            Text(appState.settings.tippingEnabled ? "Continue" : "Process \(subtotalBeforeTip.formatted(as: appState.settings.currency))")
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

                    if tipAmount > 0 {
                        receiptDetailRow("Tip", value: tipAmount.formatted(as: appState.settings.currency))
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

    // MARK: - Tip Selection View

    private var tipSelectionView: some View {
        TipSelectionView(
            subtotal: amount,
            taxAmount: taxAmount,
            surchargeAmount: surchargeAmount,
            surchargeRate: appState.settings.surchargeRate,
            currency: appState.settings.currency,
            tipPercentages: appState.settings.tipPercentages,
            customerName: firstName.isEmpty ? nil : firstName,
            onConfirmTip: { selectedTip in
                tipAmount = selectedTip
                withAnimation {
                    showTipSelection = false
                    showHandoff = true
                }
            },
            onBack: {
                withAnimation {
                    showTipSelection = false
                }
            }
        )
    }

    // MARK: - Handoff View

    private var handoffView: some View {
        HandoffView(
            tipAmount: tipAmount,
            currency: appState.settings.currency,
            onComplete: {
                withAnimation {
                    showHandoff = false
                    showTipConfirmation = true
                }
            }
        )
    }

    // MARK: - Tip Confirmation View (Merchant-Facing)

    private var tipConfirmationView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation {
                        showTipConfirmation = false
                        showTipSelection = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.body)
                    .foregroundStyle(.accent)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding()

            Spacer()

            // Content
            VStack(spacing: 24) {
                // Success indicator
                ZStack {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.78, blue: 0.62).opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))
                }

                VStack(spacing: 8) {
                    Text("Tip Confirmed")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Ready to process payment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Summary card
                VStack(spacing: 0) {
                    summaryRow("Subtotal", value: amount.formatted(as: appState.settings.currency))

                    if surchargeAmount > 0 {
                        summaryRow("Surcharge (\(appState.settings.surchargeRate.asPercentage))", value: surchargeAmount.formatted(as: appState.settings.currency), color: .orange)
                    }

                    if taxAmount > 0 {
                        summaryRow("Tax (\(appState.settings.taxRate.asPercentage))", value: taxAmount.formatted(as: appState.settings.currency))
                    }

                    if tipAmount > 0 {
                        summaryRow("Tip", value: tipAmount.formatted(as: appState.settings.currency), color: Color(red: 0.35, green: 0.78, blue: 0.62))
                    }

                    Divider()
                        .padding(.vertical, 12)

                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(totalAmount.formatted(as: appState.settings.currency))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }

            Spacer()

            // Process button
            VStack(spacing: 12) {
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
                            Image(systemName: "creditcard.fill")
                            Text("Process \(totalAmount.formatted(as: appState.settings.currency))")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .cornerRadius(14)
                }
                .disabled(isProcessing)

                if tipAmount > 0 {
                    Button {
                        withAnimation {
                            showTipConfirmation = false
                            showTipSelection = true
                        }
                    } label: {
                        Text("Change tip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
    }

    private func summaryRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.vertical, 6)
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
            tip: tipAmount,
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
            tip: tipAmount,
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
    let tip: Double
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

                    if tip > 0 {
                        shareReceiptRow("Tip", value: tip.formatted(as: currency))
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

// MARK: - Handoff View

struct HandoffView: View {
    let tipAmount: Double
    let currency: Currency
    let onComplete: () -> Void

    @State private var appeared = false
    @State private var showCheckmark = false
    @State private var showText = false
    @State private var pulsePhone = false

    var body: some View {
        ZStack {
            // Background gradient (same as tip selection for continuity)
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.18),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Checkmark that appears first
                ZStack {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.78, blue: 0.62).opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))
                        .scaleEffect(showCheckmark ? 1 : 0)
                        .opacity(showCheckmark ? 1 : 0)
                }

                // Tip confirmed message
                VStack(spacing: 8) {
                    if tipAmount > 0 {
                        Text("\(tipAmount.formatted(as: currency)) tip added")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))
                    } else {
                        Text("No tip")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Text("Thank you!")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(showCheckmark ? 1 : 0)
                .offset(y: showCheckmark ? 0 : 20)

                Spacer()

                // Phone handoff illustration and message
                VStack(spacing: 24) {
                    // Phone icon with hand
                    ZStack {
                        // Pulsing ring
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulsePhone ? 1.3 : 1)
                            .opacity(pulsePhone ? 0 : 0.5)

                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.9))
                            .offset(x: pulsePhone ? -3 : 3)
                    }

                    VStack(spacing: 8) {
                        Text("Please hand the device")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("back to the seller")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 30)

                Spacer()
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Sequence the animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showCheckmark = true
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                showText = true
            }

            // Start phone pulse animation
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.5)) {
                pulsePhone = true
            }

            // Auto-advance after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onComplete()
            }
        }
    }
}

// MARK: - Tip Selection View (Customer-Facing)

struct TipSelectionView: View {
    let subtotal: Double
    let taxAmount: Double
    let surchargeAmount: Double
    let surchargeRate: Double
    let currency: Currency
    let tipPercentages: [Double]
    let customerName: String?
    let onConfirmTip: (Double) -> Void
    let onBack: () -> Void

    @State private var selectedTipIndex: Int? = nil
    @State private var customTipString = ""
    @State private var showCustomTip = false
    @State private var appeared = false
    @FocusState private var customTipFocused: Bool

    private var totalBeforeTip: Double {
        subtotal + taxAmount + surchargeAmount
    }

    private var currentTipAmount: Double {
        if showCustomTip {
            return Double(customTipString) ?? 0
        } else if let index = selectedTipIndex,
                  index < tipPercentages.count {
            return subtotal * (tipPercentages[index] / 100)
        }
        return 0
    }

    private var totalWithTip: Double {
        totalBeforeTip + currentTipAmount
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.18),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // Main content
                VStack(spacing: 32) {
                    // Greeting
                    VStack(spacing: 8) {
                        if let name = customerName {
                            Text("Thank you, \(name)!")
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Text("Add a tip?")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                    // Amount display
                    VStack(spacing: 4) {
                        Text("Total")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))

                        Text(totalWithTip.formatted(as: currency))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: currentTipAmount)

                        if currentTipAmount > 0 {
                            Text("includes \(currentTipAmount.formatted(as: currency)) tip")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                    // Tip options
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ForEach(Array(tipPercentages.enumerated()), id: \.offset) { index, percentage in
                                if percentage > 0 {
                                    CustomerTipButton(
                                        percentage: percentage,
                                        tipAmount: subtotal * (percentage / 100),
                                        currency: currency,
                                        isSelected: selectedTipIndex == index && !showCustomTip,
                                        color: tipButtonColor(for: index)
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedTipIndex == index && !showCustomTip {
                                                selectedTipIndex = nil
                                            } else {
                                                selectedTipIndex = index
                                                showCustomTip = false
                                                customTipFocused = false
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Custom tip row
                        HStack(spacing: 12) {
                            // Custom tip button
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showCustomTip.toggle()
                                    if showCustomTip {
                                        selectedTipIndex = nil
                                        customTipFocused = true
                                    } else {
                                        customTipFocused = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16, weight: .semibold))

                                    if showCustomTip {
                                        HStack(spacing: 4) {
                                            Text(currency.symbol)
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            TextField("0", text: $customTipString)
                                                .keyboardType(.decimalPad)
                                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                                .frame(width: 80)
                                                .focused($customTipFocused)
                                        }
                                    } else {
                                        Text("Custom")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                }
                                .foregroundStyle(showCustomTip ? .white : .white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(showCustomTip
                                            ? Color(red: 0.6, green: 0.5, blue: 0.8)
                                            : Color.white.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            showCustomTip
                                                ? Color.clear
                                                : Color.white.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                }

                Spacer()

                // Bottom buttons
                VStack(spacing: 12) {
                    // Confirm button
                    Button {
                        onConfirmTip(currentTipAmount)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text(currentTipAmount > 0 ? "Confirm \(currentTipAmount.formatted(as: currency)) tip" : "No tip")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(currentTipAmount > 0 ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(currentTipAmount > 0
                                    ? Color(red: 0.35, green: 0.78, blue: 0.62)
                                    : Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)

                    // Clear tip button (only show if tip selected)
                    if currentTipAmount > 0 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTipIndex = nil
                                showCustomTip = false
                                customTipString = ""
                            }
                        } label: {
                            Text("Clear tip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    private func tipButtonColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.35, green: 0.78, blue: 0.62)  // Mint green
        case 1: return Color(red: 0.40, green: 0.65, blue: 0.95)  // Sky blue
        case 2: return Color(red: 0.95, green: 0.60, blue: 0.40)  // Warm coral
        default: return Color(red: 0.6, green: 0.5, blue: 0.8)    // Purple
        }
    }
}

// MARK: - Customer Tip Button

struct CustomerTipButton: View {
    let percentage: Double
    let tipAmount: Double
    let currency: Currency
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("\(Int(percentage))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(tipAmount.formatted(as: currency))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .opacity(isSelected ? 0.9 : 0.6)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
        subtotal: 100.00,
        surcharge: 3.00,
        surchargeRate: 2.68,
        tip: 12.00,
        currency: .usd,
        cardType: "Visa",
        lastFour: "4242",
        customerName: "John Doe",
        date: Date(),
        merchantName: "Coffee Shop"
    )
}

#Preview("Tip Selection") {
    TipSelectionView(
        subtotal: 45.00,
        taxAmount: 3.85,
        surchargeAmount: 0,
        surchargeRate: 0,
        currency: .usd,
        tipPercentages: [15, 20, 25],
        customerName: "Sarah",
        onConfirmTip: { _ in },
        onBack: { }
    )
}

#Preview("Handoff") {
    HandoffView(
        tipAmount: 9.00,
        currency: .usd,
        onComplete: { }
    )
}
