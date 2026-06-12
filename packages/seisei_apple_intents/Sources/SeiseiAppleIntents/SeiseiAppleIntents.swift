import AppIntents
import Foundation

public enum SeiseiAppIntentValue: Sendable, Equatable {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case array([SeiseiAppIntentValue])
    case object([String: SeiseiAppIntentValue])
    case null

    public var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }

    public init(jsonValue: Any?) throws {
        switch jsonValue {
        case nil:
            self = .null
        case is NSNull:
            self = .null
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .boolean(value)
        case let value as Int:
            self = .integer(value)
        case let value as Double:
            self = .number(value)
        case let value as Float:
            self = .number(Double(value))
        case let value as [Any?]:
            self = try .array(value.map { try SeiseiAppIntentValue(jsonValue: $0) })
        case let value as [String: Any?]:
            self = try .object(value.mapValues { try SeiseiAppIntentValue(jsonValue: $0) })
        case let value as [String: Any]:
            self = try .object(value.mapValues { try SeiseiAppIntentValue(jsonValue: $0) })
        default:
            throw SeiseiAppIntentWireError.unsupportedValueType(String(describing: type(of: jsonValue as Any)))
        }
    }

    public var jsonValue: Any {
        switch self {
        case let .string(value):
            return value
        case let .integer(value):
            return value
        case let .number(value):
            return value
        case let .boolean(value):
            return value
        case let .array(values):
            return values.map(\.jsonValue)
        case let .object(values):
            return values.mapValues(\.jsonValue)
        case .null:
            return NSNull()
        }
    }
}

public enum SeiseiAppIntentWireError: Error, Sendable, Equatable {
    case missingString(String)
    case unsupportedValueType(String)
    case unsupportedQueryMode(String)
}

public struct SeiseiAppIntentInvocation: Sendable, Equatable {
    public init(
        id: String,
        arguments: [String: SeiseiAppIntentValue] = [:],
        toolCallID: String? = nil,
        metadata: [String: SeiseiAppIntentValue] = [:]
    ) {
        self.id = id
        self.arguments = arguments
        self.toolCallID = toolCallID
        self.metadata = metadata
    }

    public init(methodChannelArguments: [String: Any]) throws {
        let id = try Self.requiredString("id", in: methodChannelArguments)
        let rawArguments = methodChannelArguments["arguments"] as? [String: Any] ?? [:]
        let rawMetadata = methodChannelArguments["metadata"] as? [String: Any] ?? [:]

        try self.init(
            id: id,
            arguments: Self.values(from: rawArguments),
            toolCallID: methodChannelArguments["toolCallId"] as? String,
            metadata: Self.values(from: rawMetadata)
        )
    }

    public let id: String
    public let arguments: [String: SeiseiAppIntentValue]
    public let toolCallID: String?
    public let metadata: [String: SeiseiAppIntentValue]

    public var methodChannelArguments: [String: Any] {
        var arguments: [String: Any] = [
            "id": id,
            "arguments": self.arguments.mapValues(\.jsonValue),
            "metadata": metadata.mapValues(\.jsonValue),
        ]
        if let toolCallID {
            arguments["toolCallId"] = toolCallID
        }
        return arguments
    }
}

public struct SeiseiAppIntentResult: Sendable, Equatable {
    public init(
        value: SeiseiAppIntentValue? = nil,
        metadata: [String: SeiseiAppIntentValue] = [:]
    ) {
        self.value = value
        self.metadata = metadata
    }

    public let value: SeiseiAppIntentValue?
    public let metadata: [String: SeiseiAppIntentValue]

    public var stringValue: String? {
        value?.stringValue
    }

    public init(methodChannelResult: [String: Any]) throws {
        let rawMetadata = methodChannelResult["metadata"] as? [String: Any] ?? [:]
        try self.init(
            value: SeiseiAppIntentValue(jsonValue: methodChannelResult["value"]),
            metadata: SeiseiAppIntentInvocation.values(from: rawMetadata)
        )
    }

