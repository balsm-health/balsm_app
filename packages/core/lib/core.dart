// Re-export all public APIs from src/subdirs
export 'src/domain/app_result.dart';
export 'src/domain/app_failure.dart';
export 'src/domain/events/app_event.dart';
// Cross-module domain events (published by modules, consumed via the bus).
export 'src/domain/events/country_changed.dart';
export 'src/domain/events/language_changed.dart';
export 'src/domain/events/session_expired.dart';
export 'src/domain/value_objects/uuid_v7.dart';
export 'src/domain/value_objects/unique_id.dart';
export 'src/domain/value_objects/user_id.dart';
export 'src/domain/value_objects/entity_id.dart';
export 'src/domain/value_objects/health_profile_id.dart';
export 'src/domain/value_objects/value_object.dart';
export 'src/domain/value_objects/country_code.dart';
export 'src/domain/value_objects/language_code.dart';
export 'src/domain/value_objects/gender.dart';
export 'src/domain/value_objects/currency_code.dart';
export 'src/domain/value_objects/phone_number.dart';
export 'src/domain/value_objects/nationality.dart';
export 'src/domain/value_objects/relationship.dart';
export 'src/domain/value_objects/iso8601_timestamp.dart';
export 'src/domain/value_objects/money.dart';
export 'src/domain/value_objects/tag.dart';
export 'src/event_bus/event_bus.dart';
export 'src/db/app_database.dart';
export 'src/extensions/type_extensions.dart';
export 'src/data_source/storage_exceptions.dart';
export 'src/data_source/data_source.dart';
export 'src/data_source/global_data_source.dart';
export 'src/data_source/user_data_source.dart';
export 'src/data_source/entity_data_source.dart';
export 'src/data_source/profile_data_source.dart';
export 'src/data_source/key_value_data_source.dart';
export 'src/data_source/data_source_providers.dart';
export 'src/data_source/module_preferences.dart';
export 'src/data_source/file_store.dart';
export 'src/data_source/impl/encrypted_file_store.dart';
export 'src/data_source/impl/shared_prefs_kv_data_source.dart';
// TARGETED re-export — only the two transport symbols that unmigrated
// callers (geofence, disclosure, settings screen) and the PHI fuzz test
// still reach through `package:core/core.dart`. Do NOT re-export the whole
// balsm_api library: modules import it directly for the API interfaces,
// DTOs, and ApiException, and a blanket re-export here would make every
// shared name ambiguous (defined in both core and balsm_api) in every file
// that imports both.
export 'package:balsm_api/balsm_api.dart' show BalsmApiClient, PhiLeakInterceptor;
export 'src/network/balsm_api_controller.dart';
export 'src/network/api_providers.dart';
export 'src/auth_context/current_user.dart';
export 'src/auth_context/current_entity.dart';
export 'src/auth_context/current_profile.dart';
// Cross-module read contracts (ports bound in the app composition root).
export 'src/contracts/account_summary.dart';
export 'src/contracts/read_account_repository.dart';
export 'src/contracts/account_read_providers.dart';
export 'src/localization/translation_catalog.dart';
export 'src/localization/reference_l10n.dart';
export 'src/localization/localization_util.dart';
export 'src/localization/country_registry.dart';
export 'src/crash/sentry_init.dart';
export 'src/telemetry/analytics_logger.dart';
export 'src/telemetry/allowlist.dart';
export 'src/telemetry/telemetry_scrubber.dart';
export 'src/telemetry/sentry_analytics_logger.dart';
export 'src/telemetry/console_analytics_logger.dart';
export 'src/telemetry/multi_analytics_logger.dart';
export 'src/telemetry/event_bus_forwarder.dart';
export 'src/telemetry/analytics_route_observer.dart';
export 'src/telemetry/providers.dart';
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
export 'src/kit/status_screen.dart';
export 'src/deeplink/deeplink_router.dart';
export 'src/backup/icloud_backup_adapter.dart';
export 'src/backup/drive_backup_adapter.dart';

// Dev-only: compile-time excluded in staging/prod via --dart-define FLAVOR.
// ignore: invalid_export_of_internal_element
export 'src/dev/server_selector_screen.dart' if (dart.library.io) 'src/dev/server_selector_screen.dart';
export 'src/dev/dev_log_buffer.dart' show DevLogBuffer;

// Test kit: gated by DEV environment flag.
export 'src/test_kit/fakes.dart' if (dart.library.html) 'src/test_kit/fakes.dart';
export 'src/test_kit/golden_helpers.dart';
