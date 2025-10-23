import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';

/// Provider for managing electricity price data and state.
///
/// Uses the Provider pattern with [ChangeNotifier] to manage app-wide
/// state for electricity prices, including loading states, errors, and
/// data fetching from API and cache.
class PriceProvider extends ChangeNotifier {
  /// Elering API service instance
  final EleringApiService _apiService;

  /// Cache manager instance
  final CacheManager _cacheManager;

  // State variables
  List<ElectricityPrice> _todayPrices = [];
  List<ElectricityPrice>? _tomorrowPrices;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdate;

  /// Creates a [PriceProvider] instance.
  ///
  /// [apiService] - Service for fetching prices from Elering API
  /// [cacheManager] - Service for caching price data locally
  PriceProvider({
    required EleringApiService apiService,
    required CacheManager cacheManager,
  })  : _apiService = apiService,
        _cacheManager = cacheManager;

  // Getters for state
  /// Today's electricity prices
  List<ElectricityPrice> get todayPrices => _todayPrices;

  /// Tomorrow's electricity prices (may be null if not available yet)
  List<ElectricityPrice>? get tomorrowPrices => _tomorrowPrices;

  /// Whether prices are currently being loaded
  bool get isLoading => _isLoading;

  /// Error message if the last operation failed
  String? get errorMessage => _errorMessage;

  /// Timestamp of the last successful update
  DateTime? get lastUpdate => _lastUpdate;

  /// Whether today's prices are available
  bool get hasTodayPrices => _todayPrices.isNotEmpty;

  /// Whether tomorrow's prices are available
  bool get hasTomorrowPrices => _tomorrowPrices != null && _tomorrowPrices!.isNotEmpty;