    public var methodChannelResult: [String: Any] {
        [
            "value": value?.jsonValue ?? NSNull(),
            "metadata": metadata.mapValues(\.jsonValue),
        ]
    }
}

private extension SeiseiAppIntentInvocation {
    static func requiredString(_ key: String, in dictionary: [String: Any]) throws -> String {
        guard let value = dictionary[key] as? String else {
            throw SeiseiAppIntentWireError.missingString(key)
        }
        return value
    }

    static func values(from dictionary: [String: Any]) throws -> [String: SeiseiAppIntentValue] {
        try dictionary.mapValues { try SeiseiAppIntentValue(jsonValue: $0) }
    }
}

public final class SeiseiAppIntentExecutor: @unchecked Sendable {
    public typealias Run = @Sendable (SeiseiAppIntentInvocation) async throws -> SeiseiAppIntentResult

    private let runHandler: Run

    public init(run: @escaping Run) {
        self.runHandler = run
    }

    public func run(_ invocation: SeiseiAppIntentInvocation) async throws -> SeiseiAppIntentResult {
        try await runHandler(invocation)
    }

    public static func unconfigured(actionID: String) -> SeiseiAppIntentExecutor {
        SeiseiAppIntentExecutor { _ in
            throw SeiseiAppIntentExecutorError.unconfigured(actionID: actionID)
        }
    }
}

public enum SeiseiAppIntentExecutorError: Error, Sendable, Equatable {
    case unconfigured(actionID: String)
}

public enum SeiseiAppEntityQueryMode: Sendable, Equatable {
    case identifiers
    case suggested
    case search

    public init(wireName: String) throws {
        switch wireName {
        case "identifiers":
            self = .identifiers
        case "suggested":
            self = .suggested
        case "search":
            self = .search
        default:
            throw SeiseiAppIntentWireError.unsupportedQueryMode(wireName)
        }
    }

    public var wireName: String {
        switch self {
        case .identifiers:
            return "identifiers"
        case .suggested:
            return "suggested"
        case .search:
            return "search"
        }
    }
}

public struct SeiseiAppEntityQueryInvocation: Sendable, Equatable {
    public init(
        entityTypeID: String,
        mode: SeiseiAppEntityQueryMode,
        identifiers: [String] = [],
        searchTerm: String? = nil,
        metadata: [String: SeiseiAppIntentValue] = [:]
    ) {
        self.entityTypeID = entityTypeID
        self.mode = mode
        self.identifiers = identifiers
        self.searchTerm = searchTerm
        self.metadata = metadata
    }

    public init(methodChannelArguments: [String: Any]) throws {
        let entityTypeID = try SeiseiAppIntentInvocation.requiredString("entityTypeID", in: methodChannelArguments)
        let mode = try SeiseiAppEntityQueryMode(
            wireName: SeiseiAppIntentInvocation.requiredString("mode", in: methodChannelArguments)
        )
        let rawMetadata = methodChannelArguments["metadata"] as? [String: Any] ?? [:]

        try self.init(
            entityTypeID: entityTypeID,
            mode: mode,
            identifiers: methodChannelArguments["identifiers"] as? [String] ?? [],
            searchTerm: methodChannelArguments["searchTerm"] as? String,
            metadata: SeiseiAppIntentInvocation.values(from: rawMetadata)
        )
    }

    public let entityTypeID: String
    public let mode: SeiseiAppEntityQueryMode
    public let identifiers: [String]
    public let searchTerm: String?
    public let metadata: [String: SeiseiAppIntentValue]

    public var methodChannelArguments: [String: Any] {
        var arguments: [String: Any] = [
            "entityTypeID": entityTypeID,
            "mode": mode.wireName,
            "identifiers": identifiers,
            "metadata": metadata.mapValues(\.jsonValue),
        ]
        if let searchTerm {
            arguments["searchTerm"] = searchTerm
        }
        return arguments
    }
}

