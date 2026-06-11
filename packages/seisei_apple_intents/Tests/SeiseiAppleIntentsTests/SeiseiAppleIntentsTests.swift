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

    @Test("source generator emits build-time AppIntent wrappers")
    func sourceGeneratorEmitsAppIntentWrapper() {
        let source = SeiseiAppIntentSourceGenerator.source(
            for: SeiseiGeneratedAppIntentDefinition(
                typeName: "CreateNoteIntent",
                actionID: "create_note",
                title: "Create Note",
                description: "Create a note from a title.",
                parameters: [
                    SeiseiGeneratedAppIntentParameter(
                        name: "title",
                        title: "Title",
                        type: .string
                    ),
                    SeiseiGeneratedAppIntentParameter(
                        name: "priority",
                        title: "Priority",
                        type: .integer,
                        isRequired: false
                    ),
                ],
                shortcut: SeiseiGeneratedAppShortcutDefinition(
                    phrases: ["Create a note in \\(.applicationName)"],
                    shortTitle: "Create Note",
                    systemImageName: "note.text"
                )
            )
        )

        #expect(source.contains("public struct CreateNoteIntent: AppIntent"))
        #expect(source.contains("@Parameter(title: \"Title\")"))
        #expect(source.contains("public var title: String"))
        #expect(source.contains("public var priority: Int?"))
        #expect(source.contains("\"title\": .string(title)"))
        #expect(source.contains("\"priority\": priority.map { .integer($0) } ?? .null"))
        #expect(source.contains("public struct CreateNoteIntentShortcuts: AppShortcutsProvider"))
        #expect(source.contains("phrases: [\"Create a note in \\\\(.applicationName)\"]"))
    }

    @Test("source generator emits AppEnum wrappers for string enum parameters")
    func sourceGeneratorEmitsAppEnumWrapper() {
        let source = SeiseiAppIntentSourceGenerator.source(
            for: SeiseiGeneratedAppIntentDefinition(
                typeName: "UpdateNoteIntent",
                actionID: "update_note",
                title: "Update Note",
                description: "Update note status.",
                parameters: [
                    SeiseiGeneratedAppIntentParameter(
                        name: "status",
                        title: "Status",
                        type: .stringEnum(
                            typeName: "NoteStatus",
                            cases: [
                                SeiseiGeneratedAppIntentEnumCase(
                                    name: "draft",
                                    rawValue: "draft",
                                    title: "Draft"
                                ),
                                SeiseiGeneratedAppIntentEnumCase(
                                    name: "published",
                                    rawValue: "published",
                                    title: "Published"
                                ),
                            ],
                            displayName: "Note Status"
                        )
                    ),
                ]
            )
        )

        #expect(source.contains("public enum NoteStatus: String, AppEnum {"))
        #expect(source.contains("public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: \"Note Status\")"))
        #expect(source.contains("case draft = \"draft\""))
        #expect(source.contains(".published: \"Published\""))
        #expect(source.contains("public var status: NoteStatus"))
        #expect(source.contains("\"status\": .string(status.rawValue)"))
    }

    @Test("generated-style AppIntent wrappers compile")
    func generatedStyleIntentCompiles() {
        let intent = GeneratedStyleCreateNoteIntent(
            title: "Roadmap",
            priority: nil,
            executor: SeiseiAppIntentExecutor { invocation in
                #expect(invocation.id == "create_note")
                #expect(invocation.arguments["title"] == .string("Roadmap"))
                #expect(invocation.arguments["priority"] == .null)
                return SeiseiAppIntentResult()
            }
        )

        #expect(intent.title == "Roadmap")
        #expect(intent.priority == nil)
    }

    @Test("generated-style AppIntent enum wrappers compile")
    func generatedStyleEnumIntentCompiles() {
        let intent = GeneratedStyleUpdateNoteIntent(
            status: .published,
            executor: SeiseiAppIntentExecutor { invocation in
                #expect(invocation.id == "update_note")
                #expect(invocation.arguments["status"] == .string("published"))
                return SeiseiAppIntentResult()
            }
        )

        #expect(intent.status == .published)
    }

    @Test("generated-style shortcut providers compile")
    func generatedStyleShortcutProviderCompiles() {
        #expect(GeneratedStyleCreateNoteIntentShortcuts.appShortcuts.count == 1)
    }

    @Test("source generator escapes Swift string literals")
    func sourceGeneratorEscapesStringLiterals() {
        let source = SeiseiAppIntentSourceGenerator.source(
            for: SeiseiGeneratedAppIntentDefinition(
                typeName: "QuoteIntent",
                actionID: "quote_action",
                title: "Quote \"Line\"",
                description: "Line 1\nLine 2",
                parameters: []
            ),
            accessLevel: "internal"
        )

        #expect(source.contains("internal struct QuoteIntent: AppIntent"))
        #expect(source.contains("LocalizedStringResource = \"Quote \\\"Line\\\"\""))
        #expect(source.contains("IntentDescription(\"Line 1\\nLine 2\")"))
        #expect(source.contains("arguments: [:]"))
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

private struct GeneratedStyleCreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription("Create a note from a title.")

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Priority")
    var priority: Int?

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {
        self._executor = AppDependency(default: SeiseiAppIntentExecutor { _ in
            throw TestIntentError.unconfiguredExecutor
        })
    }

    init(
        title: String,
        priority: Int?,
        executor: SeiseiAppIntentExecutor
    ) {
        self.title = title
        self.priority = priority
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await SeiseiAppIntentBridge.perform(
            actionID: "create_note",
            arguments: [
                "title": .string(title),
                "priority": priority.map { .integer($0) } ?? .null,
            ],
            executor: executor
        )
        return .result()
    }
}

private struct GeneratedStyleCreateNoteIntentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GeneratedStyleCreateNoteIntent(),
            phrases: ["Create a note in \\(.applicationName)"],
            shortTitle: "Create Note",
            systemImageName: "note.text"
        )
    }
}

private enum GeneratedStyleNoteStatus: String, AppEnum {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note Status")

    static var caseDisplayRepresentations: [GeneratedStyleNoteStatus: DisplayRepresentation] {
        [
            .draft: "Draft",
            .published: "Published",
        ]
    }

    case draft = "draft"
    case published = "published"
}

private struct GeneratedStyleUpdateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Note"
    static let description = IntentDescription("Update note status.")

    @Parameter(title: "Status")
    var status: GeneratedStyleNoteStatus

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {
        self._executor = AppDependency(default: SeiseiAppIntentExecutor { _ in
            throw TestIntentError.unconfiguredExecutor
        })
    }

    init(status: GeneratedStyleNoteStatus, executor: SeiseiAppIntentExecutor) {
        self.status = status
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await SeiseiAppIntentBridge.perform(
            actionID: "update_note",
            arguments: ["status": .string(status.rawValue)],
            executor: executor
        )
        return .result()
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
