class Tick {
  final DateTime time;
  final double price;

  Tick({required this.time, required this.price});

  Map<String, dynamic> toJson() {
    return {'time': time.toIso8601String(), 'price': price};
  }

  factory Tick.fromJson(Map<String, dynamic> json) {
    return Tick(
      time: json['time'] != null
          ? DateTime.parse(json['time'])
          : DateTime.now(),
      price: (json['price'] ?? 0.0).toDouble(),
    );
  }
}