public struct SeiseiAppEntityResolution: Sendable, Equatable {
    public init(
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

    public let id: String
    public let title: String
    public let subtitle: String?
    public let metadata: [String: SeiseiAppIntentValue]

    public init(methodChannelResult: [String: Any]) throws {
        let rawMetadata = methodChannelResult["metadata"] as? [String: Any] ?? [:]
        try self.init(
            id: SeiseiAppIntentInvocation.requiredString("id", in: methodChannelResult),
            title: SeiseiAppIntentInvocation.requiredString("title", in: methodChannelResult),
            subtitle: methodChannelResult["subtitle"] as? String,
            metadata: SeiseiAppIntentInvocation.values(from: rawMetadata)
        )
    }

    public var methodChannelResult: [String: Any] {
        var result: [String: Any] = [
            "id": id,
            "title": title,
            "metadata": metadata.mapValues(\.jsonValue),
        ]
        if let subtitle {
            result["subtitle"] = subtitle
        }
        return result
    }
}

public final class SeiseiAppEntityQueryExecutor: @unchecked Sendable {
    public typealias Resolve = @Sendable (SeiseiAppEntityQueryInvocation) async throws -> [SeiseiAppEntityResolution]

    private let resolveHandler: Resolve

    public init(resolve: @escaping Resolve) {
        self.resolveHandler = resolve
    }

    public func resolve(_ invocation: SeiseiAppEntityQueryInvocation) async throws -> [SeiseiAppEntityResolution] {
        try await resolveHandler(invocation)
    }

    public static func unconfigured(entityTypeID: String) -> SeiseiAppEntityQueryExecutor {
        SeiseiAppEntityQueryExecutor { _ in
            throw SeiseiAppEntityQueryExecutorError.unconfigured(entityTypeID: entityTypeID)
        }
    }
}

public enum SeiseiAppEntityQueryExecutorError: Error, Sendable, Equatable {
    case unconfigured(entityTypeID: String)
}

public enum SeiseiAppIntentDependencies {
    public static func configure(
        executor: SeiseiAppIntentExecutor,
        manager: AppDependencyManager = .shared
    ) {
        manager.add(dependency: executor)
    }
}

public enum SeiseiAppEntityQueryDependencies {
    public static func configure(
        executor: SeiseiAppEntityQueryExecutor,
        manager: AppDependencyManager = .shared
    ) {
        manager.add(dependency: executor)
    }
}

public enum SeiseiAppIntentBridge {
    public static func invocation(
        actionID: String,
        arguments: [String: SeiseiAppIntentValue] = [:],
        metadata: [String: SeiseiAppIntentValue] = [:]
    ) -> SeiseiAppIntentInvocation {
        SeiseiAppIntentInvocation(
            id: actionID,
            arguments: arguments,
            metadata: metadata
        )
    }

    public static func perform(
        actionID: String,
        arguments: [String: SeiseiAppIntentValue] = [:],
        metadata: [String: SeiseiAppIntentValue] = [:],
        executor: SeiseiAppIntentExecutor
    ) async throws -> SeiseiAppIntentResult {
        try await executor.run(
            invocation(
                actionID: actionID,
                arguments: arguments,
                metadata: metadata
            )
        )
    }
}

public enum SeiseiFlutterIntentsWire {
    public static let channelName = "dev.jha.seisei/seisei_flutter_intents"
    public static let invokeActionMethod = "invokeAction"
    public static let resolveEntityQueryMethod = "resolveEntityQuery"

