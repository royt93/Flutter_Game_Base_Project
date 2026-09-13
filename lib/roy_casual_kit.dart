/// Stable public entrypoint for the Roy Casual Kit package.
///
/// Consumers should prefer this library for supported APIs. Internal files
/// under `core/` and `presentation/` remain available for advanced migration
/// cases, but are not part of the recommended import surface.
library;

// Core services and contracts.
export 'core/achievement_service.dart';
export 'core/analytics_provider.dart';
export 'core/app_info.dart';
export 'core/app_translations.dart';
export 'core/audio_manager.dart';
export 'core/cloud_save_provider.dart';
export 'core/consumer_contract_test_kit.dart';
export 'core/crash_reporter.dart';
export 'core/daily_login_service.dart';
export 'core/daily_quest_service.dart';
export 'core/energy_service.dart';
export 'core/experiment_bucketing_service.dart';
export 'core/haptic_choreographer.dart';
export 'core/haptics.dart';
export 'core/in_app_review_helper.dart';
export 'core/kit_bootstrap.dart';
export 'core/local_scoreboard_service.dart';
export 'core/locale_service.dart';
export 'core/lifecycle_coordinator.dart';
export 'core/game_session_controller.dart';
export 'core/economy_wallet.dart';
export 'core/neon_theme.dart';
export 'core/offline_progression_service.dart';
export 'core/performance_tier_service.dart';
export 'core/purchase_ledger_service.dart';
export 'core/purchase_seam.dart';
export 'core/reminder_service.dart';
export 'core/remote_config_service.dart';
export 'core/runtime_flags.dart';
export 'core/save_integrity.dart';
export 'core/season_event_service.dart';
export 'core/share_helper.dart';
export 'core/storage_service.dart';
export 'core/versioned_json_store.dart';
export 'core/utils/clamped_clock.dart';
export 'core/utils/economy_math.dart';
export 'core/utils/trusted_clock.dart';
export 'core/utils/async_action_guard.dart';
export 'core/utils/save_migration_registry.dart';
export 'core/utils/sdk_result.dart';
export 'core/utils/format.dart';
export 'core/utils/label_fit.dart';
export 'core/utils/safe_json.dart';
export 'core/utils/throttle.dart';
export 'core/utils/weighted_random_pick.dart';

// Flame starter game and top-level presentation widgets.
export 'presentation/game/roy_game.dart';
export 'presentation/widgets/aurora_bg_layer.dart';
export 'presentation/widgets/flame_tracked_overlay.dart';
export 'presentation/widgets/neon_app_bar.dart';
export 'presentation/widgets/neon_aura_layer.dart';
export 'presentation/widgets/neon_bg.dart';
export 'presentation/widgets/neon_button.dart';
export 'presentation/widgets/neon_dialog.dart';
export 'presentation/widgets/neon_icon.dart';
export 'presentation/widgets/pressable_scale.dart';
export 'presentation/widgets/shader_ticker_layer.dart';
export 'presentation/widgets/stroke_text.dart';

// Game-agnostic common widget kit.
export 'presentation/widgets/common/common_widgets.dart';
