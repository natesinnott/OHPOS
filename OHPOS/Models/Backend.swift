//
//  Backend.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import Foundation

struct PaymentIntentResponse: Decodable {
    let id: String
    let clientSecret: String?
    let status: String
}

struct ReaderResponse: Decodable {
    struct Reader: Decodable { let id: String; let status: String? }
    let reader: Reader
}

struct PIErrorPayload: Decodable {
    let code: String?
    let decline_code: String?
    let message: String?
    let type: String?
}

struct PIStatus: Decodable {
    let id: String
    let status: String
    let effectiveStatus: String?
    let last_payment_error: PIErrorPayload?
    // Expanded charge-level info (backend returns these)
    let latest_charge_status: String?
    let latest_charge_failure_message: String?
    let latest_charge_failure_code: String?
    let latest_charge_outcome_type: String?
    let latest_charge_outcome_seller_message: String?

    // Prefer PI error message, then charge failure, then outcome seller message
    var errorMessage: String? {
        if let m = last_payment_error?.message, !m.isEmpty { return m }
        if let m = latest_charge_failure_message, !m.isEmpty { return m }
        if let m = latest_charge_outcome_seller_message, !m.isEmpty { return m }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case last_payment_error
        case latest_charge_status
        case latest_charge_failure_message
        case latest_charge_failure_code
        case latest_charge_outcome_type
        case latest_charge_outcome_seller_message
        case effectiveStatus = "effective_status"
    }
}

struct ConnectionTokenResponse: Decodable {
    let secret: String
}

final class Backend {
    static let shared = Backend()
    var baseURL = URL(string: "https://api.operahouseplayers.org")!
    
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 30
        return URLSession(configuration: cfg)
    }()
    
    func createPaymentIntent(amount: Int, currency: String, category: String, artNumber: Int? = nil) async throws -> PaymentIntentResponse {
        let url = baseURL.appendingPathComponent("/api/payments")
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "category": category,
        ]
        if let artNumber {
            body["description"] = "Art #\(artNumber) Sale"
        } else {
            body["description"] = category.capitalized + " Sale"
        }
        return try await post(url: url, json: body)
    }
    
    func processOnReader(paymentIntentId: String) async throws -> Bool {
        let url = baseURL.appendingPathComponent("/api/terminal/charge")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        let body: [String: Any] = [
            "payment_intent_id": paymentIntentId
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return true
    }
    
    func pollPIStatus(_ id: String) async throws -> PIStatus {
        let url = baseURL.appendingPathComponent("/api/payment_intents/\(id)")
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpMethod = "GET"
        req.timeoutInterval = 8
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PIStatus.self, from: data)
    }
    
    private func post<T: Decodable>(url: URL, json: [String: Any]) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchConnectionToken() async throws -> String {
        let url = baseURL.appendingPathComponent("/api/terminal/connection_token")
        // Backend expects a POST, even with an empty body
        let resp: ConnectionTokenResponse = try await post(url: url, json: [:])
        return resp.secret
    }
}
