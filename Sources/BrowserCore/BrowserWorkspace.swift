import AppKit

@MainActor
public protocol BrowserWorkspace {
    func applications(for scheme: WebScheme) -> [Browser]
    func defaultApplication(for scheme: WebScheme) -> Browser?
    func preferredApplicationURL(for identifier: String) -> URL?
    func setDefaultApplication(_ browser: Browser, for scheme: WebScheme) async throws
}

@MainActor
public final class SystemBrowserWorkspace: BrowserWorkspace {
    public init() {}

    public func applications(for scheme: WebScheme) -> [Browser] {
        NSWorkspace.shared.urlsForApplications(toOpen: scheme.probeURL).compactMap(browser(at:))
    }

    public func defaultApplication(for scheme: WebScheme) -> Browser? {
        NSWorkspace.shared.urlForApplication(toOpen: scheme.probeURL).flatMap(browser(at:))
    }

    public func preferredApplicationURL(for identifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    public func setDefaultApplication(_ browser: Browser, for scheme: WebScheme) async throws {
        try await NSWorkspace.shared.setDefaultApplication(
            at: browser.applicationURL,
            toOpenURLsWithScheme: scheme.rawValue
        )
    }

    private func browser(at url: URL) -> Browser? {
        guard FileManager.default.fileExists(atPath: url.path),
              let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return Browser(id: identifier, name: name, applicationURL: url)
    }
}
