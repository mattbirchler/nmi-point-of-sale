import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentScreen {
            case .login:
                LoginView()
            case .welcome:
                WelcomeView()
            case .onboarding:
                OnboardingView()
            case .main:
                MainView()
            case .locked:
                LockedView()
            }
        }
        .animation(.easeInOut, value: appState.currentScreen)
    }
}

// MARK: - Locked View

struct LockedView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAuthenticating = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon and Title
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: appState.biometricIconName)
                        .font(.system(size: 56))
                        .foregroundStyle(.accent)
                }

                Text("iProcess is Locked")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Use \(appState.biometricDisplayName) to unlock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Error message
            if showError {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Authentication failed. Please try again.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Unlock Button
            Button {
                Task {
                    await authenticate()
                }
            } label: {
                HStack(spacing: 12) {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: appState.biometricIconName)
                        Text("Unlock with \(appState.biometricDisplayName)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onAppear {
            // Automatically prompt for authentication when view appears
            Task {
                await authenticate()
            }
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        showError = false

        let success = await appState.authenticateWithBiometrics()

        isAuthenticating = false

        if !success {
            showError = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
