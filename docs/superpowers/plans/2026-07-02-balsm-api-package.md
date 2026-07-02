# `balsm_api` Package Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the API layer into a new pure-Dart `packages/balsm_api` package — abstract per-area client interfaces (`AuthApi`), dio implementations (`DioAuthApi`), hand-written DTOs — and migrate every module off raw `Dio`.

**Architecture:** Melos monorepo. New `balsm_api` package holds transport (`BalsmApiClient`, `PhiLeakInterceptor`, `ApiException`, envelope helpers) plus 7 endpoint areas. Core keeps Flutter-coupled config (`ActiveServerStore`, `FlavorConfig`, riverpod DI) and gains a `BalsmApiController` + one `Provider<XxxApi>` per area. Modules bind to abstractions; DTO→domain mapping stays inside each module.

**Tech Stack:** Dart ≥3.4, dio ^5.8.0, flutter_riverpod (core DI only), melos. NO codegen (no freezed/json_serializable/build_runner in balsm_api).

**Spec:** `docs/superpowers/specs/2026-07-02-balsm-api-package-design.md`

## Global Constraints

- `packages/balsm_api/pubspec.yaml` — `environment: sdk: '>=3.4.0 <4.0.0'`, NO `flutter:` dependency, deps: `dio: ^5.8.0` only; dev deps: `test: ^1.25.0`, `mocktail: ^1.0.4`.
- PHI rule (from AGENTS.md / adapters): never log or `toString()` email, userId, tokens, request/response bodies. `ApiException.toString()` must exclude `serverMessage`.
- Wire-key casing is per-area and MUST match exactly: account = camelCase (`preferredLanguage`, `countryCode`, `displayName`); all other areas = snake_case (`device_id`, `token_id`, …).
- Envelope: auth endpoints return FLAT bodies (token fields at top level). All other areas wrap in `{data, error}` — use `unwrapEnvelope`/`unwrapEnvelopeList`.
- Behavior preservation: this is a refactor. Every status-code → failure mapping listed in tasks reproduces current behavior exactly. No new endpoints, no payload changes.
- Modules never import `package:dio/` after their migration task. Core may (DI glue only).
- Verification commands: `(cd packages/balsm_api && dart test)` for the new package; `melos exec --scope=<pkg> -- flutter analyze --no-fatal-infos` per touched package; `melos run analyze` + `melos run test` at the end.
- Commit after every task. Message style: repo uses `[Tag] summary` (e.g. `[Refactor] ...`); keep that.
- Modules have NO existing test suites (verified) — module migration is verified by analyze; new tests are written only in `balsm_api`.

---

### Task 1: Scaffold `balsm_api` package + move `PhiLeakInterceptor`

**Files:**
- Create: `packages/balsm_api/pubspec.yaml`
- Create: `packages/balsm_api/lib/balsm_api.dart`
- Create: `packages/balsm_api/lib/src/transport/phi_leak_interceptor.dart` (copy of `packages/core/lib/src/network/phi_leak_interceptor.dart`, verbatim)
- Create: `packages/balsm_api/test/transport/phi_leak_interceptor_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class PhiLeakInterceptor extends Interceptor` with `static const Set<String> allowedFields` and `static Map<String, dynamic> scrubForTelemetry(Map<dynamic, dynamic> data)`; exported from `package:balsm_api/balsm_api.dart`.

- [ ] **Step 1: Create the package skeleton**

`packages/balsm_api/pubspec.yaml`:

```yaml
name: balsm_api
description: Balsm API contract — typed endpoint interfaces, DTOs, and dio transport.
publish_to: none

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  dio: ^5.8.0

dev_dependencies:
  test: ^1.25.0
  mocktail: ^1.0.4
```

`packages/balsm_api/lib/balsm_api.dart` (grows one export block per task):

```dart
/// Balsm API contract — typed endpoint interfaces, DTOs, and dio transport.
///
/// Pure Dart (no Flutter). PHI constraint: nothing in this package may log
/// or stringify emails, user ids, tokens, or payload bodies.
library balsm_api;

export 'src/transport/phi_leak_interceptor.dart';
```

- [ ] **Step 2: Copy the interceptor verbatim**

```bash
mkdir -p packages/balsm_api/lib/src/transport packages/balsm_api/test/transport
cp packages/core/lib/src/network/phi_leak_interceptor.dart packages/balsm_api/lib/src/transport/phi_leak_interceptor.dart
```

Do NOT edit the copy — its only import is `package:dio/dio.dart`. The core original is deleted in Task 4.

- [ ] **Step 3: Write the failing test**

`packages/balsm_api/test/transport/phi_leak_interceptor_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test('scrubForTelemetry redacts non-allowlisted fields, keeps allowlisted', () {
    final scrubbed = PhiLeakInterceptor.scrubForTelemetry({
      'email': 'a@b.c',
      'status_code': 200,
    });
    expect(scrubbed['email'], '[redacted]');
    expect(scrubbed['status_code'], 200);
  });

  test('onRequest stashes scrubbed copy without mutating the outbound body', () {
    final options = RequestOptions(path: '/x', data: {'email': 'a@b.c'});
    PhiLeakInterceptor().onRequest(
      options,
      RequestInterceptorHandler(),
    );
    expect((options.data as Map)['email'], 'a@b.c'); // wire body untouched
    expect(
      (options.extra['phi_safe_body'] as Map)['email'],
      '[redacted]',
    );
  });
}
```

- [ ] **Step 4: Run — expect failure before `dart pub get`, pass after**

```bash
cd packages/balsm_api && dart pub get && dart test
```
Expected: both tests PASS (interceptor is pre-existing, copied code; the "failing" phase here is the missing package resolution).

- [ ] **Step 5: Bootstrap melos and verify workspace still resolves**

```bash
cd /Volumes/Dev/Balsm/balsm_app_flutter && dart run melos bootstrap
```
Expected: `packages/*` glob picks up balsm_api; SUCCESS output.

- [ ] **Step 6: Commit**

```bash
git add packages/balsm_api
git commit -m "[Refactor] scaffold balsm_api package, move PhiLeakInterceptor"
```

---

### Task 2: `ApiException` + envelope helpers

**Files:**
- Create: `packages/balsm_api/lib/src/transport/api_exception.dart`
- Create: `packages/balsm_api/lib/src/transport/envelope.dart`
- Create: `packages/balsm_api/test/transport/api_exception_test.dart`
- Create: `packages/balsm_api/test/transport/envelope_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart` (add exports)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces (used by EVERY Dio impl and module):
  - `class ApiException implements Exception` — fields `String code`, `int? statusCode`, `String? serverMessage`, `int? retryAfterSeconds`, `bool fromEnvelope`; getter `bool get isUnauthorized` (401||403); factories `ApiException.fromDioException(DioException e)`, `ApiException.fromEnvelopeError(Object error, {int? statusCode})`; static `String codeForStatus(int? status)`.
  - `Map<String, dynamic> unwrapEnvelope(Response<dynamic> response)` — throws `ApiException` when `error` non-null; returns `data` map or `{}`.
  - `List<dynamic> unwrapEnvelopeList(Response<dynamic> response)` — same, for list `data`.

- [ ] **Step 1: Write the failing tests**

`packages/balsm_api/test/transport/api_exception_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

DioException _dioError({int? status, Object? data, Map<String, List<String>>? headers}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: status == null
        ? null
        : Response(
            requestOptions: req,
            statusCode: status,
            data: data,
            headers: Headers.fromMap(headers ?? {}),
          ),
  );
}

void main() {
  test('codeForStatus maps statuses like the legacy auth adapter', () {
    expect(ApiException.codeForStatus(null), 'network_error');
    expect(ApiException.codeForStatus(400), 'invalid_request');
    expect(ApiException.codeForStatus(401), 'unauthorized');
    expect(ApiException.codeForStatus(403), 'forbidden');
    expect(ApiException.codeForStatus(404), 'not_found');
    expect(ApiException.codeForStatus(409), 'conflict');
    expect(ApiException.codeForStatus(410), 'gone');
    expect(ApiException.codeForStatus(422), 'validation_error');
    expect(ApiException.codeForStatus(423), 'account_locked');
    expect(ApiException.codeForStatus(429), 'rate_limited');
    expect(ApiException.codeForStatus(500), 'server_error');
    expect(ApiException.codeForStatus(418), 'network_error');
  });

  test('fromDioException prefers body code, parses Retry-After', () {
    final e = ApiException.fromDioException(_dioError(
      status: 423,
      data: <String, dynamic>{'code': 'account_locked', 'message': 'locked'},
      headers: {'Retry-After': ['90']},
    ));
    expect(e.code, 'account_locked');
    expect(e.statusCode, 423);
    expect(e.serverMessage, 'locked');
    expect(e.retryAfterSeconds, 90);
    expect(e.fromEnvelope, isFalse);
  });

  test('fromDioException reads nested envelope error code', () {
    final e = ApiException.fromDioException(_dioError(
      status: 400,
      data: <String, dynamic>{
        'data': null,
        'error': <String, dynamic>{'code': 'otp_invalid', 'message': 'bad'},
      },
    ));
    expect(e.code, 'otp_invalid');
    expect(e.serverMessage, 'bad');
  });

  test('fromDioException falls back to status mapping', () {
    final e = ApiException.fromDioException(_dioError(status: 500, data: 'oops'));
    expect(e.code, 'server_error');
    expect(e.serverMessage, isNull);
  });

  test('network error (no response) maps to network_error', () {
    final e = ApiException.fromDioException(_dioError());
    expect(e.code, 'network_error');
    expect(e.statusCode, isNull);
  });

  test('toString never leaks serverMessage (PHI safety)', () {
    const e = ApiException(code: 'conflict', statusCode: 409, serverMessage: 'user a@b.c exists');
    expect(e.toString(), isNot(contains('a@b.c')));
  });

  test('isUnauthorized covers 401 and 403', () {
    expect(const ApiException(code: 'unauthorized', statusCode: 401).isUnauthorized, isTrue);
    expect(const ApiException(code: 'forbidden', statusCode: 403).isUnauthorized, isTrue);
    expect(const ApiException(code: 'conflict', statusCode: 409).isUnauthorized, isFalse);
  });
}
```

`packages/balsm_api/test/transport/envelope_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

Response<dynamic> _resp(Object? body, {int status = 200}) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: body,
    );

void main() {
  test('unwrapEnvelope returns data map', () {
    final data = unwrapEnvelope(_resp({'data': {'a': 1}, 'error': null}));
    expect(data, {'a': 1});
  });

  test('unwrapEnvelope returns {} when data missing or not a map', () {
    expect(unwrapEnvelope(_resp({'error': null})), isEmpty);
    expect(unwrapEnvelope(_resp('not json')), isEmpty);
    expect(unwrapEnvelope(_resp(null)), isEmpty);
  });

  test('unwrapEnvelope throws ApiException with fromEnvelope on error', () {
    expect(
      () => unwrapEnvelope(_resp({
        'data': null,
        'error': {'code': 'conflict', 'message': 'Handle taken'},
      })),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'conflict')
          .having((e) => e.serverMessage, 'serverMessage', 'Handle taken')
          .having((e) => e.fromEnvelope, 'fromEnvelope', isTrue)),
    );
  });

  test('unwrapEnvelopeList returns list data and throws on error', () {
    expect(unwrapEnvelopeList(_resp({'data': [1, 2]})), [1, 2]);
    expect(unwrapEnvelopeList(_resp({'data': {'not': 'list'}})), isEmpty);
    expect(
      () => unwrapEnvelopeList(_resp({'error': {'message': 'x'}})),
      throwsA(isA<ApiException>()),
    );
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd packages/balsm_api && dart test
```
Expected: FAIL — `api_exception.dart` / `envelope.dart` don't exist.

- [ ] **Step 3: Implement**

`packages/balsm_api/lib/src/transport/api_exception.dart`:

```dart
import 'package:dio/dio.dart';

/// Transport-level error thrown by every Dio-backed API implementation.
///
/// PHI constraint: [toString] must never include [serverMessage] or any
/// payload content — server text may echo user input (emails, names).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.statusCode,
    this.serverMessage,
    this.retryAfterSeconds,
    this.fromEnvelope = false,
  });

  /// Machine-readable code: server-provided `code` when present, else
  /// derived from the HTTP status via [codeForStatus].
  final String code;

  final int? statusCode;

  /// Raw server-provided message. May contain PII — the display layer
  /// decides whether to show it; never log it.
  final String? serverMessage;

  /// Parsed `Retry-After` header in seconds (lockout/rate-limit responses).
  final int? retryAfterSeconds;

  /// True when the failure came from a `{data, error}` envelope on an
  /// otherwise-successful HTTP response (legacy behavior surfaces these as
  /// validation failures with the server message).
  final bool fromEnvelope;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  factory ApiException.fromDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? code;
    String? message;
    if (data is Map<String, dynamic>) {
      code = data['code'] as String?;
      message = data['message'] as String?;
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        code ??= error['code'] as String?;
        message ??= error['message'] as String?;
      }
    }
    final retryAfterRaw = e.response?.headers.value('Retry-After');
    return ApiException(
      code: code ?? codeForStatus(status),
      statusCode: status,
      serverMessage: message,
      retryAfterSeconds:
          retryAfterRaw == null ? null : int.tryParse(retryAfterRaw),
    );
  }

  factory ApiException.fromEnvelopeError(Object error, {int? statusCode}) {
    if (error is Map<String, dynamic>) {
      return ApiException(
        code: (error['code'] as String?) ?? 'server_error',
        statusCode: statusCode,
        serverMessage: error['message'] as String?,
        fromEnvelope: true,
      );
    }
    return ApiException(
      code: 'server_error',
      statusCode: statusCode,
      fromEnvelope: true,
    );
  }

  /// Status → code mapping, lifted verbatim from the legacy auth adapter
  /// (plus 410 for expired emergency-QR tokens).
  static String codeForStatus(int? status) => switch (status) {
        null => 'network_error',
        400 => 'invalid_request',
        401 => 'unauthorized',
        403 => 'forbidden',
        404 => 'not_found',
        409 => 'conflict',
        410 => 'gone',
        422 => 'validation_error',
        423 => 'account_locked',
        429 => 'rate_limited',
        >= 500 => 'server_error',
        _ => 'network_error',
      };

  @override
  String toString() => 'ApiException(code: $code, status: $statusCode)';
}
```

