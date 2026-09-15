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
    hash = (hash * prime) & mask32;
  }
  return hash;
}
