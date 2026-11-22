import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/dashboard_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/transactions_screen.dart';
import 'services/hive_service.dart';
import 'theme/app_theme.dart';
import 'widgets/notched_nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await HiveService.init();

  runApp(const SakuinApp());
}

class SakuinApp extends StatelessWidget {
  const SakuinApp({super.key});

  @override
  Widget build(BuildContext context) {
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
            textTheme: GoogleFonts.instrumentSansTextTheme(
              ThemeData.light().textTheme,
            ),
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
            textTheme: GoogleFonts.instrumentSansTextTheme(
              ThemeData.dark().textTheme,
            ),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFEDEDEA),
              secondary: Color(0xFF5FD49E),
              surface: Color(0xFF1A1A1E),
            ),
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(
            nextScreen: MainShell(),
          ),
        );
      },
    );
  }
}

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color canvasBg =
        isDark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);

    final pages = <Widget>[
      DashboardScreen(onNavigateTab: _setTab),
      const TransactionsScreen(),
      const GoalsScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: canvasBg,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NotchedFloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _setTab,
        items: const [
          NotchedNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Beranda',
          ),
          NotchedNavItem(
            icon: Icons.swap_horiz_rounded,
            activeIcon: Icons.swap_horiz_rounded,
            label: 'Transaksi',
          ),
          NotchedNavItem(
            icon: Icons.savings_outlined,
            activeIcon: Icons.savings_rounded,
            label: 'Target',
          ),
          NotchedNavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: 'Statistik',
          ),
          NotchedNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Setelan',
          ),
        ],
      ),
    );
  }
}