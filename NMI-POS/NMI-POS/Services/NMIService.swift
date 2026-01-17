import Foundation
import os.log

// MARK: - API Logger

struct APILogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NMI-POS", category: "API")

    static func logRequest(endpoint: String, method: String, parameters: [String: String]) {
        let maskedParams = maskSensitiveData(parameters)
        let paramString = maskedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        logger.info("➡️ REQUEST [\(method)] \(endpoint)")
        logger.info("   Parameters: \(paramString)")
    }

    static func logResponse(endpoint: String, statusCode: Int, body: String) {
        let maskedBody = maskResponseBody(body)
        logger.info("⬅️ RESPONSE [\(statusCode)] \(endpoint)")
        logger.info("   Body: \(maskedBody)")
    }

    static func logError(endpoint: String, error: Error) {
        logger.error("❌ ERROR \(endpoint): \(error.localizedDescription)")
    }

    private static func maskSensitiveData(_ params: [String: String]) -> [String: String] {
        var masked = params

        // Mask security key - show first 4 and last 4 chars
        if let key = masked["security_key"], key.count > 8 {
            let prefix = String(key.prefix(4))
            let suffix = String(key.suffix(4))
            masked["security_key"] = "\(prefix)****\(suffix)"
        } else if masked["security_key"] != nil {
            masked["security_key"] = "****"
        }

        // Mask card number - show last 4 only
        if let ccNumber = masked["ccnumber"], ccNumber.count >= 4 {
            let lastFour = String(ccNumber.suffix(4))
            masked["ccnumber"] = "************\(lastFour)"
        }

        // Completely mask CVV
        if masked["cvv"] != nil {
            masked["cvv"] = "***"
        }

        return masked
    }

    private static func maskResponseBody(_ body: String) -> String {
        var masked = body

        // Mask any card numbers in response (pattern: 12+ digits)
        let ccPattern = try? NSRegularExpression(pattern: "\\b\\d{12,19}\\b", options: [])
        if let regex = ccPattern {
            let range = NSRange(masked.startIndex..., in: masked)
            masked = regex.stringByReplacingMatches(in: masked, options: [], range: range, withTemplate: "************$0".suffix(4).description)
        }

        // Truncate very long responses
        if masked.count > 1000 {
            masked = String(masked.prefix(1000)) + "...[truncated]"
        }

        return masked
    }
}

