import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Service for fetching electricity price data from the Elering API.
///
/// The Elering API provides Nord Pool spot prices for Baltic countries.
/// This service specifically fetches data for Latvia.
class EleringApiService {
  /// Base URL for the Elering API
  static const String baseUrl = 'https://dashboard.elering.ee/api/nps/price';

  /// VAT rate for Latvia (21%)
  static const double latviaVatRate = 1.21;

  /// Conversion factor from EUR/MWh to EUR/kWh
  static const double mwhToKwhConversion = 1000.0;

  /// Timeout duration for API calls
  static const Duration apiTimeout = Duration(seconds: 10);

  /// Maximum number of retry attempts
  static const int maxRetries = 3;

  /// Initial delay for exponential backoff (in milliseconds)
  static const int initialBackoffMs = 500;

  /// Cache duration (1 hour)
  static const Duration cacheDuration = Duration(hours: 1);

  // Cache storage
  List<ElectricityPrice>? _cachedPrices;
  DateTime? _cacheTimestamp;

  /// HTTP client instance (can be injected for testing)
  final http.Client _client;

  /// Creates an instance of [EleringApiService].
  ///
  /// [client] - Optional HTTP client for dependency injection (useful for testing)
  EleringApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches current electricity prices for Latvia.
  ///
  /// Makes a GET request to the Elering API and returns a list of hourly
  /// electricity prices. The response is cached for 1 hour to avoid
  /// excessive API calls.
  ///
  /// Returns a [Future] that completes with a list of [ElectricityPrice] objects.
  ///
  /// Throws [EleringApiException] if the request fails after all retry attempts.
  ///
  /// Example:
  /// ```dart
  /// final service = EleringApiService();
  /// try {
  ///   final prices = await service.fetchPricesForLatvia();
  ///   print('Fetched ${prices.length} price points');
  /// } catch (e) {
  ///   print('Error fetching prices: $e');
  /// }
  /// ```
  Future<List<ElectricityPrice>> fetchPricesForLatvia() async {
    // Check cache first
    if (_isCacheValid()) {
      developer.log(
        'Returning cached prices',
        name: 'EleringApiService',
      );
      return _cachedPrices!;
    }

    developer.log(
      'Fetching fresh prices from API',
      name: 'EleringApiService',
    );

    // Fetch from API with retry logic
    final prices = await _fetchWithRetry();

    // Update cache
    _cachedPrices = prices;
    _cacheTimestamp = DateTime.now();

    return prices;
  }

  /// Checks if the cached data is still valid.
  bool _isCacheValid() {
    if (_cachedPrices == null || _cacheTimestamp == null) {
      return false;
    }

    final now = DateTime.now();
    final cacheAge = now.difference(_cacheTimestamp!);

    return cacheAge < cacheDuration;
  }

