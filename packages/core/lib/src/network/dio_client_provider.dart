import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'balsm_api_client.dart';

final balsmApiClientProvider = Provider<BalsmApiClient>((ref) {
  throw UnimplementedError('Override balsmApiClientProvider in ProviderScope');
});

final dioClientProvider = Provider<Dio>((ref) {
  return ref.watch(balsmApiClientProvider).dio;
});