enum NMIError: LocalizedError {
    case invalidCredentials
    case networkError(String)
    case parseError(String)
    case transactionFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid security key. Please check your credentials."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

actor NMIService {
    private let queryURL = "https://secure.nmi.com/api/query.php"
    private let transactURL = "https://secure.nmi.com/api/transact.php"

    static let shared = NMIService()

    private init() {}

    // MARK: - Authentication / Profile Query

    func validateCredentialsAndGetProfile(securityKey: String) async throws -> MerchantProfile {
        var components = URLComponents(string: queryURL)!
        components.queryItems = [
            URLQueryItem(name: "security_key", value: securityKey),
            URLQueryItem(name: "report_type", value: "profile")
        ]

        guard let url = components.url else {
            throw NMIError.networkError("Invalid URL")
        }

        // Log the request
        APILogger.logRequest(
            endpoint: queryURL,
            method: "GET",
            parameters: ["security_key": securityKey, "report_type": "profile"]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            APILogger.logError(endpoint: queryURL, error: error)
            throw NMIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NMIError.networkError("Invalid response")
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw NMIError.parseError("Unable to decode response")
        }

        // Log the response
        APILogger.logResponse(endpoint: queryURL, statusCode: httpResponse.statusCode, body: xmlString)

        guard httpResponse.statusCode == 200 else {
            throw NMIError.networkError("Server returned status \(httpResponse.statusCode)")
        }

        return try parseProfileResponse(xmlString)
    }

    private func parseProfileResponse(_ xml: String) throws -> MerchantProfile {
        // Check for error response
        if xml.contains("<error_response>") || xml.contains("Invalid Security Key") ||
           xml.contains("Authentication Failed") {
            throw NMIError.invalidCredentials
        }

        // Parse the XML response for merchant profile data
        let merchantId = extractValue(from: xml, tag: "merchant_id") ?? ""
        let companyName = extractValue(from: xml, tag: "company") ??
                          extractValue(from: xml, tag: "company_name") ?? ""
        let firstName = extractValue(from: xml, tag: "first_name") ?? ""
        let lastName = extractValue(from: xml, tag: "last_name") ?? ""
        let email = extractValue(from: xml, tag: "email") ?? ""
        let phone = extractValue(from: xml, tag: "phone") ?? ""
        let address1 = extractValue(from: xml, tag: "address_1") ??
                       extractValue(from: xml, tag: "address1") ?? ""
        let city = extractValue(from: xml, tag: "city") ?? ""
        let state = extractValue(from: xml, tag: "state") ?? ""
        let postalCode = extractValue(from: xml, tag: "postal_code") ??
                         extractValue(from: xml, tag: "zip") ?? ""
        let country = extractValue(from: xml, tag: "country") ?? "US"

        // Validate we got some meaningful data back
        if merchantId.isEmpty && companyName.isEmpty && firstName.isEmpty {
            throw NMIError.invalidCredentials
        }

        return MerchantProfile(
            merchantId: merchantId,
            companyName: companyName,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            address1: address1,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country
        )
    }

    // MARK: - Process Sale Transaction

    func processSale(securityKey: String, sale: SaleRequest) async throws -> NMITransactionResponse {
        var components = URLComponents(string: transactURL)!

        let amountString = String(format: "%.2f", sale.total)

        let params: [String: String] = [
            "security_key": securityKey,
            "type": "sale",
            "amount": amountString,
            "ccnumber": sale.cardNumber,
            "ccexp": sale.expiration,
            "cvv": sale.cvv,
            "first_name": sale.firstName,
            "last_name": sale.lastName,
            "address1": sale.address1,
            "city": sale.city,
            "state": sale.state,
            "zip": sale.postalCode,
            "country": sale.country,
            "email": sale.email
        ]

        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw NMIError.networkError("Invalid URL")
        }

        // Log the request
        APILogger.logRequest(endpoint: transactURL, method: "POST", parameters: params)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            APILogger.logError(endpoint: transactURL, error: error)
            throw NMIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NMIError.networkError("Invalid response")
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw NMIError.parseError("Unable to decode response")
        }

        // Log the response
        APILogger.logResponse(endpoint: transactURL, statusCode: httpResponse.statusCode, body: responseString)

        guard httpResponse.statusCode == 200 else {
            throw NMIError.networkError("Server returned status \(httpResponse.statusCode)")
        }

