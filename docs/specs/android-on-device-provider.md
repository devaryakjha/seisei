# Android On-Device Provider Spec

Status: proposal for the 0.1.0 cycle. Spec only, no code ships in 0.1.0.

## Objective

Seisei's only real provider is Apple Foundation Models, so Android apps have
no on-device option. This spec proposes `seisei_android`, a Flutter plugin that
exposes Gemini Nano through the ML Kit GenAI Prompt API behind the generic
`SeiseiProvider` contract.

The same boundary rules as `seisei_apple` apply: the Android package adapts a
platform model to Seisei's contracts and must not define request, response,
schema, routing or UI-block architecture of its own.

## Platform Research

Researched on 2026-10-22 from Google's public docs (see Sources). Several of
these APIs are Beta or Alpha, so each fact below must be re-checked before
implementation starts.

### API choice

Google offers three ways to reach Gemini Nano on Android:

| Option | Status | Fit for Seisei |
| --- | --- | --- |
| ML Kit GenAI Prompt API (`com.google.mlkit:genai-prompt`) | Beta; some features Alpha | Chosen. Free-form prompts, streaming, image input, availability and download APIs. |
| ML Kit GenAI task APIs (summarize, proofread, rewrite, describe image) | Beta | Too narrow; they do not take arbitrary prompts. |
| Google AI Edge SDK (`aicore:0.0.1-exp*`) | Experimental, "not for production" | Superseded by the Prompt API. |

Firebase AI Logic's hybrid on-device mode wraps the same model but adds a
Firebase dependency and cloud fallback inside the SDK. Seisei keeps fallback in
its own router, so the plain ML Kit API is the better base.

### Facts the design depends on

- Dependency: `com.google.mlkit:genai-prompt:1.0.0-beta4` at the time of
  writing. Requires Android API 26+ and the AICore system app. Devices with an
  unlocked bootloader are not supported.
- Devices: the Prompt API runs only on devices that ship a Gemini Nano build.
  Google lists nano-v2 devices (select Honor, Motorola, OnePlus, OPPO, Samsung,
  vivo, Xiaomi and others), nano-v3 (Pixel 9 and 10 series plus select others)
  and nano-v4 (Pixel 11 series, Galaxy Z Flip8 and Z Fold8). Most Android
  devices will report unavailable. Emulators are not supported.
- Client: `Generation.getClient(GenerationConfig)` returns a
  `GenerativeModel`. `ModelConfig` picks `ModelReleaseStage.STABLE` or
  `PREVIEW` and `ModelPreference.FULL` or `FAST`.
- Availability: `checkStatus()` returns `FeatureStatus.AVAILABLE`,
  `DOWNLOADABLE`, `DOWNLOADING` or `UNAVAILABLE`. `download()` returns a flow
  of `DownloadStarted`, `DownloadProgress`, `DownloadCompleted` and
  `DownloadFailed`. `warmup()` preloads the model.
- Generation: `generateContent(request)` and `generateContentStream(request)`.
  A request holds `TextPart` and up to 10 `ImagePart`s, an optional
  `SystemInstruction` (nano-v3+), and `temperature`, `topK`, `seed`,
  `candidateCount` and `maxOutputTokens`.
- Limits: input under about 4,000 tokens and output under about 4,000 tokens.
  `countTokens` measures a request.
- Foreground only: "GenAI API inference is permitted only when the app is the
  top foreground application." Background calls, including from a foreground
  service, fail with `ErrorCode.BACKGROUND_USE_BLOCKED`.
- Quota: AICore enforces a per-app quota. Bursts return `ErrorCode.BUSY`
  (retry with backoff); long-window limits return
  `ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED`.
- Setup errors: `601-BINDING_FAILURE`, `606-FEATURE_NOT_FOUND` (AICore still
  fetching configuration, can take hours) and download host failures.
- Structured output (Alpha): Kotlin only. A data class annotated with
  `@Generable` and `@Guide` is compiled by the KSP processor
  `com.google.mlkit:genai-schema-compiler:1.0.0-alpha1`, then sent with
  `generateTypedContentRequest(..., outputClass = Foo::class)`. Requires
  `isStructuredOutputFeatureAvailable()`. Supports strings with enum values,
  ints and doubles with ranges, booleans, lists with item counts and nested
  classes (no cycles). No runtime JSON schema input and no documented
  streaming is offered.
- Tool calling: not available. Google says tool calling, structured output,
  system prompts and thinking mode will arrive in the Prompt API "throughout
  the preview period" of Gemini Nano 4. Of those four, tool calling is the
  only one with no documentation yet.

## Capability Mapping

`ProviderAvailability` is computed from `checkStatus()` plus a few device
checks, and capabilities are only advertised when Seisei can honor them.

| Seisei capability | Advertised when | Notes |
| --- | --- | --- |
| `onDeviceInference` | `checkStatus()` is `AVAILABLE` | Always true when available; inference never leaves the device. |
| `streaming` | available | Text deltas from `generateContentStream`. |
| `structuredGeneration` | available | Through JSON prompting plus Dart-side validation (see below), not the KSP API. |
| `imageInput` | available | Only once the core request model has media segments; not advertised before that. |
| `toolCalling` | never, for now | Revisit when the Prompt API documents tool calling. |

