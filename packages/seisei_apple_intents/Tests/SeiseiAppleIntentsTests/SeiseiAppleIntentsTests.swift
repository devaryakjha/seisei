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

    @Test("entity query executor forwards host-backed resolution requests")
    func entityQueryExecutorForwardsRequests() async throws {
        let executor = SeiseiAppEntityQueryExecutor { invocation in
            #expect(invocation.entityTypeID == "note")
            #expect(invocation.mode == .search)
            #expect(invocation.searchTerm == "road")
            return [
                SeiseiAppEntityResolution(
                    id: "note-1",
                    title: "Roadmap",
                    subtitle: "Planning"
                ),
            ]
        }

        let result = try await executor.resolve(
            SeiseiAppEntityQueryInvocation(
                entityTypeID: "note",
                mode: .search,
                searchTerm: "road"
            )
        )

        #expect(result == [
            SeiseiAppEntityResolution(
                id: "note-1",
                title: "Roadmap",
                subtitle: "Planning"
            ),
        ])
    }

    @Test("entity query dependency configuration accepts a host executor")
    func entityQueryDependencyConfigurationAcceptsExecutor() {
        let manager = AppDependencyManager()
        let executor = SeiseiAppEntityQueryExecutor { _ in [] }

        SeiseiAppEntityQueryDependencies.configure(
            executor: executor,
            manager: manager
        )
    }

    @Test("app action invocation converts to Flutter method-channel arguments")
    func invocationConvertsToMethodChannelArguments() throws {
        let invocation = SeiseiAppIntentInvocation(
            id: "open_note",
            arguments: [
                "note": .string("note-1"),
                "count": .integer(2),
                "published": .boolean(true),
                "tags": .array([.string("roadmap"), .null]),
                "extra": .object(["rank": .number(1.5)]),
            ],
            toolCallID: "tool-1",
            metadata: ["surface": .string("shortcuts")]
        )

        let arguments = invocation.methodChannelArguments
        let decoded = try SeiseiAppIntentInvocation(methodChannelArguments: arguments)
        let rawArguments = try #require(arguments["arguments"] as? [String: Any])
        let rawTags = try #require(rawArguments["tags"] as? [Any])

        #expect(arguments["id"] as? String == "open_note")
        #expect(arguments["toolCallId"] as? String == "tool-1")
        #expect(rawArguments["note"] as? String == "note-1")
        #expect(rawArguments["count"] as? Int == 2)
        #expect(rawArguments["published"] as? Bool == true)
        #expect(rawTags[0] as? String == "roadmap")
        #expect(rawTags[1] is NSNull)
        #expect(decoded == invocation)
    }

    @Test("app action result converts from Flutter method-channel results")
    func resultConvertsFromMethodChannelResult() throws {
        let result = try SeiseiAppIntentResult(methodChannelResult: [
            "value": ["opened": "note-1"],
            "metadata": ["status": "ok"],
        ])

        let encoded = result.methodChannelResult
        let rawValue = try #require(encoded["value"] as? [String: Any])
        let rawMetadata = try #require(encoded["metadata"] as? [String: Any])

        #expect(result.value == .object(["opened": .string("note-1")]))
        #expect(result.metadata == ["status": .string("ok")])
        #expect(rawValue["opened"] as? String == "note-1")
        #expect(rawMetadata["status"] as? String == "ok")
    }

    @Test("entity query invocation converts to Flutter method-channel arguments")
    func entityQueryConvertsToMethodChannelArguments() throws {
        let invocation = SeiseiAppEntityQueryInvocation(
            entityTypeID: "note",
            mode: .search,
            identifiers: ["note-1"],
            searchTerm: "road",
            metadata: ["surface": .string("spotlight")]
        )

        let arguments = invocation.methodChannelArguments
        let decoded = try SeiseiAppEntityQueryInvocation(methodChannelArguments: arguments)
        let rawMetadata = try #require(arguments["metadata"] as? [String: Any])

        #expect(arguments["entityTypeID"] as? String == "note")
        #expect(arguments["mode"] as? String == "search")
        #expect(arguments["identifiers"] as? [String] == ["note-1"])
        #expect(arguments["searchTerm"] as? String == "road")
        #expect(rawMetadata["surface"] as? String == "spotlight")
        #expect(decoded == invocation)
    }

    @Test("entity resolutions convert from Flutter method-channel results")
    func entityResolutionConvertsFromMethodChannelResult() throws {
        let resolution = try SeiseiAppEntityResolution(methodChannelResult: [
            "id": "note-1",
            "title": "Roadmap",
            "subtitle": "Planning",
            "metadata": ["rank": 1],
        ])

        let encoded = resolution.methodChannelResult
        let rawMetadata = try #require(encoded["metadata"] as? [String: Any])

        #expect(resolution.id == "note-1")
        #expect(resolution.title == "Roadmap")
        #expect(resolution.subtitle == "Planning")
        #expect(resolution.metadata == ["rank": .integer(1)])
        #expect(encoded["id"] as? String == "note-1")
        #expect(encoded["title"] as? String == "Roadmap")
        #expect(encoded["subtitle"] as? String == "Planning")
        #expect(rawMetadata["rank"] as? Int == 1)
    }

    @Test("Flutter method-channel action executor forwards canonical calls")
    func flutterMethodChannelActionExecutorForwardsCanonicalCalls() async throws {
        let executor = SeiseiAppIntentExecutor.flutterMethodChannel { method, arguments in
            #expect(method == SeiseiFlutterIntentsWire.invokeActionMethod)
            #expect(arguments["id"] as? String == "open_note")
            #expect(arguments["toolCallId"] as? String == "tool-1")
            let rawArguments = try #require(arguments["arguments"] as? [String: Any])
            #expect(rawArguments["note"] as? String == "note-1")
            return [
                "value": ["opened": "note-1"],
                "metadata": ["surface": "shortcuts"],
            ]
        }

        let result = try await executor.run(
            SeiseiAppIntentInvocation(
                id: "open_note",
                arguments: ["note": .string("note-1")],
                toolCallID: "tool-1"
            )
        )

        #expect(SeiseiFlutterIntentsWire.channelName == "dev.jha.seisei/seisei_flutter_intents")
        #expect(result.value == .object(["opened": .string("note-1")]))
        #expect(result.metadata == ["surface": .string("shortcuts")])
    }

    @Test("Flutter method-channel entity executor forwards canonical calls")
    func flutterMethodChannelEntityExecutorForwardsCanonicalCalls() async throws {
        let executor = SeiseiAppEntityQueryExecutor.flutterMethodChannel { method, arguments in
            #expect(method == SeiseiFlutterIntentsWire.resolveEntityQueryMethod)
            #expect(arguments["entityTypeID"] as? String == "note")
            #expect(arguments["mode"] as? String == "search")
            #expect(arguments["searchTerm"] as? String == "road")
            return [
                [
                    "id": "note-1",
                    "title": "Roadmap",
                    "subtitle": "Planning",
                    "metadata": ["rank": 1],
                ],
            ]
        }

        let result = try await executor.resolve(
            SeiseiAppEntityQueryInvocation(
                entityTypeID: "note",
                mode: .search,
                searchTerm: "road"
            )
        )

        #expect(result == [
            SeiseiAppEntityResolution(
                id: "note-1",
                title: "Roadmap",
                subtitle: "Planning",
                metadata: ["rank": .integer(1)]
            ),
        ])
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
                    SeiseiGeneratedAppIntentParameter(
                        name: "tags",
                        title: "Tags",
                        type: .stringArray,
                        isRequired: false
                    ),
                    SeiseiGeneratedAppIntentParameter(
                        name: "ranks",
                        title: "Ranks",
                        type: .integerArray,
                        isRequired: false
                    ),
                    SeiseiGeneratedAppIntentParameter(
                        name: "weights",
                        title: "Weights",
                        type: .numberArray,
                        isRequired: false
                    ),
                    SeiseiGeneratedAppIntentParameter(
                        name: "flags",
                        title: "Flags",
                        type: .booleanArray,
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
        #expect(source.contains("public var tags: [String]?"))
        #expect(source.contains("public var ranks: [Int]?"))
        #expect(source.contains("public var weights: [Double]?"))
        #expect(source.contains("public var flags: [Bool]?"))
        #expect(source.contains("\"title\": .string(title)"))
        #expect(source.contains("\"priority\": priority.map { .integer($0) } ?? .null"))
        #expect(source.contains("\"tags\": tags.map { .array($0.map { .string($0) }) } ?? .null"))
        #expect(source.contains("\"ranks\": ranks.map { .array($0.map { .integer($0) }) } ?? .null"))
        #expect(source.contains("\"weights\": weights.map { .array($0.map { .number($0) }) } ?? .null"))
        #expect(source.contains("\"flags\": flags.map { .array($0.map { .boolean($0) }) } ?? .null"))
        #expect(source.contains("self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: \"create_note\"))"))
        #expect(source.contains("executor: SeiseiAppIntentExecutor"))
        #expect(source.contains("self._executor = AppDependency(default: executor)"))
        #expect(source.contains("public func seiseiInvocation() -> SeiseiAppIntentInvocation"))
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

    @Test("source generator emits AppEntity wrappers for string entity parameters")
    func sourceGeneratorEmitsAppEntityWrapper() {
        let source = SeiseiAppIntentSourceGenerator.source(
            for: SeiseiGeneratedAppIntentDefinition(
                typeName: "OpenNoteIntent",
                actionID: "open_note",
                title: "Open Note",
                description: "Open a note.",
                parameters: [
                    SeiseiGeneratedAppIntentParameter(
                        name: "note",
                        title: "Note",
                        type: .stringEntity(
                            typeName: "NoteEntity",
                            cases: [
                                SeiseiGeneratedAppIntentEntityCase(
                                    name: "roadmap",
                                    rawValue: "note-1",
                                    title: "Roadmap"
                                ),
                            ],
                            displayName: "Note"
                        )
                    ),
                ]
            )
        )

        #expect(source.contains("public enum NoteEntity: String, AppEntity, AppEnum {"))
        #expect(source.contains("public typealias DefaultQuery = _RawRepresentableStringQuery<NoteEntity>"))
        #expect(source.contains("case roadmap = \"note-1\""))
        #expect(source.contains("public var note: NoteEntity"))
        #expect(source.contains("\"note\": .string(note.rawValue)"))
    }

    @Test("source generator emits host-backed AppEntity queries for string entity parameters")
    func sourceGeneratorEmitsHostBackedAppEntityQuery() {
        let source = SeiseiAppIntentSourceGenerator.source(
            for: SeiseiGeneratedAppIntentDefinition(
                typeName: "OpenNoteIntent",
                actionID: "open_note",
                title: "Open Note",
                description: "Open a note.",
                parameters: [
                    SeiseiGeneratedAppIntentParameter(
                        name: "note",
                        title: "Note",
                        type: .hostBackedStringEntity(
                            typeName: "NoteEntity",
                            displayName: "Note",
                            entityTypeID: "note"
                        )
                    ),
                ]
            )
        )

        #expect(source.contains("public struct NoteEntity: AppEntity {"))
        #expect(source.contains("public typealias DefaultQuery = NoteEntityQuery"))
        #expect(source.contains("public static var defaultQuery = NoteEntityQuery()"))
        #expect(source.contains("public struct NoteEntityQuery: EntityStringQuery {"))
        #expect(source.contains("private var entityExecutor: SeiseiAppEntityQueryExecutor"))
        #expect(source.contains("entityTypeID: \"note\""))
        #expect(source.contains("mode: .search"))
        #expect(source.contains("public var note: NoteEntity"))
        #expect(source.contains("\"note\": .string(note.id)"))
    }

    @Test("generated-style AppIntent wrappers compile")
    func generatedStyleIntentCompiles() {
        let intent = GeneratedStyleCreateNoteIntent(
            title: "Roadmap",
            priority: nil,
            tags: nil,
            ranks: nil,
            weights: nil,
            flags: nil,
            executor: SeiseiAppIntentExecutor { invocation in
                #expect(invocation.id == "create_note")
                #expect(invocation.arguments["title"] == .string("Roadmap"))
                #expect(invocation.arguments["priority"] == .null)
                #expect(invocation.arguments["tags"] == .null)
                #expect(invocation.arguments["ranks"] == .null)
                #expect(invocation.arguments["weights"] == .null)
                #expect(invocation.arguments["flags"] == .null)
                return SeiseiAppIntentResult()
            }
        )

        #expect(intent.title == "Roadmap")
        #expect(intent.priority == nil)
        #expect(intent.tags == nil)
        #expect(intent.ranks == nil)
        #expect(intent.weights == nil)
        #expect(intent.flags == nil)
    }

    @Test("generated-style AppIntent builds a testable invocation")
    func generatedStyleIntentBuildsInvocation() {
        let intent = GeneratedStyleCreateNoteIntent(
            title: "Roadmap",
            priority: 2,
            tags: ["planning", "draft"],
            ranks: [1, 2],
            weights: [0.25, 0.75],
            flags: [true, false],
            executor: SeiseiAppIntentExecutor { _ in SeiseiAppIntentResult() }
        )

        let invocation = intent.seiseiInvocation()

        #expect(invocation.id == "create_note")
        #expect(invocation.arguments["title"] == .string("Roadmap"))
        #expect(invocation.arguments["priority"] == .integer(2))
        #expect(invocation.arguments["tags"] == .array([
            .string("planning"),
            .string("draft"),
        ]))
        #expect(invocation.arguments["ranks"] == .array([
            .integer(1),
            .integer(2),
        ]))
        #expect(invocation.arguments["weights"] == .array([
            .number(0.25),
            .number(0.75),
        ]))
        #expect(invocation.arguments["flags"] == .array([
            .boolean(true),
            .boolean(false),
        ]))
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

    @Test("generated-style AppIntent entity wrappers compile")
    func generatedStyleEntityIntentCompiles() {
        let intent = GeneratedStyleOpenNoteIntent(
            note: .roadmap,
            executor: SeiseiAppIntentExecutor { invocation in
                #expect(invocation.id == "open_note")
                #expect(invocation.arguments["note"] == .string("note-1"))
                return SeiseiAppIntentResult()
            }
        )

        let invocation = intent.seiseiInvocation()

        #expect(intent.note == .roadmap)
        #expect(invocation.arguments["note"] == .string("note-1"))
    }

    @Test("generated-style host-backed AppEntity wrappers compile")
    func generatedStyleHostBackedEntityIntentCompiles() {
        let note = GeneratedStyleDynamicNoteEntity(
            id: "note-1",
            title: "Roadmap",
            subtitle: "Planning"
        )
        let intent = GeneratedStyleOpenDynamicNoteIntent(
            note: note,
            executor: SeiseiAppIntentExecutor { invocation in
                #expect(invocation.id == "open_dynamic_note")
                #expect(invocation.arguments["note"] == .string("note-1"))
                return SeiseiAppIntentResult()
            }
        )

        let invocation = intent.seiseiInvocation()

        #expect(intent.note.id == "note-1")
        #expect(invocation.arguments["note"] == .string("note-1"))
        _ = GeneratedStyleDynamicNoteEntityQuery()
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
        self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: "create_note"))
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

    @Parameter(title: "Tags")
    var tags: [String]?

    @Parameter(title: "Ranks")
    var ranks: [Int]?

    @Parameter(title: "Weights")
    var weights: [Double]?

    @Parameter(title: "Flags")
    var flags: [Bool]?

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
        tags: [String]?,
        ranks: [Int]?,
        weights: [Double]?,
        flags: [Bool]?,
        executor: SeiseiAppIntentExecutor
    ) {
        self.title = title
        self.priority = priority
        self.tags = tags
        self.ranks = ranks
        self.weights = weights
        self.flags = flags
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await executor.run(seiseiInvocation())
        return .result()
    }

    func seiseiInvocation() -> SeiseiAppIntentInvocation {
        SeiseiAppIntentBridge.invocation(
            actionID: "create_note",
            arguments: [
                "title": .string(title),
                "priority": priority.map { .integer($0) } ?? .null,
                "tags": tags.map { .array($0.map { .string($0) }) } ?? .null,
                "ranks": ranks.map { .array($0.map { .integer($0) }) } ?? .null,
                "weights": weights.map { .array($0.map { .number($0) }) } ?? .null,
                "flags": flags.map { .array($0.map { .boolean($0) }) } ?? .null,
            ]
        )
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

private enum GeneratedStyleNoteEntity: String, AppEntity, AppEnum {
    typealias DefaultQuery = _RawRepresentableStringQuery<GeneratedStyleNoteEntity>

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")

    static var caseDisplayRepresentations: [GeneratedStyleNoteEntity: DisplayRepresentation] {
        [
            .roadmap: "Roadmap",
        ]
    }

    case roadmap = "note-1"
}

private struct GeneratedStyleDynamicNoteEntity: AppEntity {
    typealias DefaultQuery = GeneratedStyleDynamicNoteEntityQuery

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")
    static var defaultQuery = GeneratedStyleDynamicNoteEntityQuery()

    let id: String
    let title: String
    let subtitle: String?
    let metadata: [String: SeiseiAppIntentValue]

    var displayRepresentation: DisplayRepresentation {
        if let subtitle {
            return DisplayRepresentation(
                title: LocalizedStringResource(stringLiteral: title),
                subtitle: LocalizedStringResource(stringLiteral: subtitle)
            )
        }
        return DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
    }

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        metadata: [String: SeiseiAppIntentValue] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
    }

    init(resolution: SeiseiAppEntityResolution) {
        self.init(
            id: resolution.id,
            title: resolution.title,
            subtitle: resolution.subtitle,
            metadata: resolution.metadata
        )
    }
}

