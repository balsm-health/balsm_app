import 'dart:async';
import 'dart:typed_data';
import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/active_server.dart';
import '../config/server_preset.dart';
import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';
import '../network/balsm_api_controller.dart';
import '../secure_storage/secure_storage_wrapper.dart';
import '../localization/translation_catalog.dart';
import '../localization/country_registry.dart';
import '../backup/backup_adapter.dart';

// All fakes gated behind DEV build flag — not exported in staging/prod.

class FakeEventBus extends EventBus {
  final published = <AppEvent>[];

  @override
  void publish(AppEvent event) {
    published.add(event);
    super.publish(event);
  }
}

class FakeBalsmApiController extends BalsmApiController {
  final initiated = <String>[];
  final reconfigured = <ServerPreset>[];

  FakeBalsmApiController()
      : super(
          client: BalsmApiClient(
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:5000')),
          ),
          store: ActiveServerStore(const FlutterSecureStorage()),
          bus: EventBus(),
        );

  @override
  Future<void> init() async => initiated.add('init');

  @override
  Future<void> reconfigure(ServerPreset preset) async => reconfigured.add(preset);
}

class FakeSecureStorage extends SecureStorageWrapper {
  final _store = <String, String>{};

  @override
  Future<String?> readToken(String key) async => _store[key];

  @override
  Future<void> writeToken(String key, String value) async => _store[key] = value;

  @override
  Future<void> deleteToken(String key) async => _store.remove(key);

  @override
  Future<void> clearAll() async => _store.clear();
}

class FakeTranslationCatalog extends TranslationCatalog {
  @override
  Future<void> load(List<String> locales) async {}

  @override
  String translate(String key, {String locale = 'en'}) => key;

  @override
  bool hasTranslation(String key, String locale) => true;
}

class FakeCountryRegistry extends CountryRegistry {
  @override
  String supervisoryAuthority(String isoCode) => switch (isoCode.toUpperCase()) {
        'EG' => 'Egypt PDPC',
        'SA' => 'Saudi SDAIA',
        'AE' => 'UAE Data Office',
        _ => 'Local Data Protection Authority',
      };
}

class FakeBackupAdapter implements BackupAdapter {
  final _store = <String, Uint8List>{};

  @override
  Future<void> upload(Uint8List blob, String key) async => _store[key] = blob;

  @override
  Future<Uint8List?> download(String key) async => _store[key];

  @override
  Future<bool> hasBackup(String key) async => _store.containsKey(key);
}

// Convenience provider overrides for tests.
final fakeEventBusProvider = Provider<FakeEventBus>((ref) => FakeEventBus());