Availability states map like this:

| Platform state | `ProviderAvailability` | `reason` |
| --- | --- | --- |
| Not Android, or API < 26 | unavailable | `android_unsupported_os` |
| `UNAVAILABLE` | unavailable | `gemini_nano_unsupported_device` |
| `DOWNLOADABLE` | unavailable | `gemini_nano_not_downloaded` |
| `DOWNLOADING` | unavailable | `gemini_nano_downloading` |
| `AVAILABLE` | available | none |
| App not in the foreground | unavailable | `android_background_blocked` |
| Binding or configuration error | unavailable | `aicore_not_ready` |

A downloadable model is reported as unavailable so the router can move on. The
app triggers the download explicitly through a provider method (below), never
as a side effect of `generate`.

The `reason` strings are stable identifiers rather than prose so apps and the
router can branch on them. If the core later adds a structured reason type,
these become its values.

## Privacy and Routing

- The provider id is `android_gemini_nano`.
- Every mode is on device, so `PrivacyPolicy.onDeviceOnly`,
  `onDevicePreferred` and `cloudAllowed` are all accepted once the provider is
  available.
- Unavailability is always surfaced through `availability()` before a request
  runs, matching the Apple rule that unavailability must not become a late
  generic generation failure.
- With the router, a typical Android chain is `android_gemini_nano` then a
  cloud provider. `onDeviceOnly` requests stop after the first; the router
  already enforces that through capabilities and privacy checks.
- Runtime failures that only show up mid-request (`BUSY`, quota,
  `BACKGROUND_USE_BLOCKED`) are mapped to `SeiseiErrorCode.providerUnavailable`
  with the native code in `source`, so the router can fall back.

## Structured Output Strategy

Seisei builds schemas at runtime in Dart (`ObjectSchema`), but ML Kit's typed
API needs Kotlin classes compiled by KSP. There is no way to hand it a schema
at runtime, so the native structured API cannot serve arbitrary Seisei
requests.

Proposed approach for the first version:

1. Render the request's `ObjectSchema` into a compact JSON schema description
   and put it in a `SystemInstruction` (nano-v3+) or a prompt preamble
   (nano-v2), asking for one JSON object and nothing else.
2. Parse the model's text as JSON, then validate it with
   `ObjectSchema.validate` before calling `request.decode`.
3. On a parse or validation failure, retry once with the validation errors
   appended. A second failure throws `DecodeException` with the raw text.
4. While streaming, emit text deltas and, when a prefix parses as a JSON
   object that decodes, a `partialValue`. Reuse the snapshot diffing that
   `seisei_apple` already uses for `structuredPatches`.

This gives "best effort, always validated" structured output: wrong shapes are
caught, but the model is not constrained while decoding. The README and
capability docs must say so plainly.

Constrained decoding through the native typed API stays a later option. It
would need a build-time path, for example a `build_runner` step that emits
`@Generable` Kotlin classes from Dart schema annotations, which fits with the
S3 schema codegen work. It is out of scope until the typed API leaves Alpha
and supports streaming.

## Package Shape

`seisei_android` is a Flutter plugin package with an Android implementation
only, mirroring `seisei_apple`.

```text
packages/seisei_android/
  lib/
    seisei_android.dart
    src/
      gemini_nano_provider.dart     # SeiseiProvider implementation
      backend.dart                  # GeminiNanoBackend interface + models
      method_channel_backend.dart   # Platform channel backend
      json_structured_output.dart   # schema prompt rendering + JSON repair/validation
  android/
    build.gradle.kts
    src/main/kotlin/dev/jha/seisei/android/SeiseiAndroidPlugin.kt
  test/
```

Dependencies: `flutter`, `seisei` and the schema library (after the S1
consolidation both live in `seisei`). It must not depend on `seisei_apple`.

### Dart API sketch

```dart
final class GeminiNanoProvider implements SeiseiProvider {
  const GeminiNanoProvider({
    required this.backend,
    this.config = const GeminiNanoConfig(),
  });

  final GeminiNanoBackend backend;
  final GeminiNanoConfig config;

  @override
  String get id => 'android_gemini_nano';

  /// Starts the model download and reports progress. Apps call this from
  /// their own UI; generate() never downloads implicitly.
  Stream<GeminiNanoDownloadEvent> download();

  /// Loads the model ahead of the first request.
  Future<void> warmup();
}

final class GeminiNanoConfig {
  const GeminiNanoConfig({
    this.preference = GeminiNanoPreference.full,
    this.releaseStage = GeminiNanoReleaseStage.stable,
    this.temperature,
    this.topK,
    this.seed,
    this.maxOutputTokens,
  });
}

abstract interface class GeminiNanoBackend {
  Future<GeminiNanoStatus> status(GeminiNanoConfig config);
  Stream<GeminiNanoDownloadEvent> download(GeminiNanoConfig config);
  Future<void> warmup(GeminiNanoConfig config);
  Future<String> generate(GeminiNanoRequest request);
  Stream<String> stream(GeminiNanoRequest request);
  Future<int> countTokens(GeminiNanoRequest request);
}
```