    public typealias MethodInvoker = @Sendable (
        _ method: String,
        _ arguments: [String: Any]
    ) async throws -> Any?
}

public extension SeiseiAppIntentExecutor {
    static func flutterMethodChannel(
        invokeMethod: @escaping SeiseiFlutterIntentsWire.MethodInvoker
    ) -> SeiseiAppIntentExecutor {
        SeiseiAppIntentExecutor { invocation in
            let result = try await invokeMethod(
                SeiseiFlutterIntentsWire.invokeActionMethod,
                invocation.methodChannelArguments
            )
            guard let result = result as? [String: Any] else {
                throw SeiseiAppIntentFlutterForwardingError.invalidActionResult
            }
            return try SeiseiAppIntentResult(methodChannelResult: result)
        }
    }
}

public extension SeiseiAppEntityQueryExecutor {
    static func flutterMethodChannel(
        invokeMethod: @escaping SeiseiFlutterIntentsWire.MethodInvoker
    ) -> SeiseiAppEntityQueryExecutor {
        SeiseiAppEntityQueryExecutor { invocation in
            let result = try await invokeMethod(
                SeiseiFlutterIntentsWire.resolveEntityQueryMethod,
                invocation.methodChannelArguments
            )
            guard let rows = result as? [[String: Any]] else {
                throw SeiseiAppIntentFlutterForwardingError.invalidEntityQueryResult
            }
            return try rows.map { try SeiseiAppEntityResolution(methodChannelResult: $0) }
        }
    }
}

public enum SeiseiAppIntentFlutterForwardingError: Error, Sendable, Equatable {
    case invalidActionResult
    case invalidEntityQueryResult
}

public enum SeiseiGeneratedAppIntentParameterType: Sendable, Equatable {
    case string
    case integer
    case number
    case boolean
    case stringArray
    case stringEnum(
        typeName: String,
        cases: [SeiseiGeneratedAppIntentEnumCase],
        displayName: String
    )
    case stringEntity(
        typeName: String,
        cases: [SeiseiGeneratedAppIntentEntityCase],
        displayName: String
    )
    case hostBackedStringEntity(
        typeName: String,
        displayName: String,
        entityTypeID: String
    )

    fileprivate var swiftType: String {
        switch self {
        case .string:
            return "String"
        case .integer:
            return "Int"
        case .number:
            return "Double"
        case .boolean:
            return "Bool"
        case .stringArray:
            return "[String]"
        case let .stringEnum(typeName, _, _),
             let .stringEntity(typeName, _, _),
             let .hostBackedStringEntity(typeName, _, _):
            return typeName
        }
    }

    fileprivate func invocationValueExpression(for name: String) -> String {
        switch self {
        case .string:
            return ".string(\(name))"
        case .integer:
            return ".integer(\(name))"
        case .number:
            return ".number(\(name))"
        case .boolean:
            return ".boolean(\(name))"
        case .stringArray:
            return ".array(\(name).map { .string($0) })"
        case .stringEnum, .stringEntity:
            return ".string(\(name).rawValue)"
        case .hostBackedStringEntity:
            return ".string(\(name).id)"
        }
    }
}

public struct SeiseiGeneratedAppIntentEnumCase: Sendable, Equatable {
    public init(
        name: String,
        rawValue: String,
        title: String
    ) {
        self.name = name
        self.rawValue = rawValue
        self.title = title
    }

    public let name: String
    public let rawValue: String
    public let title: String
}

public struct SeiseiGeneratedAppIntentEntityCase: Sendable, Equatable {
    public init(
        name: String,
        rawValue: String,
        title: String
    ) {
        self.name = name
        self.rawValue = rawValue
        self.title = title
    }

    public let name: String
    public let rawValue: String
    public let title: String
}

public struct SeiseiGeneratedAppIntentParameter: Sendable, Equatable {
    public init(
        name: String,
        title: String,
        type: SeiseiGeneratedAppIntentParameterType,
        isRequired: Bool = true
    ) {
        self.name = name
        self.title = title
        self.type = type
        self.isRequired = isRequired
    }

    public let name: String
    public let title: String
    public let type: SeiseiGeneratedAppIntentParameterType
    public let isRequired: Bool
}

public struct SeiseiGeneratedAppShortcutDefinition: Sendable, Equatable {
    public init(
        phrases: [String],
        shortTitle: String,
        systemImageName: String
    ) {
        self.phrases = phrases
        self.shortTitle = shortTitle
        self.systemImageName = systemImageName
    }

