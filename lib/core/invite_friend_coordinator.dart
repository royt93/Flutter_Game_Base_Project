import 'package:flutter/widgets.dart';

import 'deep_link_command_router.dart';
import 'share_helper.dart';
import 'storage_service.dart';
import 'utils/fnv1a.dart';

/// (IDEA-70) Ties together 3 pieces of already-existing kit infrastructure
/// into a referral/invite-friend loop: [fnv1aHash] (a stable per-player
/// invite code), `share_helper.dart`'s [shareText] (sending it), and
/// [DeepLinkCommandRouter] (recognizing a friend opening the invite link).
///
/// **Honest limitation (same "state it plainly" convention as
/// `ClampedClock`/`save_integrity.dart`)**: verification here is
/// best-effort, LOCAL ONLY. Nothing stops a player from generating their
/// own code (`codeFor` is a pure function of any string) and "redeeming"
/// it on the same device, or on a fresh install with no server involved at
/// all — there is no server-side check that the inviter and invitee are
/// actually 2 different real people. Because of that, this coordinator
/// deliberately does **not** grant any reward itself — it only tracks
/// "which code, if any, was this install invited by" (see
/// [redeemedInviteCode]). A consuming app that wants a referral reward
/// must apply its own anti-fraud judgment (a server check, a cooldown, a
/// minimum play-time before payout, ...) before granting one — same seam
/// convention as every other reward-adjacent service in this kit.
class InviteFriendCoordinator {
  InviteFriendCoordinator({
    required DeepLinkCommandRouter router,
    required StorageService storage,
    this.commandType = 'invite',
  }) : _storage = storage {
    router.registerHandler(commandType, _onInviteLink);
  }

  final StorageService _storage;

  /// The [DeepLinkRoute.commandType]/[DeepLinkCommandRouter.registerHandler]
  /// key this coordinator listens on. Must match the `commandType` of the
  /// route passed to [route] below when constructing the app's
  /// [DeepLinkCommandRouter].
  final String commandType;

  /// Builds the [DeepLinkRoute] a consumer app's [DeepLinkCommandRouter]
  /// must include in its `routes` list for invite links to be recognized
  /// at all — [DeepLinkCommandRouter.registerHandler] (called by this
  /// coordinator's constructor) only wires up what happens for a route
  /// that already matched, it can't add a brand new route to a router
  /// after construction.
  ///
  /// Matches a link shaped like `<scheme>://<host>?code=XYZ` (e.g.
  /// `myapp://invite?code=XYZ`) — [host] defaults to `'invite'` and rarely
  /// needs overriding; [scheme] must be the app's own registered custom
  /// scheme.
  static DeepLinkRoute route({
    required String scheme,
    String host = 'invite',
    String commandType = 'invite',
  }) => DeepLinkRoute(
    commandType: commandType,
    scheme: scheme,
    host: host,
    pathSegments: const [],
  );

  /// A stable invite code for [playerId] — the SAME [playerId] always
  /// produces the SAME code (pure function of [fnv1aHash], no randomness,
  /// no I/O), so a player's invite code never needs to be persisted
  /// separately — it can be recomputed from their existing player id at
  /// any time.
  static String codeFor(String playerId) =>
      fnv1aHash(playerId).toRadixString(36).toUpperCase();

  /// Shares [playerId]'s invite code via [shareText]. [messageBuilder]
  /// lets a caller supply their own copy/deep-link URL around the code;
  /// left `null`, a plain default message with just the code is shared.
  Future<void> shareInvite(
    String playerId, {
    BuildContext? sharePositionContext,
    String Function(String code)? messageBuilder,
  }) {
    final code = codeFor(playerId);
    final message = messageBuilder?.call(code) ?? 'Mã mời của tôi: $code';
    return shareText(message, sharePositionContext: sharePositionContext);
  }

  /// The invite code this install was redeemed by, or `null` if this
  /// install has never opened a valid invite link.
  String? get redeemedInviteCode =>
      _storage.getString(StorageKeys.inviteRedeemedCode);

  /// `true` once this install has redeemed exactly 1 invite code — see
  /// [redeemedInviteCode].
  bool get hasRedeemedInvite => redeemedInviteCode != null;

  // Marks "redeemed" at most ONCE per install — a second, different code
  // arriving later (e.g. the player opens a 2nd friend's invite link after
  // already using a 1st one) never overwrites the first, and is never
  // counted as a 2nd redemption. Matches AC3.
  Future<void> _onInviteLink(DeepLinkCommand command) async {
    if (hasRedeemedInvite) return;
    final code = command.params['code']?.trim();
    if (code == null || code.isEmpty) return;
    await _storage.setString(StorageKeys.inviteRedeemedCode, code);
  }
}
