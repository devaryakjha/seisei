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
