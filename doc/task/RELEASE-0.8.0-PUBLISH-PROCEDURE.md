# 0.8.0 publish procedure (prepared 2026-11-23, NOT executed)

Nothing here has been run. Tag, GitHub release and pub.dev publish are
irreversible and each needs an explicit request from the owner. State on
2026-11-23: `release_readiness_check` passes on `1bec453d` (CI green on all three
jobs), `publish --dry-run` reports 0 warnings (21 MB compressed).

## Same method as 0.6.8 to 0.7.1

1. Re-run `dart run tool/release_readiness_check.dart` on a clean tree. It must say
   "Ready". Tag the commit CI went green on, not a later HEAD.
2. Ask the owner for an explicit "tag + GitHub release". Then:
   `git tag -a v0.8.0 <green-commit> -m "0.8.0"` and `git push origin v0.8.0`, then
   `gh release create v0.8.0 --notes-file doc/task/RELEASE-0.8.0-NOTES-DRAFT.md`
   (read the draft first; it is the owner's to approve, and the Platforms and
   verification sections must still be true).
3. Ask the owner for an explicit "publish". Publish from a git archive of the tag,
   never the working tree, so later commits cannot leak in:
   `git archive v0.8.0 --prefix=pkg/ | tar -x -C <empty dir>`, then
   `dart pub publish --dry-run` and `dart pub publish --force` from that directory.

## After 0.8.0 exists on pub.dev (not before)

The consumer generator still defaults to `roy_casual_kit: ^0.7.0`. Changing it
earlier breaks it for outside users: measured, a generated app with `^0.8.0` fails
`flutter pub get` ("doesn't match any versions") until 0.8.0 is published.

Apply the prepared change (tool 4 places, README, 2 tests):

    git apply doc/task/evidence/RELEASE-0.8.0-generator-default.patch

then run `flutter test test/tool/create_consumer_app_test.dart` and
`flutter test test/tool/create_consumer_app_e2e_test.dart` (the e2e test uses
`kitPath`, so it does not need the hosted version), commit, and start a
`## 0.8.1` (or `## Unreleased`) CHANGELOG section for later work.

## Things to remember

- Breaking: the rewarded-ad feature is removed (see the CHANGELOG 0.8.0 section
  and the draft notes for the migration).
- Supported platforms are Android and iOS only; web compiles as a side effect.
- Device evidence is from a Pixel 7 Pro and the S24 Ultra (both Android 17);
  the S24U is the default device from now on.
- `.pubignore` excludes `doc/`, so this file and the patch are not published.
