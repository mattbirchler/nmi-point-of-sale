import Foundation
import SwiftUI

enum AppScreen: Equatable {
    case login
    case welcome
    case onboarding
    case main
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published var currentScreen: AppScreen = .login
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var credentials: NMICredentials?
    @Published var merchantProfile: MerchantProfile?
    @Published var settings: AppSettings = .default

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let credentials = "nmi_credentials"
        static let settings = "app_settings"
        static let merchantProfile = "merchant_profile"
    }

    // MARK: - Initialization

    init() {
        loadPersistedData()
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        // Load credentials
        if let credentialsData = UserDefaults.standard.data(forKey: Keys.credentials),
           let savedCredentials = try? JSONDecoder().decode(NMICredentials.self, from: credentialsData) {
            credentials = savedCredentials
        }

        // Load settings
        if let settingsData = UserDefaults.standard.data(forKey: Keys.settings),
           let savedSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            settings = savedSettings
        }

        // Load merchant profile
        if let profileData = UserDefaults.standard.data(forKey: Keys.merchantProfile),
           let savedProfile = try? JSONDecoder().decode(MerchantProfile.self, from: profileData) {
            merchantProfile = savedProfile
        }

        // Determine initial screen
        if credentials != nil && merchantProfile != nil {
            if settings.hasCompletedOnboarding {
                currentScreen = .main
            } else {
                currentScreen = .welcome
            }
        } else {
            currentScreen = .login
        }
    }

    private func saveCredentials() {
        if let credentials = credentials,
           let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: Keys.credentials)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.credentials)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Keys.settings)
        }
    }

    private func saveMerchantProfile() {
        if let profile = merchantProfile,
           let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Keys.merchantProfile)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.merchantProfile)
        }
    }

    // MARK: - Authentication

    func login(securityKey: String) async {
        guard !securityKey.isEmpty else {
            errorMessage = "Please enter your security key."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let profile = try await NMIService.shared.validateCredentialsAndGetProfile(securityKey: securityKey)

            credentials = NMICredentials(securityKey: securityKey)
            merchantProfile = profile

            saveCredentials()
            saveMerchantProfile()

            currentScreen = .welcome
        } catch let error as NMIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() {
        credentials = nil
        merchantProfile = nil
        settings = .default

        UserDefaults.standard.removeObject(forKey: Keys.credentials)
        UserDefaults.standard.removeObject(forKey: Keys.settings)
        UserDefaults.standard.removeObject(forKey: Keys.merchantProfile)

        currentScreen = .login
    }

    // MARK: - Onboarding

    func proceedToOnboarding() {
        currentScreen = .onboarding
    }

    func completeOnboarding(
        currency: Currency,
        taxRate: Double,
        surchargeEnabled: Bool = false,
        surchargeRate: Double = 0,
        tippingEnabled: Bool = false,
        tipPercentages: [Double] = [15, 20, 25]
    ) {
        settings.currency = currency
        settings.taxRate = taxRate
        settings.surchargeEnabled = surchargeEnabled
        settings.surchargeRate = surchargeRate
        settings.tippingEnabled = tippingEnabled
        settings.tipPercentages = tipPercentages
        settings.hasCompletedOnboarding = true

        saveSettings()

        currentScreen = .main
    }

    // MARK: - Settings

    func updateTaxRate(_ rate: Double) {
        settings.taxRate = rate
        saveSettings()
    }

    func updateCurrency(_ currency: Currency) {
        settings.currency = currency
        saveSettings()
    }

    func updateSurchargeEnabled(_ enabled: Bool) {
        settings.surchargeEnabled = enabled
        if !enabled {
            settings.surchargeRate = 0
        }
        saveSettings()
    }

    func updateSurchargeRate(_ rate: Double) {
        // Clamp to 0-3%
        settings.surchargeRate = min(max(rate, 0), 3)
        saveSettings()
    }

    func updateTippingEnabled(_ enabled: Bool) {
        settings.tippingEnabled = enabled
        saveSettings()
    }

    func updateTipPercentages(_ percentages: [Double]) {
        // Limit to 3 tip percentages, clamp each to 0-100%
        settings.tipPercentages = percentages.prefix(3).map { min(max($0, 0), 100) }
        saveSettings()
    }

    // MARK: - Helpers

    var securityKey: String {
        credentials?.securityKey ?? ""
    }

    func clearError() {
        errorMessage = nil
    }
}
