import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Manages local caching of electricity price data using SharedPreferences.
///
/// Provides methods to save, load, and validate cached price data with
/// automatic expiration handling.
class CacheManager {
  // Cache keys
  /// Key for today's electricity prices
  static const String keyPricesToday = 'prices_today';

  /// Key for tomorrow's electricity prices
  static const String keyPricesTomorrow = 'prices_tomorrow';

  /// Key for the last successful data update
  static const String keyLastUpdate = 'last_update';

  /// Key prefix for cache timestamps
  static const String keyTimestampPrefix = 'timestamp_';

  /// Default cache validity duration (1 hour)
  static const Duration defaultCacheDuration = Duration(hours: 1);

  /// Singleton instance
  static CacheManager? _instance;

  /// SharedPreferences instance
  SharedPreferences? _prefs;

  /// Private constructor for singleton pattern
  CacheManager._();

  /// Returns the singleton instance of [CacheManager].
  ///
  /// Initializes the instance if it hasn't been created yet.
  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      _instance = CacheManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  /// Initializes the SharedPreferences instance.
  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      developer.log(
        'CacheManager initialized',
        name: 'CacheManager',
      );
    } catch (e) {
      developer.log(
        'Failed to initialize SharedPreferences',
        name: 'CacheManager',
        error: e,
      );
      rethrow;
    }
  }

  /// Ensures SharedPreferences is initialized.
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await _init();
    }
  }

  /// Saves a list of electricity prices to cache.
  ///
  /// [prices] - The list of prices to cache
  /// [key] - The cache key (e.g., 'prices_today', 'prices_tomorrow')
  ///
  /// Returns true if the save was successful, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final manager = await CacheManager.getInstance();
  /// final success = await manager.savePrices(
  ///   prices,
  ///   CacheManager.keyPricesToday,
  /// );
  /// ```
  Future<bool> savePrices(List<ElectricityPrice> prices, String key) async {
    try {
      await _ensureInitialized();

      // Convert prices to JSON
      final jsonList = prices.map((price) => price.toJson()).toList();
      final jsonString = json.encode(jsonList);

      // Save prices
      final pricesSaved = await _prefs!.setString(key, jsonString);

      // Save timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final timestampKey = _getTimestampKey(key);
      final timestampSaved = await _prefs!.setInt(timestampKey, timestamp);

      final success = pricesSaved && timestampSaved;

      if (success) {
        developer.log(
          'Saved ${prices.length} prices with key: $key',
          name: 'CacheManager',
        );
      } else {
        developer.log(
          'Failed to save prices with key: $key',
          name: 'CacheManager',
        );
      }

      return success;
    } catch (e) {
      developer.log(
        'Error saving prices with key: $key',
        name: 'CacheManager',
        error: e,
      );
      return false;
    }
  }

  /// Loads cached electricity prices.
  ///
  /// [key] - The cache key to load from
  ///
  /// Returns a list of cached [ElectricityPrice] objects, or null if:
  /// - No cached data exists
  /// - The cached data is invalid
  /// - An error occurred during loading
  ///
  /// Example:
  /// ```dart
  /// final manager = await CacheManager.getInstance();
  /// final prices = await manager.loadPrices(CacheManager.keyPricesToday);
  /// if (prices != null) {
  ///   print('Loaded ${prices.length} cached prices');
  /// }
  /// ```
  Future<List<ElectricityPrice>?> loadPrices(String key) async {
    try {
      await _ensureInitialized();

      // Get cached JSON string
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) {
        developer.log(
          'No cached data found for key: $key',
          name: 'CacheManager',
        );
        return null;
      }

      // Parse JSON
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      // Convert to ElectricityPrice objects
      final prices = <ElectricityPrice>[];
      for (final item in jsonList) {
        try {
          if (item is Map<String, dynamic>) {
            prices.add(ElectricityPrice.fromJson(item));
          } else {
            developer.log(
              'Invalid price item type: ${item.runtimeType}',
              name: 'CacheManager',
            );
          }
        } catch (e) {
          developer.log(
            'Error parsing cached price item',
            name: 'CacheManager',
            error: e,
          );
          // Continue parsing other items
        }
      }

      if (prices.isEmpty) {
        developer.log(
          'No valid prices parsed from cache for key: $key',
          name: 'CacheManager',
        );
        return null;
      }

      developer.log(
        'Loaded ${prices.length} prices from cache with key: $key',
        name: 'CacheManager',
      );

      return prices;
    } catch (e) {
      developer.log(
        'Error loading prices with key: $key',
        name: 'CacheManager',
        error: e,
      );
      return null;
    }
  }

  /// Gets the timestamp when data was cached.
  ///
  /// [key] - The cache key to check
  ///
  /// Returns the [DateTime] when the data was cached, or null if no
  /// timestamp exists.
  ///
  /// Example:
  /// ```dart
  /// final timestamp = await manager.getCacheTimestamp(
  ///   CacheManager.keyPricesToday,
  /// );
  /// if (timestamp != null) {
  ///   print('Data cached at: $timestamp');
  /// }
  /// ```
  Future<DateTime?> getCacheTimestamp(String key) async {
    try {
      await _ensureInitialized();

      final timestampKey = _getTimestampKey(key);
      final timestamp = _prefs!.getInt(timestampKey);

      if (timestamp == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      developer.log(
        'Error getting cache timestamp for key: $key',
        name: 'CacheManager',
        error: e,
      );
      return null;
    }
  }

  /// Gets the age of cached data.
  ///
  /// [key] - The cache key to check
  ///
  /// Returns the [Duration] since the data was cached, or null if no
  /// cached data exists.
  Future<Duration?> getCacheAge(String key) async {
    final timestamp = await getCacheTimestamp(key);
    if (timestamp == null) return null;

    return DateTime.now().difference(timestamp);
  }

  /// Checks if cached data is still valid.
  ///
  /// [key] - The cache key to check
  /// [validFor] - How long the cache should be considered valid
  ///              (defaults to 1 hour)
  ///
  /// Returns true if cached data exists and is still within the validity
  /// period, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final isValid = await manager.isCacheValid(
  ///   CacheManager.keyPricesToday,
  ///   Duration(hours: 1),
  /// );
  /// if (isValid) {
  ///   // Use cached data
  /// } else {
  ///   // Fetch fresh data
  /// }
  /// ```
  Future<bool> isCacheValid(
    String key, {
    Duration validFor = defaultCacheDuration,
  }) async {
    try {
      // Check if data exists
      await _ensureInitialized();
      final hasData = _prefs!.containsKey(key);
      if (!hasData) {
        return false;
      }

      // Check timestamp
      final timestamp = await getCacheTimestamp(key);
      if (timestamp == null) {
        return false;
      }

      // Check if within validity period
      final age = DateTime.now().difference(timestamp);
      final isValid = age <= validFor;

      developer.log(
        'Cache validity check for $key: $isValid (age: ${age.inMinutes}m, valid for: ${validFor.inMinutes}m)',
        name: 'CacheManager',
      );

      return isValid;
    } catch (e) {
      developer.log(
        'Error checking cache validity for key: $key',
        name: 'CacheManager',
        error: e,
      );
      return false;
    }
  }

  /// Clears a specific cached item.
  ///
  /// [key] - The cache key to clear
  ///
  /// Returns true if the clear was successful, false otherwise.
  Future<bool> clearKey(String key) async {
    try {
      await _ensureInitialized();

      final timestampKey = _getTimestampKey(key);

      final dataRemoved = await _prefs!.remove(key);
      final timestampRemoved = await _prefs!.remove(timestampKey);

      final success = dataRemoved && timestampRemoved;

      if (success) {
        developer.log(
          'Cleared cache for key: $key',
          name: 'CacheManager',
        );
      }

      return success;
    } catch (e) {
      developer.log(
        'Error clearing cache for key: $key',
        name: 'CacheManager',
        error: e,
      );
      return false;
    }
  }

  /// Clears all cached data.
  ///
  /// Returns true if the clear was successful, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final manager = await CacheManager.getInstance();
  /// await manager.clearCache();
  /// ```
  Future<bool> clearCache() async {
    try {
      await _ensureInitialized();

      final success = await _prefs!.clear();

      if (success) {
        developer.log(
          'Cleared all cached data',
          name: 'CacheManager',
        );
      } else {
        developer.log(
          'Failed to clear all cached data',
          name: 'CacheManager',
        );
      }

      return success;
    } catch (e) {
      developer.log(
        'Error clearing all cached data',
        name: 'CacheManager',
        error: e,
      );
      return false;
    }
  }

  /// Saves the last update timestamp.
  ///
  /// This is useful for tracking when the app last successfully fetched
  /// data from the API.
  Future<bool> saveLastUpdateTime() async {
    try {
      await _ensureInitialized();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final success = await _prefs!.setInt(keyLastUpdate, timestamp);

      if (success) {
        developer.log(
          'Saved last update timestamp',
          name: 'CacheManager',
        );
      }

      return success;
    } catch (e) {
      developer.log(
        'Error saving last update timestamp',
        name: 'CacheManager',
        error: e,
      );
      return false;
    }
  }

  /// Gets the last update timestamp.
  ///
  /// Returns the [DateTime] of the last successful data update, or null
  /// if no update has been recorded.
  Future<DateTime?> getLastUpdateTime() async {
    try {
      await _ensureInitialized();

      final timestamp = _prefs!.getInt(keyLastUpdate);
      if (timestamp == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      developer.log(
        'Error getting last update timestamp',
        name: 'CacheManager',
        error: e,
      );
      return null;
    }
  }

  /// Checks if cached data exists for a given key.
  ///
  /// [key] - The cache key to check
  ///
  /// Returns true if data exists, false otherwise.
  Future<bool> hasCache(String key) async {
    try {
      await _ensureInitialized();
      return _prefs!.containsKey(key);
    } catch (e) {
      developer.log(
        'Error checking if cache exists for key: $key',
        name: 'CacheManager',
        error: e,
      );
      return false;
    }
  }

  /// Gets statistics about all cached data.
  ///
  /// Returns a map containing information about cached data including
  /// keys, timestamps, and validity status.
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      await _ensureInitialized();

      final stats = <String, dynamic>{
        'keys': <String>[],
        'totalItems': 0,
      };

      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (!key.startsWith(keyTimestampPrefix)) {
          final timestamp = await getCacheTimestamp(key);
          final age = timestamp != null
              ? DateTime.now().difference(timestamp)
              : null;
          final isValid = await isCacheValid(key);

          stats['keys'].add({
            'key': key,
            'timestamp': timestamp?.toIso8601String(),
            'ageMinutes': age?.inMinutes,
            'isValid': isValid,
          });

          stats['totalItems'] = (stats['totalItems'] as int) + 1;
        }
      }

      final lastUpdate = await getLastUpdateTime();
      stats['lastUpdate'] = lastUpdate?.toIso8601String();

      return stats;
    } catch (e) {
      developer.log(
        'Error getting cache stats',
        name: 'CacheManager',
        error: e,
      );
      return {'error': e.toString()};
    }
  }

  /// Generates the timestamp key for a given cache key.
  String _getTimestampKey(String key) {
    return '$keyTimestampPrefix$key';
  }
}