    public let phrases: [String]
    public let shortTitle: String
    public let systemImageName: String
}

public struct SeiseiGeneratedAppIntentDefinition: Sendable, Equatable {
    public init(
        typeName: String,
        actionID: String,
        title: String,
        description: String,
        parameters: [SeiseiGeneratedAppIntentParameter] = [],
        shortcut: SeiseiGeneratedAppShortcutDefinition? = nil
    ) {
        self.typeName = typeName
        self.actionID = actionID
        self.title = title
        self.description = description
        self.parameters = parameters
        self.shortcut = shortcut
    }

    public let typeName: String
    public let actionID: String
    public let title: String
    public let description: String
    public let parameters: [SeiseiGeneratedAppIntentParameter]
    public let shortcut: SeiseiGeneratedAppShortcutDefinition?
}

public enum SeiseiAppIntentSourceGenerator {
    public static func source(
        for definition: SeiseiGeneratedAppIntentDefinition,
        accessLevel: String = "public"
    ) -> String {
        var lines = [
            "import AppIntents",
            "import SeiseiAppleIntents",
            "",
            "\(accessLevel) struct \(definition.typeName): AppIntent {",
            "    \(accessLevel) static let title: LocalizedStringResource = \(definition.title.swiftStringLiteral)",
            "    \(accessLevel) static let description = IntentDescription(\(definition.description.swiftStringLiteral))",
            "",
        ]

        var emittedEnumTypeNames = Set<String>()
        for parameter in definition.parameters {
            guard let enumSource = parameter.enumSource(accessLevel: accessLevel) else {
                continue
            }
            if emittedEnumTypeNames.insert(parameter.type.swiftType).inserted {
                lines.append(enumSource)
                lines.append("")
            }
        }

        for parameter in definition.parameters {
            lines.append("    @Parameter(title: \(parameter.title.swiftStringLiteral))")
            lines.append("    \(accessLevel) var \(parameter.name): \(parameter.swiftDeclarationType)")
            lines.append("")
        }

        lines.append("    @AppDependency")
        lines.append("    private var executor: SeiseiAppIntentExecutor")
        lines.append("")
        lines.append("    \(accessLevel) init() {")
        lines.append("        self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: \(definition.actionID.swiftStringLiteral)))")
        lines.append("    }")
        lines.append("")

        if !definition.parameters.isEmpty {
            lines.append(
                "    \(accessLevel) init(\((definition.parameters.map(\.initializerParameter) + ["executor: SeiseiAppIntentExecutor"]).joined(separator: ", "))) {"
            )
            for parameter in definition.parameters {
                lines.append("        self.\(parameter.name) = \(parameter.name)")
            }
            lines.append("        self._executor = AppDependency(default: executor)")
            lines.append("    }")
            lines.append("")
        } else {
            lines.append("    \(accessLevel) init(executor: SeiseiAppIntentExecutor) {")
            lines.append("        self._executor = AppDependency(default: executor)")
            lines.append("    }")
            lines.append("")
        }

        lines.append("    \(accessLevel) func perform() async throws -> some IntentResult {")
        lines.append("        _ = try await executor.run(seiseiInvocation())")
        lines.append("        return .result()")
        lines.append("    }")
        lines.append("")
        lines.append("    \(accessLevel) func seiseiInvocation() -> SeiseiAppIntentInvocation {")
        lines.append("        SeiseiAppIntentBridge.invocation(")
        lines.append("            actionID: \(definition.actionID.swiftStringLiteral),")
        lines.append("            arguments: \(definition.argumentsExpression)")
        lines.append("        )")
        lines.append("    }")
        lines.append("}")

        if let shortcut = definition.shortcut {
            lines.append("")
            lines.append("\(accessLevel) struct \(definition.typeName)Shortcuts: AppShortcutsProvider {")
            lines.append("    \(accessLevel) static var appShortcuts: [AppShortcut] {")
            lines.append("        AppShortcut(")
            lines.append("            intent: \(definition.typeName)(),")
            lines.append("            phrases: [\(shortcut.phrases.map(\.swiftStringLiteral).joined(separator: ", "))],")
            lines.append("            shortTitle: \(shortcut.shortTitle.swiftStringLiteral),")
            lines.append("            systemImageName: \(shortcut.systemImageName.swiftStringLiteral)")
            lines.append("        )")
            lines.append("    }")
            lines.append("}")
        }

        return lines.joined(separator: "\n") + "\n"
    }
}

private extension SeiseiGeneratedAppIntentDefinition {
    var argumentsExpression: String {
        guard !parameters.isEmpty else {
            return "[:]"
        }
        let entries = parameters.map { parameter in
            "\(parameter.name.swiftStringLiteral): \(parameter.argumentExpression)"
        }
        return "[" + entries.joined(separator: ", ") + "]"
    }
}

private extension SeiseiGeneratedAppIntentParameter {
    var swiftDeclarationType: String {
        if isRequired {
            return type.swiftType
        }
        return "\(type.swiftType)?"
    }

