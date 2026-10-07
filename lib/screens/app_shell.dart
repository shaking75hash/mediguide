import 'package:flutter/material.dart';

import 'app_navigation.dart';
import 'appointments_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search_rounded),
      label: 'Search',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today_rounded),
      label: 'Appointments',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  final _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );
  final _visitedTabs = [true, false, false, false];
  int _selectedIndex = 0;
  SearchMode _searchMode = SearchMode.doctors;

  void _selectTab(int index) {
    if (index < 0 || index >= _destinations.length) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs[index] = true;
    });
  }

  void _openPriceComparison() {
    final searchNavigator = _navigatorKeys[1].currentState;
    setState(() {
      _selectedIndex = 1;
      _visitedTabs[1] = true;
      _searchMode = SearchMode.tests;
    });
    if (searchNavigator != null) {
      searchNavigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => const SearchScreen(initialMode: SearchMode.tests),
        ),
      );
    }
  }

  Widget _buildTabNavigator(int index) {
    if (!_visitedTabs[index]) return const SizedBox.shrink();

    return NavigatorPopHandler<Object?>(
      enabled: _selectedIndex == index,
      onPopWithResult: (result) {
        _navigatorKeys[index].currentState?.pop(result);
      },
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => switch (index) {
            0 => const HomeScreen(),
            1 => SearchScreen(initialMode: _searchMode),
            2 => const AppointmentsScreen(),
            3 => const ProfileScreen(),
            _ => const HomeScreen(),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigation(
      onSelectTab: _selectTab,
      onOpenPriceComparison: _openPriceComparison,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(_destinations.length, _buildTabNavigator),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          destinations: _destinations,
          height: 68,
          backgroundColor: const Color(0xFFFFFFFF),
          indicatorColor: const Color(0xFFE8F0EB),
          elevation: 8,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: selected ? 11 : 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
        ),
      ),
    );
  }
}
