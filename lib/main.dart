import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/dashboard_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/transactions_screen.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi format tanggal Indonesia ('id_ID')
  await initializeDateFormatting('id_ID', null);

  // 2. Inisialisasi database lokal Hive & preferensi pengaturan
  await HiveService.init();

  // 3. Inisialisasi notifikasi luar aplikasi & minta izin Android 12+/13+
  await NotificationService.init();

  // 4. Sinkronkan jadwal pengingat harian sesuai pengaturan tersimpan
  if (SettingsController.reminderEnabled) {
    final parts = SettingsController.reminderTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 20;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    await NotificationService.scheduleDailyReminder(
      hour: hour,
      minute: minute,
    );
  } else {
    await NotificationService.cancelDailyReminder();
  }

  runApp(const SakuinApp());
}

class SakuinApp extends StatelessWidget {
  const SakuinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Memantau perubahan Hive secara otomatis saat SettingsController.toggleDarkMode dipanggil
    return ValueListenableBuilder(
      valueListenable: HiveService.box.listenable(),
      builder: (context, _, __) {
        final isDark = SettingsController.isDark;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        );

        return MaterialApp(
          title: 'Sakuin',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F6F3),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF17171A),
              secondary: Color(0xFF007D50),
              surface: Color(0xFFFFFFFF),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF111113),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFEDEDEA),
              secondary: Color(0xFF5FD49E),
              surface: Color(0xFF1A1A1E),
            ),
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const MainShell(),
        );
      },
    );
  }
}

/// ============================================================================
/// MAIN SHELL — Navigasi bawah datar (hairline border, tanpa shadow/elevation)
/// ============================================================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _setTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);
    final activeColor =
        isDark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
    final inactiveColor =
        isDark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);

    final pages = <Widget>[
      DashboardScreen(onNavigateTab: _setTab),
      const TransactionsScreen(),
      const GoalsScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Ringkasan',
                  selected: _currentIndex == 0,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => _setTab(0),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Transaksi',
                  selected: _currentIndex == 1,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => _setTab(1),
                ),
                _NavItem(
                  icon: Icons.savings_outlined,
                  activeIcon: Icons.savings_rounded,
                  label: 'Target',
                  selected: _currentIndex == 2,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => _setTab(2),
                ),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Statistik',
                  selected: _currentIndex == 3,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => _setTab(3),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Setelan',
                  selected: _currentIndex == 4,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => _setTab(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 20,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}