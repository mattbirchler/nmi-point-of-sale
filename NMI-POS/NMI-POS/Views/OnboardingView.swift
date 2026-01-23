import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCurrency: Currency = .usd
    @State private var taxRateString = ""
    @State private var currentStep = 0

    // Surcharge settings
    @State private var surchargeEnabled = false
    @State private var surchargeRateString = ""

    // Tipping settings
    @State private var tippingEnabled = false

    // Biometric settings
    @State private var biometricEnabled = false

    private var totalSteps: Int {
        appState.canUseBiometrics ? 5 : 4
    }

    private var taxRate: Double {
        Double(taxRateString) ?? 0
    }

    private var surchargeRate: Double {
        Double(surchargeRateString) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.accentColor : Color(.systemGray4))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Content
                TabView(selection: $currentStep) {
                    // Step 1: Currency Selection
                    currencySelectionView
                        .tag(0)

                    // Step 2: Tax Rate
                    taxRateView
                        .tag(1)

                    // Step 3: Surcharging
                    surchargeView
                        .tag(2)

                    // Step 4: Tipping
                    tippingView
                        .tag(3)

                    // Step 5: Biometric (only if available)
                    if appState.canUseBiometrics {
                        biometricView
                            .tag(4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            Text("Back")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        if currentStep < totalSteps - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            completeSetup()
                        }
                    } label: {
                        Text(currentStep == totalSteps - 1 ? "Complete Setup" : "Next")
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
            .navigationBarHidden(true)
            .onTapGesture {
                hideKeyboard()
            }
        }
    }

    // MARK: - Currency Selection View

    private var currencySelectionView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("Select Your Currency")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose the default currency for your transactions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Currency Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Currency.allCases) { currency in
                    CurrencyCard(
                        currency: currency,
                        isSelected: selectedCurrency == currency
                    ) {
                        selectedCurrency = currency
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Tax Rate View

    private var taxRateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "percent")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("Set Your Tax Rate")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Enter your local sales tax rate to automatically calculate tax on transactions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Tax Rate Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Tax Rate (%)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("0.00", text: $taxRateString)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .multilineTextAlignment(.center)

                    Text("%")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text("Enter 0 if you don't charge sales tax")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            // Preview
            if taxRate > 0 {
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("On a \(selectedCurrency.symbol)100.00 sale:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(selectedCurrency.symbol)\(String(format: "%.2f", 100 * (1 + taxRate / 100))) total")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Surcharge View

    private var surchargeView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Credit Card Surcharging")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Add a fee to credit card transactions to offset processing costs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Toggle
            VStack(spacing: 16) {
                Toggle(isOn: $surchargeEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Surcharging")
                            .font(.headline)
                        Text("Applies only to credit cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if surchargeEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surcharge Rate")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            TextField("0.00", text: $surchargeRateString)
                                .keyboardType(.decimalPad)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .onChange(of: surchargeRateString) { _, newValue in
                                    if let rate = Double(newValue), rate > 3.0 {
                                        surchargeRateString = "3.00"
                                    }
                                }

                            Text("%")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        Text("Maximum allowed is 3%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Preview
                    if surchargeRate > 0 {
                        HStack {
                            Text("On a \(selectedCurrency.symbol)100.00 credit card sale:")
                                .font(.subheadline)
                            Spacer()
                            Text("+\(selectedCurrency.symbol)\(String(format: "%.2f", surchargeRate))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 32)

            if !surchargeEnabled {
                Text("You can enable this later in Settings")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Tipping View

    private var tippingView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))

                Text("Customer Tipping")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Let customers add a tip during checkout")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Toggle
            VStack(spacing: 16) {
                Toggle(isOn: $tippingEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Tipping")
                            .font(.headline)
                        Text("Shows tip options before payment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color(red: 0.35, green: 0.78, blue: 0.62))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if tippingEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))
                        Text("Customers will see 15%, 20%, and 25% tip options")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.35, green: 0.78, blue: 0.62).opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)

            Text("You can customize tip amounts later in Settings")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Biometric View

    private var biometricView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: appState.biometricIconName)
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Secure Your App")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Use \(appState.biometricDisplayName) to quickly and securely unlock iProcess")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Toggle
            VStack(spacing: 16) {
                Toggle(isOn: $biometricEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable \(appState.biometricDisplayName)")
                            .font(.headline)
                        Text("Require authentication when opening the app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.blue)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if biometricEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.blue)
                        Text("Your payment data will be protected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)

            Text("You can change this later in Settings")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func completeSetup() {
        appState.completeOnboarding(
            currency: selectedCurrency,
            taxRate: taxRate,
            surchargeEnabled: surchargeEnabled,
            surchargeRate: surchargeRate,
            tippingEnabled: tippingEnabled,
            tipPercentages: [15, 20, 25],
            biometricEnabled: biometricEnabled
        )
    }
}

struct CurrencyCard: View {
    let currency: Currency
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(currency.symbol)
                    .font(.title)
                    .fontWeight(.bold)

                Text(currency.rawValue)
                    .font(.headline)

                Text(currency.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
