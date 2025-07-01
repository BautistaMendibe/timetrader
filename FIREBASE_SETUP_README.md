# Firebase Setup Integration

## Overview

This implementation adds Firebase Firestore integration for storing and managing trading setups. The system includes:

- **2 Example Setups**: Always available and cannot be deleted
- **User Setups**: Stored in Firebase Firestore and can be created, edited, and deleted
- **Real-time Updates**: Changes are reflected immediately across the app

## Features

### Example Setups
Two example setups are always available:

1. **Scalping BTC**
   - Asset: BTC/USD
   - Position Size: $100 (fixed)
   - Stop Loss: 2% (percentage)
   - Take Profit: 4% (percentage)
   - Rules: EMA Cross, Morning Session

2. **Swing Trading EUR/USD**
   - Asset: EUR/USD
   - Position Size: 5% (percentage)
   - Stop Loss: 1.5% (percentage)
   - Take Profit: 3% (percentage)
   - Rules: RSI Oversold, Hammer Pattern

### User Setups
- Stored in Firebase Firestore collection `setups`
- Marked with `isExample: false`
- Can be created, edited, and deleted
- Include all setup properties (name, asset, position size, stop loss, take profit, rules)

## Implementation Details

### Files Modified/Created

1. **`lib/src/services/firebase_setup_service.dart`** (NEW)
   - Handles all Firebase operations
   - Manages example setups
   - Provides real-time listeners

2. **`lib/src/models/setup.dart`** (MODIFIED)
   - Added `isExample` field
   - Updated JSON serialization

3. **`lib/src/services/setup_provider.dart`** (MODIFIED)
   - Integrated with Firebase service
   - Added loading states
   - Real-time updates

4. **`lib/src/screens/setup_form_screen.dart`** (MODIFIED)
   - Async save operations
   - Loading indicators

5. **`lib/src/screens/setups_list_screen.dart`** (MODIFIED)
   - Loading states
   - Example setup indicators

6. **`lib/src/screens/setup_detail_screen.dart`** (MODIFIED)
   - Delete protection for example setups
   - Async delete operations

7. **`lib/src/app.dart`** (MODIFIED)
   - Added SetupListenerWrapper for real-time updates

### Firebase Collection Structure

```json
{
  "setups": {
    "document_id": {
      "id": "user_generated_id",
      "name": "Setup Name",
      "asset": "BTC/USD",
      "positionSize": 100.0,
      "positionSizeType": "ValueType.fixed",
      "stopLossPercent": 2.0,
      "stopLossType": "ValueType.percentage",
      "takeProfitPercent": 4.0,
      "takeProfitType": "ValueType.percentage",
      "useAdvancedRules": true,
      "rules": [...],
      "createdAt": "2024-01-01T00:00:00.000Z",
      "isExample": false
    }
  }
}
```

## Usage

### Creating a Setup
1. Navigate to Setups List
2. Tap the + button
3. Fill in the setup details
4. Tap "Guardar" to save to Firebase

### Editing a Setup
1. Open any setup (example or user)
2. Tap the edit icon
3. Modify the setup
4. Tap "Guardar" to update in Firebase

### Deleting a Setup
- Only user setups can be deleted
- Example setups are protected from deletion
- Deletion is permanent and cannot be undone

## Error Handling

- If Firebase is not available, only example setups are shown
- Loading states are displayed during operations
- Error messages are shown for failed operations
- Graceful fallback to example setups only

## Security Rules (Recommended)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /setups/{setupId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Testing

1. **Example Setups**: Should always be visible and non-deletable
2. **User Setups**: Should persist across app restarts
3. **Real-time Updates**: Changes should appear immediately
4. **Offline Support**: App should work with example setups only when offline

## Dependencies

- `firebase_core`: ^3.13.1
- `cloud_firestore`: ^5.6.8
- `firebase_auth`: ^5.5.4

## Notes

- Example setups are hardcoded and always available
- User setups require Firebase authentication
- All operations are async and include proper error handling
- The app gracefully handles Firebase connection issues 