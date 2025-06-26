import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/candle.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  Future<List<Candle>> loadHistorical(String asset, DateTime date) async {
    debugPrint('🔥 DataService: loadHistorical() - Asset: $asset, Date: $date');
    try {
      // Try to load sample data from assets
      debugPrint('🔥 DataService: Intentando cargar archivo JSON...');
      final String jsonString = await rootBundle.loadString('assets/data/btc_usd_sample.json');
      debugPrint('🔥 DataService: Archivo JSON cargado, longitud: ${jsonString.length}');
      
      final List<dynamic> jsonData = json.decode(jsonString);
      debugPrint('🔥 DataService: JSON decodificado, elementos: ${jsonData.length}');
      
      final candles = jsonData.map((json) => Candle.fromJson(json)).toList();
      debugPrint('🔥 DataService: Cargados ${candles.length} velas desde archivo JSON');
      
      // Log first and last candle for verification
      if (candles.isNotEmpty) {
        debugPrint('🔥 DataService: Primera vela: ${candles.first.timestamp} - ${candles.first.close}');
        debugPrint('🔥 DataService: Última vela: ${candles.last.timestamp} - ${candles.last.close}');
      }
      
      return candles;
    } catch (e) {
      debugPrint('🔥 DataService: Error cargando JSON, generando datos de prueba: $e');
      // Return mock data if file doesn't exist
      return _generateMockData(date);
    }
  }

  List<Candle> _generateMockData([DateTime? startDate]) {
    debugPrint('DataService: Generando datos de prueba');
    final List<Candle> mockData = [];
    final DateTime baseDate = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final Random random = Random(42); // Fixed seed for consistent data
    
    double price = 50000.0;
    double volatility = 0.02; // 2% volatility
    
    for (int i = 0; i < 200; i++) { // Generate 200 candles
      final timestamp = baseDate.add(Duration(hours: i));
      
      // Generate realistic price movement
      final change = price * volatility * (random.nextDouble() - 0.5);
      final open = price;
      final close = price + change;
      
      // Generate high and low based on open/close
      final range = (close - open).abs() * (1.5 + random.nextDouble());
      final high = open > close ? open + range * random.nextDouble() : close + range * random.nextDouble();
      final low = open > close ? close - range * random.nextDouble() : open - range * random.nextDouble();
      
      // Generate volume
      final volume = 1000.0 + (random.nextDouble() * 2000.0);
      
      mockData.add(Candle(
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));
      
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