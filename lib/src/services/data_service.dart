import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/candle.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  Future<List<Candle>> loadHistorical(String asset, DateTime date) async {
    try {
      // Load sample data from assets
      final String jsonString = await rootBundle.loadString('assets/data/btc_usd_sample.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      
      return jsonData.map((json) => Candle.fromJson(json)).toList();
    } catch (e) {
      // Return mock data if file doesn't exist
      return _generateMockData();
    }
  }

  List<Candle> _generateMockData() {
    final List<Candle> mockData = [];
    final DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    
    double price = 50000.0;
    
    for (int i = 0; i < 100; i++) {
      final timestamp = startDate.add(Duration(hours: i));
      final change = (price * 0.02) * (0.5 - (i % 3) * 0.3);
      final open = price;
      final close = price + change;
      final high = open + (change * 1.5).abs();
      final low = open - (change * 1.5).abs();
      
      mockData.add(Candle(
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 1000.0 + (i * 10),
      ));
      
      price = close;
    }
    
    return mockData;
  }

  List<String> getAvailableAssets() {
    return ['BTC/USD', 'EUR/USD', 'S&P500'];
  }

  List<DateTime> getAvailableDates() {
    final List<DateTime> dates = [];
    final DateTime now = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      dates.add(now.subtract(Duration(days: i * 30)));
    }
    
    return dates;
  }
} 