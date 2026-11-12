import Foundation
import XCTest

@testable import SeiseiAppleCore

final class SeiseiAppleRequestTests: XCTestCase {
  func testParsesEveryField() throws {
    let request = try SeiseiAppleRequest.parse([
      "requestId": NSNumber(value: 7),
      "prompt": "Hi",
      "mode": "system",
      "instructions": "Be brief.",
      "temperature": NSNumber(value: 0.5),
      "maximumResponseTokens": NSNumber(value: 64),
      "schema": "{\"type\":\"object\"}",
      "sessionId": "chat-1",
    ] as [String: Any])

    XCTAssertEqual(
      request,
      SeiseiAppleRequest(
        requestId: 7,
        prompt: "Hi",
        instructions: "Be brief.",
        temperature: 0.5,
        maximumResponseTokens: 64,
        schemaJSON: Data("{\"type\":\"object\"}".utf8),
        sessionId: "chat-1"
      )
    )
  }

  func testLeavesOptionalFieldsUnset() throws {
    let request = try SeiseiAppleRequest.parse(["prompt": "Hi"])
    XCTAssertEqual(request, SeiseiAppleRequest(prompt: "Hi"))
  }

  func testRejectsAMissingPrompt() {
    XCTAssertThrowsError(try SeiseiAppleRequest.parse(["mode": "system"])) {
      XCTAssertEqual(($0 as? SeiseiAppleBridgeError)?.code, "invalid_arguments")
    }
    XCTAssertThrowsError(try SeiseiAppleRequest.parse(nil))
  }

  func testRejectsModesOtherThanSystem() {
    XCTAssertThrowsError(
      try SeiseiAppleRequest.parse(["prompt": "Hi", "mode": "pcc"])
    ) {
      XCTAssertEqual(($0 as? SeiseiAppleBridgeError)?.code, "unsupported_mode")
    }
  }

  func testReadsALegacySchemaFile() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("seisei_schema_\(UUID().uuidString).json")
    try Data("{}".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let request = try SeiseiAppleRequest.parse([
      "prompt": "Hi",
      "schemaPath": url.path,
    ])
    XCTAssertEqual(request.schemaJSON, Data("{}".utf8))
  }

  func testReportsAMissingSchemaFile() {
    XCTAssertThrowsError(
      try SeiseiAppleRequest.parse([
        "prompt": "Hi",
        "schemaPath": "/nonexistent/seisei.json",
      ])
    ) {
      XCTAssertEqual(($0 as? SeiseiAppleBridgeError)?.code, "invalid_arguments")
    }
  }

  func testReadsCancelAndCloseArguments() {
    XCTAssertEqual(seiseiAppleRequestId(["requestId": NSNumber(value: 3)]), 3)
    XCTAssertNil(seiseiAppleRequestId("nope"))
    XCTAssertEqual(seiseiAppleSessionId(["sessionId": "s"]), "s")
    XCTAssertNil(seiseiAppleSessionId([:] as [String: Any]))
  }
}

private struct FakeGenerationError: Error, CustomStringConvertible {
  let description: String
}

final class SeiseiAppleErrorCodeTests: XCTestCase {
  func testMapsGenerationErrorsByDescription() {
    let cases = [
      "guardrailViolation(context)": "refused",
      "refusal(…)": "refused",
      "rateLimited(context)": "rate_limited",
      "concurrentRequests(context)": "rate_limited",
      "exceededContextWindowSize(context)": "context_window_exceeded",
      "decodingFailure(context)": "decode_failed",
      "assetsUnavailable(context)": "generation_failed",
    ]
    for (description, code) in cases {
      XCTAssertEqual(
        seiseiAppleErrorCode(for: FakeGenerationError(description: description)),
        code,
        description
      )
    }
  }

  func testMapsCancellationAndBridgeErrors() {
    XCTAssertEqual(seiseiAppleErrorCode(for: CancellationError()), "cancelled")
    XCTAssertEqual(
      seiseiAppleErrorCode(
        for: SeiseiAppleBridgeError(code: "unsupported_mode", message: "")
      ),
      "unsupported_mode"
    )
  }
}

