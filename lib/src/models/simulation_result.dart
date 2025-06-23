class SimulationResult {
  final String id;
  final String setupId;
  final DateTime startDate;
  final DateTime endDate;
  final double initialBalance;
  final double finalBalance;
  final double netPnL;
  final double winRate;
  final double maxDrawdown;
  final int totalTrades;
  final int winningTrades;
  final List<Trade> trades;
  final List<double> equityCurve;

  SimulationResult({
    required this.id,
    required this.setupId,
    required this.startDate,
    required this.endDate,
    required this.initialBalance,
    required this.finalBalance,
    required this.netPnL,
    required this.winRate,
    required this.maxDrawdown,
    required this.totalTrades,
    required this.winningTrades,
    required this.trades,
    required this.equityCurve,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setupId': setupId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'initialBalance': initialBalance,
      'finalBalance': finalBalance,
      'netPnL': netPnL,
      'winRate': winRate,
      'maxDrawdown': maxDrawdown,
      'totalTrades': totalTrades,
      'winningTrades': winningTrades,
      'trades': trades.map((trade) => trade.toJson()).toList(),
      'equityCurve': equityCurve,
    };
  }

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      id: json['id'],
      setupId: json['setupId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      initialBalance: json['initialBalance'].toDouble(),
      finalBalance: json['finalBalance'].toDouble(),
      netPnL: json['netPnL'].toDouble(),
      winRate: json['winRate'].toDouble(),
      maxDrawdown: json['maxDrawdown'].toDouble(),
      totalTrades: json['totalTrades'],
      winningTrades: json['winningTrades'],
      trades: (json['trades'] as List).map((trade) => Trade.fromJson(trade)).toList(),
      equityCurve: (json['equityCurve'] as List<dynamic>).cast<double>(),
    );
  }
}

class Trade {
  final String id;
  final DateTime timestamp;
  final String type; // 'buy' or 'sell'
  final double price;
  final double quantity;
  double pnl;

  Trade({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.price,
    required this.quantity,
    this.pnl = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'price': price,
      'quantity': quantity,
      'pnl': pnl,
    };
  }

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
      price: json['price'].toDouble(),
      quantity: json['quantity'].toDouble(),
      pnl: json['pnl']?.toDouble() ?? 0.0,
    );
  }
} 