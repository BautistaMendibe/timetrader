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
  final int candleIndex; // Índice de la vela donde se ejecutó el trade
  final String? reason; // Razón por la que se ejecutó el trade
  final double? amount; // Monto de la operación
  final int? leverage; // Apalancamiento
  double pnl;
  final String? tradeGroupId; // ID para agrupar trades relacionados (entrada/salida)

  Trade({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.price,
    required this.quantity,
    required this.candleIndex,
    this.reason,
    this.amount,
    this.leverage,
    this.pnl = 0.0,
    this.tradeGroupId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'price': price,
      'quantity': quantity,
      'candleIndex': candleIndex,
      'reason': reason,
      'amount': amount,
      'leverage': leverage,
      'pnl': pnl,
      'tradeGroupId': tradeGroupId,
    };
  }

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
      price: json['price'].toDouble(),
      quantity: json['quantity'].toDouble(),
      candleIndex: json['candleIndex'] ?? 0,
      reason: json['reason'],
      amount: json['amount']?.toDouble(),
      leverage: json['leverage'],
      pnl: json['pnl']?.toDouble() ?? 0.0,
      tradeGroupId: json['tradeGroupId'],
    );
  }
}

// Nueva clase para representar una operación completa
class CompletedTrade {
  final String id;
  final Trade entryTrade; // Trade de entrada (compra o venta)
  final Trade exitTrade;  // Trade de salida (venta o compra)
  final double totalPnL;  // P&L total de la operación
  final DateTime entryTime;
  final DateTime exitTime;
  final double entryPrice;
  final double exitPrice;
  final double quantity;
  final int? leverage;
  final String? reason;

  CompletedTrade({
    required this.id,
    required this.entryTrade,
    required this.exitTrade,
    required this.totalPnL,
    required this.entryTime,
    required this.exitTime,
    required this.entryPrice,
    required this.exitPrice,
    required this.quantity,
    this.leverage,
    this.reason,
  });

  // Método de conveniencia para obtener el tipo de operación
  String get operationType => entryTrade.type; // 'buy' para long, 'sell' para short

  // Método para obtener la duración de la operación
  Duration get duration => exitTime.difference(entryTime);

  // Método para formatear la duración
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entryTrade': entryTrade.toJson(),
      'exitTrade': exitTrade.toJson(),
      'totalPnL': totalPnL,
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime.toIso8601String(),
      'entryPrice': entryPrice,
      'exitPrice': exitPrice,
      'quantity': quantity,
      'leverage': leverage,
      'reason': reason,
    };
  }

  factory CompletedTrade.fromJson(Map<String, dynamic> json) {
    return CompletedTrade(
      id: json['id'],
      entryTrade: Trade.fromJson(json['entryTrade']),
      exitTrade: Trade.fromJson(json['exitTrade']),
      totalPnL: json['totalPnL'].toDouble(),
      entryTime: DateTime.parse(json['entryTime']),
      exitTime: DateTime.parse(json['exitTime']),
      entryPrice: json['entryPrice'].toDouble(),
      exitPrice: json['exitPrice'].toDouble(),
      quantity: json['quantity'].toDouble(),
      leverage: json['leverage'],
      reason: json['reason'],
    );
  }
} 