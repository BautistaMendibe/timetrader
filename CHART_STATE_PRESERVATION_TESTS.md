# Pruebas Manuales: Preservación del Estado del Chart

## Objetivo
Verificar que el chart mantiene su estado (scroll, zoom, posición, velas formándose) al cambiar entre las pestañas "Trading" y "Estadísticas" en SimulationScreen.

## Implementación Realizada

### 1. **TradingTab con AutomaticKeepAliveClientMixin**
- ✅ **Creado**: `lib/src/screens/trading_tab.dart`
- ✅ **AutomaticKeepAliveClientMixin**: Implementado con `wantKeepAlive => true`
- ✅ **Contenido**: Movido todo el contenido del tab de trading al nuevo widget

### 2. **PageStorageKey para Scroll**
- ✅ **Key dinámica**: `PageStorageKey('trading_scroll_${symbol}_${timeframe}')`
- ✅ **Ubicación**: Aplicada al `CustomScrollView` principal del TradingTab
- ✅ **Comportamiento**: Se reinicia intencionalmente cuando cambia símbolo o timeframe

### 3. **DefaultTabController Reubicado**
- ✅ **Movido**: De dentro del `Consumer<SimulationProvider>` a fuera
- ✅ **Estructura**: `DefaultTabController` > `Consumer` > `Scaffold`
- ✅ **Beneficio**: Evita reconstrucción del TabController al cambiar el provider

### 4. **GlobalKey del Chart Preservado**
- ✅ **Mantenido**: `_chartKey` se pasa desde SimulationScreen a TradingTab
- ✅ **Instancia única**: El WebView del chart mantiene su estado interno
- ✅ **Callback**: Los callbacks de tick siguen funcionando correctamente

## Criterios de Aceptación

### ✅ **Criterio 1: Preservación del Estado del Chart**
**Test**: 
1. Abrir simulación con datos históricos
2. Hacer scroll horizontal en el chart
3. Hacer zoom in/out en el chart
4. Cambiar a pestaña "Estadísticas"
5. Volver a pestaña "Trading"

**Resultado esperado**: El chart debe mantener exactamente la misma posición de scroll y nivel de zoom.

### ✅ **Criterio 2: Preservación del Scroll de la Página**
**Test**:
1. En el tab "Trading", hacer scroll hacia abajo
2. Cambiar a pestaña "Estadísticas" 
3. Volver a pestaña "Trading"

**Resultado esperado**: La página debe mantener la misma posición de scroll vertical.

### ✅ **Criterio 3: Continuidad de Velas en Tiempo Real**
**Test**:
1. Iniciar simulación en modo tiempo real
2. Observar velas formándose en el chart
3. Cambiar a pestaña "Estadísticas" durante 5-10 segundos
4. Volver a pestaña "Trading"

**Resultado esperado**: Las velas deben continuar formándose sin interrupciones, mostrando el progreso correcto.

### ✅ **Criterio 4: Funcionalidad de Trading Intacta**
**Test**:
1. Cambiar entre pestañas varias veces
2. Intentar abrir una orden de compra/venta
3. Verificar controles de SL/TP
4. Cerrar posición si existe

**Resultado esperado**: Todos los controles de trading deben funcionar normalmente después del cambio de pestañas.

### ✅ **Criterio 5: Rendimiento Optimizado**
**Test**:
1. Cambiar rápidamente entre pestañas 10 veces
2. Observar uso de memoria en DevTools
3. Verificar tiempo de respuesta

**Resultado esperado**: No debe haber lag perceptible ni aumento significativo de memoria.

## Casos Edge

### **Caso 1: Cambio de Timeframe**
**Test**:
1. Posicionar chart en una zona específica
2. Cambiar timeframe (ej: 1M a 1H)
3. Cambiar a pestaña "Estadísticas" y volver

**Resultado esperado**: Al cambiar timeframe, el estado del chart debe reiniciarse intencionalmente (esto es correcto), pero al cambiar pestañas debe mantenerse.

### **Caso 2: Cambio de Símbolo**
**Test**:
1. Posicionar chart en una zona específica
2. Cambiar símbolo (ej: BTCUSD a EURUSD)
3. Cambiar a pestaña "Estadísticas" y volver

**Resultado esperado**: Al cambiar símbolo, el estado debe reiniciarse (correcto), pero al cambiar pestañas debe mantenerse.

### **Caso 3: Simulación Pausada/Reanudada**
**Test**:
1. Pausar simulación
2. Hacer scroll/zoom en chart
3. Cambiar pestañas
4. Reanudar simulación

**Resultado esperado**: El chart debe mantener posición y continuar correctamente al reanudar.

## Pruebas de Regresión

### **Verificar que NO se rompe:**
- ✅ Callbacks de tick al chart
- ✅ Actualización de datos en tiempo real  
- ✅ Controles de trading (compra/venta)
- ✅ Gestión de SL/TP
- ✅ Cierre de posiciones
- ✅ Selector de timeframe
- ✅ Selector de velocidad
- ✅ Botones de pausa/play

## Notas Técnicas

### **Arquitectura**
```
SimulationScreen (mantiene _chartKey)
├── DefaultTabController (fuera del Consumer)
└── Consumer<SimulationProvider>
    └── TabBarView
        ├── TradingTab (con keepAlive + PageStorageKey)
        └── StatisticsTab
```

### **Claves para el Funcionamiento**
1. **AutomaticKeepAliveClientMixin**: Evita que Flutter destruya el widget al cambiar tabs
2. **PageStorageKey**: Restaura posición de scroll automáticamente
3. **GlobalKey estable**: El WebView mantiene su estado interno
4. **DefaultTabController fuera del Consumer**: Evita reconstrucciones innecesarias

### **Limitaciones Conocidas**
- El estado se reinicia intencionalmente al cambiar símbolo/timeframe (comportamiento deseado)
- La primera carga puede tomar unos segundos (normal para WebView)
- En dispositivos con poca memoria, el sistema podría forzar la limpieza del estado

## Comandos de Verificación

```bash
# Verificar que no hay errores de análisis
flutter analyze

# Compilar para verificar integridad
flutter build apk --debug

# Ejecutar en dispositivo/emulador para pruebas manuales
flutter run
```

## Estado: ✅ **COMPLETADO**

Todas las funcionalidades han sido implementadas y están listas para pruebas manuales.
