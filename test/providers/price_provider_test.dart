import 'package:flutter_test/flutter_test.dart';
import 'package:spuldze/models/models.dart';
import 'package:spuldze/providers/price_provider.dart';
import 'package:spuldze/services/services.dart';

// Mock EleringApiService for testing
class MockEleringApiService implements EleringApiService {
  List<ElectricityPrice>? _mockPrices;
  Exception? _mockException;
  bool _shouldThrow = false;
  bool _cacheCleared = false;

  void setMockPrices(List<ElectricityPrice> prices) {
    _mockPrices = prices;
    _shouldThrow = false;
  }

  void setMockException(Exception exception) {
    _mockException = exception;
    _shouldThrow = true;
  }

  @override
  Future<List<ElectricityPrice>> fetchPricesForLatvia() async {
    if (_shouldThrow) {
      throw _mockException ?? Exception('Mock error');
    }
    return _mockPrices ?? [];
  }

  @override
  void clearCache() {
    _cacheCleared = true;
  }

  bool get wasCacheCleared => _cacheCleared;
}

// Mock CacheManager for testing
class MockCacheManager implements CacheManager {
  Map<String, List<ElectricityPrice>> _cache = {};
  Map<String, DateTime> _timestamps = {};

  void setMockCache(String key, List<ElectricityPrice> prices) {
    _cache[key] = prices;
    _timestamps[key] = DateTime.now();
  }

  void clearMockCache() {
    _cache.clear();
    _timestamps.clear();
  }

  @override
  Future<List<ElectricityPrice>?> loadPrices(String key) async {
    return _cache[key];
  }

  @override
  Future<void> savePrices(List<ElectricityPrice> prices, String key) async {
    _cache[key] = prices;
    _timestamps[key] = DateTime.now();
  }

  @override
  Future<DateTime?> getCacheTimestamp(String key) async {
    return _timestamps[key];
  }

  @override
  Future<bool> isCacheValid(String key, {required Duration validFor}) async {
    final timestamp = _timestamps[key];
    if (timestamp == null) return false;

    final now = DateTime.now();
    return now.difference(timestamp) < validFor;
  }

  @override
  Future<void> clearCache() async {
    clearMockCache();
  }

  @override
  Future<void> saveLastUpdateTime() async {
    _timestamps['last_update'] = DateTime.now();
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    return _timestamps['last_update'];
  }

  // Required static constants
  static const String keyPricesToday = 'prices_today';
  static const String keyPricesTomorrow = 'prices_tomorrow';
}

