import 'dart:async';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/read_account_repository.dart';
import '../../domain/value_objects/account_summary.dart';

/// .NET REST adapter for the account read-model.
///
/// Response envelope: `{ "data": { ... }, "error": null }`.
/// PHI rule: never logs the response body (it may contain user identifiers);
/// only structural failures are surfaced as typed [AppFailure]s upstream.
class BalsmAccountAdapter implements ReadAccountRepository {
  BalsmAccountAdapter(this._dio);

  final Dio _dio;

  /// Local fan-out so [watchAccount] re-emits after mutations re-fetch.
  final _controller = StreamController<AccountSummary>.broadcast();

  @override
  Future<AccountSummary?> getAccount(String userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/account/self');
      final body = res.data;
      if (body == null) return null;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final summary = AccountSummary.fromJson(data);
      if (!_controller.isClosed) _controller.add(summary);
      return summary;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Stream<AccountSummary> watchAccount(String userId) async* {
    final current = await getAccount(userId);
    if (current != null) yield current;
    yield* _controller.stream;
  }

  void dispose() => _controller.close();
}

/// DI: the account read-repository backed by the shared dio client.
final readAccountRepositoryProvider = Provider<ReadAccountRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final adapter = BalsmAccountAdapter(dio);
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// GET /account/self → AccountSummary (null when the account is missing).
final accountSummaryProvider = FutureProvider<AccountSummary?>((ref) async {
  final repo = ref.watch(readAccountRepositoryProvider);
  // 'self' is resolved server-side from the auth token; the id arg is unused
  // by the /account/self endpoint but kept for the repository contract.
  return repo.getAccount('self');
});
