// Re-export all public APIs from src/subdirs
export 'src/domain/app_result.dart';
export 'src/domain/app_failure.dart';
export 'src/domain/events/app_event.dart';
export 'src/domain/value_objects/uuid_v7.dart';
export 'src/domain/value_objects/country_code.dart';
export 'src/domain/value_objects/bcp47_tag.dart';
export 'src/domain/value_objects/iso8601_timestamp.dart';
export 'src/domain/value_objects/money.dart';
export 'src/event_bus/event_bus.dart';
export 'src/db/app_database.dart';
export 'src/network/balsm_api_client.dart';
export 'src/network/phi_leak_interceptor.dart';
export 'src/network/dio_client_provider.dart';
export 'src/auth_context/current_user.dart';
export 'src/localization/translation_catalog.dart';
export 'src/localization/country_registry.dart';
export 'src/crash/sentry_init.dart';
export 'src/secure_storage/secure_storage_wrapper.dart';
export 'src/notifications/notification_service.dart';
export 'src/notifications/permission_state.dart';
export 'src/notifications/permission_change_event.dart';
export 'src/config/flavor.dart';
export 'src/config/server_preset.dart';
export 'src/config/active_server.dart';
export 'src/config/recaptcha_adapter.dart';
export 'src/backup/backup_adapter.dart';
export 'src/backup/backup_key_derivation.dart';
export 'src/backup/backup_debouncer.dart';
export 'src/backup/concurrent_conflict_resolver.dart';
export 'src/backup/blob_codec.dart';
export 'src/backup/recovery_code.dart';
export 'src/backup/snapshot_service.dart';
export 'src/backup/backup_service.dart';
export 'src/backup/restore_service.dart';
export 'src/backup/sync_status.dart';
export 'src/backup/connectivity_online_stream.dart';
export 'src/backup/backup_prompts.dart';
export 'src/backup/sync_status_badge.dart';
export 'src/kit/balsm_kit.dart';
export 'src/kit/theme.dart';
export 'src/kit/shared_widgets.dart';
export 'src/kit/not_found_screen.dart';
export 'src/deeplink/deeplink_router.dart';
export 'src/backup/icloud_backup_adapter.dart';
export 'src/backup/drive_backup_adapter.dart';

// Dev-only: compile-time excluded in staging/prod via --dart-define FLAVOR.
// ignore: invalid_export_of_internal_element
export 'src/dev/server_selector_screen.dart'
    if (dart.library.io) 'src/dev/server_selector_screen.dart';

// Test kit: gated by DEV environment flag.
export 'src/test_kit/fakes.dart'
    if (dart.library.html) 'src/test_kit/fakes.dart';
export 'src/test_kit/golden_helpers.dart';
