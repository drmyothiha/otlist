import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For json encoding/decoding

class LocalCacheService {
  static const String _operationsKey = 'cached_operations';
  static const String _deletedOperationsKey = 'deleted_operations';

  /// Save a single operation to local cache
  static Future<void> saveOperation(Map<String, dynamic> operation) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getCachedOperations();
    existing.add(operation);
    await prefs.setString(_operationsKey, jsonEncode(existing));
  }

  /// Get all cached operations (excluding deleted ones)
  static Future<List<Map<String, dynamic>>> getCachedOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_operationsKey);
    final deletedIds = prefs.getStringList(_deletedOperationsKey) ?? [];

    if (cachedData == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded
          .map((e) => e as Map<String, dynamic>)
          .where((op) => !deletedIds.contains(op['id']?.toString()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Remove an operation from cache (for successful syncs)
  static Future<void> removeOperation(Map<String, dynamic> operation) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getCachedOperations();
    existing.removeWhere((op) => op['id'] == operation['id']);
    await prefs.setString(_operationsKey, jsonEncode(existing));
  }

  /// Mark operations for deletion (offline mode)
  static Future<void> markOperationsForDeletion(List<dynamic> operations) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList(_deletedOperationsKey) ?? [];

    // Add new IDs to track deletions
    for (final op in operations) {
      if (op['id'] != null) {
        deletedIds.add(op['id'].toString());
      }
    }

    await prefs.setStringList(_deletedOperationsKey, deletedIds);
    
    // Also remove from main cache immediately
    final currentOps = await getCachedOperations();
    final remainingOps = currentOps.where(
      (op) => !operations.any((deleted) => deleted['id'] == op['id'])
    ).toList();
    
    await prefs.setString(_operationsKey, jsonEncode(remainingOps));
  }

  /// Clear all cached data (for logout or debugging)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_operationsKey);
    await prefs.remove(_deletedOperationsKey);
  }
}