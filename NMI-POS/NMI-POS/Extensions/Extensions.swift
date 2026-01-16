import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }

    var isValidCardNumber: Bool {
        let digitsOnly = self.filter { $0.isNumber }
        return digitsOnly.count >= 13 && digitsOnly.count <= 19
    }

    var isValidCVV: Bool {
        let digitsOnly = self.filter { $0.isNumber }
        return digitsOnly.count >= 3 && digitsOnly.count <= 4
    }

    var isValidExpiration: Bool {
        let digitsOnly = self.filter { $0.isNumber }
        return digitsOnly.count == 4
    }

    var cardNumberFormatted: String {
        let digitsOnly = self.filter { $0.isNumber }
        var result = ""
        for (index, char) in digitsOnly.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }

    var maskedCardNumber: String {
        let digitsOnly = self.filter { $0.isNumber }
        guard digitsOnly.count >= 4 else { return self }
        let lastFour = String(digitsOnly.suffix(4))
        return "**** **** **** \(lastFour)"
    }
}

// MARK: - Double Extensions

extension Double {
    func formatted(as currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        switch currency {
        case .usd:
            formatter.currencyCode = "USD"
        case .eur:
            formatter.currencyCode = "EUR"
        case .gbp:
            formatter.currencyCode = "GBP"
        case .cad:
            formatter.currencyCode = "CAD"
        case .aud:
            formatter.currencyCode = "AUD"
        case .jpy:
            formatter.currencyCode = "JPY"
            formatter.maximumFractionDigits = 0
        case .chf:
            formatter.currencyCode = "CHF"
        case .mxn:
            formatter.currencyCode = "MXN"
        }

        return formatter.string(from: NSNumber(value: self)) ?? "\(currency.symbol)\(self)"
    }

    var asPercentage: String {
        String(format: "%.2f%%", self)
    }
}

// MARK: - Date Extensions

extension Date {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}

// MARK: - View Extensions

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Color Extensions

extension Color {
    static let nmiPrimary = Color("AccentColor")
    static let nmiSuccess = Color.green
    static let nmiError = Color.red
    static let nmiWarning = Color.orange
}
