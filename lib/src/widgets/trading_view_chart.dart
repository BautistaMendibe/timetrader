import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../models/candle.dart';
import '../models/simulation_result.dart';

class TradingViewChart extends StatefulWidget {
  final List<Candle> candles;
  final List<Trade>? trades;
  final int? currentCandleIndex;
  final double? stopLoss;
  final double? takeProfit;
  
  const TradingViewChart({
    required this.candles,
    this.trades,
    this.currentCandleIndex,
    this.stopLoss,
    this.takeProfit,
    super.key,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late final WebViewController _controller;
  bool _isWebViewReady = false;
  String _status = 'Inicializando...';
  int _debugCounter = 0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1E1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _debugCounter++;
            setState(() => _status = 'Cargando página... ($_debugCounter)');
          },
          onPageFinished: (String url) {
            _debugCounter++;
            setState(() {
              _isWebViewReady = true;
              _status = 'Enviando datos... ($_debugCounter)';
            });
            // Send data after page is loaded
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                _sendDataToWebView();
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() => _status = 'Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    
    _controller.loadFlutterAsset('assets/chart.html');
  }

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isWebViewReady && 
        (oldWidget.candles != widget.candles || 
         oldWidget.trades != widget.trades ||
         oldWidget.currentCandleIndex != widget.currentCandleIndex ||
         oldWidget.stopLoss != widget.stopLoss ||
         oldWidget.takeProfit != widget.takeProfit)) {
      _sendDataToWebView();
    }
  }

  void _sendDataToWebView() async {
    if (!_isWebViewReady) {
      return;
    }

    if (widget.candles.isEmpty) {
      setState(() => _status = 'No hay datos disponibles');
      return;
    }

    try {
      // Show "Renderizando gráfico" message on first load
      if (_status.contains('Enviando datos')) {
        setState(() => _status = 'Renderizando gráfico...');
      }
      
      // Determine which candles to show
      final candlesToShow = widget.currentCandleIndex != null 
          ? widget.candles.take(widget.currentCandleIndex! + 1).toList()
          : widget.candles;
      
      // Prepare data structure
      final data = {
        'candles': candlesToShow.map((c) => {
          'time': c.timestamp.millisecondsSinceEpoch ~/ 1000, // Convert to seconds since epoch
          'open': c.open,
          'high': c.high,
          'low': c.low,
          'close': c.close,
          'volume': c.volume,
        }).toList(),
        'trades': widget.trades?.map((t) => {
          'time': t.timestamp.millisecondsSinceEpoch ~/ 1000, // Convert to seconds since epoch
          'type': t.type,
          'price': t.price,
          'amount': t.amount,
          'leverage': t.leverage,
        }).toList() ?? [],
        'stopLoss': (widget.stopLoss != null && widget.stopLoss! > 0) ? widget.stopLoss : null,
        'takeProfit': (widget.takeProfit != null && widget.takeProfit! > 0) ? widget.takeProfit : null,
      };



      final jsonData = jsonEncode(data);
      
      // Test JavaScript execution
      try {
        await _controller.runJavaScriptReturningResult('1 + 1');
      } catch (e) {
        // Ignore test errors
      }
      
      await _controller.runJavaScript("window.postMessage('$jsonData', '*')");
      
      // Update status to "Gráfico listo" on first load
      if (_status == 'Renderizando gráfico...') {
        setState(() => _status = 'Gráfico listo');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF888888), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (!_isWebViewReady || _status != 'Gráfico listo')
              Container(
                color: const Color(0xFF1E1E1E),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF21CE99),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Velas: ${widget.candles.length}, Trades: ${widget.trades?.length ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Debug: $_debugCounter',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 