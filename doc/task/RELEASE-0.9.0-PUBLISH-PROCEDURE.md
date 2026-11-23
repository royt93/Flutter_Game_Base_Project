# 0.9.0 publish procedure (prepared 2026-11-23, NOT executed)

Nothing here has been run. Tag, GitHub release and pub.dev publish are
irreversible and each needs an explicit request from the owner. Same method as
0.8.0 (see `RELEASE-0.8.0-PUBLISH-PROCEDURE.md`).

1. On a clean tree run `dart run tool/release_readiness_check.dart`; it must say
   "Ready". Tag the commit CI went green on, not a later HEAD. The version bump
   commit is the one to tag; wait for its CI.
2. Ask the owner for "tag + GitHub release". Then
   `git tag -a v0.9.0 <green-commit> -m "roy_casual_kit 0.9.0"`,
   `git push origin v0.9.0`, and create the release from the notes with the
   DRAFT header and this "before publishing" part removed
   (`gh release create v0.9.0 --title "roy_casual_kit 0.9.0" --notes-file <clean notes> --verify-tag`).
3. Ask the owner for "publish". Publish from `git archive` of the tag in an empty
   directory (never the working tree): `git archive v0.9.0 --prefix=pkg/ | tar -x -C <empty dir>`,
   then `dart pub publish --dry-run` and `dart pub publish --force` inside `pkg/`.

## After 0.9.0 is on pub.dev (not before)

The consumer generator still defaults to `^0.8.0`. Changing it earlier breaks
outside users (a generated app fails `flutter pub get` until 0.9.0 exists). Then:

    git apply doc/task/evidence/RELEASE-0.9.0-generator-default.patch

run `flutter test test/tool/create_consumer_app_test.dart` and
`flutter test test/tool/create_consumer_app_e2e_test.dart`, commit and push.

`.pubignore` excludes `doc/`, so these files are not published.
