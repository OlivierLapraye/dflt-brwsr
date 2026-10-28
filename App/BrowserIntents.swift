import AppIntents

struct SetDefaultBrowserIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Default Browser"
    static let description = IntentDescription(
        "Set an installed browser as the default for HTTP and HTTPS. macOS may ask you to confirm the change."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Browser") var browser: BrowserEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set default browser to \(\.$browser)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<BrowserEntity> {
        let selected = try await BrowserManager.shared.setDefaultBrowser(identifier: browser.id)
        return .result(value: BrowserEntity(browser: selected))
    }
}

struct GetDefaultBrowserIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Default Browser"
    static let description = IntentDescription(
        "Return the current default browser. Reports an error if HTTP and HTTPS use different apps."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<BrowserEntity> {
        let browser = try await BrowserManager.shared.currentBrowser()
        return .result(value: BrowserEntity(browser: browser))
    }
}

struct ListInstalledBrowsersIntent: AppIntent {
    static let title: LocalizedStringResource = "List Installed Browsers"
    static let description = IntentDescription("Return installed apps that can open both HTTP and HTTPS links.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<[BrowserEntity]> {
        let browsers = await BrowserManager.shared.installedBrowsers()
        return .result(value: browsers.map(BrowserEntity.init))
    }
}

struct BrowserShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetDefaultBrowserIntent(),
            phrases: ["Set my default browser with \(.applicationName)"],
            shortTitle: "Set Default Browser",
            systemImageName: "globe"
        )
        AppShortcut(
            intent: GetDefaultBrowserIntent(),
            phrases: ["Get my default browser with \(.applicationName)"],
            shortTitle: "Get Default Browser",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: ListInstalledBrowsersIntent(),
            phrases: ["List browsers with \(.applicationName)"],
            shortTitle: "List Installed Browsers",
            systemImageName: "list.bullet"
        )
    }
}