Per-request overrides travel in `GenerationRequest.metadata` under keys
prefixed `seisei.android.` (for example `seisei.android.temperature`), the
same pattern as `seisei.apple.schemaPath`.

## Native Bridge

- Method channel `dev.jha.seisei/seisei_android` with methods `status`,
  `warmup`, `generate` and `countTokens`.
- Event channels `dev.jha.seisei/seisei_android/stream` for
  `generateContentStream` chunks and
  `dev.jha.seisei/seisei_android/download` for download progress.
- The Kotlin plugin owns one `GenerativeModel` per distinct `GenerationConfig`
  and closes it when the engine detaches.
- Coroutines run on a plugin scope; a cancelled Dart stream subscription
  cancels the collecting coroutine so inference stops.
- Errors cross the channel as `PlatformException(code, message, details)`
  where `code` is the ML Kit error name (`BUSY`,
  `BACKGROUND_USE_BLOCKED`, `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`,
  `BINDING_FAILURE`, `FEATURE_NOT_FOUND`, ...). The Dart side maps these to
  `SeiseiException` codes.
- Gradle: `minSdk 26`, Kotlin coroutines, and `genai-prompt` pinned to an
  exact version. No KSP in the plugin for the first version.

## Test Strategy

Mirrors the Apple provider: CI tests contracts with fakes; real hardware is an
optional local smoke.

1. Dart unit tests with a `FakeGeminiNanoBackend` covering every availability
   state and reason, capability sets, privacy policy acceptance, error-code
   mapping, structured output parse, validate, retry and failure, and stream
   chunk shapes including `partialValue` and `isDone`.
2. Method-channel tests using `TestDefaultBinaryMessengerBinding` to check the
   wire format for each method and event channel.
3. Kotlin unit tests (JVM, no device) for the request builder and error
   mapping, with the ML Kit client behind an interface.
4. CI builds the plugin's Android module (`flutter build apk` on an example
   or `./gradlew assembleDebug`) so Gradle and Kotlin breakage shows up.
   No emulator test, since emulators cannot run Gemini Nano.
5. An optional `tool/android_gemini_nano_smoke.dart` (or integration test) run
   by hand on a supported device, reporting `status`, one plain prompt, one
   structured prompt and one stream. Like the AFM smoke, it is an
   environment probe, not a CI gate.

## Milestones

1. Land this spec (0.1.0).
2. Scaffold `seisei_android` with the backend interface, fake backend and
   provider logic, all tested without a device.
3. Add the Kotlin plugin for `status`, `download`, `warmup` and plain
   `generate`.
4. Add streaming through the event channel.
5. Add JSON-prompted structured output with validation and one retry.
6. Run the device smoke on at least one nano-v3 and one nano-v2 device before
   the first publish.
7. Revisit native typed output and tool calling once Google documents them as
   Beta.

## Open Questions

- Package name: `seisei_android` (platform-named like `seisei_apple`) or
  `seisei_gemini_nano` (model-named)? This spec assumes `seisei_android`.
- Should `DOWNLOADABLE` be reported as available-with-a-download-step instead
  of unavailable? Reporting unavailable keeps routing simple but hides that the
  device could work after a download.
- How good is JSON-prompted output on nano-v2 without system instructions?
  Needs measurement on a real device before structured generation is
  advertised for nano-v2.
- Should the provider auto-retry `BUSY` with backoff, or always surface it so
  the router can fall back immediately?
- Is the foreground-only rule worth checking up front via the app lifecycle,
  or only on the native error?
- Does the ~4,000 token input limit need a `ModelCapability` or request
  metadata so the router can skip the provider for long prompts?
- When Gemini Nano 4's tool calling ships, does it map onto `ToolDefinition`
  JSON schemas at runtime, or will it share the KSP-only limitation?

## Sources

All accessed 2026-10-22.

- [ML Kit GenAI overview: supported devices, quota, foreground rule, API status](https://developers.google.com/ml-kit/genai)
- [Prompt API: get started](https://developers.google.com/ml-kit/genai/prompt/android/get-started)
- [Prompt API: structured output](https://developers.google.com/ml-kit/genai/prompt/android/structured-output)
- [Prompt API: select a model](https://developers.google.com/ml-kit/genai/prompt/android/select-model)
- [Prompt API: system instructions](https://developers.google.com/ml-kit/genai/prompt/android/system-instructions)
- [Android Developers Blog: ML Kit GenAI Prompt API alpha release (Oct 2025)](https://android-developers.googleblog.com/2025/10/ml-kit-genai-prompt-api-alpha-release.html)
- [Android Developers Blog: Gemini Nano experimental access (AI Edge SDK, Oct 2024)](https://android-developers.googleblog.com/2024/10/gemini-nano-experimental-access-available-on-android.html)
- [9to5Google: Gemini Nano 4 and Prompt API preview roadmap (Apr 2026)](https://9to5google.com/2026/04/02/gemini-nano-4-android/)
