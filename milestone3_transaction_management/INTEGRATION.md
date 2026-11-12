# Milestone 3 — Transaction Management

## 1. Copy the new files

From the extracted folder, copy:
- `lib/services/finance_service.dart` to `frontend/lib/services/finance_service.dart`
- `lib/screens/transaction_screen.dart` to `frontend/lib/screens/transaction_screen.dart`

The service replacement preserves the existing account/category methods and adds update/delete.

## 2. Connect the screen to the sidebar

Open `frontend/lib/main.dart`.

Add this import with the other imports:

```dart
import 'screens/transaction_screen.dart';
```

Find this section in `_MainDashboardState.build()`:

```dart
child: selectedIndex == 0
    ? buildDashboard()
    : buildModulePage(),
```

Replace it with:

```dart
child: selectedIndex == 0
    ? buildDashboard()
    : selectedIndex == 1
        ? const TransactionManagementScreen()
        : buildModulePage(),
```

No other sidebar changes are required. The existing `Transactions` item already has index 1.

## 3. Format and validate

```bash
cd ~/Documents/Home/MyMoney/frontend
dart format lib/services/finance_service.dart lib/screens/transaction_screen.dart lib/main.dart
flutter analyze
flutter test
```

## 4. Run

In terminal 1:

```bash
cd ~/Documents/Home/MyMoney
docker compose up -d
```

In terminal 2:

```bash
cd ~/Documents/Home/MyMoney/frontend
flutter run -d chrome
```

## Features
- All / Income / Expenses tabs
- Search by description, category, or account
- Category filter
- Date-range filter
- Income, expense, and net totals for the current filtered result
- Add and edit transactions
- Delete with confirmation
- Refresh after changes; Riverpod providers are invalidated so the dashboard sees updated data

The transaction screen uses the same white/purple palette and existing backend endpoints.