        return parseTransactionResponse(responseString)
    }

    private func parseTransactionResponse(_ response: String) -> NMITransactionResponse {
        // NMI returns URL-encoded key=value pairs
        var params: [String: String] = [:]
        let pairs = response.split(separator: "&")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0])
                let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }

        let responseCode = params["response_code"] ?? ""
        let responseText = params["responsetext"] ?? params["response_text"] ?? "Unknown"
        let transactionId = params["transactionid"] ?? params["transaction_id"]
        let authCode = params["authcode"] ?? params["auth_code"]

        // Response code "100" indicates approval
        let isSuccess = responseCode == "100"

        return NMITransactionResponse(
            isSuccess: isSuccess,
            transactionId: transactionId,
            responseText: responseText,
            responseCode: responseCode,
            authCode: authCode
        )
    }

    // MARK: - Query Transactions

    func getTransactions(securityKey: String, startDate: Date? = nil, endDate: Date? = nil) async throws -> [Transaction] {
        var components = URLComponents(string: queryURL)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        var params: [String: String] = [
            "security_key": securityKey,
            "report_type": "transaction"
        ]

        if let start = startDate {
            params["start_date"] = dateFormatter.string(from: start)
        }

        if let end = endDate {
            params["end_date"] = dateFormatter.string(from: end)
        }

        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw NMIError.networkError("Invalid URL")
        }

        // Log the request
        APILogger.logRequest(endpoint: queryURL, method: "GET", parameters: params)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            APILogger.logError(endpoint: queryURL, error: error)
            throw NMIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NMIError.networkError("Invalid response")
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw NMIError.parseError("Unable to decode response")
        }

        // Log the response
        APILogger.logResponse(endpoint: queryURL, statusCode: httpResponse.statusCode, body: xmlString)

        guard httpResponse.statusCode == 200 else {
            throw NMIError.networkError("Server returned status \(httpResponse.statusCode)")
        }

        return parseTransactionsResponse(xmlString)
    }

    private func parseTransactionsResponse(_ xml: String) -> [Transaction] {
        var transactions: [Transaction] = []

        // Split by transaction tags
        let transactionBlocks = xml.components(separatedBy: "<transaction>")

        for block in transactionBlocks.dropFirst() {
            guard let endIndex = block.range(of: "</transaction>")?.lowerBound else { continue }
            let transactionXml = String(block[..<endIndex])

            let transactionId = extractValue(from: transactionXml, tag: "transaction_id") ?? UUID().uuidString
            let amountStr = extractValue(from: transactionXml, tag: "amount") ?? "0"
            let amount = Double(amountStr) ?? 0

            let conditionStr = extractValue(from: transactionXml, tag: "condition") ?? "pending"
            let status = mapConditionToStatus(conditionStr)

            let cardType = extractValue(from: transactionXml, tag: "cc_type") ?? "Unknown"
            let ccNumber = extractValue(from: transactionXml, tag: "cc_number") ?? ""
            let lastFour = String(ccNumber.suffix(4))

            let firstName = extractValue(from: transactionXml, tag: "first_name") ?? ""
            let lastName = extractValue(from: transactionXml, tag: "last_name") ?? ""
            let customerName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            let customerEmail = extractValue(from: transactionXml, tag: "email") ?? ""

            // Extract date from first <action> block's <date> field
            let dateStr = extractDateFromAction(transactionXml) ?? ""
            let date = parseDate(dateStr) ?? Date()

            let responseText = extractValue(from: transactionXml, tag: "response_text") ?? ""

            // For simplicity, treat full amount as total (tax is embedded in amount from NMI)
            let transaction = Transaction(
                id: transactionId,
                transactionId: transactionId,
                amount: amount,
                tax: 0,
                total: amount,
                status: status,
                cardType: cardType,
                lastFour: lastFour,
                customerName: customerName,
                customerEmail: customerEmail,
                date: date,
                responseText: responseText
            )

            transactions.append(transaction)
        }

        // Sort by date descending
        return transactions.sorted { $0.date > $1.date }
    }

    private func mapConditionToStatus(_ condition: String) -> TransactionStatus {
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

    // MARK: - Daily Summary

    func getDailySummary(securityKey: String) async throws -> DailySummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let transactions = try await getTransactions(
            securityKey: securityKey,
            startDate: today,
            endDate: tomorrow
        )

        let approvedTransactions = transactions.filter { $0.status.isSuccessful }
        let totalRevenue = approvedTransactions.reduce(0) { $0 + $1.total }

        return DailySummary(
            totalRevenue: totalRevenue,
            transactionCount: approvedTransactions.count,
            date: today
        )
    }

    // MARK: - Helpers

    private func extractValue(from xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"

        guard let openRange = xml.range(of: openTag),
              let closeRange = xml.range(of: closeTag, range: openRange.upperBound..<xml.endIndex) else {
            return nil
        }

        let value = String(xml[openRange.upperBound..<closeRange.lowerBound])
        return value.isEmpty ? nil : value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractDateFromAction(_ xml: String) -> String? {
        // Find the first <action> block
        guard let actionStart = xml.range(of: "<action>"),
              let actionEnd = xml.range(of: "</action>", range: actionStart.upperBound..<xml.endIndex) else {
            return nil
        }

        let actionXml = String(xml[actionStart.upperBound..<actionEnd.lowerBound])

        // Extract <date> from within the action block
        return extractValue(from: actionXml, tag: "date")
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "yyyyMMddHHmmss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}
