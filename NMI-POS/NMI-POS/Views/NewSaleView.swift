import SwiftUI

struct NewSaleView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let onComplete: () -> Void

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

    private var amount: Double {
        Double(amountString) ?? 0
    }

    private var taxAmount: Double {
        amount * (appState.settings.taxRate / 100)
    }

    private var totalAmount: Double {
        amount + taxAmount
    }

    private var isFormValid: Bool {
        amount > 0 &&
        cardNumber.isValidCardNumber &&
        !expirationMonth.isEmpty &&
        !expirationYear.isEmpty &&
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
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exp Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("MM", text: $expirationMonth)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exp Year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("YY", text: $expirationYear)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("123", text: $cvv)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
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
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Doe", text: $lastName)
                            .textContentType(.familyName)
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
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("City")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("City", text: $city)
                            .textContentType(.addressCity)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("State")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("ST", text: $state)
                            .textContentType(.addressState)
                            .frame(width: 60)
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
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("US", text: $country)
                            .textContentType(.countryName)
                            .frame(width: 60)
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
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Actions

    private func processTransaction() async {
        isProcessing = true
        errorMessage = nil

        let saleRequest = SaleRequest(
            amount: amount,
            tax: taxAmount,
            cardNumber: cardNumber.filter { $0.isNumber },
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

#Preview {
    NewSaleView(onComplete: {})
        .environmentObject(AppState())
}
