//
//  Backend.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import Foundation

private func managedAppConfig() -> [String: Any] {
    (UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")) ?? [:]
}

private func managedString(_ key: String) -> String? {
    (managedAppConfig()[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func envString(_ key: String) -> String? {
    let v = ProcessInfo.processInfo.environment[key]
    guard let t = v?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
    return t
}

private var POS_API_URL_VALUE: String? {
    if let v = managedString("POS_API_URL"), !v.isEmpty { return v }
    return Bundle.main.object(forInfoDictionaryKey: "POS_API_URL") as? String
}

private var POS_API_KEY_VALUE: String {
    if let v = envString("POS_API_KEY") { return v }
    if let v = managedString("POS_API_KEY"), !v.isEmpty { return v }
    if let v = Bundle.main.object(forInfoDictionaryKey: "POS_API_KEY") as? String, !v.isEmpty { return v }
    #if DEBUG
    print("Missing POS_API_KEY in Managed App Config, Info.plist, or env POS_API_KEY")
    return ""
    #else
    return ""
    #endif
}

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

// Intercepts all requests from our URLSession to guarantee required headers are present
private class HeaderInjectorURLProtocol: URLProtocol {
    private static let handledKey = "ohpos.header.injected"
    private var innerTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        // Avoid infinite loop; only handle if not already handled
        if URLProtocol.property(forKey: handledKey, in: request) as? Bool == true { return false }
        guard let host = request.url?.host else { return false }
        // Only intercept requests destined for our backend host
        let backendHost = Backend.shared.baseURL.host ?? ""
        return host == backendHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let mreq = (self.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        // mark so we don't re-inject on the same request
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mreq)

        // Always attach x-api-key
        mreq.setValue(POS_API_KEY_VALUE, forHTTPHeaderField: "x-api-key")
        // Always attach Idempotency-Key for POST if missing
        if (mreq.httpMethod.uppercased() == "POST") && (mreq.value(forHTTPHeaderField: "Idempotency-Key") == nil) {
            mreq.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }

        // Execute the real request without using this protocol again
        let cfg = URLSessionConfiguration.default
        let session = URLSession(configuration: cfg)
        let req = mreq as URLRequest
        innerTask = session.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }
            if let err = err {
                self.client?.urlProtocol(self, didFailWithError: err)
                return
            }
            if let resp = resp {
                self.client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        innerTask?.resume()
    }

    override func stopLoading() {
        innerTask?.cancel()
    }
}

final class Backend {
    static let shared = Backend()
    var baseURL: URL {
        if let s = POS_API_URL_VALUE, let u = URL(string: s) { return u }
        return URL(string: "https://api.operahouseplayers.org")!
    }

    /// True when a usable POS API key is available from env, Managed App Config, or Info.plist
    var isConfigured: Bool { !POS_API_KEY_VALUE.isEmpty }
    
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 30
        // Ensure header injection on every request & across redirects
        var protocols = cfg.protocolClasses ?? []
        protocols.insert(HeaderInjectorURLProtocol.self, at: 0)
        cfg.protocolClasses = protocols
        return URLSession(configuration: cfg)
    }()
    
    func createPaymentIntent(amount: Int, currency: String, category: String, artNumber: Int? = nil) async throws -> PaymentIntentResponse {
        let url = baseURL.appendingPathComponent("api/payments")
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
        let url = baseURL.appendingPathComponent("api/terminal/charge")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(POS_API_KEY_VALUE, forHTTPHeaderField: "x-api-key")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
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
        let url = baseURL.appendingPathComponent("api/payment_intents/\(id)")
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(POS_API_KEY_VALUE, forHTTPHeaderField: "x-api-key")
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
        req.setValue(POS_API_KEY_VALUE, forHTTPHeaderField: "x-api-key")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.timeoutInterval = 12
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchConnectionToken() async throws -> String {
        let url = baseURL.appendingPathComponent("api/terminal/connection_token")
        // Backend expects a POST, even with an empty body
        let resp: ConnectionTokenResponse = try await post(url: url, json: [:])
        return resp.secret
    }
    
    func debugPOSKeySource() {
        let env = envString("POS_API_KEY")
        let managed = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")
        let plist = Bundle.main.object(forInfoDictionaryKey: "POS_API_KEY") as? String

        print("BundleID:", Bundle.main.bundleIdentifier ?? "<nil>")
        print("ENV:", env ?? "nil")
        print("Managed.POS_API_KEY:", (managed?["POS_API_KEY"] as? String) ?? "nil")
        print("Info.plist:", plist ?? "nil")
        print("Resolved (POS_API_KEY_VALUE):", POS_API_KEY_VALUE)
    }
}
