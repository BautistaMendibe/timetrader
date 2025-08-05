import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/candle.dart';
import '../models/tick.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  Future<List<Candle>> loadHistorical(String asset, DateTime date) async {
    debugPrint('🔥 DataService: loadHistorical() - Asset: $asset, Date: $date');
    try {
      // Determine which JSON file to load based on the asset
      String jsonFileName;
      switch (asset.toUpperCase()) {
        case 'EUR/USD':
        case 'EURUSD':
          jsonFileName = 'assets/data/eurusd_sample.json';
          debugPrint('🔥 DataService: Cargando datos de EUR/USD');
          break;
        case 'BTC/USD':
        case 'BTCUSD':
          jsonFileName = 'assets/data/btc_usd_sample.json';
          debugPrint('🔥 DataService: Cargando datos de BTC/USD');
          break;
        default:
          jsonFileName = 'assets/data/btc_usd_sample.json'; // Default fallback
          debugPrint(
            '🔥 DataService: Asset no reconocido, usando BTC/USD como fallback',
          );
      }

      // Try to load sample data from assets
      debugPrint(
        '🔥 DataService: Intentando cargar archivo JSON: $jsonFileName',
      );
      final String jsonString = await rootBundle.loadString(jsonFileName);
      debugPrint(
        '🔥 DataService: Archivo JSON cargado, longitud: ${jsonString.length}',
      );

      final List<dynamic> jsonData = json.decode(jsonString);
      debugPrint(
        '🔥 DataService: JSON decodificado, elementos: ${jsonData.length}',
      );

      final candles = jsonData.map((json) => Candle.fromJson(json)).toList();
      debugPrint(
        '🔥 DataService: Cargados ${candles.length} velas desde archivo JSON',
      );

      // Log first and last candle for verification
      if (candles.isNotEmpty) {
        debugPrint(
          '🔥 DataService: Primera vela: ${candles.first.timestamp} - ${candles.first.close}',
        );
        debugPrint(
          '🔥 DataService: Última vela: ${candles.last.timestamp} - ${candles.last.close}',
        );
      }

      return candles;
    } catch (e) {
      debugPrint(
        '🔥 DataService: Error cargando JSON, generando datos de prueba: $e',
      );
      // Return mock data if file doesn't exist
      return _generateMockData(date, asset);
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

  Future<List<Tick>> loadTicksFromCsv() async {
    debugPrint(
      '🔥 DataService: loadTicksFromCsv() - Iniciando carga de ticks desde CSV',
    );
    try {
      // Load CSV file from assets
      final String csvString = await rootBundle.loadString(
        'assets/data/ticks.csv',
      );
      debugPrint('🔥 DataService: CSV cargado, longitud: ${csvString.length}');

      // Split lines and ignore header
      final List<String> lines = csvString.split('\n');
      debugPrint('🔥 DataService: Total de líneas en CSV: ${lines.length}');

      // Remove header and empty lines
      final List<String> dataLines = lines
          .where((line) => line.trim().isNotEmpty)
          .skip(1) // Skip header
          .toList();

      debugPrint(
        '🔥 DataService: Líneas de datos (sin header): ${dataLines.length}',
      );

      final List<Tick> ticks = [];
      final DateFormat dateFormat = DateFormat(
        "dd.MM.yyyy HH:mm:ss.SSS 'GMT'Z",
      );

      // Fallback patterns in case the CSV format is different
      final List<DateFormat> fallbackFormats = [
        DateFormat("dd.MM.yyyy HH:mm:ss.SSS"),
        DateFormat("yyyy-MM-dd HH:mm:ss.SSS"),
        DateFormat("dd/MM/yyyy HH:mm:ss"),
        DateFormat("yyyy/MM/dd HH:mm:ss"),
      ];

      for (String line in dataLines) {
        try {
          final List<String> columns = line.split(',');
          if (columns.length >= 3) {
            // Ensure we have at least timestamp, bid, ask
            // Parse timestamp from first column
            final String timestampStr = columns[0].trim();

            // Debug the timestamp string
            debugPrint('🔥 DataService: Parseando timestamp: "$timestampStr"');

            DateTime? time;
            try {
              time = dateFormat.parse(timestampStr);
            } catch (e) {
              // Try fallback formats
              for (DateFormat fallbackFormat in fallbackFormats) {
                try {
                  time = fallbackFormat.parse(timestampStr);
                  debugPrint(
                    '🔥 DataService: Usando formato fallback: ${fallbackFormat.pattern}',
                  );
                  break;
                } catch (e2) {
                  // Continue to next format
                }
              }
            }

            if (time == null) {
              debugPrint(
                '🔥 DataService: No se pudo parsear timestamp: "$timestampStr"',
              );
              continue; // Skip this line
            }

            // Parse bid and ask prices
            final double bid = double.parse(columns[1].trim());
            final double ask = double.parse(columns[2].trim());

            // Use mid price (bid + ask) / 2
            final double price = (bid + ask) / 2;

            ticks.add(Tick(time: time!, price: price));
          }
        } catch (e) {
          debugPrint('🔥 DataService: Error parseando línea: "$line" - $e');
          // Continue with next line
        }
      }

      debugPrint(
        '🔥 DataService: Ticks parseados exitosamente: ${ticks.length}',
      );

      // Log first and last tick for verification
      if (ticks.isNotEmpty) {
        debugPrint(
          '🔥 DataService: Primer tick: ${ticks.first.time} - ${ticks.first.price}',
        );
        debugPrint(
          '🔥 DataService: Último tick: ${ticks.last.time} - ${ticks.last.price}',
        );
      }

      return ticks;
    } catch (e) {
      debugPrint('🔥 DataService: Error cargando ticks desde CSV: $e');
      return [];
    }
  }
}