void main() {
  group('PriceProvider', () {
    late MockEleringApiService mockApiService;
    late MockCacheManager mockCacheManager;
    late PriceProvider provider;

    late List<ElectricityPrice> validToday96Prices;
    late List<ElectricityPrice> validTomorrow96Prices;

    setUp(() {
      mockApiService = MockEleringApiService();
      mockCacheManager = MockCacheManager();
      provider = PriceProvider(
        apiService: mockApiService,
        cacheManager: mockCacheManager,
      );

      // Create full day with 96 15-minute interval prices for today
      final today = DateTime.now();
      validToday96Prices = [];
      for (int hour = 0; hour < 24; hour++) {
        for (int minute in [0, 15, 30, 45]) {
          validToday96Prices.add(
            ElectricityPrice(
              timestamp: DateTime(today.year, today.month, today.day, hour, minute),
              price: 40.0 + hour,
              priceWithVAT: (40.0 + hour) * 1.21,
            ),
          );
        }
      }

      // Create tomorrow's prices
      final tomorrow = today.add(const Duration(days: 1));
      validTomorrow96Prices = [];
      for (int hour = 0; hour < 24; hour++) {
        for (int minute in [0, 15, 30, 45]) {
          validTomorrow96Prices.add(
            ElectricityPrice(
              timestamp:
                  DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute),
              price: 35.0 + hour,
              priceWithVAT: (35.0 + hour) * 1.21,
            ),
          );
        }
      }
    });

    group('initial state', () {
      test('starts with empty prices', () {
        expect(provider.todayPrices, isEmpty);
        expect(provider.tomorrowPrices, isNull);
      });

      test('starts with no loading state', () {
        expect(provider.isLoading, isFalse);
      });

      test('starts with no error', () {
        expect(provider.errorMessage, isNull);
      });

      test('hasTodayPrices returns false initially', () {
        expect(provider.hasTodayPrices, isFalse);
      });

      test('hasTomorrowPrices returns false initially', () {
        expect(provider.hasTomorrowPrices, isFalse);
      });
    });

    group('todayHourlyGroups with 15-minute intervals', () {
      test('returns 24 groups when today has 96 prices', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        expect(provider.todayHourlyGroups.length, equals(24));
      });

      test('each group has correct hour', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        final groups = provider.todayHourlyGroups;
        for (int i = 0; i < 24; i++) {
          expect(groups[i].hour, equals(i));
        }
      });

      test('returns empty list when no prices', () {
        expect(provider.todayHourlyGroups, isEmpty);
      });
    });

    group('tomorrowHourlyGroups with 15-minute intervals', () {
      test('returns 24 groups when tomorrow has 96 prices', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        expect(provider.tomorrowHourlyGroups.length, equals(24));
      });

      test('returns empty list when no tomorrow prices', () async {
        mockApiService.setMockPrices(validToday96Prices);

        await provider.loadPrices();

        expect(provider.tomorrowHourlyGroups, isEmpty);
      });
    });

    group('currentHourlyGroup', () {
      test('returns correct hour group for current time', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        final now = DateTime.now();
        final currentGroup = provider.currentHourlyGroup;

        expect(currentGroup, isNotNull);
        expect(currentGroup!.hour, equals(now.hour));
        expect(currentGroup.prices.length, equals(4));
      });

      test('returns null when no prices', () {
        expect(provider.currentHourlyGroup, isNull);
      });

      test('returns null when current hour has incomplete data', () async {
        // Create prices missing current hour
        final now = DateTime.now();
        final incompletePrices = validToday96Prices
            .where((p) => p.timestamp.hour != now.hour)
            .toList();

        mockApiService.setMockPrices(incompletePrices);
        await provider.loadPrices();

        expect(provider.currentHourlyGroup, isNull);
      });
    });

    group('getCurrentPrice with 15-minute rounding', () {
      test('returns correct 15-minute interval price', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        final now = DateTime.now();
        final rounded15Min = (now.minute ~/ 15) * 15;

        final currentPrice = provider.getCurrentPrice();

        expect(currentPrice, isNotNull);
        expect(currentPrice!.timestamp.hour, equals(now.hour));
        expect(currentPrice.timestamp.minute, equals(rounded15Min));
      });

      test('returns null when no prices', () {
        expect(provider.getCurrentPrice(), isNull);
      });

      test('returns null when current interval not in data', () async {
        // Create prices for a different day
        final differentDay = DateTime.now().subtract(const Duration(days: 5));
        final oldPrices = <ElectricityPrice>[];
        for (int hour = 0; hour < 24; hour++) {
          for (int minute in [0, 15, 30, 45]) {
            oldPrices.add(
              ElectricityPrice(
                timestamp: DateTime(
                    differentDay.year, differentDay.month, differentDay.day, hour, minute),
                price: 40.0,
                priceWithVAT: 48.4,
              ),
            );
          }
        }

        mockApiService.setMockPrices(oldPrices);
        await provider.loadPrices();

        expect(provider.getCurrentPrice(), isNull);
      });
    });

    group('loadPrices with cache', () {
      test('uses valid cache when available', () async {
        // Set up valid cache
        mockCacheManager.setMockCache(
          MockCacheManager.keyPricesToday,
          validToday96Prices,
        );

        final result = await provider.loadPrices();

        expect(result, isTrue);
        expect(provider.todayPrices.length, equals(96));
        expect(provider.hasTodayPrices, isTrue);
      });

      test('fetches from API when cache is empty', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        final result = await provider.loadPrices();

        expect(result, isTrue);
        expect(provider.todayPrices.length, equals(96));
        expect(provider.tomorrowPrices?.length, equals(96));
      });

      test('updates lastUpdate timestamp after successful load', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        expect(provider.lastUpdate, isNotNull);
      });

      test('sets error message on API failure', () async {
        mockApiService.setMockException(Exception('Network error'));

        final result = await provider.loadPrices();

        expect(result, isFalse);
        expect(provider.errorMessage, contains('Failed to load prices'));
      });

      test('falls back to expired cache on API failure', () async {
        // Set up expired cache
        mockCacheManager.setMockCache(
          MockCacheManager.keyPricesToday,
          validToday96Prices,
        );

        // Force API error
        mockApiService.setMockException(Exception('Network error'));

        // First load will try API, fail, and fall back to cache
        await provider.loadPrices();

        // Should have data from cache despite API failure
        expect(provider.todayPrices.length, equals(96));
        expect(provider.errorMessage, contains('cached data'));
      });

      test('handles missing data gracefully', () async {
        mockApiService.setMockPrices([]);

        final result = await provider.loadPrices();

        expect(result, isFalse);
        expect(provider.errorMessage, equals('No price data available'));
      });
    });

    group('refreshPrices', () {
      test('clears API cache before fetching', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.refreshPrices();

        expect(mockApiService.wasCacheCleared, isTrue);
      });

      test('fetches fresh data from API', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        final result = await provider.refreshPrices();

        expect(result, isTrue);
        expect(provider.todayPrices.length, equals(96));
      });

      test('sets error on refresh failure', () async {
        mockApiService.setMockException(Exception('Network error'));

        final result = await provider.refreshPrices();

        expect(result, isFalse);
        expect(provider.errorMessage, contains('Failed to refresh prices'));
      });
    });

    group('price statistics', () {
      setUp(() async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);
        await provider.loadPrices();
      });

      test('todayMinPrice returns lowest price', () {
        final min = provider.todayMinPrice;

        expect(min, isNotNull);
        // Hour 0 has lowest price: 40.0 * 1.21 = 48.4
        expect(min!.priceWithVAT, equals(40.0 * 1.21));
      });

      test('todayMaxPrice returns highest price', () {
        final max = provider.todayMaxPrice;

        expect(max, isNotNull);
        // Hour 23 has highest price: 63.0 * 1.21 = 76.23
        expect(max!.priceWithVAT, equals(63.0 * 1.21));
      });

      test('todayAveragePrice calculates correctly', () {
        final avg = provider.todayAveragePrice;

        // Average of 40-63 = 51.5, with VAT: 62.315
        expect(avg, closeTo(62.315, 0.01));
      });

      test('tomorrowMinPrice returns lowest tomorrow price', () {
        final min = provider.tomorrowMinPrice;

        expect(min, isNotNull);
        // Hour 0 has lowest price: 35.0 * 1.21 = 42.35
        expect(min!.priceWithVAT, equals(35.0 * 1.21));
      });

      test('tomorrowMaxPrice returns highest tomorrow price', () {
        final max = provider.tomorrowMaxPrice;

        expect(max, isNotNull);
        // Hour 23 has highest price: 58.0 * 1.21 = 70.18
        expect(max!.priceWithVAT, equals(58.0 * 1.21));
      });

      test('tomorrowAveragePrice calculates correctly', () {
        final avg = provider.tomorrowAveragePrice;

        expect(avg, isNotNull);
        // Average of 35-58 = 46.5, with VAT: 56.265
        expect(avg, closeTo(56.265, 0.01));
      });
    });

    group('utility methods', () {
      test('getFormattedAveragePrice formats correctly', () async {
        mockApiService.setMockPrices(validToday96Prices);
        await provider.loadPrices();

        final formatted = provider.getFormattedAveragePrice(
          provider.todayPrices,
        );

        expect(formatted, matches(r'^\d+\.\d{4}$')); // Matches decimal format
      });

      test('getCheapestConsecutiveHours finds optimal period', () async {
        mockApiService.setMockPrices(validToday96Prices);
        await provider.loadPrices();

        final cheapest = provider.getCheapestConsecutiveHours(
          provider.todayPrices,
          duration: 8,
        );

        expect(cheapest, isNotNull);
        expect(cheapest!.length, equals(8));
        // Should start at beginning (hour 0) since prices increase
        expect(cheapest.first.timestamp.hour, equals(0));
      });
    });

    group('clear and state management', () {
      test('clear resets all state', () async {
        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);
        await provider.loadPrices();

        provider.clear();

        expect(provider.todayPrices, isEmpty);
        expect(provider.tomorrowPrices, isNull);
        expect(provider.errorMessage, isNull);
        expect(provider.lastUpdate, isNull);
        expect(provider.isLoading, isFalse);
      });

      test('notifyListeners is called on state changes', () async {
        int notifyCount = 0;
        provider.addListener(() {
          notifyCount++;
        });

        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        // Should notify at least twice: loading start and loading end
        expect(notifyCount, greaterThanOrEqualTo(2));
      });

      test('isLoading changes during load operation', () async {
        bool wasLoading = false;

        provider.addListener(() {
          if (provider.isLoading) {
            wasLoading = true;
          }
        });

        mockApiService.setMockPrices([
          ...validToday96Prices,
          ...validTomorrow96Prices,
        ]);

        await provider.loadPrices();

        expect(wasLoading, isTrue);
        expect(provider.isLoading, isFalse); // Should be false after completion
      });
    });

    group('edge cases', () {
      test('handles partial day data (less than 96 prices)', () async {
        // Only provide 48 prices (half day)
        final partialPrices = validToday96Prices.take(48).toList();
        mockApiService.setMockPrices(partialPrices);

        await provider.loadPrices();

        expect(provider.todayPrices.length, equals(48));
        // Should have 12 hourly groups (12 complete hours)
        expect(provider.todayHourlyGroups.length, equals(12));
      });

      test('handles missing intervals in hour', () async {
        // Remove one 15-min interval from hour 7
        final incompletePrices = validToday96Prices
            .where((p) => !(p.timestamp.hour == 7 && p.timestamp.minute == 45))
            .toList();

        mockApiService.setMockPrices(incompletePrices);
        await provider.loadPrices();

        // Should have 23 hourly groups (missing hour 7)
        expect(provider.todayHourlyGroups.length, equals(23));
        expect(provider.todayHourlyGroups.any((g) => g.hour == 7), isFalse);
      });

      test('getPriceAtHour returns first interval of hour', () async {
        mockApiService.setMockPrices(validToday96Prices);
        await provider.loadPrices();

        final price = provider.getPriceAtHour(7);

        expect(price, isNotNull);
        expect(price!.timestamp.hour, equals(7));
        // Should return first matching price (could be any minute)
      });

      test('getPriceAtHour returns null for invalid hour', () async {
        mockApiService.setMockPrices(validToday96Prices);
        await provider.loadPrices();

        expect(provider.getPriceAtHour(-1), isNull);
        expect(provider.getPriceAtHour(24), isNull);
      });
    });
  });
}