final class SeiseiAppleStreamTests: XCTestCase {
  func testTextDeltaSendsOnlyNewText() {
    var delta = SeiseiAppleTextDelta()
    XCTAssertEqual(delta.next("Hel"), "Hel")
    XCTAssertEqual(delta.next("Hello"), "lo")
    XCTAssertEqual(delta.next("Hello"), "")
    // A rewrite of earlier text is sent whole.
    XCTAssertEqual(delta.next("Help"), "Help")
    XCTAssertEqual(delta.content, "Help")
  }

  func testEventsCarryTheirRequestId() {
    let chunk = SeiseiAppleStreamEvent.chunk(4, "a")
    XCTAssertEqual(chunk["requestId"] as? Int, 4)
    XCTAssertEqual(chunk["type"] as? String, "chunk")
    XCTAssertEqual(chunk["value"] as? String, "a")

    let done = SeiseiAppleStreamEvent.done(4, nil)
    XCTAssertEqual(done["type"] as? String, "done")
    XCTAssertTrue(done["value"] is NSNull)

    let error = SeiseiAppleStreamEvent.error(
      5,
      FakeGenerationError(description: "rateLimited(context)")
    )
    XCTAssertEqual(error["requestId"] as? Int, 5)
    XCTAssertEqual(error["type"] as? String, "error")
    XCTAssertEqual(error["code"] as? String, "rate_limited")
    XCTAssertEqual(error["message"] as? String, "rateLimited(context)")
  }
}

final class SeiseiAppleTaskRegistryTests: XCTestCase {
  func testCancelsOneRequestAndLeavesTheOthers() {
    let registry = SeiseiAppleTaskRegistry()
    var cancelled: [Int] = []
    registry.register(1) { cancelled.append(1) }
    registry.register(2) { cancelled.append(2) }

    registry.cancel(1)

    XCTAssertEqual(cancelled, [1])
    XCTAssertEqual(registry.count, 1)
    registry.cancel(1)
    XCTAssertEqual(cancelled, [1], "a second cancel does nothing")
  }

  func testFinishForgetsWithoutCancelling() {
    let registry = SeiseiAppleTaskRegistry()
    var cancelled = false
    registry.register(1) { cancelled = true }
    registry.finish(1)
    registry.cancel(1)
    XCTAssertFalse(cancelled)
    XCTAssertEqual(registry.count, 0)
  }

  func testCancelAllStopsEverything() {
    let registry = SeiseiAppleTaskRegistry()
    var cancelled = Set<Int>()
    for id in 0..<3 {
      registry.register(id) { cancelled.insert(id) }
    }
    registry.cancelAll()
    XCTAssertEqual(cancelled, [0, 1, 2])
    XCTAssertEqual(registry.count, 0)
  }

  func testReusingAnIdCancelsTheEarlierWork() {
    let registry = SeiseiAppleTaskRegistry()
    var cancelled: [String] = []
    registry.register(1) { cancelled.append("first") }
    registry.register(1) { cancelled.append("second") }
    XCTAssertEqual(cancelled, ["first"])
  }
}

final class SeiseiAppleSessionStoreTests: XCTestCase {
  final class Session {}

  func testReusesANamedSession() {
    let store = SeiseiAppleSessionStore<Session>()
    var made = 0
    let make = { () -> Session in
      made += 1
      return Session()
    }
    let first = store.session(for: "chat", make: make)
    let second = store.session(for: "chat", make: make)
    XCTAssertTrue(first === second)
    XCTAssertEqual(made, 1)
  }

  func testMakesAFreshSessionWithoutAnId() {
    let store = SeiseiAppleSessionStore<Session>()
    let first = store.session(for: nil) { Session() }
    let second = store.session(for: nil) { Session() }
    XCTAssertFalse(first === second)
    XCTAssertEqual(store.count, 0)
  }

  func testClosingStartsANewTranscript() {
    let store = SeiseiAppleSessionStore<Session>()
    let first = store.session(for: "chat") { Session() }
    store.close("chat")
    let second = store.session(for: "chat") { Session() }
    XCTAssertFalse(first === second)
    XCTAssertEqual(store.count, 1)
  }
}
