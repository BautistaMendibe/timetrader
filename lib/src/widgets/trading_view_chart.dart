import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../models/candle.dart';
import '../models/simulation_result.dart';

class TradingViewChart extends StatefulWidget {
  final List<Candle> candles;
  final List<Trade>? trades;
  
  const TradingViewChart({
    required this.candles,
    this.trades,
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
    debugPrint('🔥 TradingViewChart: initState() - Candles: ${widget.candles.length}, Trades: ${widget.trades?.length ?? 0}');
    _initializeWebView();
  }

  void _initializeWebView() {
    debugPrint('🔥 TradingViewChart: Inicializando WebView...');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1E1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _debugCounter++;
            debugPrint('🔥 TradingViewChart: onPageStarted #$_debugCounter - URL: $url');
            setState(() => _status = 'Cargando página... ($_debugCounter)');
          },
          onPageFinished: (String url) {
            _debugCounter++;
            debugPrint('🔥 TradingViewChart: onPageFinished #$_debugCounter - URL: $url');
            setState(() {
              _isWebViewReady = true;
              _status = 'Enviando datos... ($_debugCounter)';
            });
            // Send data after page is loaded
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                debugPrint('🔥 TradingViewChart: Delay completado, enviando datos...');
                _sendDataToWebView();
              } else {
                debugPrint('🔥 TradingViewChart: Widget no montado después del delay');
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🔥 TradingViewChart: Error WebView: ${error.description} - Code: ${error.errorCode}');
            setState(() => _status = 'Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🔥 TradingViewChart: Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );
    
    debugPrint('🔥 TradingViewChart: Cargando asset: assets/chart.html');
    _controller.loadFlutterAsset('assets/chart.html');
  }

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🔥 TradingViewChart: didUpdateWidget - Candles: ${widget.candles.length} -> ${oldWidget.candles.length}');
    if (_isWebViewReady && 
        (oldWidget.candles != widget.candles || oldWidget.trades != widget.trades)) {
      debugPrint('🔥 TradingViewChart: Datos actualizados, enviando...');
      _sendDataToWebView();
    }
  }

  void _sendDataToWebView() async {
    debugPrint('🔥 TradingViewChart: _sendDataToWebView() - WebView ready: $_isWebViewReady');
    
    if (!_isWebViewReady) {
      debugPrint('🔥 TradingViewChart: WebView no está listo');
      return;
    }

    if (widget.candles.isEmpty) {
      debugPrint('🔥 TradingViewChart: No hay datos de velas');
      setState(() => _status = 'No hay datos disponibles');
      return;
    }

    try {
      debugPrint('🔥 TradingViewChart: Enviando ${widget.candles.length} velas al WebView');
      setState(() => _status = 'Renderizando gráfico...');
      
      // Prepare data structure
      final data = {
        'candles': widget.candles.map((c) => {
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
        }).toList() ?? [],
      };

      final jsonData = jsonEncode(data);
      debugPrint('🔥 TradingViewChart: JSON preparado, longitud: ${jsonData.length}');
      
      // Test JavaScript execution
      try {
        final testResult = await _controller.runJavaScriptReturningResult('1 + 1');
        debugPrint('🔥 TradingViewChart: Test JS ejecutado: $testResult');
      } catch (e) {
        debugPrint('🔥 TradingViewChart: Error en test JS: $e');
      }
      
      await _controller.runJavaScript("window.postMessage('$jsonData', '*')");
      debugPrint('🔥 TradingViewChart: Datos enviados exitosamente via postMessage');
      setState(() => _status = 'Gráfico listo');
    } catch (e) {
      debugPrint('🔥 TradingViewChart: Error enviando datos: $e');
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔥 TradingViewChart: build() - Status: $_status, Ready: $_isWebViewReady');
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