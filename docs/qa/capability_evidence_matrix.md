# Capability & Evidence Matrix

What the package does itself, where a consuming app must supply an adapter or
backend, and what proof exists. This is a claim ledger, not marketing: a row is
only as strong as its evidence column. Device proof lives in
[device_matrix.md](device_matrix.md); this file does not duplicate it.

## Labels

| Label | Meaning |
| --- | --- |
| `local` | Logic runs fully on-device inside the package; covered by host unit tests. |
| `seam` | Package defines an interface only. No store/ads/cloud SDK ships; the consuming app writes the adapter. |
| `demo` | `example/` wires it with a fake or local implementation to show the shape. |
| `device verified` | A dated physical-device record exists in `device_matrix.md` (scope-limited to that build and flow). |
| `not verified` | No evidence of real backend, network, store, or ad delivery. |

A row never claims backend behavior. "Verified" for a seam means the contract
and fake adapter are tested, not that any real provider was exercised.

## Matrix (representative, not exhaustive)

| Capability | Code | Type | Evidence | Not proven |
| --- | --- | --- | --- | --- |
| Save signing / tamper detection | `lib/core/save_integrity.dart` | `local` | `test/core/save_integrity_test.dart` | Secret is supplied by the consuming app, but a client-side secret can be recovered from the app binary: deters casual save editing only, not a determined attacker. No server-side validation. |
| Storage export/import, versioned saves | `lib/core/storage_service.dart`, `lib/core/versioned_json_store.dart` | `local` | `test/core/versioned_json_store_test.dart`, `test/core/storage_replace_reload_test.dart` | Behavior under real disk-full / process-kill is not device tested. |
| Cloud save sync + conflict resolution | `lib/core/cloud_save_provider.dart` | `seam` | `test/core/cloud_save_provider_test.dart`, `test/core/plugin_adapter_conformance_suite_test.dart` | No Play Games / Game Center / Firebase adapter exercised. |
| Offline progression, energy, daily login | `lib/core/offline_progression_service.dart`, `energy_service.dart`, `daily_login_service.dart` | `local` | `test/core/offline_progression_service_test.dart`, `energy_service_test.dart`, `daily_login_service_test.dart`, `test/tool/economy_sim_test.dart` | Clock-tamper resistance is local only; no server time check. |
| In-app purchase | `lib/core/purchase_seam.dart`, `purchase_ledger_service.dart` | `seam` + `local` ledger, `demo` | `test/core/purchase_seam_test.dart`, `test/core/purchase_ledger_service_test.dart`, `example/test/monetization_screen_test.dart` | No store receipt, entitlement, or refund flow. The ledger records a result the app already verified. |
| Rewarded ad | `lib/core/ad_reward_seam.dart` | `seam`, `demo` (fake adapter) | `test/core/ad_reward_seam_test.dart`, `example/test/monetization_screen_test.dart` | No ad network, no real reward delivery or payout. |
| Analytics consent + ACK/retry | `lib/core/analytics_provider.dart`, `consent_state_service.dart` | `seam` + `local`, `demo` | `test/core/consent_state_service_test.dart`, `test/core/consent_gated_analytics_provider_test.dart`, `example/test/analytics_ack_demo_screen_test.dart`; device: S24U `analytics_ack_recovery_test.dart` in [device_matrix.md](device_matrix.md) | Fake uploader and RAM storage only. No analytics transport or backend was reached. |
| Offline outbox + conflict policy | `lib/core/offline_outbox_service.dart` | `local` | `test/core/offline_outbox_service_test.dart`; `example/integration_test/offline_outbox_recovery_test.dart` | No real remote authority; conflicts are against a test double. |

## Rules for changing this file

- Add or upgrade a row only with a linked test, log, or `device_matrix.md` record. A screenshot is not evidence.
- Upgrade to `device verified` only by linking a dated record that names device, build, and flow. Keep the "Not proven" cell.
- Never write "verified" for backend, payout, store, or analytics transport without backend evidence.
- Review when `lib/roy_casual_kit.dart` exports change (the API snapshot gate fires) and before each release, alongside the intake checklist. Owner: whoever cuts the release.
- Scope boundary: this is a claim ledger. It does not replace the release intake checklist (`doc/task/RELEASE-0.6.3-INTAKE-CHECKLIST.md`) or a future consumer integration doctor (`IDEA-90`).