  /// Fetches prices with retry logic and exponential backoff.
  Future<List<ElectricityPrice>> _fetchWithRetry() async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        return await _fetchPrices();
      } on TimeoutException catch (e) {
        lastException = e;
        developer.log(
          'Timeout on attempt ${attempt + 1}/$maxRetries',
          name: 'EleringApiService',
          error: e,
        );
      } on http.ClientException catch (e) {
        lastException = e;
        developer.log(
          'Network error on attempt ${attempt + 1}/$maxRetries',
          name: 'EleringApiService',
          error: e,
        );
      } on FormatException catch (e) {
        lastException = e;
        developer.log(
          'Parse error on attempt ${attempt + 1}/$maxRetries',
          name: 'EleringApiService',
          error: e,
        );
        // Don't retry on parse errors - they won't fix themselves
        break;
      } on EleringApiException catch (e) {
        lastException = e;
        developer.log(
          'API error on attempt ${attempt + 1}/$maxRetries: ${e.message}',
          name: 'EleringApiService',
          error: e,
        );
        // Don't retry on client errors (4xx)
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          break;
        }
      } catch (e) {
        lastException = Exception('Unexpected error: $e');
        developer.log(
          'Unexpected error on attempt ${attempt + 1}/$maxRetries',
          name: 'EleringApiService',
          error: e,
        );
      }

      attempt++;

      // Wait before retrying (exponential backoff)
      if (attempt < maxRetries) {
        final delayMs = initialBackoffMs * (1 << attempt); // 500ms, 1s, 2s
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    // All retries failed
    throw EleringApiException(
      'Failed to fetch prices after $maxRetries attempts',
      originalError: lastException,
    );
  }

  /// Makes the actual HTTP request to fetch prices.
  Future<List<ElectricityPrice>> _fetchPrices() async {
    // Note: Using /lv for Latvia (LV is the ISO country code for Latvia)
    // If the API uses different endpoints, this may need adjustment
    final uri = Uri.parse('$baseUrl/lv/current');

    developer.log(
      'Making request to: $uri',
      name: 'EleringApiService',
    );

    final response = await _client
        .get(uri)
        .timeout(apiTimeout);

    developer.log(
      'Response status: ${response.statusCode}',
      name: 'EleringApiService',
    );

    if (response.statusCode != 200) {
      throw EleringApiException(
        'API request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    // Parse JSON response
    final Map<String, dynamic> jsonData;
    try {
      jsonData = json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw EleringApiException(
        'Failed to parse JSON response',
        originalError: e,
        responseBody: response.body,
      );
    }

    // Extract price data
    if (!jsonData.containsKey('data')) {
      throw EleringApiException(
        'Response missing "data" field',
        responseBody: response.body,
      );
    }

    final data = jsonData['data'];
    if (data is! Map<String, dynamic>) {
      throw EleringApiException(
        'Invalid data format: expected Map, got ${data.runtimeType}',
        responseBody: response.body,
      );
    }

    // The Elering API typically returns data in a 'lv' or 'ee' field
    // Adjust this based on actual API response structure
    final priceData = data['lv'] ?? data['ee'] ?? data;

    if (priceData is! List) {
      throw EleringApiException(
        'Invalid price data format: expected List, got ${priceData.runtimeType}',
        responseBody: response.body,
      );
    }

    // Parse each price entry
    final List<ElectricityPrice> prices = [];
    for (final item in priceData) {
      try {
        if (item is! Map<String, dynamic>) {
          developer.log(
            'Skipping invalid price item: $item',
            name: 'EleringApiService',
          );
          continue;
        }
        prices.add(ElectricityPrice.fromJson(item));
      } catch (e) {
        developer.log(
          'Error parsing price item: $e',
          name: 'EleringApiService',
          error: e,
        );
        // Continue parsing other items
      }
    }

    if (prices.isEmpty) {
      throw EleringApiException(
        'No valid price data found in response',
        responseBody: response.body,
      );
    }

    // Sort prices chronologically
    prices.sort();

    developer.log(
      'Successfully parsed ${prices.length} price entries',
      name: 'EleringApiService',
    );

    return prices;
  }

  /// Clears the cached data, forcing a fresh fetch on the next request.
  void clearCache() {
    _cachedPrices = null;
    _cacheTimestamp = null;
    developer.log(
      'Cache cleared',
      name: 'EleringApiService',
    );
  }

  /// Returns whether there is valid cached data available.
  bool get hasCachedData => _isCacheValid();

  /// Returns the age of the cached data, or null if no cache exists.
  Duration? get cacheAge {
    if (_cacheTimestamp == null) return null;
    return DateTime.now().difference(_cacheTimestamp!);
  }

  /// Disposes of resources used by this service.
  void dispose() {
    _client.close();
  }
}

/// Exception thrown when the Elering API request fails.
class EleringApiException implements Exception {
  /// Human-readable error message
  final String message;

  /// HTTP status code (if applicable)
  final int? statusCode;

  /// Original exception that caused this error
  final dynamic originalError;

  /// Response body from the failed request
  final String? responseBody;

  /// Creates an [EleringApiException].
  EleringApiException(
    this.message, {
    this.statusCode,
    this.originalError,
    this.responseBody,
  });

  @override
  String toString() {
    final buffer = StringBuffer('EleringApiException: $message');

    if (statusCode != null) {
      buffer.write(' (HTTP $statusCode)');
    }

    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }

    if (responseBody != null && responseBody!.isNotEmpty) {
      final truncatedBody = responseBody!.length > 200
          ? '${responseBody!.substring(0, 200)}...'
          : responseBody;
      buffer.write('\nResponse: $truncatedBody');
    }

    return buffer.toString();
  }
}
