import AppIntents
import Testing
@testable import SeiseiAppleIntents

@Suite("SeiseiAppleIntents")
struct SeiseiAppleIntentsTests {
    @Test("bridge forwards action payloads to the executor")
    func bridgeForwardsPayloads() async throws {
        let executor = SeiseiAppIntentExecutor { invocation in
            #expect(invocation.id == "create_note")
            #expect(invocation.arguments["title"] == .string("Roadmap"))
            #expect(invocation.metadata["surface"] == .string("shortcuts"))
            return SeiseiAppIntentResult(
                value: .string("note-1"),
                metadata: ["status": .string("created")]
            )
        }

        let result = try await SeiseiAppIntentBridge.perform(
            actionID: "create_note",
            arguments: ["title": .string("Roadmap")],
            metadata: ["surface": .string("shortcuts")],
            executor: executor
        )

        #expect(result.value == .string("note-1"))
        #expect(result.metadata["status"] == .string("created"))
        #expect(result.stringValue == "note-1")
    }

    @Test("dependency configuration accepts a host executor")
    func dependencyConfigurationAcceptsExecutor() {
        let manager = AppDependencyManager()
        let executor = SeiseiAppIntentExecutor { _ in
            SeiseiAppIntentResult(value: .string("done"))
        }

        SeiseiAppIntentDependencies.configure(
            executor: executor,
            manager: manager
        )
    }

    @Test("handwritten AppIntent types can be constructed around Seisei helpers")
    func handwrittenIntentCompiles() {
        let intent = CreateNoteIntent(
            title: "Roadmap",
            executor: SeiseiAppIntentExecutor { invocation in
                return SeiseiAppIntentResult(value: .string("done"))
            }
        )

        #expect(intent.title == "Roadmap")
    }

    @Test("shortcut providers can expose Seisei-backed intents")
    func shortcutsProviderCompiles() {
        #expect(CreateNoteShortcuts.appShortcuts.count == 1)
        #expect(CreateNoteShortcuts.shortcutTileColor == .teal)
    }

    @Test("AppIntentsPackage roots can include package types")
    func packageRootsCompile() {
        #expect(TestPackageRoot.includedPackages.count == 1)
        #expect(TestPackageRoot.includedPackages[0] == NestedPackage.self)
    }
}

private struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"

    @Parameter(title: "Title")
    var title: String

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {
        self._executor = AppDependency(default: SeiseiAppIntentExecutor { _ in
            throw TestIntentError.unconfiguredExecutor
        })
    }

    init(title: String, executor: SeiseiAppIntentExecutor) {
        self.title = title
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await SeiseiAppIntentBridge.perform(
            actionID: "create_note",
            arguments: ["title": .string(title)],
            executor: executor
        )
        return .result()
    }
}

private struct CreateNoteShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: ["Create a note in \\(.applicationName)"],
            shortTitle: "Create Note",
            systemImageName: "note.text"
        )
    }
}

private struct NestedPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [] }
}

private struct TestPackageRoot: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [NestedPackage.self] }
}

private enum TestIntentError: Error {
    case unconfiguredExecutor
}
