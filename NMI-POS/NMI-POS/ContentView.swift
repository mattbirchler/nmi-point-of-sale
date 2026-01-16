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
            }
        }
        .animation(.easeInOut, value: appState.currentScreen)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
