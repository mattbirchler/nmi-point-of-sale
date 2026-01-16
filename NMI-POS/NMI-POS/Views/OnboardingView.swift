import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCurrency: Currency = .usd
    @State private var taxRateString = ""
    @State private var currentStep = 0

    private var taxRate: Double {
        Double(taxRateString) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Indicator
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
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
                        if currentStep < 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            completeSetup()
                        }
                    } label: {
                        Text(currentStep == 1 ? "Complete Setup" : "Next")
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

    // MARK: - Actions

    private func completeSetup() {
        appState.completeOnboarding(currency: selectedCurrency, taxRate: taxRate)
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
