import 'package:flutter/material.dart';

import '../dashboard_page.dart';
import '../pages/appointments.dart';
import '../pages/calendar.dart';
import '../pages/profile.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:flutter/services.dart';

class MainNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onIndexSelected;

  const MainNavBar({
    super.key,
    required this.currentIndex,
    this.onIndexSelected,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Feedback.forTap(context);
    if (onIndexSelected != null) {
      onIndexSelected!(index);
      return;
    }
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
    final loc = AppLocalizations.of(context)!;
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (i) => _onTap(context, i),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_outlined),
          label: loc.dashboardHome,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.event_note_outlined),
          label: loc.appointmentsTitle,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_today_outlined),
          label: loc.dashboardCalendar,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          label: loc.profileTitle,
        ),
      ],
    );
  }
}