private struct GeneratedStyleDynamicNoteEntityQuery: EntityStringQuery {
    @AppDependency
    private var entityExecutor: SeiseiAppEntityQueryExecutor

    init() {
        self._entityExecutor = AppDependency(default: SeiseiAppEntityQueryExecutor.unconfigured(entityTypeID: "note"))
    }

    init(entityExecutor: SeiseiAppEntityQueryExecutor) {
        self._entityExecutor = AppDependency(default: entityExecutor)
    }

    func entities(for identifiers: [GeneratedStyleDynamicNoteEntity.ID]) async throws -> [GeneratedStyleDynamicNoteEntity] {
        let resolutions = try await entityExecutor.resolve(
            SeiseiAppEntityQueryInvocation(
                entityTypeID: "note",
                mode: .identifiers,
                identifiers: identifiers
            )
        )
        return resolutions.map { GeneratedStyleDynamicNoteEntity(resolution: $0) }
    }

    func suggestedEntities() async throws -> [GeneratedStyleDynamicNoteEntity] {
        let resolutions = try await entityExecutor.resolve(
            SeiseiAppEntityQueryInvocation(
                entityTypeID: "note",
                mode: .suggested
            )
        )
        return resolutions.map { GeneratedStyleDynamicNoteEntity(resolution: $0) }
    }

