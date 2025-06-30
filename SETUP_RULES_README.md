# Funcionalidad de Setups con Reglas - TimeTrader

## Descripción

Se ha implementado una funcionalidad completa para crear y gestionar setups de trading con reglas personalizables. Cada setup puede incluir múltiples reglas que definen las condiciones de entrada al mercado.

## Características Principales

### 1. Modelo de Reglas (`lib/src/models/rule.dart`)

- **Tipos de Reglas**:
  - `technicalIndicator`: Indicadores técnicos (EMA, RSI, etc.)
  - `candlestickPattern`: Patrones de velas (Doji, Martillo, etc.)
  - `timeFrame`: Restricciones de horario
  - `other`: Otros tipos de reglas

- **Reglas Predefinidas**:
  - EMA 10 cruza EMA 5
  - RSI en sobreventa/sobrecompra
  - Patrones de velas (Doji, Martillo, Estrella Fugaz)
  - Sesiones de trading (Mañana, Londres)
  - Picos de volumen
  - Soporte y resistencia

### 2. Modelo de Setup Mejorado (`lib/src/models/setup.dart`)

- Incluye lista de reglas asociadas
- Métodos de conveniencia para gestionar reglas
- Serialización/deserialización completa

### 3. Gestión de Estado (`lib/src/services/setup_provider.dart`)

- CRUD completo para setups
- Gestión de reglas dentro de setups
- Acceso a reglas predefinidas
- Notificaciones automáticas de cambios

### 4. Interfaz de Usuario

#### Lista de Setups (`lib/src/screens/setups_list_screen.dart`)
- Vista de tarjetas con información completa
- Muestra estadísticas básicas y reglas
- Navegación al detalle y formulario

#### Formulario de Setup (`lib/src/screens/setup_form_screen.dart`)
- Formulario completo con validación
- Selección de reglas con interfaz de pestañas
- Vista previa de reglas seleccionadas

#### Detalle de Setup (`lib/src/screens/setup_detail_screen.dart`)
- Vista detallada de toda la información
- Lista completa de reglas
- Opción de eliminación

### 5. Widgets Reutilizables

#### RuleCard (`lib/src/widgets/rule_card.dart`)
- Tarjeta visual para mostrar reglas
- Iconos y colores por tipo
- Estados activo/inactivo

#### RuleSelector (`lib/src/widgets/rule_selector.dart`)
- Selector con pestañas por tipo
- Interfaz intuitiva para selección múltiple
- Filtrado automático

## Flujo de Uso

1. **Crear Setup**:
   - Navegar a "Mis Setups"
   - Tocar botón "+"
   - Llenar información básica
   - Activar "Usar reglas avanzadas"
   - Seleccionar reglas deseadas
   - Guardar

2. **Ver Setups**:
   - Lista con vista previa de reglas
   - Tocar setup para ver detalles completos
   - Opción de eliminación

3. **Gestionar Reglas**:
   - Agregar/quitar reglas en formulario
   - Ver descripción completa en detalle
   - Estados activo/inactivo

## Estructura de Datos

### Setup
```dart
{
  id: String,
  name: String,
  asset: String,
  positionSize: double,
  stopLossPercent: double,
  takeProfitPercent: double,
  useAdvancedRules: bool,
  rules: List<Rule>,
  createdAt: DateTime
}
```

### Rule
```dart
{
  id: String,
  name: String,
  description: String,
  type: RuleType,
  parameters: Map<String, dynamic>,
  isActive: bool
}
```

## Reglas Predefinidas Disponibles

### Indicadores Técnicos
- EMA 10 cruza EMA 5
- RSI en sobreventa (< 30)
- RSI en sobrecompra (> 70)
- Pico de volumen
- Soporte y resistencia

### Patrones de Velas
- Patrón Doji
- Patrón Martillo
- Patrón Estrella Fugaz

### Horarios
- Sesión de Mañana (10:00 AM - 1:00 PM)
- Sesión de Londres (8:00 AM - 4:00 PM GMT)

## Tecnologías Utilizadas

- **Flutter**: Framework principal
- **Provider**: Gestión de estado
- **Material Design**: Componentes UI
- **Firebase**: Autenticación y persistencia (preparado)

## Próximos Pasos

1. **Persistencia**: Integrar con Firebase Firestore
2. **Validación Avanzada**: Validación de reglas en tiempo real
3. **Reglas Personalizadas**: Permitir crear reglas propias
4. **Backtesting**: Integrar con sistema de simulación
5. **Notificaciones**: Alertas cuando se cumplan condiciones

## Archivos Modificados/Creados

### Nuevos Archivos
- `lib/src/models/rule.dart`
- `lib/src/widgets/rule_card.dart`
- `lib/src/widgets/rule_selector.dart`
- `SETUP_RULES_README.md`

### Archivos Modificados
- `lib/src/models/setup.dart`
- `lib/src/services/setup_provider.dart`
- `lib/src/screens/setups_list_screen.dart`
- `lib/src/screens/setup_form_screen.dart`
- `lib/src/screens/setup_detail_screen.dart`

## Instalación y Uso

1. Asegurarse de tener las dependencias instaladas:
   ```bash
   flutter pub get
   ```

2. Ejecutar la aplicación:
   ```bash
   flutter run
   ```

3. Navegar a "Mis Setups" para probar la funcionalidad

## Notas Técnicas

- Todas las reglas son inmutables para evitar efectos secundarios
- El sistema está preparado para integración con Firebase
- La UI sigue el diseño system de TimeTrader
- Código completamente documentado y tipado 