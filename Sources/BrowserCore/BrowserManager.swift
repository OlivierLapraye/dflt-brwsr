import Foundation

@MainActor
public final class BrowserManager {
    public static let shared = BrowserManager(workspace: SystemBrowserWorkspace())
    private let workspace: any BrowserWorkspace
    private let verificationAttempts: Int
    private let verificationDelay: Duration
    private var isChanging = false

    public init(
        workspace: any BrowserWorkspace,
        verificationAttempts: Int = 10,
        verificationDelay: Duration = .milliseconds(100)
    ) {
        self.workspace = workspace
        self.verificationAttempts = max(1, verificationAttempts)
        self.verificationDelay = verificationDelay
    }

    public func installedBrowsers() -> [Browser] {
        let httpsURLs = Set(workspace.applications(for: .https).map { canonicalURL($0.applicationURL) })
        let candidates = workspace.applications(for: .http).filter {
            httpsURLs.contains(canonicalURL($0.applicationURL))
        }
        // Stable identifiers let saved Shortcuts survive app moves and upgrades.
        let groups = Dictionary(grouping: candidates, by: \.id)
        return groups.values.compactMap { copies in
            guard let first = copies.first else { return nil }
            if let preferred = workspace.preferredApplicationURL(for: first.id),
               let match = copies.first(where: { canonicalURL($0.applicationURL) == canonicalURL(preferred) }) {
                return match
            }
            return copies.sorted { $0.applicationURL.path < $1.applicationURL.path }.first
        }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    public func defaults() -> BrowserDefaults {
        BrowserDefaults(
            http: workspace.defaultApplication(for: .http),
            https: workspace.defaultApplication(for: .https)
        )
    }

    public func currentBrowser() throws -> Browser {
        let current = defaults()
        guard let http = current.http, let https = current.https,
              sameApplication(http, https) else {
            throw BrowserError.inconsistentDefaults(current.description)
        }
        return https
    }

    @discardableResult
    public func setDefaultBrowser(identifier: String) async throws -> Browser {
        // The main actor is reentrant: serialize overlapping Shortcuts while awaiting consent.
        while isChanging {
            try await Task.sleep(for: .milliseconds(100))
        }
        isChanging = true
        defer { isChanging = false }
        try Task.checkCancellation()

        guard let browser = installedBrowsers().first(where: { $0.id == identifier }) else {
            throw BrowserError.unavailable(identifier)
        }
        for scheme in WebScheme.allCases {
            try Task.checkCancellation()
            if let current = workspace.defaultApplication(for: scheme), sameApplication(current, browser) {
                continue
            }
            do {
                try await workspace.setDefaultApplication(browser, for: scheme)
            } catch {
                throw BrowserError.changeFailed(
                    browser: browser.name, scheme: scheme.rawValue,
                    reason: error.localizedDescription, current: defaults().description
                )
            }
        }
        // LaunchServices can take a moment to publish its updated associations.
        for attempt in 0..<verificationAttempts {
            try Task.checkCancellation()
            if let current = try? currentBrowser(), sameApplication(current, browser) { return current }
            if attempt + 1 < verificationAttempts {
                try await Task.sleep(for: verificationDelay)
            }
        }
        throw BrowserError.verificationFailed(browser: browser.name, current: defaults().description)
    }

    private func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func sameApplication(_ lhs: Browser, _ rhs: Browser) -> Bool {
        lhs.id == rhs.id && canonicalURL(lhs.applicationURL) == canonicalURL(rhs.applicationURL)
    }
}
