import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Welcome Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                // Welcome Message
                VStack(spacing: 12) {
                    Text("Welcome!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let profile = appState.merchantProfile {
                        Text(profile.displayName)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(.accent)
                    }
                }

                // Account Details Card
                if let profile = appState.merchantProfile {
                    VStack(spacing: 16) {
                        Text("Account Details")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            if !profile.merchantId.isEmpty {
                                ProfileRow(label: "Merchant ID", value: profile.merchantId)
                            }

                            if !profile.fullName.isEmpty {
                                ProfileRow(label: "Contact Name", value: profile.fullName)
                            }

                            if !profile.email.isEmpty {
                                ProfileRow(label: "Email", value: profile.email)
                            }

                            if !profile.phone.isEmpty {
                                ProfileRow(label: "Phone", value: profile.phone)
                            }

                            if !profile.city.isEmpty || !profile.state.isEmpty {
                                ProfileRow(
                                    label: "Location",
                                    value: [profile.city, profile.state, profile.country]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: ", ")
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                Spacer()

                // Continue Button
                VStack(spacing: 16) {
                    Text("Let's set up your point-of-sale preferences")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        appState.proceedToOnboarding()
                    } label: {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
    }
}

struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
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
    WelcomeView()
        .environmentObject({
            let state = AppState()
            state.merchantProfile = MerchantProfile(
                merchantId: "123456",
                companyName: "Acme Store",
                firstName: "John",
                lastName: "Doe",
                email: "john@acmestore.com",
                phone: "555-123-4567",
                address1: "123 Main St",
                city: "New York",
                state: "NY",
                postalCode: "10001",
                country: "US"
            )
            return state
        }())
}
