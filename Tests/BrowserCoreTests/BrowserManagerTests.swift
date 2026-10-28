import Foundation
import Testing
@testable import BrowserCore

@MainActor
@Suite("Browser management")
struct BrowserManagerTests {
    let safari = Browser(id: "com.apple.Safari", name: "Safari", applicationURL: URL(filePath: "/Applications/Safari.app"))
    let chrome = Browser(id: "com.google.Chrome", name: "Google Chrome", applicationURL: URL(filePath: "/Applications/Google Chrome.app"))

    private func setup() -> (MockWorkspace, BrowserManager) {
        let workspace = MockWorkspace()
        workspace.candidates = [.http: [safari, chrome], .https: [safari, chrome]]
        workspace.defaults = [.http: safari, .https: safari]
        return (workspace, BrowserManager(workspace: workspace, verificationAttempts: 2, verificationDelay: .zero))
    }

    @Test func discoversOnlyAppsSupportingBothSchemes() {
        let (workspace, manager) = setup()
        workspace.candidates[.https] = [safari]
        #expect(manager.installedBrowsers() == [safari])
    }

    @Test func deduplicatesByIdentifierAndUsesPreferredInstallation() {
        let (workspace, manager) = setup()
        let copy = Browser(id: chrome.id, name: chrome.name, applicationURL: URL(filePath: "/Users/test/Applications/Google Chrome.app"))
        workspace.candidates = [.http: [copy, safari, chrome], .https: [chrome, copy, safari]]
        workspace.preferred[chrome.id] = chrome.applicationURL
        #expect(manager.installedBrowsers() == [chrome, safari])
    }

    @Test func doesNotCombineSchemesFromDifferentCopies() {
        let (workspace, manager) = setup()
        let copy = Browser(id: chrome.id, name: chrome.name, applicationURL: URL(filePath: "/Users/test/Applications/Google Chrome.app"))
        workspace.candidates = [.http: [chrome], .https: [copy]]
        #expect(manager.installedBrowsers().isEmpty)
    }

    @Test func changesBothSchemesAndReturnsVerifiedBrowser() async throws {
        let (workspace, manager) = setup()
        let result = try await manager.setDefaultBrowser(identifier: chrome.id)
        #expect(result == chrome)
        #expect(workspace.changes == [.http, .https])
        #expect(try manager.currentBrowser() == chrome)
    }

    @Test func alreadyDefaultDoesNotRequestConsent() async throws {
        let (workspace, manager) = setup()
        _ = try await manager.setDefaultBrowser(identifier: safari.id)
        #expect(workspace.changes.isEmpty)
    }

    @Test func repairsOnlyTheMismatchedScheme() async throws {
        let (workspace, manager) = setup()
        workspace.defaults[.http] = chrome
        _ = try await manager.setDefaultBrowser(identifier: chrome.id)
        #expect(workspace.changes == [.https])
    }

    @Test func rejectsRemovedBrowserBeforeAnyChanges() async {
        let (workspace, manager) = setup()
        await #expect(throws: BrowserError.unavailable("missing.browser")) {
            try await manager.setDefaultBrowser(identifier: "missing.browser")
        }
        #expect(workspace.changes.isEmpty)
    }

    @Test func reportsSplitDefaults() {
        let (workspace, manager) = setup()
        workspace.defaults[.https] = chrome
        #expect(throws: BrowserError.inconsistentDefaults("HTTP: Safari; HTTPS: Google Chrome")) {
            try manager.currentBrowser()
        }
    }

    @Test func reportsMissingDefault() {
        let (workspace, manager) = setup()
        workspace.defaults[.http] = nil
        #expect(throws: BrowserError.inconsistentDefaults("HTTP: none; HTTPS: Safari")) {
            try manager.currentBrowser()
        }
    }

    @Test func denialStopsBeforeChangingSecondScheme() async {
        let (workspace, manager) = setup()
        workspace.failure = .http
        await #expect(throws: BrowserError.changeFailed(
            browser: chrome.name, scheme: "http", reason: "Consent denied.",
            current: "HTTP: Safari; HTTPS: Safari"
        )) { try await manager.setDefaultBrowser(identifier: chrome.id) }
        #expect(workspace.changes == [.http])
    }

    @Test func reportsPartialChangeWithoutSilentlyRollingBack() async {
        let (workspace, manager) = setup()
        workspace.failure = .https
        await #expect(throws: BrowserError.changeFailed(
            browser: chrome.name, scheme: "https", reason: "Consent denied.",
            current: "HTTP: Google Chrome; HTTPS: Safari"
        )) { try await manager.setDefaultBrowser(identifier: chrome.id) }
        #expect(workspace.changes == [.http, .https])
        #expect(workspace.defaults[.http] == chrome)
    }

    @Test func successfulAPICallbackDoesNotCountAsVerifiedSuccess() async {
        let (workspace, manager) = setup()
        workspace.ignoresChanges = true
        await #expect(throws: BrowserError.verificationFailed(
            browser: chrome.name, current: "HTTP: Safari; HTTPS: Safari"
        )) { try await manager.setDefaultBrowser(identifier: chrome.id) }
    }

    @Test func waitsForDelayedDefaultPublication() async throws {
        let (workspace, manager) = setup()
        workspace.delaysPublication = true
        #expect(try await manager.setDefaultBrowser(identifier: chrome.id) == chrome)
    }

    @Test func sameBundleIdentifierAtDifferentPathsIsNotOneDefault() {
        let (workspace, manager) = setup()
        workspace.defaults[.https] = Browser(id: safari.id, name: safari.name, applicationURL: URL(filePath: "/Other/Safari.app"))
        #expect(throws: BrowserError.inconsistentDefaults("HTTP: Safari; HTTPS: Safari")) {
            try manager.currentBrowser()
        }
    }
}

@MainActor
private final class MockWorkspace: BrowserWorkspace {
    var candidates: [WebScheme: [Browser]] = [:]
    var defaults: [WebScheme: Browser] = [:]
    var preferred: [String: URL] = [:]
    var changes: [WebScheme] = []
    var failure: WebScheme?
    var ignoresChanges = false
    var delaysPublication = false
    private var pending: [WebScheme: Browser] = [:]

    func applications(for scheme: WebScheme) -> [Browser] { candidates[scheme] ?? [] }
    func preferredApplicationURL(for identifier: String) -> URL? { preferred[identifier] }

    func defaultApplication(for scheme: WebScheme) -> Browser? {
        let current = defaults[scheme]
        if let update = pending.removeValue(forKey: scheme) { defaults[scheme] = update }
        return current
    }

    func setDefaultApplication(_ browser: Browser, for scheme: WebScheme) async throws {
        changes.append(scheme)
        if failure == scheme { throw ConsentError() }
        if ignoresChanges { return }
        if delaysPublication { pending[scheme] = browser }
        else { defaults[scheme] = browser }
    }
}

private struct ConsentError: LocalizedError {
    var errorDescription: String? { "Consent denied." }
}