    var initializerParameter: String {
        "\(name): \(swiftDeclarationType)"
    }

    var argumentExpression: String {
        if isRequired {
            return type.invocationValueExpression(for: name)
        }
        return "\(name).map { \(type.invocationValueExpression(for: "$0")) } ?? .null"
    }

    func enumSource(accessLevel: String) -> String? {
        switch type {
        case let .stringEnum(enumTypeName, enumCases, enumDisplayName):
            return staticEnumSource(
                accessLevel: accessLevel,
                typeName: enumTypeName,
                cases: enumCases.map { ($0.name, $0.rawValue, $0.title) },
                displayName: enumDisplayName,
                conformance: "AppEnum",
                includeEntityDefaultQuery: false
            )
        case let .stringEntity(entityTypeName, entityCases, entityDisplayName):
            return staticEnumSource(
                accessLevel: accessLevel,
                typeName: entityTypeName,
                cases: entityCases.map { ($0.name, $0.rawValue, $0.title) },
                displayName: entityDisplayName,
                conformance: "AppEntity, AppEnum",
                includeEntityDefaultQuery: true
            )
        case let .hostBackedStringEntity(typeName, displayName, entityTypeID):
            return hostBackedEntitySource(
                accessLevel: accessLevel,
                typeName: typeName,
                displayName: displayName,
                entityTypeID: entityTypeID
            )
        default:
            return nil
        }
    }

