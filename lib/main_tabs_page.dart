import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'pages/appointments.dart';
import 'pages/calendar.dart';
import 'pages/profile.dart';
import 'widgets/main_nav.dart';

class MainTabsPage extends StatefulWidget {
  final int initialIndex;

  const MainTabsPage({super.key, this.initialIndex = 0});

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> {
  late final PageController _pageController;
  late int _currentIndex;
  final List<Widget?> _pages = List.filled(4, null);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex < 0
        ? 0
        : (widget.initialIndex > 3 ? 3 : widget.initialIndex);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPage(int index) {
    final existing = _pages[index];
    if (existing != null) return existing;

    late final Widget page;
    switch (index) {
      case 0:
        page = DashboardPage(
          showBottomNav: false,
          onTabSelected: _onNavTap,
        );
        break;
      case 1:
        page = const AppointmentsPage(showBottomNav: false);
        break;
      case 2:
        page = const CalendarPage(showBottomNav: false);
        break;
      case 3:
      default:
        page = const ProfilePage(showBottomNav: false);
        break;
    }

    _pages[index] = page;
    return page;
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: 4,
        itemBuilder: (context, index) => _buildPage(index),
      ),
      bottomNavigationBar: MainNavBar(
        currentIndex: _currentIndex,
        onIndexSelected: _onNavTap,
      ),
    );
  }
}
