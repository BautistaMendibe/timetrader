import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/candle.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  Future<List<Candle>> loadHistorical(String asset, DateTime date) async {
    debugPrint('🔥 DataService: loadHistorical() - Asset: $asset, Date: $date');
    try {
      // For EUR/USD, use CSV minute data
      switch (asset.toUpperCase()) {
        case 'EUR/USD':
        case 'EURUSD':
          debugPrint('🔥 DataService: Loading EUR/USD from CSV minute data');
          return await loadMinuteCandles();
        case 'BTC/USD':
        case 'BTCUSD':
          debugPrint('🔥 DataService: Loading BTC/USD from JSON');
          final jsonFileName = 'assets/data/btc_usd_sample.json';
          final String jsonString = await rootBundle.loadString(jsonFileName);
          final List<dynamic> jsonData = json.decode(jsonString);
          final candles = jsonData
              .map((json) => Candle.fromJson(json))
              .toList();
          debugPrint(
            '🔥 DataService: Loaded ${candles.length} candles from JSON',
          );
          return candles;
        default:
          debugPrint(
            '🔥 DataService: Asset not recognized, using BTC/USD as fallback',
          );
          final jsonFileName = 'assets/data/btc_usd_sample.json';
          final String jsonString = await rootBundle.loadString(jsonFileName);
          final List<dynamic> jsonData = json.decode(jsonString);
          final candles = jsonData
              .map((json) => Candle.fromJson(json))
              .toList();
          return candles;
      }
    } catch (e) {
      debugPrint(
        '🔥 DataService: Error loading data, generating mock data: $e',
      );
      // Return mock data if file doesn't exist
      return _generateMockData(date, asset);
    }
  }

  Future<List<Candle>> loadMinuteCandles() async {
    debugPrint(
      '🔥 DataService: loadMinuteCandles() - Loading EUR/USD M1 data from CSV',
    );
    try {
      final raw = await rootBundle.loadString('assets/data/eur_usd_m1.csv');
      debugPrint('🔥 DataService: CSV file loaded, length: ${raw.length}');

      final rows = const CsvToListConverter().convert(raw, eol: '\n');
      debugPrint('🔥 DataService: CSV parsed, rows: ${rows.length}');

      // Debug: print first few rows to see structure
      for (int i = 0; i < (rows.length < 3 ? rows.length : 3); i++) {
        debugPrint('🔥 DataService: Row $i: ${rows[i]}');
      }

      // Skip header and map each row to Candle
      final candles = rows.skip(1).map((r) {
        try {
          // Parse custom timestamp format: "07.08.2025 06:00:00.000 UTC"
          final timestampStr = (r[0] as String).trim();
          final cleanTimestamp = timestampStr.replaceAll(' UTC', '');

          // Split into date and time parts
          final parts = cleanTimestamp.split(' ');
          if (parts.length != 2) {
            throw FormatException('Invalid timestamp format: $timestampStr');
          }

          final datePart = parts[0].split('.');
          final timePart = parts[1].split(':');

          if (datePart.length != 3 || timePart.length < 2) {
            throw FormatException('Invalid date/time format: $timestampStr');
          }

          final day = int.parse(datePart[0]);
          final month = int.parse(datePart[1]);
          final year = int.parse(datePart[2]);
          final hour = int.parse(timePart[0]);
          final minute = int.parse(timePart[1]);
          final second = timePart.length > 2
              ? int.parse(timePart[2].split('.')[0])
              : 0;

          final timestamp = DateTime.utc(
            year,
            month,
            day,
            hour,
            minute,
            second,
          );

          return Candle(
            timestamp: timestamp,
            open: (r[1] as num).toDouble(),
            high: (r[2] as num).toDouble(),
            low: (r[3] as num).toDouble(),
            close: (r[4] as num).toDouble(),
            volume: (r[5] as num).toDouble(),
          );
        } catch (e) {
          debugPrint('🔥 DataService: Error parsing row: $r, error: $e');
          rethrow;
        }
      }).toList();

      debugPrint(
        '🔥 DataService: Loaded ${candles.length} minute candles from CSV',
      );

      // Log first and last candle for verification
      if (candles.isNotEmpty) {
        debugPrint(
          '🔥 DataService: First candle: ${candles.first.timestamp} - ${candles.first.close}',
        );
        debugPrint(
          '🔥 DataService: Last candle: ${candles.last.timestamp} - ${candles.last.close}',
        );

        // Log time differences between first few candles to verify M1 intervals
        if (candles.length > 3) {
          for (int i = 1; i < 4; i++) {
            final diff = candles[i].timestamp.difference(
              candles[i - 1].timestamp,
            );
            debugPrint(
              '🔥 DataService: Candle $i time diff: ${diff.inMinutes} minutes, ${diff.inSeconds} seconds',
            );
          }
        }
      }

      return candles;
    } catch (e) {
      debugPrint('🔥 DataService: Error loading CSV: $e');
      rethrow;
    }
  }

  List<Candle> _generateMockData([DateTime? startDate, String? asset]) {
    debugPrint('DataService: Generando datos de prueba para asset: $asset');
    final List<Candle> mockData = [];
    final DateTime baseDate =
        startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final Random random = Random(42); // Fixed seed for consistent data

    // Set initial price based on asset type
    double price;
    double volatility;

    if (asset != null &&
        (asset.toUpperCase().contains('EUR') ||
            asset.toUpperCase().contains('GBP') ||
            asset.toUpperCase().contains('AUD') ||
            asset.toUpperCase().contains('NZD'))) {
      price = 1.0850; // Typical forex price
      volatility = 0.001; // 0.1% volatility for forex
      debugPrint(
        'DataService: Generando datos de forex con precio inicial: $price',
      );
    } else {
      price = 50000.0; // Default crypto price
      volatility = 0.02; // 2% volatility for crypto
      debugPrint(
        'DataService: Generando datos de crypto con precio inicial: $price',
      );
    }

    for (int i = 0; i < 200; i++) {
      // Generate 200 candles
      final timestamp = baseDate.add(Duration(hours: i));

      // Generate realistic price movement
      final change = price * volatility * (random.nextDouble() - 0.5);
      final open = price;
      final close = price + change;

      // Generate high and low based on open/close
      final range = (close - open).abs() * (1.5 + random.nextDouble());
      final high = open > close
          ? open + range * random.nextDouble()
          : close + range * random.nextDouble();
      final low = open > close
          ? close - range * random.nextDouble()
          : open - range * random.nextDouble();

      // Generate volume
      final volume = 1000.0 + (random.nextDouble() * 2000.0);

      mockData.add(
        Candle(
          timestamp: timestamp,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ),
      );

      price = close;

      // Add some trend
      if (i % 20 == 0) {
        volatility = 0.01 + (random.nextDouble() * 0.03); // Vary volatility
      }
    }

    debugPrint('DataService: Generados ${mockData.length} velas de prueba');
    return mockData;
  }

  List<String> getAvailableAssets() {
    return ['BTC/USD', 'EUR/USD', 'S&P500'];
  }

  List<DateTime> getAvailableDates() {
    final List<DateTime> dates = [];
    // Use a fixed reference date to ensure consistency
    final DateTime referenceDate = DateTime(2024, 1, 1);

    for (int i = 0; i < 12; i++) {
      dates.add(referenceDate.subtract(Duration(days: i * 30)));
    }

    return dates;
  }
}
