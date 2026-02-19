import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/home_screen.dart';
import 'package:ios_tiretest_ai/Screens/location_google_maos.dart';
import 'package:ios_tiretest_ai/Screens/profile_screen.dart' show ProfilePage;
import 'package:ios_tiretest_ai/Screens/report_history_screen.dart';
import 'package:ios_tiretest_ai/Screens/sponser_vendors_screen.dart';
import '../Widgets/bottom_bar.dart' hide BottomTab;

import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Models/bottom_tab.dart' hide BottomTab;
import 'package:ios_tiretest_ai/Widgets/bottom_bar.dart';

import 'package:flutter/material.dart';


// import 'package:ios_tiretest_ai/Models/bottom_tab.dart';
// import 'package:ios_tiretest_ai/Widgets/bottom_bar.dart';



// class AppShell extends StatefulWidget {
//   const AppShell({super.key});

//   /// ✅ Access AppShell state from any child widget
//   static _AppShellState? of(BuildContext context) {
//     return context.findAncestorStateOfType<_AppShellState>();
//   }

//   @override
//   State<AppShell> createState() => _AppShellState();
// }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// ✅ Access AppShell state from any child widget
  static _AppShellState? of(BuildContext context, {bool root = false}) {
    return root
        ? context.findRootAncestorStateOfType<_AppShellState>()
        : context.findAncestorStateOfType<_AppShellState>();
  }

  @override
  State<AppShell> createState() => _AppShellState();
}


class _AppShellState extends State<AppShell> {
  BottomTab _tab = BottomTab.home;

  final Map<BottomTab, GlobalKey<NavigatorState>> _keys = {
    BottomTab.home: GlobalKey<NavigatorState>(),
    BottomTab.reports: GlobalKey<NavigatorState>(),
    BottomTab.map: GlobalKey<NavigatorState>(),
    BottomTab.about: GlobalKey<NavigatorState>(),
    BottomTab.profile: GlobalKey<NavigatorState>(),
  };

  /// ✅ THIS IS THE METHOD YOU WERE MISSING
  void goToTab(BottomTab tab, {bool popToRoot = false}) {
    if (!mounted) return;

    if (popToRoot) {
      final nav = _keys[tab]?.currentState;
      nav?.popUntil((route) => route.isFirst);
    }

    setState(() => _tab = tab);
  }

  void _setTab(BottomTab tab) {
    setState(() => _tab = tab);
  }

  Future<bool> _onWillPop() async {
    final nav = _keys[_tab]!.currentState!;
    if (nav.canPop()) {
      nav.pop();
      return false;
    }

    if (_tab != BottomTab.home) {
      setState(() => _tab = BottomTab.home);
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: IndexedStack(
          index: _tab.index,
          children: [
            _TabNavigator(
              key: _keys[BottomTab.home],
              initial: const InspectionHomePixelPerfect(),
            ),
            _TabNavigator(
              key: _keys[BottomTab.reports],
              initial: ReportHistoryScreen(),
            ),
            _TabNavigator(
              key: _keys[BottomTab.map],
              initial: const LocationVendorsMapScreen(),
            ),
            _TabNavigator(
              key: _keys[BottomTab.about],
              initial: const SponsoredVendorsScreen(),
            ),
            _TabNavigator(
              key: _keys[BottomTab.profile],
              initial: const ProfilePage(),
            ),
          ],
        ),
        bottomNavigationBar: BottomBar(
          active: _tab,
          onChanged: _setTab, // ✅ matches ValueChanged<BottomTab>
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({super.key, required this.initial});
  final Widget initial;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => initial,
          settings: settings,
        );
      },
    );
  }
}



// class AppShell extends StatefulWidget {
//   const AppShell({super.key});

//   @override
//   State<AppShell> createState() => _AppShellState();
// }

// class _AppShellState extends State<AppShell> {
//   BottomTab _tab = BottomTab.home;

//   final _keys = {
//     BottomTab.home: GlobalKey<NavigatorState>(),
//     BottomTab.reports: GlobalKey<NavigatorState>(),
//     BottomTab.map: GlobalKey<NavigatorState>(),
//     BottomTab.about: GlobalKey<NavigatorState>(),
//     BottomTab.profile: GlobalKey<NavigatorState>(),
//   };

//   Future<bool> _onWillPop() async {
//     final nav = _keys[_tab]!.currentState!;
//     if (nav.canPop()) {
//       nav.pop();
//       return false;
//     }
//     if (_tab != BottomTab.home) {
//       setState(() => _tab = BottomTab.home);
//       return false;
//     }
//     return true;
//   }

//   void _setTab(BottomTab t) => setState(() => _tab = t);

//   @override
//   Widget build(BuildContext context) {
//     // ignore: deprecated_member_use
//     return WillPopScope(
//       onWillPop: _onWillPop,
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF7F8FA),
//         body: IndexedStack(
//           index: _tab.index,
//           children: [
//             _TabNavigator(key: _keys[BottomTab.home], initial: const InspectionHomePixelPerfect()),
//             _TabNavigator(key: _keys[BottomTab.reports], initial:  ReportHistoryScreen()),
//             _TabNavigator(key: _keys[BottomTab.map], initial: const LocationVendorsMapScreen()),
//             _TabNavigator(key: _keys[BottomTab.about], initial: const SponsoredVendorsScreen()),
//             _TabNavigator(key: _keys[BottomTab.profile], initial: const ProfilePage()),
//           ],
//         ),
//         bottomNavigationBar: BottomBar(
//           active: _tab,
//           onChanged: _setTab,
//         ),
//       ),
//     );
//   }
// }

// class _TabNavigator extends StatelessWidget {
//   const _TabNavigator({super.key, required this.initial});
//   final Widget initial;

//   @override
//   Widget build(BuildContext context) {
//     return Navigator(
//       onGenerateRoute: (settings) {
//         return MaterialPageRoute(
//           builder: (_) => initial,
//           settings: settings,
//         );
//       },
//     );
//   }
// }




