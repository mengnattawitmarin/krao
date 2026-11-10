import 'package:flutter/material.dart';

import 'app_state.dart';
import 'bridge.dart';
import 'pages/emergency_page.dart';
import 'pages/home_page.dart';
import 'pages/me_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/scan_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KraoApp(state: AppState(ChannelBridge())..init()));
}

class KraoApp extends StatelessWidget {
  final AppState state;
  const KraoApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'เกราะ',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const _Root(),
        ),
      );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!s.onboarded) return const OnboardingPage();
    return const MainShell();
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _pages = <Widget>[HomePage(), ScanPage(), EmergencyPage(), MePage()];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final danger = s.risks.where((r) => r.score >= 60).length;
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: s.tab, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: s.tab,
        onDestinationSelected: s.goTab,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'หน้าหลัก'),
          NavigationDestination(
            icon: Badge(isLabelVisible: danger > 0, label: Text('$danger'), child: const Icon(Icons.apps_outlined)),
            selectedIcon: const Icon(Icons.apps),
            label: 'สแกนแอป',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sos_outlined, color: K.red),
            selectedIcon: Icon(Icons.sos, color: K.red),
            label: 'ถูกแฮ็ก?',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'ฉัน'),
        ],
      ),
    );
  }
}
