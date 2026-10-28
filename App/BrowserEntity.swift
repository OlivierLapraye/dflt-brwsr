import AppIntents

struct BrowserEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Browser"
    static let defaultQuery = BrowserQuery()

    let id: String
    @Property(title: "Name") var name: String
    @Property(title: "Bundle Identifier") var bundleIdentifier: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(bundleIdentifier)")
    }

    init(browser: Browser) {
        id = browser.id
        name = browser.name
        bundleIdentifier = browser.id
    }
}

struct BrowserQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [BrowserEntity] {
        let browsers = await BrowserManager.shared.installedBrowsers()
        return identifiers.compactMap { identifier in
            browsers.first { $0.id == identifier }.map(BrowserEntity.init)
        }
    }

    func suggestedEntities() async throws -> [BrowserEntity] {
        await BrowserManager.shared.installedBrowsers().map(BrowserEntity.init)
    }

    func entities(matching string: String) async throws -> [BrowserEntity] {
        let browsers = await BrowserManager.shared.installedBrowsers()
        return browsers.filter {
            string.isEmpty || $0.name.localizedCaseInsensitiveContains(string)
                || $0.id.localizedCaseInsensitiveContains(string)
        }.map(BrowserEntity.init)
    }
}
