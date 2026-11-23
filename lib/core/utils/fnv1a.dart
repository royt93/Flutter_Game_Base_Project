import 'dart:convert';

/// FNV-1a, 32-bit — a small, dependency-free string hash. Deterministic by
/// construction (no reliance on Dart's `String.hashCode`, which is
/// explicitly NOT guaranteed stable across Dart versions/runs) — any code
/// that needs a hash to stay the same across app rebuilds/SDK upgrades
/// (an experiment bucket assignment, a namespaced RNG seed, ...) must use
/// this instead.
int fnv1aHash(String input) {
  const prime = 16777619;
  const mask32 = 0xFFFFFFFF;
  var hash = 2166136261;
  for (final byte in utf8.encode(input)) {
    hash = (hash ^ byte) & mask32;
    // `(hash * prime) & mask32` as one product reaches ~2^56, past the 2^53
    // a JavaScript number holds exactly, so on the web it rounds and the
    // hash silently differs from native. Splitting `hash` into 16-bit halves
    // keeps every product below 2^53 and gives the identical 32-bit result.
    final low = hash & 0xFFFF;
    final high = hash >> 16;
    hash = (low * prime + (((high * prime) & 0xFFFF) << 16)) & mask32;
  }
  return hash;
}
