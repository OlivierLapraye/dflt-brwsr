import Foundation

public struct Browser: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let applicationURL: URL

    public init(id: String, name: String, applicationURL: URL) {
        self.id = id
        self.name = name
        self.applicationURL = applicationURL
    }
}

public enum WebScheme: String, CaseIterable, Sendable {
    case http, https

    // Used only to query LaunchServices. No request is sent to this address.
    public var probeURL: URL { URL(string: "\(rawValue)://example.com")! }
}

public struct BrowserDefaults: Equatable, Sendable {
    public let http: Browser?
    public let https: Browser?

    public var description: String {
        "HTTP: \(http?.name ?? "none"); HTTPS: \(https?.name ?? "none")"
    }
}

public enum BrowserError: LocalizedError, Equatable {
    case unavailable(String)
    case inconsistentDefaults(String)
    case changeFailed(browser: String, scheme: String, reason: String, current: String)
    case verificationFailed(browser: String, current: String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let identifier):
            "The browser \(identifier) is no longer installed or cannot handle both HTTP and HTTPS. Choose an installed browser again."
        case .inconsistentDefaults(let current):
            "There is no single default browser. \(current). Run Set Default Browser to set both protocols."
        case let .changeFailed(browser, scheme, reason, current):
            "Could not set \(browser) for \(scheme.uppercased()): \(reason) Current defaults — \(current). macOS may have changed one protocol before the operation stopped."
        case let .verificationFailed(browser, current):
            "macOS did not confirm \(browser) as the default for both protocols. Current defaults — \(current)."
        }
    }
}
