import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var taxRateString = ""
    @State private var surchargeRateString = ""
    @State private var showSignOutAlert = false
    @State private var showSurchargeWarning = false
    @State private var pendingSurchargeEnable = false
    @State private var tipStrings: [String] = ["", "", ""]
    @State private var editingTipIndex: Int?

    var body: some View {
        NavigationStack {
            Form {
                // Account Section
                Section {
                    if let profile = appState.merchantProfile {
                        HStack {
                            Image(systemName: "building.2")
                                .font(.title2)
                                .foregroundStyle(.accent)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName)
                                    .font(.headline)

                                if !profile.merchantId.isEmpty {
                                    Text("Merchant ID: \(profile.merchantId)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Account")
                }

                // Tax Settings Section
                Section {
                    HStack {
                        Text("Tax Rate")
                        Spacer()
                        HStack {
                            TextField("0.00", text: $taxRateString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: taxRateString) { _, newValue in
                                    if let rate = Double(newValue) {
                                        appState.updateTaxRate(rate)
                                    }
                                }
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if appState.settings.taxRate > 0 {
                        HStack {
                            Text("Tax on \(appState.settings.currency.symbol)100")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(appState.settings.currency.symbol + String(format: "%.2f", appState.settings.taxRate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Tax Settings")
                } footer: {
                    Text("This tax rate will be automatically applied to all transactions.")
                }

                // Surcharge Section
                Section {
                    Toggle("Enable Surcharge", isOn: Binding(
                        get: { appState.settings.surchargeEnabled },
                        set: { newValue in
                            if newValue {
                                // Show warning before enabling
                                pendingSurchargeEnable = true
                                showSurchargeWarning = true
                            } else {
                                appState.updateSurchargeEnabled(false)
                            }
                        }
                    ))

                    if appState.settings.surchargeEnabled {
                        HStack {
                            Text("Surcharge Rate")
                            Spacer()
                            HStack {
                                TextField("0.00", text: $surchargeRateString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .onChange(of: surchargeRateString) { _, newValue in
                                        if let rate = Double(newValue), rate <= 3.0 {
                                            appState.updateSurchargeRate(rate)
                                        } else if let rate = Double(newValue), rate > 3.0 {
                                            // Clamp to max 3%
                                            surchargeRateString = "3.00"
                                            appState.updateSurchargeRate(3.0)
                                        }
                                    }
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if appState.settings.surchargeRate > 0 {
                            HStack {
                                Text("Surcharge on \(appState.settings.currency.symbol)100")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(appState.settings.currency.symbol + String(format: "%.2f", appState.settings.surchargeRate))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Surcharge")
                } footer: {
                    if appState.settings.surchargeEnabled {
                        Text("Surcharge applies only to credit cards. Debit, prepaid, and other card types will not be surcharged. Maximum allowed is 3%.")
                    } else {
                        Text("Enable surcharging to add a fee for credit card transactions.")
                    }
                }

                // Tipping Section
                Section {
                    Toggle("Enable Tipping", isOn: Binding(
                        get: { appState.settings.tippingEnabled },
                        set: { appState.updateTippingEnabled($0) }
                    ))

                    if appState.settings.tippingEnabled {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Quick Tip Options")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            HStack(spacing: 12) {
                                ForEach(0..<3, id: \.self) { index in
                                    TipPercentageCard(
                                        percentage: tipStrings[index],
                                        isEditing: editingTipIndex == index,
                                        accentColor: tipCardColor(for: index),
                                        onTap: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                editingTipIndex = index
                                            }
                                        },
                                        onUpdate: { newValue in
                                            tipStrings[index] = newValue
                                            if let value = Double(newValue) {
                                                var percentages = appState.settings.tipPercentages
                                                while percentages.count <= index {
                                                    percentages.append(0)
                                                }
                                                percentages[index] = value
                                                appState.updateTipPercentages(percentages)
                                            }
                                        },
                                        onCommit: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                editingTipIndex = nil
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        // Preview of tip amounts
                        if appState.settings.tipPercentages.contains(where: { $0 > 0 }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preview on \(appState.settings.currency.symbol)100")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                HStack(spacing: 8) {
                                    ForEach(Array(appState.settings.tipPercentages.enumerated()), id: \.offset) { index, percentage in
                                        if percentage > 0 {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(tipCardColor(for: index))
                                                    .frame(width: 6, height: 6)
                                                Text("\(appState.settings.currency.symbol)\(String(format: "%.0f", percentage))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tipping")
                } footer: {
                    if appState.settings.tippingEnabled {
                        Text("Customers will see these quick tip options during checkout. They can also enter a custom amount.")
                    } else {
                        Text("Enable tipping to let customers add gratuity during checkout.")
                    }
                }

                // Currency Section
                Section {
                    Picker("Currency", selection: Binding(
                        get: { appState.settings.currency },
                        set: { appState.updateCurrency($0) }
                    )) {
                        ForEach(Currency.allCases) { currency in
                            Text("\(currency.symbol) \(currency.rawValue) - \(currency.name)")
                                .tag(currency)
                        }
                    }
                } header: {
                    Text("Currency")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                taxRateString = String(format: "%.2f", appState.settings.taxRate)
                surchargeRateString = String(format: "%.2f", appState.settings.surchargeRate)
                // Initialize tip strings
                for (index, percentage) in appState.settings.tipPercentages.enumerated() where index < 3 {
                    tipStrings[index] = percentage > 0 ? String(format: "%.0f", percentage) : ""
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("Are you sure you want to sign out? You will need to enter your credentials again to use the app.")
            }
            .alert("Enable Surcharging?", isPresented: $showSurchargeWarning) {
                Button("Cancel", role: .cancel) {
                    pendingSurchargeEnable = false
                }
                Button("I Understand, Enable") {
                    appState.updateSurchargeEnabled(true)
                    pendingSurchargeEnable = false
                }
            } message: {
                Text("Surcharging credit card transactions may be subject to legal restrictions. Before enabling this feature, ensure you:\n\n• Comply with all applicable local, state, and federal laws\n• Have permission from your payment processor/bank\n• Follow card brand rules (Visa, Mastercard, etc.)\n• Display proper signage at your point of sale\n\nYou are solely responsible for compliance with surcharging regulations in your jurisdiction.")
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }

    private func tipCardColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.35, green: 0.78, blue: 0.62)  // Mint green
        case 1: return Color(red: 0.40, green: 0.65, blue: 0.95)  // Sky blue
        case 2: return Color(red: 0.95, green: 0.60, blue: 0.40)  // Warm coral
        default: return .accentColor
        }
    }
}

// MARK: - Tip Percentage Card

struct TipPercentageCard: View {
    let percentage: String
    let isEditing: Bool
    let accentColor: Color
    let onTap: () -> Void
    let onUpdate: (String) -> Void
    let onCommit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isEditing
                        ? accentColor.opacity(0.15)
                        : Color(.systemGray6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isEditing ? accentColor : Color.clear,
                            lineWidth: 2
                        )
                )

            VStack(spacing: 4) {
                if isEditing {
                    TextField("0", text: Binding(
                        get: { percentage },
                        set: { newValue in
                            // Only allow digits
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count <= 3 {
                                onUpdate(filtered)
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue {
                            onCommit()
                        }
                    }
                } else {
                    Text(percentage.isEmpty ? "—" : percentage)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(percentage.isEmpty ? .tertiary : .primary)
                }

                Text("%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEditing ? accentColor : .secondary)
            }
        }
        .frame(height: 80)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onTap()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

#Preview {
    SettingsView()
        .environmentObject({
            let state = AppState()
            state.merchantProfile = MerchantProfile(
                merchantId: "123456",
                companyName: "Acme Store",
                firstName: "John",
                lastName: "Doe",
                email: "john@acme.com",
                phone: "555-1234",
                address1: "123 Main St",
                city: "New York",
                state: "NY",
                postalCode: "10001",
                country: "US"
            )
            return state
        }())
}
