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
    @State private var tipStrings: [String] = ["15", "20", "25"]

    private let totalSteps = 4

    private var taxRate: Double {
        Double(taxRateString) ?? 0
    }

    private var surchargeRate: Double {
        Double(surchargeRateString) ?? 0
    }

    private var tipPercentages: [Double] {
        tipStrings.compactMap { Double($0) }
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
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if tippingEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Tip Options")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { index in
                                OnboardingTipCard(
                                    percentage: tipStrings[index],
                                    color: tipCardColor(for: index),
                                    onUpdate: { newValue in
                                        tipStrings[index] = newValue
                                    }
                                )
                            }
                        }

                        Text("Customers can also enter a custom amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview on \(selectedCurrency.symbol)50.00")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 12) {
                            ForEach(Array(tipPercentages.enumerated()), id: \.offset) { index, percentage in
                                if percentage > 0 {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(tipCardColor(for: index))
                                            .frame(width: 8, height: 8)
                                        Text("\(selectedCurrency.symbol)\(String(format: "%.0f", 50 * percentage / 100))")
                                            .font(.subheadline)
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
            }
            .padding(.horizontal, 32)

            if !tippingEnabled {
                Text("You can enable this later in Settings")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
    }

    private func tipCardColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.35, green: 0.78, blue: 0.62)  // Mint green
        case 1: return Color(red: 0.40, green: 0.65, blue: 0.95)  // Sky blue
        case 2: return Color(red: 0.95, green: 0.60, blue: 0.40)  // Warm coral
        default: return .accentColor
        }
    }

    // MARK: - Actions

    private func completeSetup() {
        appState.completeOnboarding(
            currency: selectedCurrency,
            taxRate: taxRate,
            surchargeEnabled: surchargeEnabled,
            surchargeRate: surchargeRate,
            tippingEnabled: tippingEnabled,
            tipPercentages: tipPercentages
        )
    }
}

// MARK: - Onboarding Tip Card

struct OnboardingTipCard: View {
    let percentage: String
    let color: Color
    let onUpdate: (String) -> Void

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isEditing ? color.opacity(0.15) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isEditing ? color : Color.clear, lineWidth: 2)
                )

            VStack(spacing: 4) {
                if isEditing {
                    TextField("0", text: Binding(
                        get: { percentage },
                        set: { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count <= 3 {
                                onUpdate(filtered)
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue {
                            withAnimation { isEditing = false }
                        }
                    }
                } else {
                    Text(percentage.isEmpty ? "—" : percentage)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(percentage.isEmpty ? .tertiary : .primary)
                }

                Text("%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isEditing ? color : .secondary)
            }
        }
        .frame(height: 70)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isEditing = true
            }
        }
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
