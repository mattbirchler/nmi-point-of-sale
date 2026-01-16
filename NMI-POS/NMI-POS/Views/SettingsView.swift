import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var taxRateString = ""
    @State private var showSignOutAlert = false

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
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("Are you sure you want to sign out? You will need to enter your credentials again to use the app.")
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
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
