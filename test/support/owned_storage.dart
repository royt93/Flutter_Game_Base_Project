import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [StorageService] backed by mock SharedPreferences, closed at the end of
/// the current test so its change notifiers are released (leak tracking).
Future<StorageService> ownedStorage([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final s = StorageService(await SharedPreferences.getInstance());
  addTearDown(s.onClose);
  return s;
}

/// Same, with no preferences backing (the in-memory fallback).
StorageService ownedMemoryStorage() {
  final s = StorageService(null);
  addTearDown(s.onClose);
  return s;
}
