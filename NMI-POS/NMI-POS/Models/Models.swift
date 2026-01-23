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
    var historyDateRange: HistoryDateRange
    var surchargeEnabled: Bool
    var surchargeRate: Double  // Percentage (0.00 - 3.00)
    var tippingEnabled: Bool
    var tipPercentages: [Double]  // Up to 3 custom tip percentages
    var biometricEnabled: Bool

    static let `default` = AppSettings(
        currency: .usd,
        taxRate: 0.0,
        hasCompletedOnboarding: false,
        historyDateRange: .last30Days,
        surchargeEnabled: false,
        surchargeRate: 0.0,
        tippingEnabled: false,
        tipPercentages: [15, 20, 25],
        biometricEnabled: false
    )
}

enum HistoryDateRange: String, Codable, CaseIterable, Identifiable {
    case today = "today"
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case last90Days = "last_90_days"
    case last6Months = "last_6_months"
    case lastYear = "last_year"
    case allTime = "all_time"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .last6Months: return "Last 6 Months"
        case .lastYear: return "Last Year"
        case .allTime: return "All Time"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: now)
        case .last6Months:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }

    /// Whether this range should use timezone adjustment for the API query
    var shouldAdjustForTimezone: Bool {
        self == .today
    }
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

struct Transaction: Identifiable, Codable, Equatable, Hashable {
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
    let tip: Double
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
        amount + tax + tip
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

// MARK: - Transaction Detail

struct TransactionDetail: Equatable {
    // Basic info
    let transactionId: String
    let transactionType: String
    let condition: String
    let orderId: String
    let authorizationCode: String

    // Billing
    let firstName: String
    let lastName: String
    let company: String
    let address1: String
    let address2: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let email: String
    let phone: String

    // Shipping
    let shippingFirstName: String
    let shippingLastName: String
    let shippingCompany: String
    let shippingAddress1: String
    let shippingAddress2: String
    let shippingCity: String
    let shippingState: String
    let shippingPostalCode: String
    let shippingCountry: String

    // Card info
    let ccNumber: String
    let ccExp: String
    let ccType: String
    let ccBin: String
    let avsResponse: String
    let cscResponse: String

    // Amounts
    let amount: Double
    let tax: Double
    let shipping: Double
    let tip: Double
    let surcharge: Double
    let currency: String

    // Related data
    let products: [TransactionProduct]
    let actions: [TransactionAction]

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var shippingFullName: String {
        "\(shippingFirstName) \(shippingLastName)".trimmingCharacters(in: .whitespaces)
    }

    var hasShippingAddress: Bool {
        !shippingAddress1.isEmpty || !shippingCity.isEmpty
    }

    var hasBillingAddress: Bool {
        !address1.isEmpty || !city.isEmpty
    }

    var status: TransactionStatus {
        switch condition.lowercased() {
        case "complete", "completed", "pendingsettlement", "pending_settlement":
            return .approved
        case "declined", "failed":
            return .declined
        case "pending":
            return .pending
        case "voided", "void":
            return .voided
        case "refunded", "refund":
            return .refunded
        default:
            return .pending
        }
    }

    var transactionDate: Date? {
        actions.first?.date
    }
}

struct TransactionProduct: Equatable, Identifiable {
    let id: String
    let sku: String
    let quantity: Double
    let description: String
    let amount: Double

    init(id: String = UUID().uuidString, sku: String, quantity: Double, description: String, amount: Double) {
        self.id = id
        self.sku = sku
        self.quantity = quantity
        self.description = description
        self.amount = amount
    }
}

struct TransactionAction: Equatable, Identifiable {
    let id: String
    let actionType: String
    let amount: Double
    let date: Date
    let success: Bool
    let responseText: String

    init(id: String = UUID().uuidString, actionType: String, amount: Double, date: Date, success: Bool, responseText: String) {
        self.id = id
        self.actionType = actionType
        self.amount = amount
        self.date = date
        self.success = success
        self.responseText = responseText
    }

    var displayActionType: String {
        switch actionType.lowercased() {
        case "sale": return "Sale"
        case "auth": return "Authorization"
        case "capture": return "Capture"
        case "void": return "Void"
        case "refund": return "Refund"
        case "credit": return "Credit"
        case "settle": return "Settlement"
        default: return actionType.capitalized
        }
    }
}

// MARK: - Customer Vault

struct VaultCustomer: Identifiable, Codable, Equatable {
    let id: String
    let customerVaultId: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let company: String
    let address1: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let ccNumber: String      // Masked, e.g., "4xxxxxxxxxxx1111"
    let ccExp: String         // e.g., "1225"
    let ccType: String        // e.g., "visa"
    let ccBin: String
    let created: Date?
    let updated: Date?

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var displayName: String {
        if !fullName.isEmpty {
            return fullName
        } else if !company.isEmpty {
            return company
        } else if !email.isEmpty {
            return email
        }
        return "Customer"
    }

    var lastFour: String {
        String(ccNumber.suffix(4))
    }

    var formattedExpiration: String {
        guard ccExp.count == 4 else { return ccExp }
        let month = String(ccExp.prefix(2))
        let year = String(ccExp.suffix(2))
        return "\(month)/\(year)"
    }

    var cardTypeDisplayName: String {
        switch ccType.lowercased() {
        case "visa": return "Visa"
        case "mastercard", "mc": return "Mastercard"
        case "amex", "americanexpress", "american express": return "Amex"
        case "discover": return "Discover"
        case "diners", "dinersclub": return "Diners Club"
        case "jcb": return "JCB"
        default: return ccType.capitalized
        }
    }
}

struct VaultSaleRequest {
    let customerVaultId: String
    let billingId: String?    // For customers with multiple cards
    let amount: Double
    let tax: Double
    let tip: Double

    var total: Double {
        amount + tax + tip
    }
}
