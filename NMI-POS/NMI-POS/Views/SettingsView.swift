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
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Merchant Profile Card
                    if let profile = appState.merchantProfile {
                        merchantProfileCard(profile)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                    }

                    // Settings Cards
                    VStack(spacing: 16) {
                        // Tax & Fees Section
                        settingsCard {
                            VStack(spacing: 0) {
                                taxSettingsRow

                                SettingsDivider()

                                surchargeSettingsRow
                            }
                        } header: {
                            SettingsSectionHeader(icon: "percent", title: "Tax & Fees", color: .orange)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                        // Tipping Section
                        settingsCard {
                            tippingContent
                        } header: {
                            SettingsSectionHeader(icon: "heart.fill", title: "Tipping", color: Color(red: 0.35, green: 0.78, blue: 0.62))
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                        // Currency Section
                        settingsCard {
                            currencyRow
                        } header: {
                            SettingsSectionHeader(icon: "dollarsign.circle.fill", title: "Currency", color: Color(red: 0.40, green: 0.65, blue: 0.95))
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

                        // Security Section (only if biometrics available)
                        if appState.canUseBiometrics {
                            settingsCard {
                                biometricRow
                            } header: {
                                SettingsSectionHeader(icon: "lock.fill", title: "Security", color: .accentColor)
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)
                        }

                        // About Section
                        settingsCard {
                            VStack(spacing: 0) {
                                aboutRow("Version", value: "1.0.0")
                                SettingsDivider()
                                aboutRow("Build", value: "1")
                            }
                        } header: {
                            SettingsSectionHeader(icon: "info.circle.fill", title: "About", color: .secondary)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)

                        // Sign Out Button
                        signOutButton
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                taxRateString = String(format: "%.2f", appState.settings.taxRate)
                surchargeRateString = String(format: "%.2f", appState.settings.surchargeRate)
                for (index, percentage) in appState.settings.tipPercentages.enumerated() where index < 3 {
                    tipStrings[index] = percentage > 0 ? String(format: "%.0f", percentage) : ""
                }
                withAnimation {
                    appeared = true
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

    // MARK: - Merchant Profile Card

    private func merchantProfileCard(_ profile: MerchantProfile) -> some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(profile.displayName.prefix(1).uppercased())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                if !profile.merchantId.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.system(size: 11))
                        Text("ID: \(profile.merchantId)")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Settings Card Container

    private func settingsCard<Content: View, Header: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header()
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Tax Settings

    private var taxSettingsRow: some View {
        VStack(spacing: 12) {
            HStack {
                Label {
                    Text("Tax Rate")
                        .font(.system(size: 16, weight: .medium))
                } icon: {
                    Image(systemName: "receipt")
                        .foregroundStyle(.orange)
                }

                Spacer()

                HStack(spacing: 4) {
                    TextField("0.00", text: $taxRateString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(width: 60)
                        .onChange(of: taxRateString) { _, newValue in
                            if let rate = Double(newValue) {
                                appState.updateTaxRate(rate)
                            }
                        }

                    Text("%")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            if appState.settings.taxRate > 0 {
                HStack {
                    Spacer()
                    Text("On \(appState.settings.currency.symbol)100 → +\(appState.settings.currency.symbol)\(String(format: "%.2f", appState.settings.taxRate))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Surcharge Settings

    private var surchargeSettingsRow: some View {
        VStack(spacing: 12) {
            HStack {
                Label {
                    Text("Credit Card Surcharge")
                        .font(.system(size: 16, weight: .medium))
                } icon: {
                    Image(systemName: "creditcard")
                        .foregroundStyle(.orange)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { appState.settings.surchargeEnabled },
                    set: { newValue in
                        if newValue {
                            pendingSurchargeEnable = true
                            showSurchargeWarning = true
                        } else {
                            appState.updateSurchargeEnabled(false)
                        }
                    }
                ))
                .labelsHidden()
                .tint(.orange)
            }

            if appState.settings.surchargeEnabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("Rate")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            TextField("0.00", text: $surchargeRateString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(width: 50)
                                .onChange(of: surchargeRateString) { _, newValue in
                                    if let rate = Double(newValue), rate <= 3.0 {
                                        appState.updateSurchargeRate(rate)
                                    } else if let rate = Double(newValue), rate > 3.0 {
                                        surchargeRateString = "3.00"
                                        appState.updateSurchargeRate(3.0)
                                    }
                                }

                            Text("%")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                        Text("Maximum 3% • Credit cards only")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .animation(.spring(response: 0.3), value: appState.settings.surchargeEnabled)
    }

    // MARK: - Tipping Content

    private var tippingContent: some View {
        VStack(spacing: 16) {
            HStack {
                Label {
                    Text("Enable Tipping")
                        .font(.system(size: 16, weight: .medium))
                } icon: {
                    Image(systemName: "heart")
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.62))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { appState.settings.tippingEnabled },
                    set: { appState.updateTippingEnabled($0) }
                ))
                .labelsHidden()
                .tint(Color(red: 0.35, green: 0.78, blue: 0.62))
            }

            if appState.settings.tippingEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("QUICK TIP OPTIONS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.5)

                    HStack(spacing: 10) {
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

                    // Preview chips
                    if appState.settings.tipPercentages.contains(where: { $0 > 0 }) {
                        HStack(spacing: 6) {
                            Text("On \(appState.settings.currency.symbol)100:")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)

                            ForEach(Array(appState.settings.tipPercentages.enumerated()), id: \.offset) { index, percentage in
                                if percentage > 0 {
                                    Text("\(appState.settings.currency.symbol)\(String(format: "%.0f", percentage))")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(tipCardColor(for: index))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(tipCardColor(for: index).opacity(0.12))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .animation(.spring(response: 0.3), value: appState.settings.tippingEnabled)
    }

    // MARK: - Biometric Row

    private var biometricRow: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.biometricDisplayName)
                        .font(.system(size: 16, weight: .medium))
                    Text("Require \(appState.biometricDisplayName) to open the app")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: appState.biometricIconName)
                    .foregroundStyle(.accent)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { appState.settings.biometricEnabled },
                set: { appState.updateBiometricEnabled($0) }
            ))
            .labelsHidden()
            .tint(.accentColor)
        }
        .padding(16)
    }

    // MARK: - Currency Row

    private var currencyRow: some View {
        HStack {
            Label {
                Text("Default Currency")
                    .font(.system(size: 16, weight: .medium))
            } icon: {
                Text(appState.settings.currency.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.40, green: 0.65, blue: 0.95))
            }

            Spacer()

            Picker("", selection: Binding(
                get: { appState.settings.currency },
                set: { appState.updateCurrency($0) }
            )) {
                ForEach(Currency.allCases) { currency in
                    Text("\(currency.symbol) \(currency.rawValue)")
                        .tag(currency)
                }
            }
            .labelsHidden()
            .tint(.primary)
        }
        .padding(16)
    }

    // MARK: - About Row

    private func aboutRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(16)
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func tipCardColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.35, green: 0.78, blue: 0.62)  // Mint green
        case 1: return Color(red: 0.40, green: 0.65, blue: 0.95)  // Sky blue
        case 2: return Color(red: 0.95, green: 0.60, blue: 0.40)  // Warm coral
        default: return .accentColor
        }
    }
}

// MARK: - Section Header

struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 1)
            .padding(.leading, 52)
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
            // Background with gradient when editing
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isEditing
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [accentColor.opacity(0.2), accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isEditing ? accentColor : Color.clear,
                            lineWidth: 2
                        )
                )

            VStack(spacing: 2) {
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
                    .font(.system(size: 26, weight: .bold, design: .rounded))
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
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(percentage.isEmpty ? .tertiary : .primary)
                }

                Text("%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isEditing ? accentColor : .secondary)
            }
        }
        .frame(height: 72)
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
                companyName: "Birchwood Coffee",
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