`packages/balsm_api/lib/src/transport/envelope.dart`:

```dart
import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Unwraps the `{data, error}` envelope used by most Balsm endpoints
/// (auth is the exception — it returns flat bodies).
///
/// Throws [ApiException] when `error` is non-null. Returns `{}` when the
/// body carries no map `data`.
Map<String, dynamic> unwrapEnvelope(Response<dynamic> response) {
  final body = response.data;
  if (body is! Map<String, dynamic>) return const {};
  final error = body['error'];
  if (error != null) {
    throw ApiException.fromEnvelopeError(error, statusCode: response.statusCode);
  }
  final data = body['data'];
  return data is Map<String, dynamic> ? data : const {};
}

/// List variant of [unwrapEnvelope] (e.g. `GET /sessions`).
List<dynamic> unwrapEnvelopeList(Response<dynamic> response) {
  final body = response.data;
  if (body is! Map<String, dynamic>) return const [];
  final error = body['error'];
  if (error != null) {
    throw ApiException.fromEnvelopeError(error, statusCode: response.statusCode);
  }
  final data = body['data'];
  return data is List ? data : const [];
}
```

Add to `packages/balsm_api/lib/balsm_api.dart`:

```dart
export 'src/transport/api_exception.dart';
export 'src/transport/envelope.dart';
```

- [ ] **Step 4: Run tests — verify pass**