    func staticEnumSource(
        accessLevel: String,
        typeName: String,
        cases: [(name: String, rawValue: String, title: String)],
        displayName: String,
        conformance: String,
        includeEntityDefaultQuery: Bool
    ) -> String {
        var lines = [
            "\(accessLevel) enum \(typeName): String, \(conformance) {",
        ]

        if includeEntityDefaultQuery {
            lines.append("    \(accessLevel) typealias DefaultQuery = _RawRepresentableStringQuery<\(typeName)>")
            lines.append("")
        }

        lines.append(contentsOf: [
            "    \(accessLevel) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: \(displayName.swiftStringLiteral))",
            "",
            "    \(accessLevel) static var caseDisplayRepresentations: [\(typeName): DisplayRepresentation] {",
            "        [",
        ])

        for enumCase in cases {
            lines.append("            .\(enumCase.name): \(enumCase.title.swiftStringLiteral),")
        }

        lines.append("        ]")
        lines.append("    }")
        lines.append("")

        for enumCase in cases {
            lines.append("    case \(enumCase.name) = \(enumCase.rawValue.swiftStringLiteral)")
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    func hostBackedEntitySource(
        accessLevel: String,
        typeName: String,
        displayName: String,
        entityTypeID: String
    ) -> String {
        let queryTypeName = "\(typeName)Query"
        let lines = [
            "\(accessLevel) struct \(typeName): AppEntity {",
            "    \(accessLevel) typealias DefaultQuery = \(queryTypeName)",
            "",
            "    \(accessLevel) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: \(displayName.swiftStringLiteral))",
            "    \(accessLevel) static var defaultQuery = \(queryTypeName)()",
            "",
            "    \(accessLevel) let id: String",
            "    \(accessLevel) let title: String",
            "    \(accessLevel) let subtitle: String?",
            "    \(accessLevel) let metadata: [String: SeiseiAppIntentValue]",
            "",
            "    \(accessLevel) var displayRepresentation: DisplayRepresentation {",
            "        if let subtitle {",
            "            return DisplayRepresentation(",
            "                title: LocalizedStringResource(stringLiteral: title),",
            "                subtitle: LocalizedStringResource(stringLiteral: subtitle)",
            "            )",
            "        }",
            "        return DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))",
            "    }",
            "",
            "    \(accessLevel) init(id: String, title: String, subtitle: String? = nil, metadata: [String: SeiseiAppIntentValue] = [:]) {",
            "        self.id = id",
            "        self.title = title",
            "        self.subtitle = subtitle",
            "        self.metadata = metadata",
            "    }",
            "",
            "    \(accessLevel) init(resolution: SeiseiAppEntityResolution) {",
            "        self.init(",
            "            id: resolution.id,",
            "            title: resolution.title,",
            "            subtitle: resolution.subtitle,",
            "            metadata: resolution.metadata",
            "        )",
            "    }",
            "}",
            "",
            "\(accessLevel) struct \(queryTypeName): EntityStringQuery {",
            "    @AppDependency",
            "    private var entityExecutor: SeiseiAppEntityQueryExecutor",
            "",
            "    \(accessLevel) init() {",
            "        self._entityExecutor = AppDependency(default: SeiseiAppEntityQueryExecutor.unconfigured(entityTypeID: \(entityTypeID.swiftStringLiteral)))",
            "    }",
            "",
            "    \(accessLevel) init(entityExecutor: SeiseiAppEntityQueryExecutor) {",
            "        self._entityExecutor = AppDependency(default: entityExecutor)",
            "    }",
            "",
            "    \(accessLevel) func entities(for identifiers: [\(typeName).ID]) async throws -> [\(typeName)] {",
            "        let resolutions = try await entityExecutor.resolve(",
            "            SeiseiAppEntityQueryInvocation(",
            "                entityTypeID: \(entityTypeID.swiftStringLiteral),",
            "                mode: .identifiers,",
            "                identifiers: identifiers",
            "            )",
            "        )",
            "        return resolutions.map { \(typeName)(resolution: $0) }",
            "    }",
            "",
            "    \(accessLevel) func suggestedEntities() async throws -> [\(typeName)] {",
            "        let resolutions = try await entityExecutor.resolve(",
            "            SeiseiAppEntityQueryInvocation(",
            "                entityTypeID: \(entityTypeID.swiftStringLiteral),",
            "                mode: .suggested",
            "            )",
            "        )",
            "        return resolutions.map { \(typeName)(resolution: $0) }",
            "    }",
            "",
            "    \(accessLevel) func entities(matching string: String) async throws -> [\(typeName)] {",
            "        let resolutions = try await entityExecutor.resolve(",
            "            SeiseiAppEntityQueryInvocation(",
            "                entityTypeID: \(entityTypeID.swiftStringLiteral),",
            "                mode: .search,",
            "                searchTerm: string",
            "            )",
            "        )",
            "        return resolutions.map { \(typeName)(resolution: $0) }",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n")
    }
}

private extension String {
    var swiftStringLiteral: String {
        var escaped = "\""
        for scalar in unicodeScalars {
            switch scalar {
            case "\\":
                escaped += "\\\\"
            case "\"":
                escaped += "\\\""
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                escaped.unicodeScalars.append(scalar)
            }
        }
        escaped += "\""
        return escaped
    }
}