  /// Loads electricity prices using smart caching strategy.
  ///
  /// Strategy:
  /// 1. Check cache for today's prices
  /// 2. If cache is valid, use cached data
  /// 3. If cache is expired or empty, fetch from API
  /// 4. Update cache after successful API call
  /// 5. Try to load tomorrow's prices (if available)
  ///
  /// Returns true if prices were loaded successfully, false otherwise.
  Future<bool> loadPrices() async {
    developer.log('Loading prices...', name: 'PriceProvider');

    _setLoading(true);
    _clearError();

    try {
      // Try loading from cache first
      final cachedToday = await _loadFromCache(CacheManager.keyPricesToday);
      final cachedTomorrow = await _loadFromCache(CacheManager.keyPricesTomorrow);

      // Check if today's cache is valid
      final isCacheValid = await _cacheManager.isCacheValid(
        CacheManager.keyPricesToday,
        validFor: const Duration(hours: 1),
      );

      if (cachedToday != null && isCacheValid) {
        // Use cached data
        developer.log(
          'Using cached today prices: ${cachedToday.length} items',
          name: 'PriceProvider',
        );

        _todayPrices = cachedToday;
        _tomorrowPrices = cachedTomorrow;
        _lastUpdate = await _cacheManager.getCacheTimestamp(
          CacheManager.keyPricesToday,
        );

        _setLoading(false);
        return true;
      }

      // Cache is expired or empty, fetch from API
      developer.log('Cache expired or empty, fetching from API', name: 'PriceProvider');
      return await _fetchFromApi();
    } catch (e) {
      developer.log('Error loading prices', name: 'PriceProvider', error: e);
      _setError('Failed to load prices: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Forces a refresh of prices from the API, bypassing the cache.
  ///
  /// This clears the cache and fetches fresh data from the Elering API.
  /// Use this when the user explicitly requests fresh data.
  ///
  /// Returns true if refresh was successful, false otherwise.
  Future<bool> refreshPrices() async {
    developer.log('Refreshing prices from API...', name: 'PriceProvider');

    _setLoading(true);
    _clearError();

    try {
      // Clear API service cache
      _apiService.clearCache();

      // Fetch from API
      return await _fetchFromApi();
    } catch (e) {
      developer.log('Error refreshing prices', name: 'PriceProvider', error: e);
      _setError('Failed to refresh prices: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Fetches prices from the API and updates cache.
  Future<bool> _fetchFromApi() async {
    try {
      // Fetch today's prices
      final apiPrices = await _apiService.fetchPricesForLatvia();

      if (apiPrices.isEmpty) {
        _setError('No price data available');
        _setLoading(false);
        return false;
      }

      // Separate today's and tomorrow's prices
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
      final dayAfterMidnight = tomorrowMidnight.add(const Duration(days: 1));

      final today = <ElectricityPrice>[];
      final tomorrow = <ElectricityPrice>[];

      for (final price in apiPrices) {
        if (price.timestamp.isAfter(todayMidnight) &&
            price.timestamp.isBefore(tomorrowMidnight)) {
          today.add(price);
        } else if (price.timestamp.isAfter(tomorrowMidnight) &&
            price.timestamp.isBefore(dayAfterMidnight)) {
          tomorrow.add(price);
        }
      }

      // Update state
      _todayPrices = today;
      _tomorrowPrices = tomorrow.isNotEmpty ? tomorrow : null;
      _lastUpdate = DateTime.now();

      // Save to cache
      await _saveToCache(today, CacheManager.keyPricesToday);
      if (tomorrow.isNotEmpty) {
        await _saveToCache(tomorrow, CacheManager.keyPricesTomorrow);
      }
      await _cacheManager.saveLastUpdateTime();

      developer.log(
        'Successfully fetched prices - Today: ${today.length}, Tomorrow: ${tomorrow.length}',
        name: 'PriceProvider',
      );

      _setLoading(false);
      return true;
    } catch (e) {
      developer.log('Error fetching from API', name: 'PriceProvider', error: e);

      // Try to fall back to expired cache
      final cachedToday = await _loadFromCache(CacheManager.keyPricesToday);
      if (cachedToday != null && cachedToday.isNotEmpty) {
        developer.log('Using expired cache as fallback', name: 'PriceProvider');
        _todayPrices = cachedToday;
        _tomorrowPrices = await _loadFromCache(CacheManager.keyPricesTomorrow);
        _lastUpdate = await _cacheManager.getCacheTimestamp(
          CacheManager.keyPricesToday,
        );
        _setError('Using cached data (API unavailable)');
      } else {
        _setError('Failed to load prices: $e');
      }

      _setLoading(false);
      return false;
    }
  }

  /// Loads prices from cache.
  Future<List<ElectricityPrice>?> _loadFromCache(String key) async {
    try {
      return await _cacheManager.loadPrices(key);
    } catch (e) {
      developer.log(
        'Error loading from cache: $key',
        name: 'PriceProvider',
        error: e,
      );
      return null;
    }
  }

  /// Saves prices to cache.
  Future<void> _saveToCache(List<ElectricityPrice> prices, String key) async {
    try {
      await _cacheManager.savePrices(prices, key);
    } catch (e) {
      developer.log(
        'Error saving to cache: $key',
        name: 'PriceProvider',
        error: e,
      );
    }
  }

  /// Gets the current hour's electricity price.
  ///
  /// Returns the price for the current hour from today's prices,
  /// or null if not available.
  ElectricityPrice? getCurrentPrice() {
    if (_todayPrices.isEmpty) return null;

    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);

    try {
      return _todayPrices.firstWhere(
        (price) {
          final priceHour = DateTime(
            price.timestamp.year,
            price.timestamp.month,
            price.timestamp.day,
            price.timestamp.hour,
          );
          return priceHour == currentHour;
        },
      );
    } catch (e) {
      developer.log(
        'Current hour price not found',
        name: 'PriceProvider',
      );
      return null;
    }
  }

  /// Gets the price for a specific hour (0-23) from today's prices.
  ///
  /// [hour] - Hour of the day (0-23)
  /// Returns the price for that hour, or null if not available.
  ElectricityPrice? getPriceAtHour(int hour) {
    if (_todayPrices.isEmpty || hour < 0 || hour > 23) return null;

    try {
      return _todayPrices.firstWhere(
        (price) => price.timestamp.hour == hour,
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets the minimum (cheapest) price from a list of prices.
  ///
  /// [prices] - List of prices to search
  /// [includeVAT] - Whether to compare prices with VAT (default: true)
  /// Returns the cheapest price, or null if the list is empty.
  ElectricityPrice? getMinPrice(
    List<ElectricityPrice> prices, {
    bool includeVAT = true,
  }) {
    if (prices.isEmpty) return null;

    return prices.reduce((curr, next) =>
        curr.compareByPrice(next, includeVAT: includeVAT) <= 0 ? curr : next);
  }

  /// Gets the maximum (most expensive) price from a list of prices.
  ///
  /// [prices] - List of prices to search
  /// [includeVAT] - Whether to compare prices with VAT (default: true)
  /// Returns the most expensive price, or null if the list is empty.
  ElectricityPrice? getMaxPrice(
    List<ElectricityPrice> prices, {
    bool includeVAT = true,
  }) {
    if (prices.isEmpty) return null;

    return prices.reduce((curr, next) =>
        curr.compareByPrice(next, includeVAT: includeVAT) >= 0 ? curr : next);
  }

  /// Calculates the average price from a list of prices.
  ///
  /// [prices] - List of prices to calculate average from
  /// [includeVAT] - Whether to include VAT in calculation (default: true)
  /// Returns the average price in EUR/MWh, or 0.0 if the list is empty.
  double getAveragePrice(
    List<ElectricityPrice> prices, {
    bool includeVAT = true,
  }) {
    if (prices.isEmpty) return 0.0;

    final sum = prices.fold<double>(
      0.0,
      (sum, price) => sum + (includeVAT ? price.priceWithVAT : price.price),
    );

    return sum / prices.length;
  }

  /// Gets the average price formatted in EUR/kWh.
  ///
  /// [prices] - List of prices to calculate average from
  /// [includeVAT] - Whether to include VAT (default: true)
  /// [decimals] - Number of decimal places (default: 4)
  String getFormattedAveragePrice(
    List<ElectricityPrice> prices, {
    bool includeVAT = true,
    int decimals = 4,
  }) {
    final avg = getAveragePrice(prices, includeVAT: includeVAT);
    final avgInKWh = avg / 1000; // Convert EUR/MWh to EUR/kWh
    return avgInKWh.toStringAsFixed(decimals);
  }

  /// Gets the cheapest consecutive hours for a given duration.
  ///
  /// Useful for finding the best time to charge electric vehicles or
  /// run energy-intensive appliances.
  ///
  /// [prices] - List of prices to search
  /// [duration] - Number of consecutive hours needed
  /// [includeVAT] - Whether to consider prices with VAT (default: true)
  /// Returns a list of prices for the cheapest period, or null if not found.
  List<ElectricityPrice>? getCheapestConsecutiveHours(
    List<ElectricityPrice> prices, {
    required int duration,
    bool includeVAT = true,
  }) {
    if (duration <= 0 || duration > prices.length) return null;

    double minSum = double.infinity;
    int minIndex = 0;

    for (int i = 0; i <= prices.length - duration; i++) {
      final sum = prices
          .skip(i)
          .take(duration)
          .fold<double>(
            0.0,
            (sum, price) => sum + (includeVAT ? price.priceWithVAT : price.price),
          );

      if (sum < minSum) {
        minSum = sum;
        minIndex = i;
      }
    }

    return prices.skip(minIndex).take(duration).toList();
  }

  /// Gets today's minimum price.
  ElectricityPrice? get todayMinPrice => getMinPrice(_todayPrices);

  /// Gets today's maximum price.
  ElectricityPrice? get todayMaxPrice => getMaxPrice(_todayPrices);

  /// Gets today's average price.
  double get todayAveragePrice => getAveragePrice(_todayPrices);

  /// Gets tomorrow's minimum price (if available).
  ElectricityPrice? get tomorrowMinPrice =>
      _tomorrowPrices != null ? getMinPrice(_tomorrowPrices!) : null;

  /// Gets tomorrow's maximum price (if available).
  ElectricityPrice? get tomorrowMaxPrice =>
      _tomorrowPrices != null ? getMaxPrice(_tomorrowPrices!) : null;

  /// Gets tomorrow's average price (if available).
  double? get tomorrowAveragePrice =>
      _tomorrowPrices != null ? getAveragePrice(_tomorrowPrices!) : null;

  /// Clears all price data and resets state.
  void clear() {
    _todayPrices = [];
    _tomorrowPrices = null;
    _errorMessage = null;
    _lastUpdate = null;
    _isLoading = false;
    notifyListeners();
    developer.log('Cleared all price data', name: 'PriceProvider');
  }

  /// Sets the loading state and notifies listeners.
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Sets an error message and notifies listeners.
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
    developer.log('Error set: $error', name: 'PriceProvider');
  }

  /// Clears the error message.
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      // Don't notify here, as we'll notify when loading completes
    }
  }

  @override
  void dispose() {
    // Clean up if needed
    developer.log('PriceProvider disposed', name: 'PriceProvider');
    super.dispose();
  }
}
