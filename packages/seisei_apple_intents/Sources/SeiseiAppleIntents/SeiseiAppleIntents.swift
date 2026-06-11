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
}

public struct SeiseiAppIntentInvocation: Sendable, Equatable {
    public init(
        id: String,
        arguments: [String: SeiseiAppIntentValue] = [:],
        metadata: [String: SeiseiAppIntentValue] = [:]
    ) {
        self.id = id
        self.arguments = arguments
        self.metadata = metadata
    }

    public let id: String
    public let arguments: [String: SeiseiAppIntentValue]
    public let metadata: [String: SeiseiAppIntentValue]
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
}

public enum SeiseiAppIntentDependencies {
    public static func configure(
        executor: SeiseiAppIntentExecutor,
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

public enum SeiseiGeneratedAppIntentParameterType: Sendable, Equatable {
    case string
    case integer
    case number
    case boolean

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
        }
    }
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

        for parameter in definition.parameters {
            lines.append("    @Parameter(title: \(parameter.title.swiftStringLiteral))")
            lines.append("    \(accessLevel) var \(parameter.name): \(parameter.swiftDeclarationType)")
            lines.append("")
        }

        lines.append("    @AppDependency")
        lines.append("    private var executor: SeiseiAppIntentExecutor")
        lines.append("")
        lines.append("    \(accessLevel) init() {}")
        lines.append("")

        if !definition.parameters.isEmpty {
            lines.append(
                "    \(accessLevel) init(\(definition.parameters.map(\.initializerParameter).joined(separator: ", "))) {"
            )
            for parameter in definition.parameters {
                lines.append("        self.\(parameter.name) = \(parameter.name)")
            }
            lines.append("    }")
            lines.append("")
        }

        lines.append("    \(accessLevel) func perform() async throws -> some IntentResult {")
        lines.append("        _ = try await SeiseiAppIntentBridge.perform(")
        lines.append("            actionID: \(definition.actionID.swiftStringLiteral),")
        lines.append("            arguments: \(definition.argumentsExpression),")
        lines.append("            executor: executor")
        lines.append("        )")
        lines.append("        return .result()")
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
