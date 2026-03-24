import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

enum ApplicantTab { home, applications, notifications, profile }

class ApplicantShellScaffold extends StatelessWidget {
  const ApplicantShellScaffold({
    required this.title,
    required this.tab,
    required this.body,
    this.actions = const <Widget>[],
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final ApplicantTab tab;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  int get _currentIndex {
    switch (tab) {
      case ApplicantTab.home:
        return 0;
      case ApplicantTab.applications:
        return 1;
      case ApplicantTab.notifications:
        return 2;
      case ApplicantTab.profile:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Applications',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
              return;
            case 1:
              context.go('/applications');
              return;
            case 2:
              context.go('/notifications');
              return;
            case 3:
              context.go('/profile');
              return;
          }
        },
      ),
    );
  }
}

class ScreenSection extends StatelessWidget {
  const ScreenSection({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