    func entities(matching string: String) async throws -> [GeneratedStyleDynamicNoteEntity] {
        let resolutions = try await entityExecutor.resolve(
            SeiseiAppEntityQueryInvocation(
                entityTypeID: "note",
                mode: .search,
                searchTerm: string
            )
        )
        return resolutions.map { GeneratedStyleDynamicNoteEntity(resolution: $0) }
    }
}

private struct GeneratedStyleUpdateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Note"
    static let description = IntentDescription("Update note status.")

    @Parameter(title: "Status")
    var status: GeneratedStyleNoteStatus

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {
        self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: "update_note"))
    }

    init(status: GeneratedStyleNoteStatus, executor: SeiseiAppIntentExecutor) {
        self.status = status
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await executor.run(seiseiInvocation())
        return .result()
    }

    func seiseiInvocation() -> SeiseiAppIntentInvocation {
        SeiseiAppIntentBridge.invocation(
            actionID: "update_note",
            arguments: ["status": .string(status.rawValue)]
        )
    }
}

private struct GeneratedStyleOpenNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"
    static let description = IntentDescription("Open a note.")

    @Parameter(title: "Note")
    var note: GeneratedStyleNoteEntity

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {
        self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: "open_note"))
    }

    init(note: GeneratedStyleNoteEntity, executor: SeiseiAppIntentExecutor) {
        self.note = note
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await executor.run(seiseiInvocation())
        return .result()
    }

    func seiseiInvocation() -> SeiseiAppIntentInvocation {
        SeiseiAppIntentBridge.invocation(
            actionID: "open_note",
            arguments: ["note": .string(note.rawValue)]
        )
    }
}

private struct GeneratedStyleOpenDynamicNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"
    static let description = IntentDescription("Open a note.")

    @Parameter(title: "Note")
    var note: GeneratedStyleDynamicNoteEntity

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {
        self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: "open_dynamic_note"))
    }

    init(note: GeneratedStyleDynamicNoteEntity, executor: SeiseiAppIntentExecutor) {
        self.note = note
        self._executor = AppDependency(default: executor)
    }

    func perform() async throws -> some IntentResult {
        _ = try await executor.run(seiseiInvocation())
        return .result()
    }

    func seiseiInvocation() -> SeiseiAppIntentInvocation {
        SeiseiAppIntentBridge.invocation(
            actionID: "open_dynamic_note",
            arguments: ["note": .string(note.id)]
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