```bash
cd packages/balsm_api && dart test
```
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/balsm_api
git commit -m "[Refactor] balsm_api: ApiException and {data,error} envelope helpers"
```

---

### Task 3: Pure `BalsmApiClient` + shared test fake

**Files:**
- Create: `packages/balsm_api/lib/src/transport/balsm_api_client.dart`
- Create: `packages/balsm_api/test/helpers/fake_http_adapter.dart`
- Create: `packages/balsm_api/test/transport/balsm_api_client_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`

**Interfaces:**
- Consumes: `PhiLeakInterceptor` (Task 1).
- Produces:
  - `class BalsmApiClient` — `BalsmApiClient({required Dio dio})`; `Dio get dio`; `String get baseUrl`; `set baseUrl(String value)`; `factory BalsmApiClient.create({required String baseUrl})` (10s connect / 30s receive timeouts, JSON headers, PhiLeakInterceptor installed).
  - Test helper `FakeHttpAdapter` — `FakeHttpAdapter(this.handler)` where `handler` is `ResponseBody Function(RequestOptions options)`; records `requests` list. Every area test in Tasks 5–10 uses it.

- [ ] **Step 1: Write the test helper**

`packages/balsm_api/test/helpers/fake_http_adapter.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Canned-response HttpClientAdapter for exercising Dio impls without a
/// network. Records every request for assertion.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// JSON 200/xx response shorthand.
ResponseBody jsonResponse(String json, {int status = 200, Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(
      json,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...?headers,
      },
    );

/// Dio wired to a [FakeHttpAdapter], mirroring BalsmApiClient BaseOptions.
Dio fakeDio(FakeHttpAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.test',
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    // Surface non-2xx as DioException like production defaults.
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}
```

- [ ] **Step 2: Write the failing client test**

`packages/balsm_api/test/transport/balsm_api_client_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

void main() {
  test('create() configures baseUrl, timeouts, headers, PHI interceptor', () {
    final client = BalsmApiClient.create(baseUrl: 'https://api.example.com');
    expect(client.baseUrl, 'https://api.example.com');
    expect(client.dio.options.connectTimeout, const Duration(seconds: 10));
    expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
    expect(client.dio.options.headers['Accept'], 'application/json');
    expect(client.dio.options.headers['Content-Type'], 'application/json');
    expect(client.dio.interceptors.whereType<PhiLeakInterceptor>(), hasLength(1));
  });

  test('baseUrl setter re-points the shared Dio instance', () {
    final client = BalsmApiClient.create(baseUrl: 'https://a.example');
    client.baseUrl = 'https://b.example';
    expect(client.dio.options.baseUrl, 'https://b.example');
  });
}
```

- [ ] **Step 3: Run — verify fail**

```bash
cd packages/balsm_api && dart test test/transport/balsm_api_client_test.dart
```
Expected: FAIL — `BalsmApiClient` undefined.

- [ ] **Step 4: Implement**

`packages/balsm_api/lib/src/transport/balsm_api_client.dart`:

```dart
import 'package:dio/dio.dart';

import 'phi_leak_interceptor.dart';

/// Owns the shared [Dio] instance for all Balsm API areas.
///
/// Pure Dart on purpose: server-preset persistence, flavors, and DI live in
/// the app's `core` package, which drives [baseUrl] at runtime.
class BalsmApiClient {
  BalsmApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Dio get dio => _dio;

  String get baseUrl => _dio.options.baseUrl;

  set baseUrl(String value) => _dio.options.baseUrl = value;

  factory BalsmApiClient.create({required String baseUrl}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(PhiLeakInterceptor());
    return BalsmApiClient(dio: dio);
  }
}
```

Add to `packages/balsm_api/lib/balsm_api.dart`:

```dart
export 'src/transport/balsm_api_client.dart';
```

- [ ] **Step 5: Run all package tests — pass**

```bash
cd packages/balsm_api && dart test
```
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/balsm_api
git commit -m "[Refactor] balsm_api: pure BalsmApiClient + FakeHttpAdapter test helper"
```

---

### Task 4: Rewire core onto `balsm_api` (controller, providers, exports)

**Files:**
- Modify: `packages/core/pubspec.yaml` (add `balsm_api` path dep)
- Create: `packages/core/lib/src/network/balsm_api_controller.dart`
- Create: `packages/core/lib/src/network/api_providers.dart` (starts with client/dio providers; grows per area in Tasks 5–10)
- Delete: `packages/core/lib/src/network/balsm_api_client.dart`
- Delete: `packages/core/lib/src/network/phi_leak_interceptor.dart`
- Delete: `packages/core/lib/src/network/dio_client_provider.dart`
- Modify: `packages/core/lib/core.dart:12-14` (exports)
- Modify: `packages/core/lib/src/dev/server_selector_screen.dart` (client → controller)
- Modify: `packages/account/lib/src/presentation/routes.dart:49-51` (controller provider)
- Modify: root `pubspec.yaml` (add `balsm_api` path dev dep) and `test/phi_leak_fuzz_test/sentry_allowlist_test.dart` (import)

**Interfaces:**
- Consumes: `BalsmApiClient`, `PhiLeakInterceptor` from `balsm_api`.
- Produces (all exported via `package:core/core.dart`):
  - `class ServerReconfigured extends AppEvent` — unchanged shape (`preset` field).
  - `class BalsmApiController` — `BalsmApiController({required BalsmApiClient client, required ActiveServerStore store, required EventBus bus})`; `BalsmApiClient get client`; `Future<void> init()`; `Future<void> reconfigure(ServerPreset preset)`; `static BalsmApiController create({required FlutterSecureStorage storage, required EventBus bus})`.
  - `final balsmApiControllerProvider = Provider<BalsmApiController>` (throws `UnimplementedError` until overridden — same contract the old `balsmApiClientProvider` had).
  - `final balsmApiClientProvider = Provider<BalsmApiClient>` (derives from controller).
  - `final dioClientProvider = Provider<Dio>` (TEMPORARY — deleted in Task 11; keeps unmigrated modules compiling).

- [ ] **Step 1: Add the dependency**

In `packages/core/pubspec.yaml` `dependencies:` block (after `dio: ^5.8.0`):

```yaml
  balsm_api:
    path: ../balsm_api
```

- [ ] **Step 2: Create the controller**

`packages/core/lib/src/network/balsm_api_controller.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/active_server.dart';
import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';

class ServerReconfigured extends AppEvent {
  final ServerPreset preset;
  const ServerReconfigured(this.preset);
  @override String get eventName => 'server_reconfigured';
  @override Map<String, dynamic> toJson() => {'preset': preset.apiBaseUrl};
}

/// Flutter-side owner of the pure [BalsmApiClient]: applies persisted server
/// presets on startup and handles dev-time server switching.
class BalsmApiController {
  BalsmApiController({
    required BalsmApiClient client,
    required ActiveServerStore store,
    required EventBus bus,
  })  : _client = client,
        _store = store,
        _bus = bus;

  final BalsmApiClient _client;
  final ActiveServerStore _store;
  final EventBus _bus;

  BalsmApiClient get client => _client;

  Future<void> init() async {
    final preset = await _store.read() ?? _store.defaultPreset;
    _client.baseUrl = preset.apiBaseUrl;
  }

  Future<void> reconfigure(ServerPreset preset) async {
    await _store.write(preset);
    _client.baseUrl = preset.apiBaseUrl;
    _bus.publish(ServerReconfigured(preset));
  }

  static BalsmApiController create({
    required FlutterSecureStorage storage,
    required EventBus bus,
  }) {
    return BalsmApiController(
      client: BalsmApiClient.create(baseUrl: FlavorConfig.current.apiBaseUrl),
      store: ActiveServerStore(storage),
      bus: bus,
    );
  }
}
```

- [ ] **Step 3: Create the providers file**

`packages/core/lib/src/network/api_providers.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'balsm_api_controller.dart';

/// Root override point — the app's ProviderScope must override this with a
/// constructed [BalsmApiController] (same contract the old
/// balsmApiClientProvider had).
final balsmApiControllerProvider = Provider<BalsmApiController>((ref) {
  throw UnimplementedError('Override balsmApiControllerProvider in ProviderScope');
});

final balsmApiClientProvider = Provider<BalsmApiClient>((ref) {
  return ref.watch(balsmApiControllerProvider).client;
});

/// TEMPORARY during the balsm_api migration — deleted once no module reads
/// raw Dio anymore.
final dioClientProvider = Provider<Dio>((ref) {
  return ref.watch(balsmApiClientProvider).dio;
});

// One Provider<XxxApi> per area is appended here by each area task.
```

- [ ] **Step 4: Delete old files, re-point exports**

```bash
git rm packages/core/lib/src/network/balsm_api_client.dart packages/core/lib/src/network/phi_leak_interceptor.dart packages/core/lib/src/network/dio_client_provider.dart
```

In `packages/core/lib/core.dart` replace lines 12–14:

```dart
export 'src/network/balsm_api_client.dart';
export 'src/network/phi_leak_interceptor.dart';
export 'src/network/dio_client_provider.dart';
```

with:

```dart
export 'package:balsm_api/balsm_api.dart';
export 'src/network/balsm_api_controller.dart';
export 'src/network/api_providers.dart';
```

(The `balsm_api` re-export keeps every existing `package:core/core.dart` consumer — geofence's `BalsmApiClient` reference, disclosure, settings screen — compiling before their own migration tasks. Modules still gain a DIRECT `balsm_api` dependency in their migration task; the re-export is a transition aid and stays afterward for convenience.)

- [ ] **Step 5: Port the server selector screen**

In `packages/core/lib/src/dev/server_selector_screen.dart`:

Replace:
```dart
import '../network/balsm_api_client.dart';

class ServerSelectorScreen extends StatefulWidget {
  const ServerSelectorScreen({super.key, required this.client});
  final BalsmApiClient client;
```
with:
```dart
import '../network/balsm_api_controller.dart';

class ServerSelectorScreen extends StatefulWidget {
  const ServerSelectorScreen({super.key, required this.controller});
  final BalsmApiController controller;
```

Replace `String get _currentBaseUrl => widget.client.dio.options.baseUrl;` with `String get _currentBaseUrl => widget.controller.client.baseUrl;`

Replace `await widget.client.reconfigure(preset);` with `await widget.controller.reconfigure(preset);`

- [ ] **Step 6: Port the account dev route**

In `packages/account/lib/src/presentation/routes.dart` replace:
```dart
      final client =
          ProviderScope.containerOf(context).read(balsmApiClientProvider);
      return ServerSelectorScreen(client: client);
```
with:
```dart
      final controller =
          ProviderScope.containerOf(context).read(balsmApiControllerProvider);
      return ServerSelectorScreen(controller: controller);
```
Also update the comment two lines above it (mentions `BalsmApiClient`) to say `BalsmApiController`.

- [ ] **Step 7: Re-point the root PHI fuzz suite**

Root `pubspec.yaml` `dev_dependencies:` — add below the `core:` path dep:

```yaml
  balsm_api:
    path: packages/balsm_api
```

In `test/phi_leak_fuzz_test/sentry_allowlist_test.dart`: the `import 'package:core/core.dart';` still resolves `PhiLeakInterceptor` via the re-export, so no import change is strictly required — but update the stale path comment (`packages/core/lib/src/network/phi_leak_interceptor.dart` → `packages/balsm_api/lib/src/transport/phi_leak_interceptor.dart`).

- [ ] **Step 8: Verify**

```bash
dart run melos bootstrap
melos exec --scope=core --scope=account -- "flutter analyze --no-fatal-infos"
melos exec --scope=core -- "flutter test"
cd /Volumes/Dev/Balsm/balsm_app_flutter && flutter test test/phi_leak_fuzz_test
```
Expected: analyze clean for core + account; core tests pass; fuzz suite passes.

- [ ] **Step 9: Commit**

```bash
git add -A packages/core packages/account pubspec.yaml test/phi_leak_fuzz_test
git commit -m "[Refactor] core: rewire transport onto balsm_api via BalsmApiController"
```

---

### Task 5: emergency_qr area + emergency_card migration

**Files:**
- Create: `packages/balsm_api/lib/src/emergency_qr/emergency_qr_api.dart`
- Create: `packages/balsm_api/lib/src/emergency_qr/requests.dart`
- Create: `packages/balsm_api/lib/src/emergency_qr/responses.dart`
- Create: `packages/balsm_api/lib/src/emergency_qr/dio_emergency_qr_api.dart`
- Create: `packages/balsm_api/test/emergency_qr/dio_emergency_qr_api_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`
- Modify: `packages/core/lib/src/network/api_providers.dart` (add provider)
- Modify: `packages/emergency_card/pubspec.yaml` (swap `dio` → `balsm_api`)
- Modify: `packages/emergency_card/lib/src/application/use_cases/mint_emergency_qr_token_use_case.dart`
- Modify: `packages/emergency_card/lib/src/application/use_cases/resolve_emergency_qr_token_use_case.dart`
- Modify: `packages/emergency_card/lib/src/application/use_cases/revoke_emergency_qr_token_use_case.dart`

**Interfaces:**
- Consumes: `unwrapEnvelope`, `ApiException`, `FakeHttpAdapter`/`jsonResponse`/`fakeDio`.
- Produces:
  - `abstract class EmergencyQrApi { Future<MintQrResponse> mint(MintQrRequest request); Future<ResolveQrResponse> resolve(String tokenId); Future<void> revoke(RevokeQrRequest request); }`
  - `class MintQrRequest { final String ciphertextBase64; final int ttlSeconds; }` → json `{'ciphertext_base64', 'ttl_seconds'}`
  - `class MintQrResponse { final String tokenId; final DateTime expiresAt; }` ← json `{'token_id', 'expires_at'}`
  - `class ResolveQrResponse { final String? ciphertextBase64; }` ← json `{'ciphertext_base64'}` (nullable — expired/revoked)
  - `class RevokeQrRequest { final String tokenId; }` → json `{'token_id'}`
  - `class DioEmergencyQrApi implements EmergencyQrApi` — `DioEmergencyQrApi({required Dio dio})`
  - Core: `final emergencyQrApiProvider = Provider<EmergencyQrApi>`

- [ ] **Step 1: Write the failing area tests**

`packages/balsm_api/test/emergency_qr/dio_emergency_qr_api_test.dart`:

```dart
import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('mint posts snake_case body and parses token envelope', () async {
    final adapter = FakeHttpAdapter((options) => jsonResponse(
        '{"data": {"token_id": "jti-1", "expires_at": "2026-07-02T10:00:00Z"}, "error": null}'));
    final api = DioEmergencyQrApi(dio: fakeDio(adapter));

    final res = await api.mint(
        const MintQrRequest(ciphertextBase64: 'abc=', ttlSeconds: 900));

    expect(adapter.requests.single.path, '/emergency-qr/mint');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data,
        {'ciphertext_base64': 'abc=', 'ttl_seconds': 900});
    expect(res.tokenId, 'jti-1');
    expect(res.expiresAt, DateTime.parse('2026-07-02T10:00:00Z'));
  });

  test('mint throws ApiException on HTTP error', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 401));
    final api = DioEmergencyQrApi(dio: fakeDio(adapter));
    expect(
      () => api.mint(const MintQrRequest(ciphertextBase64: 'x', ttlSeconds: 1)),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('resolve GETs token path and surfaces nullable ciphertext', () async {
    final adapter = FakeHttpAdapter((_) =>
        jsonResponse(jsonEncode({'data': {'ciphertext_base64': null}})));
    final api = DioEmergencyQrApi(dio: fakeDio(adapter));

    final res = await api.resolve('jti-9');

    expect(adapter.requests.single.path, '/emergency-qr/resolve/jti-9');
    expect(res.ciphertextBase64, isNull);
  });

  test('revoke posts token_id and returns void', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    final api = DioEmergencyQrApi(dio: fakeDio(adapter));

    await api.revoke(const RevokeQrRequest(tokenId: 'jti-9'));

    expect(adapter.requests.single.data, {'token_id': 'jti-9'});
  });
}
```

- [ ] **Step 2: Run — verify fail**

```bash
cd packages/balsm_api && dart test test/emergency_qr
```
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement the area**

`packages/balsm_api/lib/src/emergency_qr/requests.dart`:

```dart
/// POST /emergency-qr/mint body. The AES-GCM key is NEVER part of any
/// request — client-side encryption only.
class MintQrRequest {
  const MintQrRequest({required this.ciphertextBase64, required this.ttlSeconds});

  final String ciphertextBase64;
  final int ttlSeconds;

  Map<String, dynamic> toJson() => {
        'ciphertext_base64': ciphertextBase64,
        'ttl_seconds': ttlSeconds,
      };
}

/// POST /emergency-qr/revoke body.
class RevokeQrRequest {
  const RevokeQrRequest({required this.tokenId});

  final String tokenId;

  Map<String, dynamic> toJson() => {'token_id': tokenId};
}
```

`packages/balsm_api/lib/src/emergency_qr/responses.dart`:

```dart
class MintQrResponse {
  const MintQrResponse({required this.tokenId, required this.expiresAt});

  final String tokenId;
  final DateTime expiresAt;

  factory MintQrResponse.fromJson(Map<String, dynamic> json) => MintQrResponse(
        tokenId: json['token_id'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

class ResolveQrResponse {
  const ResolveQrResponse({this.ciphertextBase64});

  /// Null when the token is expired/revoked (module maps to not-found).
  final String? ciphertextBase64;

  factory ResolveQrResponse.fromJson(Map<String, dynamic> json) =>
      ResolveQrResponse(ciphertextBase64: json['ciphertext_base64'] as String?);
}
```

`packages/balsm_api/lib/src/emergency_qr/emergency_qr_api.dart`:

```dart
import 'requests.dart';
import 'responses.dart';

/// Emergency QR endpoints (.NET module: EmergencyQr).
/// All methods throw [ApiException] on transport or envelope errors.
abstract class EmergencyQrApi {
  /// POST /emergency-qr/mint
  Future<MintQrResponse> mint(MintQrRequest request);

  /// GET /emergency-qr/resolve/{tokenId} — public, unauthenticated.
  Future<ResolveQrResponse> resolve(String tokenId);

  /// POST /emergency-qr/revoke
  Future<void> revoke(RevokeQrRequest request);
}
```

`packages/balsm_api/lib/src/emergency_qr/dio_emergency_qr_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'emergency_qr_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioEmergencyQrApi implements EmergencyQrApi {
  const DioEmergencyQrApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<MintQrResponse> mint(MintQrRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/emergency-qr/mint',
        data: request.toJson(),
      );
      return MintQrResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<ResolveQrResponse> resolve(String tokenId) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/emergency-qr/resolve/$tokenId');
      return ResolveQrResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> revoke(RevokeQrRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/emergency-qr/revoke',
        data: request.toJson(),
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
```

Add to `packages/balsm_api/lib/balsm_api.dart`:

```dart
export 'src/emergency_qr/emergency_qr_api.dart';
export 'src/emergency_qr/dio_emergency_qr_api.dart';
export 'src/emergency_qr/requests.dart';
export 'src/emergency_qr/responses.dart';
```

- [ ] **Step 4: Run — verify pass**

```bash
cd packages/balsm_api && dart test
```
Expected: ALL PASS.

- [ ] **Step 5: Add the core provider**

Append to `packages/core/lib/src/network/api_providers.dart`:

```dart
final emergencyQrApiProvider = Provider<EmergencyQrApi>((ref) {
  return DioEmergencyQrApi(dio: ref.watch(balsmApiClientProvider).dio);
});
```

- [ ] **Step 6: Migrate emergency_card**

`packages/emergency_card/pubspec.yaml`: delete the `dio: ^5.8.0` line; add:

```yaml
  balsm_api:
    path: ../balsm_api
```

**mint_emergency_qr_token_use_case.dart** — replace the dio import with `import 'package:balsm_api/balsm_api.dart';`; constructor `required Dio dio` → `required EmergencyQrApi api`, field `final Dio _dio` → `final EmergencyQrApi _api` (init `_api = api`). Replace the HTTP block:

```dart
// BEFORE (shape):
response = await _dio.post<dynamic>('/emergency-qr/mint', data: {
  'ciphertext_base64': ciphertextBase64,
  'ttl_seconds': ttlSeconds,
});
// ...envelope/data extraction, jti/expiresAt parse...
} on DioException catch (e) { return _mapDioError(e); }

// AFTER:
final MintQrResponse minted;
try {
  minted = await _api.mint(MintQrRequest(
    ciphertextBase64: ciphertextBase64,
    ttlSeconds: ttlSeconds,
  ));
} on ApiException catch (e) {
  return AppResult.failure(_mapApiError(e));
}
final jti = minted.tokenId;
final expiresAt = minted.expiresAt;
```

Delete the manual envelope/`data == null` checks (`NetworkFailure('Malformed mint response')` case disappears — a missing `token_id` now throws a `TypeError` inside `fromJson`; guard it by catching it in the same try as `on ApiException`, adding `on TypeError { return AppResult.failure(NetworkFailure('Malformed mint response')); }`). Replace `_mapDioError` with:

```dart
Failure _mapApiError(ApiException e) {
  if (e.isUnauthorized) return UnauthorizedFailure();
  if (e.statusCode == 422 || e.statusCode == 400) {
    return ValidationFailure('Invalid mint request');
  }
  return NetworkFailure('Could not generate emergency QR');
}
```

Provider at file bottom: `dio: ref.watch(dioClientProvider)` → `api: ref.watch(emergencyQrApiProvider)`.

**resolve_emergency_qr_token_use_case.dart** — same import/constructor swap (`required EmergencyQrApi api`). Replace HTTP + parse:

```dart
final ResolveQrResponse resolved;
try {
  resolved = await _api.resolve(tokenId);
} on ApiException catch (e) {
  if (e.statusCode == 404 || e.statusCode == 410) {
    return AppResult.failure(NotFoundFailure('QR expired or revoked'));
  }
  return AppResult.failure(NetworkFailure('Could not resolve QR'));
}
final ciphertextBase64 = resolved.ciphertextBase64;
if (ciphertextBase64 == null) {
  return AppResult.failure(NotFoundFailure('QR expired or revoked'));
}
```

Keep every pre-existing key-validation / base64 / decrypt step untouched. Provider: `api: ref.watch(emergencyQrApiProvider)`.

**revoke_emergency_qr_token_use_case.dart** — same swap. HTTP block:

```dart
try {
  await _api.revoke(RevokeQrRequest(tokenId: tokenId));
} on ApiException catch (e) {
  if (e.isUnauthorized) return AppResult.failure(UnauthorizedFailure());
  if (e.statusCode == 404) {
    return AppResult.failure(NotFoundFailure('Token not found'));
  }
  return AppResult.failure(NetworkFailure('Could not revoke QR'));
}
```

Provider: `api: ref.watch(emergencyQrApiProvider)`.

- [ ] **Step 7: Verify**

```bash
dart run melos bootstrap
melos exec --scope=balsm_api --scope=core --scope=emergency_card -- "flutter analyze --no-fatal-infos"
grep -rn "package:dio" packages/emergency_card/lib && echo "DIO STILL PRESENT — FIX" || echo "clean"
```
Expected: analyze clean ×3; grep prints `clean`.

- [ ] **Step 8: Commit**

```bash
git add packages/balsm_api packages/core packages/emergency_card
git commit -m "[Refactor] emergency_card: consume EmergencyQrApi from balsm_api"
```

---

### Task 6: sessions area + migration

**Files:**
- Create: `packages/balsm_api/lib/src/sessions/sessions_api.dart`
- Create: `packages/balsm_api/lib/src/sessions/responses.dart` (no requests file — no bodies)
- Create: `packages/balsm_api/lib/src/sessions/dio_sessions_api.dart`
- Create: `packages/balsm_api/test/sessions/dio_sessions_api_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`, `packages/core/lib/src/network/api_providers.dart`
- Modify: `packages/sessions/pubspec.yaml` (`dio` → `balsm_api`)
- Modify: `packages/sessions/lib/src/application/use_cases/list_active_sessions_use_case.dart`
- Modify: `packages/sessions/lib/src/application/use_cases/revoke_session_use_case.dart`
- Modify: `packages/sessions/lib/src/application/use_cases/sign_out_everywhere_use_case.dart`

**Interfaces:**
- Consumes: envelope helpers, `ApiException`, test helpers.
- Produces:
  - `abstract class SessionsApi { Future<List<SessionResponse>> listSessions(); Future<void> revokeSession(String sessionId); Future<RevokeAllSessionsResponse> revokeAllSessions(); }`
  - `class SessionResponse { final String id; final String deviceId; final String deviceLabel; final String deviceType; final DateTime firstSeenAt; final DateTime lastActivityAt; final DateTime? revokedAt; final bool isCurrent; }` ← wire keys `id, device_id, device_label, device_type, first_seen_at, last_activity_at, revoked_at, is_current`; all DateTimes `.toUtc()`; `isCurrent` defaults false.
  - `class RevokeAllSessionsResponse { final int revokedCount; }` ← `{'revoked_count': num}`, default 0.
  - `class DioSessionsApi implements SessionsApi` — `DioSessionsApi({required Dio dio})`
  - Core: `final sessionsApiProvider = Provider<SessionsApi>`

- [ ] **Step 1: Write the failing tests**

`packages/balsm_api/test/sessions/dio_sessions_api_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('listSessions parses envelope list with UTC dates', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('''
      {"data": [{
        "id": "s1", "device_id": "d1", "device_label": "iPhone",
        "device_type": "ios", "first_seen_at": "2026-01-01T00:00:00+02:00",
        "last_activity_at": "2026-01-02T00:00:00Z",
        "revoked_at": null, "is_current": true
      }], "error": null}'''));
    final api = DioSessionsApi(dio: fakeDio(adapter));

    final sessions = await api.listSessions();

    expect(adapter.requests.single.path, '/sessions');
    expect(sessions, hasLength(1));
    expect(sessions.first.id, 's1');
    expect(sessions.first.firstSeenAt.isUtc, isTrue);
    expect(sessions.first.revokedAt, isNull);
    expect(sessions.first.isCurrent, isTrue);
  });

  test('listSessions throws fromEnvelope ApiException on error body', () {
    final adapter = FakeHttpAdapter((_) =>
        jsonResponse('{"data": null, "error": {"message": "boom"}}'));
    final api = DioSessionsApi(dio: fakeDio(adapter));
    expect(
      api.listSessions(),
      throwsA(isA<ApiException>()
          .having((e) => e.fromEnvelope, 'fromEnvelope', isTrue)
          .having((e) => e.serverMessage, 'serverMessage', 'boom')),
    );
  });

  test('revokeSession DELETEs the session path', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    await DioSessionsApi(dio: fakeDio(adapter)).revokeSession('s9');
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/sessions/s9');
  });

  test('revokeAllSessions parses revoked_count with 0 default', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"revoked_count": 3}}'));
    final res =
        await DioSessionsApi(dio: fakeDio(adapter)).revokeAllSessions();
    expect(res.revokedCount, 3);

    final adapter2 = FakeHttpAdapter((_) => jsonResponse('{"data": {}}'));
    final res2 =
        await DioSessionsApi(dio: fakeDio(adapter2)).revokeAllSessions();
    expect(res2.revokedCount, 0);
  });
}
```

- [ ] **Step 2: Run — verify fail** — `cd packages/balsm_api && dart test test/sessions` → FAIL (types undefined).

- [ ] **Step 3: Implement**

`packages/balsm_api/lib/src/sessions/responses.dart`:

```dart
class SessionResponse {
  const SessionResponse({
    required this.id,
    required this.deviceId,
    required this.deviceLabel,
    required this.deviceType,
    required this.firstSeenAt,
    required this.lastActivityAt,
    this.revokedAt,
    this.isCurrent = false,
  });

  final String id;
  final String deviceId;
  final String deviceLabel;
  final String deviceType;
  final DateTime firstSeenAt;
  final DateTime lastActivityAt;
  final DateTime? revokedAt;
  final bool isCurrent;

  factory SessionResponse.fromJson(Map<String, dynamic> json) => SessionResponse(
        id: json['id'] as String,
        deviceId: json['device_id'] as String,
        deviceLabel: json['device_label'] as String,
        deviceType: json['device_type'] as String,
        firstSeenAt: DateTime.parse(json['first_seen_at'] as String).toUtc(),
        lastActivityAt:
            DateTime.parse(json['last_activity_at'] as String).toUtc(),
        revokedAt: json['revoked_at'] != null
            ? DateTime.parse(json['revoked_at'] as String).toUtc()
            : null,
        isCurrent: json['is_current'] as bool? ?? false,
      );
}

class RevokeAllSessionsResponse {
  const RevokeAllSessionsResponse({required this.revokedCount});

  final int revokedCount;

  factory RevokeAllSessionsResponse.fromJson(Map<String, dynamic> json) =>
      RevokeAllSessionsResponse(
        revokedCount: (json['revoked_count'] as num?)?.toInt() ?? 0,
      );
}
```

`packages/balsm_api/lib/src/sessions/sessions_api.dart`:

```dart
import 'responses.dart';

/// Session-management endpoints (.NET module: Sessions).
/// All methods throw [ApiException] on transport or envelope errors.
abstract class SessionsApi {
  /// GET /sessions
  Future<List<SessionResponse>> listSessions();

  /// DELETE /sessions/{sessionId}
  Future<void> revokeSession(String sessionId);

  /// POST /sessions/revoke-all
  Future<RevokeAllSessionsResponse> revokeAllSessions();
}
```

`packages/balsm_api/lib/src/sessions/dio_sessions_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'responses.dart';
import 'sessions_api.dart';

class DioSessionsApi implements SessionsApi {
  const DioSessionsApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<SessionResponse>> listSessions() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/sessions');
      return unwrapEnvelopeList(res)
          .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/sessions/$sessionId');
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/sessions/revoke-all');
      return RevokeAllSessionsResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
```

Exports in `balsm_api.dart`:

```dart
export 'src/sessions/sessions_api.dart';
export 'src/sessions/dio_sessions_api.dart';
export 'src/sessions/responses.dart';
```

- [ ] **Step 4: Run — verify pass** — `cd packages/balsm_api && dart test` → ALL PASS.

- [ ] **Step 5: Core provider**

Append to `api_providers.dart`:

```dart
final sessionsApiProvider = Provider<SessionsApi>((ref) {
  return DioSessionsApi(dio: ref.watch(balsmApiClientProvider).dio);
});
```

- [ ] **Step 6: Migrate the sessions module**

`packages/sessions/pubspec.yaml`: remove `dio: ^5.8.0`, add `balsm_api: {path: ../balsm_api}` (YAML block form as in Task 5).

**list_active_sessions_use_case.dart** — swap dio import → `package:balsm_api/balsm_api.dart`; `final Dio _dio` → `final SessionsApi _api`; ctor `ListActiveSessionsUseCase(this._api)`. Body becomes:

```dart
Future<AppResult<List<ActiveSession>>> call() async {
  try {
    final sessions = await _api.listSessions();
    return AppResult.success(
      sessions.map(_toDomain).toList(growable: false),
    );
  } on ApiException catch (e) {
    return AppResult.failure(_failureFor(e));
  }
}

ActiveSession _toDomain(SessionResponse r) => ActiveSession(
      id: r.id,
      deviceId: r.deviceId,
      deviceLabel: r.deviceLabel,
      deviceType: r.deviceType,
      firstSeenAt: r.firstSeenAt,
      lastActivityAt: r.lastActivityAt,
      revokedAt: r.revokedAt,
      isCurrent: r.isCurrent,
    );

Failure _failureFor(ApiException e) {
  if (e.fromEnvelope) {
    return ValidationFailure(e.serverMessage ?? 'Unable to load sessions.');
  }
  if (e.isUnauthorized) return UnauthorizedFailure();
  return NetworkFailure();
}
```

Delete the old `_messageFailure`/envelope-check code. Provider: `ListActiveSessionsUseCase(ref.watch(sessionsApiProvider))`.

**revoke_session_use_case.dart** — same swaps (`RevokeSessionUseCase(this._api, this._bus)`). Body:

```dart
try {
  await _api.revokeSession(sessionId);
} on ApiException catch (e) {
  if (e.fromEnvelope) {
    return AppResult.failure(
        ValidationFailure(e.serverMessage ?? 'Unable to revoke session.'));
  }
  if (e.isUnauthorized) return AppResult.failure(UnauthorizedFailure());
  if (e.statusCode == 404) {
    return AppResult.failure(NotFoundFailure('Session not found.'));
  }
  return AppResult.failure(NetworkFailure());
}
_bus.publish(SessionRevoked(sessionId, deviceLabel));
return AppResult.success(null);
```

Provider: `RevokeSessionUseCase(ref.watch(sessionsApiProvider), ref.watch(eventBusProvider))`.

**sign_out_everywhere_use_case.dart** — same swaps. Body:

```dart
try {
  final res = await _api.revokeAllSessions();
  _bus.publish(SessionRevoked(sessionId: '*', deviceLabel: 'All devices'));
  return AppResult.success(res.revokedCount);
} on ApiException catch (e) {
  if (e.fromEnvelope) {
    return AppResult.failure(
        ValidationFailure(e.serverMessage ?? 'Unable to sign out everywhere.'));
  }
  if (e.isUnauthorized) return AppResult.failure(UnauthorizedFailure());
  return AppResult.failure(NetworkFailure());
}
```

(Match the existing `SessionRevoked` constructor call shape — if it uses positional args `SessionRevoked('*', 'All devices')`, keep positional.)

- [ ] **Step 7: Verify**

```bash
dart run melos bootstrap
melos exec --scope=balsm_api --scope=core --scope=sessions -- "flutter analyze --no-fatal-infos"
grep -rn "package:dio" packages/sessions/lib && echo "DIO STILL PRESENT — FIX" || echo "clean"
```

- [ ] **Step 8: Commit**

```bash
git add packages/balsm_api packages/core packages/sessions
git commit -m "[Refactor] sessions: consume SessionsApi from balsm_api"
```

---

### Task 7: deletion area + migration

**Files:**
- Create: `packages/balsm_api/lib/src/deletion/deletion_api.dart`
- Create: `packages/balsm_api/lib/src/deletion/responses.dart`
- Create: `packages/balsm_api/lib/src/deletion/dio_deletion_api.dart`
- Create: `packages/balsm_api/test/deletion/dio_deletion_api_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`, `packages/core/lib/src/network/api_providers.dart`
- Modify: `packages/deletion/pubspec.yaml` (`dio` → `balsm_api`)
- Modify: `packages/deletion/lib/src/application/use_cases/request_deletion_use_case.dart`
- Modify: `packages/deletion/lib/src/application/use_cases/cancel_deletion_use_case.dart`

**Interfaces:**
- Consumes: envelope helpers, `ApiException`, test helpers.
- Produces:
  - `abstract class DeletionApi { Future<DeletionIntakeResponse> requestIntake(); Future<DeletionCancelResponse> cancel(); }`
  - `class DeletionIntakeResponse { final DateTime graceUntil; final String? deletionState; }` ← `{'grace_until'(.toUtc()), 'deletion_state'}`
  - `class DeletionCancelResponse { final String? deletionState; }` ← `{'deletion_state'}`
  - `class DioDeletionApi implements DeletionApi` — `DioDeletionApi({required Dio dio})`
  - Core: `final deletionApiProvider = Provider<DeletionApi>`
  - Wire states are strings (`'DELETION_REQUESTED'`, `'DELETION_CANCELLED'`); the module's `_parseState` → `DeletionState` enum mapping STAYS in the module.

- [ ] **Step 1: Write the failing tests**

`packages/balsm_api/test/deletion/dio_deletion_api_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('requestIntake POSTs and parses grace_until as UTC', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"grace_until": "2026-07-30T00:00:00+02:00", "deletion_state": "DELETION_REQUESTED"}}'));
    final api = DioDeletionApi(dio: fakeDio(adapter));

    final res = await api.requestIntake();

    expect(adapter.requests.single.path, '/deletion/intake');
    expect(adapter.requests.single.method, 'POST');
    expect(res.graceUntil.isUtc, isTrue);
    expect(res.deletionState, 'DELETION_REQUESTED');
  });

  test('cancel POSTs and parses deletion_state', () async {
    final adapter = FakeHttpAdapter((_) =>
        jsonResponse('{"data": {"deletion_state": "DELETION_CANCELLED"}}'));
    final res = await DioDeletionApi(dio: fakeDio(adapter)).cancel();
    expect(res.deletionState, 'DELETION_CANCELLED');
  });

  test('envelope error surfaces as fromEnvelope ApiException', () {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"error": {"message": "already pending"}}'));
    expect(
      DioDeletionApi(dio: fakeDio(adapter)).requestIntake(),
      throwsA(isA<ApiException>()
          .having((e) => e.serverMessage, 'serverMessage', 'already pending')),
    );
  });
}
```

- [ ] **Step 2: Run — verify fail** — `cd packages/balsm_api && dart test test/deletion` → FAIL.

- [ ] **Step 3: Implement**

`packages/balsm_api/lib/src/deletion/responses.dart`:

```dart
class DeletionIntakeResponse {
  const DeletionIntakeResponse({required this.graceUntil, this.deletionState});

  final DateTime graceUntil;

  /// Wire values: 'ACTIVE' | 'DELETION_REQUESTED' | 'DELETION_CANCELLED'.
  final String? deletionState;

  factory DeletionIntakeResponse.fromJson(Map<String, dynamic> json) =>
      DeletionIntakeResponse(
        graceUntil: DateTime.parse(json['grace_until'] as String).toUtc(),
        deletionState: json['deletion_state'] as String?,
      );
}

class DeletionCancelResponse {
  const DeletionCancelResponse({this.deletionState});

  final String? deletionState;

  factory DeletionCancelResponse.fromJson(Map<String, dynamic> json) =>
      DeletionCancelResponse(deletionState: json['deletion_state'] as String?);
}
```

`packages/balsm_api/lib/src/deletion/deletion_api.dart`:

```dart
import 'responses.dart';

/// Account-deletion endpoints (.NET module: Deletion).
/// All methods throw [ApiException] on transport or envelope errors.
abstract class DeletionApi {
  /// POST /deletion/intake
  Future<DeletionIntakeResponse> requestIntake();

  /// POST /deletion/cancel
  Future<DeletionCancelResponse> cancel();
}
```

`packages/balsm_api/lib/src/deletion/dio_deletion_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'deletion_api.dart';
import 'responses.dart';

class DioDeletionApi implements DeletionApi {
  const DioDeletionApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<DeletionIntakeResponse> requestIntake() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/deletion/intake');
      return DeletionIntakeResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<DeletionCancelResponse> cancel() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/deletion/cancel');
      return DeletionCancelResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
```

Exports:

```dart
export 'src/deletion/deletion_api.dart';
export 'src/deletion/dio_deletion_api.dart';
export 'src/deletion/responses.dart';
```

- [ ] **Step 4: Run — verify pass** — `cd packages/balsm_api && dart test` → ALL PASS.

- [ ] **Step 5: Core provider**

```dart
final deletionApiProvider = Provider<DeletionApi>((ref) {
  return DioDeletionApi(dio: ref.watch(balsmApiClientProvider).dio);
});
```

- [ ] **Step 6: Migrate the deletion module**

`packages/deletion/pubspec.yaml`: remove `dio`, add `balsm_api` path dep.

**request_deletion_use_case.dart** — dio import → balsm_api; `final Dio _dio` → `final DeletionApi _api`; ctor `RequestDeletionUseCase(this._api, this._bus)`. Body:

```dart
try {
  final res = await _api.requestIntake();
  final state = _parseState(res.deletionState);
  _bus.publish(DeletionRequested(res.graceUntil));
  return AppResult.success(
      DeletionIntakeResult(graceUntil: res.graceUntil, state: state));
} on ApiException catch (e) {
  return AppResult.failure(_failureFor(e));
}
```

```dart
Failure _failureFor(ApiException e) {
  if (e.fromEnvelope) {
    return ValidationFailure(
        e.serverMessage ?? 'Unable to request account deletion.');
  }
  if (e.isUnauthorized) return UnauthorizedFailure();
  if (e.statusCode == 409) return ConflictFailure();
  return NetworkFailure();
}
```

Keep `_parseState` and `DeletionIntakeResult` exactly as they are (adjust `DeletionIntakeResult` construction to its actual constructor — it's a two-field class defined at the top of this same file). Match `DeletionRequested`'s existing constructor call shape. Provider: `RequestDeletionUseCase(ref.watch(deletionApiProvider), ref.watch(eventBusProvider))`.

**cancel_deletion_use_case.dart** — same swaps. Body:

```dart
try {
  final res = await _api.cancel();
  final state = _parseState(res.deletionState);
  _bus.publish(DeletionCancelled());
  return AppResult.success(state);
} on ApiException catch (e) {
  if (e.fromEnvelope) {
    return AppResult.failure(ValidationFailure(
        e.serverMessage ?? 'Unable to cancel account deletion.'));
  }
  if (e.isUnauthorized) return AppResult.failure(UnauthorizedFailure());
  if (e.statusCode == 409) {
    return AppResult.failure(
        ConflictFailure('Deletion can no longer be cancelled.'));
  }
  return AppResult.failure(NetworkFailure());
}
```

Provider: `CancelDeletionUseCase(ref.watch(deletionApiProvider), ref.watch(eventBusProvider))`.

- [ ] **Step 7: Verify**

```bash
dart run melos bootstrap
melos exec --scope=balsm_api --scope=core --scope=deletion -- "flutter analyze --no-fatal-infos"
grep -rn "package:dio" packages/deletion/lib && echo "DIO STILL PRESENT — FIX" || echo "clean"
```

- [ ] **Step 8: Commit**

```bash
git add packages/balsm_api packages/core packages/deletion
git commit -m "[Refactor] deletion: consume DeletionApi from balsm_api"
```

---

### Task 8: account area + migration (camelCase wire keys)

**Files:**
- Create: `packages/balsm_api/lib/src/account/account_api.dart`
- Create: `packages/balsm_api/lib/src/account/requests.dart`
- Create: `packages/balsm_api/lib/src/account/responses.dart`
- Create: `packages/balsm_api/lib/src/account/dio_account_api.dart`
- Create: `packages/balsm_api/test/account/dio_account_api_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`, `packages/core/lib/src/network/api_providers.dart`
- Modify: `packages/account/pubspec.yaml` (remove `dio`, add `balsm_api`)
- Modify: `packages/account/lib/src/infrastructure/api/balsm_account_adapter.dart`
- Modify: `packages/account/lib/src/application/use_cases/claim_handle_use_case.dart`
- Modify: `packages/account/lib/src/application/use_cases/change_language_use_case.dart`
- Modify: `packages/account/lib/src/application/use_cases/change_country_use_case.dart`
- Modify: `packages/account/lib/src/presentation/screens/handle_claim_screen.dart`

**Interfaces:**
- Consumes: envelope helpers, `ApiException`, test helpers.
- Produces:
  - `abstract class AccountApi { Future<AccountSelfResponse?> getSelf(); Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request); Future<void> changeLanguage(ChangeLanguageRequest request); Future<void> changeCountry(ChangeCountryRequest request); Future<HandleAvailabilityResponse> checkHandleAvailability(String handle); }`
  - `getSelf()` returns **null on HTTP 404** (documented contract; impl catches it).
  - `class AccountSelfResponse { final String id; final String? handle; final String? displayName; final String countryCode; final String preferredLanguage; final String deletionState /*default 'ACTIVE'*/; }` ← camelCase keys `id, handle, displayName, countryCode, preferredLanguage, deletionState`.
  - `class ClaimHandleRequest { final String handle; }` → `{'handle'}`; `class ClaimHandleResponse { final String? handle; }` ← `{'handle'}`.
  - `class ChangeLanguageRequest { final String preferredLanguage; }` → `{'preferredLanguage'}` (camelCase!).
  - `class ChangeCountryRequest { final String countryCode; }` → `{'countryCode'}` (camelCase!).
  - `class HandleAvailabilityResponse { final bool available /*default false*/; }` ← `{'available'}`.
  - `class DioAccountApi implements AccountApi` — `DioAccountApi({required Dio dio})`
  - Core: `final accountApiProvider = Provider<AccountApi>`

- [ ] **Step 1: Write the failing tests**

`packages/balsm_api/test/account/dio_account_api_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('getSelf parses camelCase payload', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"id": "u1", "handle": "hoss", "displayName": "Hossam", "countryCode": "EG", "preferredLanguage": "ar", "deletionState": "ACTIVE"}}'));
    final res = await DioAccountApi(dio: fakeDio(adapter)).getSelf();
    expect(adapter.requests.single.path, '/account/self');
    expect(res!.id, 'u1');
    expect(res.displayName, 'Hossam');
    expect(res.deletionState, 'ACTIVE');
  });

  test('getSelf returns null on 404', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 404));
    final res = await DioAccountApi(dio: fakeDio(adapter)).getSelf();
    expect(res, isNull);
  });

  test('getSelf deletionState defaults to ACTIVE', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"id": "u1", "countryCode": "EG", "preferredLanguage": "en"}}'));
    final res = await DioAccountApi(dio: fakeDio(adapter)).getSelf();
    expect(res!.deletionState, 'ACTIVE');
  });

  test('claimHandle posts handle and echoes claimed handle', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"handle": "hoss"}}'));
    final res = await DioAccountApi(dio: fakeDio(adapter))
        .claimHandle(const ClaimHandleRequest(handle: 'hoss'));
    expect(adapter.requests.single.path, '/account/handle/claim');
    expect(adapter.requests.single.data, {'handle': 'hoss'});
    expect(res.handle, 'hoss');
  });

  test('changeLanguage/changeCountry send camelCase keys', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    final api = DioAccountApi(dio: fakeDio(adapter));
    await api.changeLanguage(const ChangeLanguageRequest(preferredLanguage: 'ar'));
    await api.changeCountry(const ChangeCountryRequest(countryCode: 'EG'));
    expect(adapter.requests[0].data, {'preferredLanguage': 'ar'});
    expect(adapter.requests[1].data, {'countryCode': 'EG'});
  });

  test('checkHandleAvailability sends query param, default false', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"available": true}}'));
    final api = DioAccountApi(dio: fakeDio(adapter));
    final res = await api.checkHandleAvailability('hoss');
    expect(adapter.requests.single.queryParameters, {'handle': 'hoss'});
    expect(res.available, isTrue);

    final adapter2 = FakeHttpAdapter((_) => jsonResponse('{"data": {}}'));
    final res2 = await DioAccountApi(dio: fakeDio(adapter2))
        .checkHandleAvailability('x');
    expect(res2.available, isFalse);
  });
}
```

- [ ] **Step 2: Run — verify fail** — `cd packages/balsm_api && dart test test/account` → FAIL.

- [ ] **Step 3: Implement**

`packages/balsm_api/lib/src/account/requests.dart`:

```dart
class ClaimHandleRequest {
  const ClaimHandleRequest({required this.handle});
  final String handle;
  Map<String, dynamic> toJson() => {'handle': handle};
}

/// NOTE: the account area uses camelCase wire keys (unlike other areas).
class ChangeLanguageRequest {
  const ChangeLanguageRequest({required this.preferredLanguage});
  final String preferredLanguage;
  Map<String, dynamic> toJson() => {'preferredLanguage': preferredLanguage};
}

class ChangeCountryRequest {
  const ChangeCountryRequest({required this.countryCode});
  final String countryCode;
  Map<String, dynamic> toJson() => {'countryCode': countryCode};
}
```

`packages/balsm_api/lib/src/account/responses.dart`:

```dart
/// PHI rule: this payload carries no PHI — do not add fields like
/// date_of_birth here.
class AccountSelfResponse {
  const AccountSelfResponse({
    required this.id,
    this.handle,
    this.displayName,
    required this.countryCode,
    required this.preferredLanguage,
    this.deletionState = 'ACTIVE',
  });

  final String id;
  final String? handle;
  final String? displayName;
  final String countryCode;
  final String preferredLanguage;

  /// 'ACTIVE' | 'DELETION_REQUESTED' | 'DELETION_CANCELLED'.
  final String deletionState;

  factory AccountSelfResponse.fromJson(Map<String, dynamic> json) =>
      AccountSelfResponse(
        id: json['id'] as String,
        handle: json['handle'] as String?,
        displayName: json['displayName'] as String?,
        countryCode: json['countryCode'] as String,
        preferredLanguage: json['preferredLanguage'] as String,
        deletionState: (json['deletionState'] as String?) ?? 'ACTIVE',
      );
}

class ClaimHandleResponse {
  const ClaimHandleResponse({this.handle});
  final String? handle;
  factory ClaimHandleResponse.fromJson(Map<String, dynamic> json) =>
      ClaimHandleResponse(handle: json['handle'] as String?);
}

class HandleAvailabilityResponse {
  const HandleAvailabilityResponse({this.available = false});
  final bool available;
  factory HandleAvailabilityResponse.fromJson(Map<String, dynamic> json) =>
      HandleAvailabilityResponse(available: json['available'] as bool? ?? false);
}
```

`packages/balsm_api/lib/src/account/account_api.dart`:

```dart
import 'requests.dart';
import 'responses.dart';

/// Account endpoints (.NET module: Account).
/// All methods throw [ApiException] on transport or envelope errors,
/// except [getSelf], which returns null on HTTP 404.
abstract class AccountApi {
  /// GET /account/self — null when the account does not exist (404).
  Future<AccountSelfResponse?> getSelf();

  /// POST /account/handle/claim
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request);

  /// POST /account/language
  Future<void> changeLanguage(ChangeLanguageRequest request);

  /// POST /account/country
  Future<void> changeCountry(ChangeCountryRequest request);

  /// GET /account/handle/available?handle=
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle);
}
```

`packages/balsm_api/lib/src/account/dio_account_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'account_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAccountApi implements AccountApi {
  const DioAccountApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<AccountSelfResponse?> getSelf() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/account/self');
      final data = unwrapEnvelope(res);
      if (data.isEmpty) return null;
      return AccountSelfResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/handle/claim',
        data: request.toJson(),
      );
      return ClaimHandleResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> changeLanguage(ChangeLanguageRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/language',
        data: request.toJson(),
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> changeCountry(ChangeCountryRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/account/country',
        data: request.toJson(),
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/account/handle/available',
        queryParameters: {'handle': handle},
      );
      return HandleAvailabilityResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
```

Exports:

```dart
export 'src/account/account_api.dart';
export 'src/account/dio_account_api.dart';
export 'src/account/requests.dart';
export 'src/account/responses.dart';
```

- [ ] **Step 4: Run — verify pass** — `cd packages/balsm_api && dart test` → ALL PASS. Note: `getSelf` returning null when `data` is empty also covers the legacy "body/data null → null" behavior.

- [ ] **Step 5: Core provider**

```dart
final accountApiProvider = Provider<AccountApi>((ref) {
  return DioAccountApi(dio: ref.watch(balsmApiClientProvider).dio);
});
```

- [ ] **Step 6: Migrate the account module**

`packages/account/pubspec.yaml`: remove `dio`, add `balsm_api` path dep.

**balsm_account_adapter.dart** — swap dio import → balsm_api; ctor takes `AccountApi`:

```dart
class BalsmAccountAdapter implements ReadAccountRepository {
  BalsmAccountAdapter(this._api);

  final AccountApi _api;

  @override
  Future<AccountSummary?> getAccount(String userId) async {
    final res = await _api.getSelf();
    if (res == null) return null;
    return AccountSummary(
      id: res.id,
      handle: res.handle,
      displayName: res.displayName,
      countryCode: res.countryCode,
      preferredLanguage: res.preferredLanguage,
      deletionState: res.deletionState,
    );
  }
}
```

(The old 404→null branch is now inside `DioAccountApi.getSelf`; other errors now arrive as `ApiException` instead of `DioException` — the old code rethrew those, and `ApiException` propagating keeps that contract.) Provider in the same file: `BalsmAccountAdapter(ref.watch(accountApiProvider))`.

**claim_handle_use_case.dart** — ctor takes `AccountApi _api`. Post block:

```dart
try {
  final res = await _api.claimHandle(ClaimHandleRequest(handle: value));
  return AppResult.success(res.handle ?? value);
} on ApiException catch (e) {
  return AppResult.failure(switch (e.statusCode) {
    409 => ConflictFailure('Handle taken'),
    401 || 403 => UnauthorizedFailure(),
    400 || 422 => ValidationFailure('Invalid handle'),
    _ => NetworkFailure(),
  });
}
```

Keep the `kHandleFormat` pre-check untouched. Provider: `ClaimHandleUseCase(ref.watch(accountApiProvider))`.

**change_language_use_case.dart** — ctor `{required AccountApi api, required EventBus bus}`. HTTP block:

```dart
try {
  await _api.changeLanguage(ChangeLanguageRequest(preferredLanguage: tag.value));
} on ApiException catch (e) {
  return AppResult.failure(switch (e.statusCode) {
    401 || 403 => UnauthorizedFailure(),
    400 || 422 => ValidationFailure('Invalid language'),
    _ => NetworkFailure(),
  });
}
```

Keep the `Bcp47Tag` pre-check and `LanguageChanged` event publish untouched. Provider: `api: ref.watch(accountApiProvider), bus: ref.watch(eventBusProvider)`.

**change_country_use_case.dart** — same pattern (`ChangeCountryRequest(countryCode: target)`, failures `Invalid country`). Keep denied-countries pre-check and `CountryChanged` publish. Provider: `api: ref.watch(accountApiProvider), ...`.

**handle_claim_screen.dart** `_check(...)`:

```dart
// BEFORE:
final dio = ref.read(dioClientProvider);
final res = await dio.get<Map<String, dynamic>>('/account/handle/available', queryParameters: {'handle': handle});
// ...reads data.available, DioException 409 → taken...

// AFTER:
final api = ref.read(accountApiProvider);
try {
  final res = await api.checkHandleAvailability(handle);
  // use res.available exactly where the old `available` bool was used
} on ApiException catch (e) {
  if (e.statusCode == 409) {
    // old 409 branch: status taken
  } else {
    // old fallback branch: idle + "Could not check availability"
  }
}
```

(Adapt to the exact local variable/state names in the method — logic mapping is 1:1.)

- [ ] **Step 7: Verify**

```bash
dart run melos bootstrap
melos exec --scope=balsm_api --scope=core --scope=account -- "flutter analyze --no-fatal-infos"
grep -rn "package:dio" packages/account/lib && echo "DIO STILL PRESENT — FIX" || echo "clean"
```

- [ ] **Step 8: Commit**

```bash
git add packages/balsm_api packages/core packages/account
git commit -m "[Refactor] account: consume AccountApi from balsm_api"
```

---

### Task 9: auth area + adapter rewrite (flat bodies, lockout mapping)

**Files:**
- Create: `packages/balsm_api/lib/src/auth/auth_api.dart`
- Create: `packages/balsm_api/lib/src/auth/requests.dart`
- Create: `packages/balsm_api/lib/src/auth/responses.dart`
- Create: `packages/balsm_api/lib/src/auth/dio_auth_api.dart`
- Create: `packages/balsm_api/test/auth/dio_auth_api_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`, `packages/core/lib/src/network/api_providers.dart`
- Rewrite: `packages/auth/lib/src/infrastructure/api/balsm_auth_adapter.dart` (public surface preserved)
- Modify: `packages/auth/pubspec.yaml` (add `balsm_api`; remove `dio` only if no other file imports it — check)

**Interfaces:**
- Consumes: `ApiException` (NOT envelope helpers — auth bodies are FLAT).
- Produces:
  - `abstract class AuthApi { Future<void> requestOtp(RequestOtpRequest request); Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request); Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request); Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request); Future<void> signOut(); Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request); Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request); }`
  - Requests (all snake_case): `RequestOtpRequest{email, countryCode}`→`{'email','country_code'}`; `VerifyOtpRequest{email, code, deviceId, deviceLabel}`; `GoogleSignInRequest{idToken, deviceId, deviceLabel}`→`{'id_token',…}`; `AppleSignInRequest{idToken, authorizationCode, deviceId, deviceLabel}`→`{'id_token','authorization_code',…}`; `RefreshTokenRequest{refreshToken, deviceId}`→`{'refresh_token','device_id'}`; `RecoveryClaimRequest{recoveryToken, newEmail, deviceId, deviceLabel}`→`{'recovery_token','new_email',…}`.
  - `class AuthTokensResponse { final String accessToken; final String refreshToken; final String userId; final bool isNewUser /*default false*/; }` ← FLAT keys `access_token, refresh_token, user_id, is_new_user`.
  - `class RefreshedTokensResponse { final String accessToken; final String refreshToken; }` ← FLAT keys.
  - `class DioAuthApi implements AuthApi` — `DioAuthApi({required Dio dio})`.
  - Core: `final authApiProvider = Provider<AuthApi>`.
  - Auth module: `BalsmAuthAdapter` PUBLIC SURFACE UNCHANGED — same 7 method signatures, same `AuthTokens`/`RefreshedTokens` records, same `AuthException`, same `balsmAuthAdapterProvider` name. Use cases and repositories are NOT touched.

- [ ] **Step 1: Write the failing tests**

`packages/balsm_api/test/auth/dio_auth_api_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('verifyOtp posts snake_case body and parses FLAT token response', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"access_token": "at", "refresh_token": "rt", "user_id": "u1", "is_new_user": true}'));
    final api = DioAuthApi(dio: fakeDio(adapter));

    final res = await api.verifyOtp(const VerifyOtpRequest(
        email: 'a@b.c', code: '123456', deviceId: 'd1', deviceLabel: 'iPhone'));

    expect(adapter.requests.single.path, '/auth/otp/verify');
    expect(adapter.requests.single.data, {
      'email': 'a@b.c',
      'code': '123456',
      'device_id': 'd1',
      'device_label': 'iPhone',
    });
    expect(res.accessToken, 'at');
    expect(res.userId, 'u1');
    expect(res.isNewUser, isTrue);
  });

  test('is_new_user defaults to false', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"access_token": "at", "refresh_token": "rt", "user_id": "u1"}'));
    final res = await DioAuthApi(dio: fakeDio(adapter)).signInWithGoogle(
        const GoogleSignInRequest(idToken: 't', deviceId: 'd', deviceLabel: 'l'));
    expect(res.isNewUser, isFalse);
  });

  test('423 lockout carries account_locked code and Retry-After', () {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"code": "account_locked"}',
        status: 423,
        headers: {'Retry-After': ['120']}));
    final api = DioAuthApi(dio: fakeDio(adapter));
    expect(
      api.verifyOtp(const VerifyOtpRequest(
          email: 'a@b.c', code: '1', deviceId: 'd', deviceLabel: 'l')),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'account_locked')
          .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 120)),
    );
  });

  test('server error code from flat body wins over status mapping', () {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"code": "otp_expired"}', status: 400));
    final api = DioAuthApi(dio: fakeDio(adapter));
    expect(
      api.requestOtp(const RequestOtpRequest(email: 'a@b.c', countryCode: 'EG')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'otp_expired')),
    );
  });

  test('refresh and recoveryClaim parse flat refreshed tokens', () async {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"access_token": "at2", "refresh_token": "rt2"}'));
    final api = DioAuthApi(dio: fakeDio(adapter));

    final r1 = await api.refresh(
        const RefreshTokenRequest(refreshToken: 'rt', deviceId: 'd'));
    expect(r1.accessToken, 'at2');

    final r2 = await api.recoveryClaim(const RecoveryClaimRequest(
        recoveryToken: 'rec', newEmail: 'n@b.c', deviceId: 'd', deviceLabel: 'l'));
    expect(adapter.requests[1].data, {
      'recovery_token': 'rec',
      'new_email': 'n@b.c',
      'device_id': 'd',
      'device_label': 'l',
    });
    expect(r2.refreshToken, 'rt2');
  });

  test('signOut posts empty body', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}'));
    await DioAuthApi(dio: fakeDio(adapter)).signOut();
    expect(adapter.requests.single.path, '/auth/sign-out');
    expect(adapter.requests.single.data, isEmpty);
  });
}
```

- [ ] **Step 2: Run — verify fail** — `cd packages/balsm_api && dart test test/auth` → FAIL.

- [ ] **Step 3: Implement**

`packages/balsm_api/lib/src/auth/requests.dart`:

```dart
/// PHI constraint (all auth DTOs): never log or stringify these — they
/// carry emails, device identifiers, and tokens.
class RequestOtpRequest {
  const RequestOtpRequest({required this.email, required this.countryCode});
  final String email;
  final String countryCode;
  Map<String, dynamic> toJson() => {'email': email, 'country_code': countryCode};
}

class VerifyOtpRequest {
  const VerifyOtpRequest({
    required this.email,
    required this.code,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String email;
  final String code;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'email': email,
        'code': code,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class GoogleSignInRequest {
  const GoogleSignInRequest({
    required this.idToken,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String idToken;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'id_token': idToken,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class AppleSignInRequest {
  const AppleSignInRequest({
    required this.idToken,
    required this.authorizationCode,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String idToken;
  final String authorizationCode;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'id_token': idToken,
        'authorization_code': authorizationCode,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class RefreshTokenRequest {
  const RefreshTokenRequest({required this.refreshToken, required this.deviceId});
  final String refreshToken;
  final String deviceId;
  Map<String, dynamic> toJson() =>
      {'refresh_token': refreshToken, 'device_id': deviceId};
}

class RecoveryClaimRequest {
  const RecoveryClaimRequest({
    required this.recoveryToken,
    required this.newEmail,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String recoveryToken;
  final String newEmail;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'recovery_token': recoveryToken,
        'new_email': newEmail,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}
```

`packages/balsm_api/lib/src/auth/responses.dart`:

```dart
/// Auth endpoints return FLAT bodies — token fields at the top level,
/// no {data, error} envelope.
class AuthTokensResponse {
  const AuthTokensResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.isNewUser = false,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final bool isNewUser;

  factory AuthTokensResponse.fromJson(Map<String, dynamic> json) =>
      AuthTokensResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        userId: json['user_id'] as String,
        isNewUser: (json['is_new_user'] as bool?) ?? false,
      );
}

class RefreshedTokensResponse {
  const RefreshedTokensResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory RefreshedTokensResponse.fromJson(Map<String, dynamic> json) =>
      RefreshedTokensResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );
}
```

`packages/balsm_api/lib/src/auth/auth_api.dart`:

```dart
import 'requests.dart';
import 'responses.dart';

/// Auth endpoints (.NET module: Auth). Flat response bodies.
/// All methods throw [ApiException] on transport errors.
/// PHI constraint: implementations must never log emails, ids, or tokens.
abstract class AuthApi {
  /// POST /auth/otp/request
  Future<void> requestOtp(RequestOtpRequest request);

  /// POST /auth/otp/verify — 423 lockout surfaces code 'account_locked'
  /// with [ApiException.retryAfterSeconds] from the Retry-After header.
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request);

  /// POST /auth/google
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request);

  /// POST /auth/apple
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request);

  /// POST /auth/sign-out
  Future<void> signOut();

  /// POST /auth/refresh
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request);

  /// POST /auth/recovery/claim
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request);
}
```

`packages/balsm_api/lib/src/auth/dio_auth_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import 'auth_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAuthApi implements AuthApi {
  const DioAuthApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> requestOtp(RequestOtpRequest request) =>
      _post('/auth/otp/request', request.toJson());

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request) async =>
      AuthTokensResponse.fromJson(await _post('/auth/otp/verify', request.toJson()));

  @override
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request) async =>
      AuthTokensResponse.fromJson(await _post('/auth/google', request.toJson()));

  @override
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request) async =>
      AuthTokensResponse.fromJson(await _post('/auth/apple', request.toJson()));

  @override
  Future<void> signOut() => _post('/auth/sign-out', {});

  @override
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request) async =>
      RefreshedTokensResponse.fromJson(await _post('/auth/refresh', request.toJson()));

  @override
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request) async =>
      RefreshedTokensResponse.fromJson(
          await _post('/auth/recovery/claim', request.toJson()));
}
```

Exports:

```dart
export 'src/auth/auth_api.dart';
export 'src/auth/dio_auth_api.dart';
export 'src/auth/requests.dart';
export 'src/auth/responses.dart';
```

- [ ] **Step 4: Run — verify pass** — `cd packages/balsm_api && dart test` → ALL PASS.

- [ ] **Step 5: Core provider**

```dart
final authApiProvider = Provider<AuthApi>((ref) {
  return DioAuthApi(dio: ref.watch(balsmApiClientProvider).dio);
});
```

- [ ] **Step 6: Rewrite the auth adapter internals (surface preserved)**

`packages/auth/pubspec.yaml`: add `balsm_api: {path: ../balsm_api}`. Then check `grep -rn "package:dio" packages/auth/lib` — if the adapter was the only importer, remove `dio` from the pubspec too (auth's pubspec may not even list it — it wasn't in the direct-dep list; skip removal if absent).

Replace the whole body of `packages/auth/lib/src/infrastructure/api/balsm_auth_adapter.dart` with:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart' hide AuthApi; // keep provider imports working; hide avoids re-export clash
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_exception.dart';

/// ({String accessToken, String refreshToken, String userId, bool isNewUser})
typedef AuthTokens = ({
  String accessToken,
  String refreshToken,
  String userId,
  bool isNewUser,
});

/// ({String accessToken, String refreshToken})
typedef RefreshedTokens = ({
  String accessToken,
  String refreshToken,
});

/// Anti-corruption adapter — maps balsm_api DTOs/ApiException into the auth
/// module's records and AuthException.
/// PHI constraint: do not log email, userId, or tokens at any level.
class BalsmAuthAdapter {
  const BalsmAuthAdapter({required AuthApi api}) : _api = api;

  final AuthApi _api;

  /// POST /auth/otp/request
  Future<void> requestOtp(String email, String countryCode) =>
      _guard(() => _api.requestOtp(
          RequestOtpRequest(email: email, countryCode: countryCode)));

  /// POST /auth/otp/verify
  Future<AuthTokens> verifyOtp(
    String email,
    String code,
    String deviceId,
    String deviceLabel,
  ) =>
      _guard(() async => _toAuthTokens(await _api.verifyOtp(VerifyOtpRequest(
            email: email,
            code: code,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
          ))));

  /// POST /auth/google
  Future<AuthTokens> signInWithGoogle(
    String idToken,
    String deviceId,
    String deviceLabel,
  ) =>
      _guard(() async =>
          _toAuthTokens(await _api.signInWithGoogle(GoogleSignInRequest(
            idToken: idToken,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
          ))));

  /// POST /auth/apple
  Future<AuthTokens> signInWithApple(
    String idToken,
    String authCode,
    String deviceId,
    String deviceLabel,
  ) =>
      _guard(() async =>
          _toAuthTokens(await _api.signInWithApple(AppleSignInRequest(
            idToken: idToken,
            authorizationCode: authCode,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
          ))));

  /// POST /auth/sign-out
  Future<void> signOut() => _guard(() => _api.signOut());

  /// POST /auth/refresh
  Future<RefreshedTokens> refresh(String refreshToken, String deviceId) =>
      _guard(() async {
        final r = await _api.refresh(RefreshTokenRequest(
          refreshToken: refreshToken,
          deviceId: deviceId,
        ));
        return (accessToken: r.accessToken, refreshToken: r.refreshToken);
      });

  /// POST /auth/recovery/claim
  Future<RefreshedTokens> recoveryClaim(
    String recoveryToken,
    String newEmail,
    String deviceId,
    String deviceLabel,
  ) =>
      _guard(() async {
        final r = await _api.recoveryClaim(RecoveryClaimRequest(
          recoveryToken: recoveryToken,
          newEmail: newEmail,
          deviceId: deviceId,
          deviceLabel: deviceLabel,
        ));
        return (accessToken: r.accessToken, refreshToken: r.refreshToken);
      });

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (e) {
      throw _toAuthException(e);
    }
  }

  AuthTokens _toAuthTokens(AuthTokensResponse r) => (
        accessToken: r.accessToken,
        refreshToken: r.refreshToken,
        userId: r.userId,
        isNewUser: r.isNewUser,
      );

  AuthException _toAuthException(ApiException e) {
    if (e.statusCode == 423) {
      final retryAfter = e.retryAfterSeconds ?? 60;
      return AuthException(
        code: 'account_locked',
        message: 'Account temporarily locked. Try again in $retryAfter seconds.',
      );
    }
    // Use generic message; never echo server text (may contain PII).
    return AuthException(code: e.code, message: _messageFromCode(e.code));
  }

  String _messageFromCode(String code) => switch (code) {
        'invalid_request' => 'The request was invalid. Please check your input.',
        'unauthorized' => 'Authentication required. Please sign in again.',
        'forbidden' => 'Access denied.',
        'not_found' => 'The requested resource was not found.',
        'conflict' => 'A conflict occurred. This account may already exist.',
        'validation_error' => 'Validation failed. Please check your input.',
        'account_locked' => 'Account temporarily locked. Please try again later.',
        'rate_limited' => 'Too many requests. Please wait before trying again.',
        'server_error' => 'A server error occurred. Please try again later.',
        'otp_expired' => 'The verification code has expired. Please request a new one.',
        'otp_invalid' => 'Incorrect verification code.',
        _ => 'An unexpected error occurred. Please try again.',
      };
}

// ── Riverpod provider ────────────────────────────────────────────────────────

final balsmAuthAdapterProvider = Provider<BalsmAuthAdapter>((ref) {
  return BalsmAuthAdapter(api: ref.watch(authApiProvider));
});
```

(If `package:core/core.dart` produces no name clash for `AuthApi`, drop the `hide`. `authApiProvider` comes from core's `api_providers.dart`.)

- [ ] **Step 7: Verify**

```bash
dart run melos bootstrap
melos exec --scope=balsm_api --scope=core --scope=auth -- "flutter analyze --no-fatal-infos"
grep -rn "package:dio" packages/auth/lib && echo "DIO STILL PRESENT — FIX" || echo "clean"
```
Expected: clean — auth use cases/repos compile UNCHANGED (adapter surface preserved).

- [ ] **Step 8: Commit**

```bash
git add packages/balsm_api packages/core packages/auth
git commit -m "[Refactor] auth: BalsmAuthAdapter maps balsm_api AuthApi to domain records"
```

---

### Task 10: disclosure + geofence areas + migrations

**Files:**
- Create: `packages/balsm_api/lib/src/disclosure/disclosure_api.dart`
- Create: `packages/balsm_api/lib/src/disclosure/requests.dart`
- Create: `packages/balsm_api/lib/src/disclosure/dio_disclosure_api.dart`
- Create: `packages/balsm_api/lib/src/geofence/geofence_api.dart`
- Create: `packages/balsm_api/lib/src/geofence/responses.dart`
- Create: `packages/balsm_api/lib/src/geofence/dio_geofence_api.dart`
- Create: `packages/balsm_api/test/disclosure/dio_disclosure_api_test.dart`
- Create: `packages/balsm_api/test/geofence/dio_geofence_api_test.dart`
- Modify: `packages/balsm_api/lib/balsm_api.dart`, `packages/core/lib/src/network/api_providers.dart`
- Modify: `packages/disclosure/pubspec.yaml`, `packages/geofence_block/pubspec.yaml` (add `balsm_api`)
- Modify: `packages/disclosure/lib/src/application/use_cases/accept_disclosure_use_case.dart`
- Modify: `packages/disclosure/lib/src/presentation/screens/consolidated_disclosure_screen.dart` (provider wiring)
- Modify: `packages/geofence_block/lib/src/infrastructure/api/balsm_geofence_adapter.dart`

**Interfaces:**
- Consumes: envelope helpers, `ApiException`, test helpers.
- Produces:
  - `abstract class DisclosureApi { Future<void> accept(AcceptDisclosureRequest request); }`
  - `class AcceptDisclosureRequest { final String disclosureId; final String version; final String countryCode; final String supervisoryAuthority; final String preferredLanguage; }` → `{'disclosure_id','version','country_code','supervisory_authority','preferred_language'}`
  - `abstract class GeofenceApi { Future<DeniedCountriesResponse> getDeniedCountries(); }`
  - `class DeniedCountriesResponse { final List<String> deniedCodes /*default const []*/; }` — tolerant parse: non-list `denied_codes` → `[]`; raw `.toString()` values, no normalization (module keeps trim/uppercase).
  - `class DioDisclosureApi implements DisclosureApi`, `class DioGeofenceApi implements GeofenceApi` — both `({required Dio dio})`.
  - `DioGeofenceApi` preserves the legacy fallback: if the body has no map `data`, parse `denied_codes` from the body itself.
  - Core: `final disclosureApiProvider = Provider<DisclosureApi>`, `final geofenceApiProvider = Provider<GeofenceApi>`.

- [ ] **Step 1: Write the failing tests**

`packages/balsm_api/test/disclosure/dio_disclosure_api_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('accept posts snake_case disclosure payload', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    await DioDisclosureApi(dio: fakeDio(adapter)).accept(
      const AcceptDisclosureRequest(
        disclosureId: 'disc-1',
        version: '2',
        countryCode: 'EG',
        supervisoryAuthority: 'PDPC',
        preferredLanguage: 'ar',
      ),
    );
    expect(adapter.requests.single.path, '/disclosure/accept');
    expect(adapter.requests.single.data, {
      'disclosure_id': 'disc-1',
      'version': '2',
      'country_code': 'EG',
      'supervisory_authority': 'PDPC',
      'preferred_language': 'ar',
    });
  });
}
```

`packages/balsm_api/test/geofence/dio_geofence_api_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('parses enveloped denied_codes', () async {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"data": {"denied_codes": ["kp", " ir "]}}'));
    final res = await DioGeofenceApi(dio: fakeDio(adapter)).getDeniedCountries();
    expect(adapter.requests.single.path, '/geofence/denied-countries');
    expect(res.deniedCodes, ['kp', ' ir ']); // raw — module normalizes
  });

  test('falls back to flat body when data missing (legacy tolerance)', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"denied_codes": ["kp"]}'));
    final res = await DioGeofenceApi(dio: fakeDio(adapter)).getDeniedCountries();
    expect(res.deniedCodes, ['kp']);
  });

  test('non-list denied_codes → empty', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"denied_codes": "oops"}}'));
    final res = await DioGeofenceApi(dio: fakeDio(adapter)).getDeniedCountries();
    expect(res.deniedCodes, isEmpty);
  });
}
```

- [ ] **Step 2: Run — verify fail** — `cd packages/balsm_api && dart test test/disclosure test/geofence` → FAIL.

- [ ] **Step 3: Implement**

`packages/balsm_api/lib/src/disclosure/requests.dart`:

```dart
class AcceptDisclosureRequest {
  const AcceptDisclosureRequest({
    required this.disclosureId,
    required this.version,
    required this.countryCode,
    required this.supervisoryAuthority,
    required this.preferredLanguage,
  });

