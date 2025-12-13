import 'package:flutter/material.dart';

import '../dashboard_page.dart';
import '../pages/appointments.dart';
import '../pages/calendar.dart';
import '../pages/profile.dart';

class MainNavBar extends StatelessWidget {
  final int currentIndex;
  const MainNavBar({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Widget page;
    switch (index) {
      case 0:
        page = const DashboardPage();
        break;
      case 1:
        page = const AppointmentsPage();
        break;
      case 2:
        page = const CalendarPage();
        break;
      case 3:
      default:
        page = const ProfilePage();
        break;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (i) => _onTap(context, i),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_note_outlined),
          label: 'Randevular',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: 'Takvim',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    );
  }
}
