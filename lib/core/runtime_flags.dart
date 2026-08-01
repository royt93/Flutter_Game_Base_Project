/// Build-time switches used only to make device automation deterministic.
///
/// Production builds keep every flag disabled unless explicitly supplied by
/// the build command, e.g. `--dart-define=E2E_TEST=true`.
const isE2eTest = bool.fromEnvironment('E2E_TEST');