  final String disclosureId;
  final String version;
  final String countryCode;
  final String supervisoryAuthority;
  final String preferredLanguage;

  Map<String, dynamic> toJson() => {
        'disclosure_id': disclosureId,
        'version': version,
        'country_code': countryCode,
        'supervisory_authority': supervisoryAuthority,
        'preferred_language': preferredLanguage,
      };
}
```

`packages/balsm_api/lib/src/disclosure/disclosure_api.dart`:

```dart
import 'requests.dart';

/// Disclosure endpoints (.NET module: Disclosure).
/// Throws [ApiException]; callers that treat acceptance sync as best-effort
/// (offline-tolerant) catch and swallow in their own layer.
abstract class DisclosureApi {
  /// POST /disclosure/accept
  Future<void> accept(AcceptDisclosureRequest request);
}
```

`packages/balsm_api/lib/src/disclosure/dio_disclosure_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'disclosure_api.dart';
import 'requests.dart';

class DioDisclosureApi implements DisclosureApi {
  const DioDisclosureApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<void> accept(AcceptDisclosureRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/disclosure/accept',
        data: request.toJson(),
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
```

`packages/balsm_api/lib/src/geofence/responses.dart`:

```dart
class DeniedCountriesResponse {
  const DeniedCountriesResponse({this.deniedCodes = const []});

  /// Raw wire values — callers normalize (trim/uppercase) themselves.
  final List<String> deniedCodes;

  factory DeniedCountriesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['denied_codes'];
    if (raw is! List) return const DeniedCountriesResponse();
    return DeniedCountriesResponse(
      deniedCodes: raw.map((e) => e.toString()).toList(growable: false),
    );
  }
}
```

`packages/balsm_api/lib/src/geofence/geofence_api.dart`:

```dart
import 'responses.dart';

/// Geofence endpoints (.NET shared/geofence).
/// Throws [ApiException] on transport errors.
abstract class GeofenceApi {
  /// GET /geofence/denied-countries
  Future<DeniedCountriesResponse> getDeniedCountries();
}
```

`packages/balsm_api/lib/src/geofence/dio_geofence_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import 'geofence_api.dart';
import 'responses.dart';

class DioGeofenceApi implements GeofenceApi {
  const DioGeofenceApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<DeniedCountriesResponse> getDeniedCountries() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/geofence/denied-countries');
      final body = res.data ?? const <String, dynamic>{};
      // Legacy tolerance: unwrap {data: {...}} but fall back to the flat body.
      final data = body['data'];
      final payload = data is Map<String, dynamic> ? data : body;
      return DeniedCountriesResponse.fromJson(payload);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
```

Exports:

```dart
export 'src/disclosure/disclosure_api.dart';
export 'src/disclosure/dio_disclosure_api.dart';
export 'src/disclosure/requests.dart';
export 'src/geofence/geofence_api.dart';
export 'src/geofence/dio_geofence_api.dart';
export 'src/geofence/responses.dart';
```

- [ ] **Step 4: Run — verify pass** — `cd packages/balsm_api && dart test` → ALL PASS.

- [ ] **Step 5: Core providers**

```dart
final disclosureApiProvider = Provider<DisclosureApi>((ref) {
  return DioDisclosureApi(dio: ref.watch(balsmApiClientProvider).dio);
});

final geofenceApiProvider = Provider<GeofenceApi>((ref) {
  return DioGeofenceApi(dio: ref.watch(balsmApiClientProvider).dio);
});
```

- [ ] **Step 6: Migrate disclosure**

`packages/disclosure/pubspec.yaml`: add `balsm_api: {path: ../balsm_api}` (keep `core`).

**accept_disclosure_use_case.dart** — constructor `required BalsmApiClient apiClient` → `required DisclosureApi api`; field swap. The HTTP step:

```dart
// BEFORE:
try {
  await _apiClient.dio.post<void>('/disclosure/accept', data: { ...5 keys... });
} catch (_) {}

// AFTER (still best-effort — swallow everything):
try {
  await _api.accept(AcceptDisclosureRequest(
    disclosureId: disclosureId,
    version: version,
    countryCode: countryCode,
    supervisoryAuthority: supervisoryAuthority,
    preferredLanguage: preferredLanguage,
  ));
} catch (_) {
  // Best-effort sync — local persistence is the source of truth (offline OK).
}
```

**consolidated_disclosure_screen.dart** provider wiring: `apiClient: ref.watch(balsmApiClientProvider)` → `api: ref.watch(disclosureApiProvider)`.

- [ ] **Step 7: Migrate geofence_block**

`packages/geofence_block/pubspec.yaml`: add `balsm_api` path dep.

**balsm_geofence_adapter.dart** — constructor `required BalsmApiClient apiClient` → `required GeofenceApi api`; `_fetch()` becomes:

```dart
Future<List<String>> _fetch() async {
  final res = await _api.getDeniedCountries();
  return res.deniedCodes
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
```

(Keep the surrounding 24h-cache + stale-fallback `try/catch` in `_deniedCountryCodes()` exactly as-is — `ApiException` is caught by its existing `catch (_)`.) Provider: `apiClient: ref.watch(balsmApiClientProvider)` → `api: ref.watch(geofenceApiProvider)`.

- [ ] **Step 8: Verify + commit**

```bash
dart run melos bootstrap
melos exec --scope=balsm_api --scope=core --scope=disclosure --scope=geofence_block -- "flutter analyze --no-fatal-infos"
git add packages/balsm_api packages/core packages/disclosure packages/geofence_block
git commit -m "[Refactor] disclosure+geofence: consume typed APIs from balsm_api"
```

---

### Task 11: Cleanup — kill `dioClientProvider`, final dio sweep

**Files:**
- Modify: `packages/core/lib/src/network/api_providers.dart` (delete `dioClientProvider`)
- Verify-only: all module pubspecs and libs

- [ ] **Step 1: Delete the temporary provider**

Remove from `api_providers.dart`:

```dart
/// TEMPORARY during the balsm_api migration — deleted once no module reads
/// raw Dio anymore.
final dioClientProvider = Provider<Dio>((ref) {
  return ref.watch(balsmApiClientProvider).dio;
});
```

Also remove the now-unused `import 'package:dio/dio.dart';` from that file if nothing else references `Dio`... it does — the `DioXxxApi(dio: ...)` constructions take `Dio`. Keep the import.

- [ ] **Step 2: Sweep**

```bash
grep -rn "dioClientProvider" packages app test && echo "REFERENCES REMAIN — FIX" || echo "clean"
grep -rn "package:dio" packages/*/lib --include="*.dart" | grep -v "packages/balsm_api\|packages/core" && echo "MODULE DIO IMPORT REMAINS — FIX" || echo "clean"
grep -n "dio" packages/auth/pubspec.yaml packages/emergency_card/pubspec.yaml packages/sessions/pubspec.yaml packages/deletion/pubspec.yaml packages/account/pubspec.yaml packages/disclosure/pubspec.yaml packages/geofence_block/pubspec.yaml || echo "pubspecs clean"
```
Expected: `clean` / `clean` / pubspecs show no direct `dio:` lines (path dep `balsm_api` is fine).

- [ ] **Step 3: Full workspace verification**

```bash
dart run melos bootstrap
melos run analyze
melos run test
(cd packages/balsm_api && dart test)
flutter test test/phi_leak_fuzz_test
```
Expected: all green (pre-existing failures unrelated to this refactor are acceptable — note them in the commit).

- [ ] **Step 4: Commit**

```bash
git add -A packages
git commit -m "[Refactor] drop dioClientProvider — Dio no longer visible outside balsm_api/core"
```

---

### Task 12: Cross-repo docs — AGENTS.md architecture note

**Files:**
- Modify: `/Volumes/Dev/Balsm/Balsm-Core/agents/rules/AGENTS.md` (line ~22, P001 architecture note) — **separate repo, separate commit**

- [ ] **Step 1: Update the Flutter architecture bullet**

Current line 22 says: `Modules depend only on core (boundary lint enforces this). Client talks to the .NET API via dio (BalsmApiClient), never Supabase.`

Replace that sentence pair with:

```
Modules depend only on `core` and `balsm_api` (boundary lint's module list stays module-only, so both are importable). The client talks to the .NET API exclusively through `packages/balsm_api` — abstract per-area interfaces (`AuthApi`, `SessionsApi`, …) + dio implementations + hand-written DTOs; raw `dio` never appears in feature modules. Never Supabase.
```

Also update the "12 packages" wording to "13 packages" and add `balsm_api` to the package enumeration in the same bullet.

- [ ] **Step 2: Commit (in Balsm-Core repo)**

```bash
cd /Volumes/Dev/Balsm/Balsm-Core
git add agents/rules/AGENTS.md
git commit -m "docs(agents): Flutter modules depend on core + balsm_api; API layer extracted"
```

---

### Task 13: Repo skill — `flutter-add-api-endpoint`

**Files:**
- Create: `/Volumes/Dev/Balsm/balsm_app_flutter/.claude/skills/flutter-add-api-endpoint/SKILL.md`

- [ ] **Step 1: Write the skill** (format mirrors `.claude/skills/flutter-use-asset-constants/SKILL.md`)

```markdown
---
name: flutter-add-api-endpoint
description: Route every backend HTTP call through packages/balsm_api — abstract per-area interfaces (AuthApi, SessionsApi, …), dio implementations, and hand-written DTOs. Use when adding, changing, or consuming any API endpoint, request/response model, or DTO — or on sight of `import 'package:dio/dio.dart'`, an inline `Map` payload, or a hardcoded '/path' HTTP call inside a feature module.
metadata:
  type: convention
---

# Add or Change a Balsm API Endpoint

All backend HTTP lives in **`packages/balsm_api`**. Feature modules never
import `dio`, never build inline `Map` payloads, and never parse raw JSON
envelopes. Modules bind to **abstract interfaces** via core DI providers.

## Package anatomy

```
packages/balsm_api/lib/src/
  transport/   BalsmApiClient, PhiLeakInterceptor, ApiException, envelope.dart
  <area>/      <area>_api.dart        ← abstract interface (pure signatures)
               dio_<area>_api.dart    ← DioXxxApi implements XxxApi
               requests.dart          ← request DTOs (toJson)
               responses.dart         ← response DTOs (fromJson)
```

Areas mirror the .NET backend modules: auth, account, emergency_qr,
sessions, deletion, disclosure, geofence. New backend module ⇒ new area
folder, same four-file shape.

## Wire-format rules (violating these breaks the backend contract)

- **Casing is per-area:** account = camelCase (`preferredLanguage`);
  everything else = snake_case (`device_id`). Match the .NET controller.
- **Envelope is per-area:** auth returns FLAT bodies; all other areas wrap
  in `{data, error}` — use `unwrapEnvelope` / `unwrapEnvelopeList` from
  `transport/envelope.dart`. Never hand-parse `body['data']`.
- DTOs are plain immutable classes with hand-written `fromJson`/`toJson`.
  **No freezed / json_serializable / build_runner** in this package.

## When you add or change an endpoint

1. **DTOs** in the area's `requests.dart` / `responses.dart`.
2. **Signature** on the abstract interface (`<area>_api.dart`) with a doc
   comment naming the route (`/// POST /sessions/revoke-all`).
3. **Implementation** in `dio_<area>_api.dart`: wrap the dio call in
   `try { … } on DioException catch (e) { throw ApiException.fromDioException(e); }`.
   Implementations throw `ApiException` — never `DioException`.
4. **Export** all new files from `lib/balsm_api.dart`.
5. **Test** in `packages/balsm_api/test/<area>/` using
   `test/helpers/fake_http_adapter.dart` — assert path, method, exact wire
   keys, and response parsing. Run `(cd packages/balsm_api && dart test)`.
6. **Provider**: new area ⇒ add `Provider<XxxApi>` in
   `packages/core/lib/src/network/api_providers.dart`
   (`DioXxxApi(dio: ref.watch(balsmApiClientProvider).dio)`).
7. **Module**: consume the interface via the provider; map DTO → domain
   type and `ApiException` → the module's `Failure`/exception in the
   module's own layer. Never construct `DioXxxApi` in a module.
8. **Cross-repo duty** (AGENTS.md): update the API client collection in
   `Balsm-Core` `/docs/api/` for any added/changed endpoint.

## PHI constraints

- Never log or `toString()` emails, user ids, tokens, or payload bodies.
- `ApiException.toString()` excludes `serverMessage` — keep it that way.
- Don't grow `PhiLeakInterceptor.allowedFields` casually: new telemetry
  fields must be deliberately non-PHI (see `test/phi_leak_fuzz_test/`).

## Do / Don't

| Do | Don't |
|----|-------|
| `ref.watch(sessionsApiProvider)` in a module | `ref.watch(...)` a Dio or build one |
| `on ApiException catch (e)` + map to module Failure | `on DioException` in a module |
| `e.fromEnvelope ? ValidationFailure(e.serverMessage ?? …)` | show `serverMessage` in logs |
| Add DTO + interface + impl + test + provider together | leave an inline `Map` payload "for now" |

## Checklist

- [ ] DTOs with exact wire keys (casing per area).
- [ ] Interface method with route doc comment.
- [ ] Dio impl throws only `ApiException`.
- [ ] Exports from `balsm_api.dart`.
- [ ] Area test green: `(cd packages/balsm_api && dart test)`.
- [ ] Core provider exists; module uses the abstraction.
- [ ] No `package:dio` import outside `balsm_api`/`core`.
- [ ] `Balsm-Core /docs/api/` collection updated.
```

- [ ] **Step 2: Commit**

```bash
cd /Volumes/Dev/Balsm/balsm_app_flutter
git add .claude/skills/flutter-add-api-endpoint
git commit -m "[Docs] add flutter-add-api-endpoint skill — balsm_api conventions"
```

---

### Task 14: Final verification + spec status

**Files:**
- Modify: `docs/superpowers/specs/2026-07-02-balsm-api-package-design.md` (status line)

- [ ] **Step 1: Full suite**

```bash
dart run melos bootstrap
melos run analyze
melos run test
(cd packages/balsm_api && dart test)
flutter test test/phi_leak_fuzz_test
```
Expected: all green. If `melos run test` chokes on the pure-Dart package, scope it out (`melos exec --ignore=balsm_api -- flutter test`) and note the follow-up.

- [ ] **Step 2: Contract sweep**

```bash
grep -rn "'/auth/\|'/account/\|'/sessions\|'/deletion/\|'/disclosure/\|'/emergency-qr/\|'/geofence/" packages/*/lib --include="*.dart" | grep -v "packages/balsm_api" && echo "ENDPOINT STRING OUTSIDE balsm_api — FIX" || echo "clean"
```
Expected: `clean` — every endpoint path literal lives in `balsm_api` only.

- [ ] **Step 3: Update spec status + commit**

Change spec header `**Status:** Approved (design review with Hossam)` → `**Status:** Implemented (2026-07-02)`.

```bash
git add docs/superpowers/specs/2026-07-02-balsm-api-package-design.md
git commit -m "[Docs] mark balsm_api extraction spec implemented"
```
