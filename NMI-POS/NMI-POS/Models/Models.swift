import Foundation

// MARK: - User Profile

struct MerchantProfile: Codable, Equatable {
    let merchantId: String
    let companyName: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let address1: String
    let city: String
    let state: String
    let postalCode: String
    let country: String

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var displayName: String {
        companyName.isEmpty ? fullName : companyName
    }
}

// MARK: - Credentials

struct NMICredentials: Codable, Equatable {
    let securityKey: String

    var isValid: Bool {
        !securityKey.isEmpty
    }
}

// MARK: - App Settings

struct AppSettings: Codable, Equatable {
    var currency: Currency
    var taxRate: Double
    var hasCompletedOnboarding: Bool

    static let `default` = AppSettings(
        currency: .usd,
        taxRate: 0.0,
        hasCompletedOnboarding: false
    )
}

enum Currency: String, Codable, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    case chf = "CHF"
    case mxn = "MXN"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd, .cad, .aud, .mxn: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .chf: return "CHF "
        }
    }

    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        case .chf: return "Swiss Franc"
        case .mxn: return "Mexican Peso"
        }
    }
}

// MARK: - Transaction

struct Transaction: Identifiable, Codable, Equatable {
    let id: String
    let transactionId: String
    let amount: Double
    let tax: Double
    let total: Double
    let status: TransactionStatus
    let cardType: String
    let lastFour: String
    let customerName: String
    let customerEmail: String
    let date: Date
    let responseText: String

    var formattedAmount: String {
        String(format: "%.2f", amount)
    }

    var formattedTotal: String {
        String(format: "%.2f", total)
    }

    var formattedTax: String {
        String(format: "%.2f", tax)
    }
}

enum TransactionStatus: String, Codable {
    case approved = "approved"
    case declined = "declined"
    case pending = "pending"
    case error = "error"
    case voided = "voided"
    case refunded = "refunded"

    var displayName: String {
        rawValue.capitalized
    }

    var isSuccessful: Bool {
        self == .approved
    }
}

// MARK: - Sale Request

struct SaleRequest {
    let amount: Double
    let tax: Double
    let cardNumber: String
    let expirationMonth: String
    let expirationYear: String
    let cvv: String
    let firstName: String
    let lastName: String
    let address1: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let email: String

    var total: Double {
        amount + tax
    }

    var expiration: String {
        "\(expirationMonth)\(expirationYear)"
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - API Response Models

struct NMIQueryResponse {
    let isSuccess: Bool
    let errorMessage: String?
    let merchantProfile: MerchantProfile?
    let transactions: [Transaction]
}

struct NMITransactionResponse {
    let isSuccess: Bool
    let transactionId: String?
    let responseText: String
    let responseCode: String
    let authCode: String?
}

// MARK: - Daily Summary

struct DailySummary: Equatable {
    let totalRevenue: Double
    let transactionCount: Int
    let date: Date

    var formattedRevenue: String {
        String(format: "%.2f", totalRevenue)
    }

    static let empty = DailySummary(totalRevenue: 0, transactionCount: 0, date: Date())
}
