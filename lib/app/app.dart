import 'package:flutter/material.dart';

import '../ui/theme/app_theme.dart';
import 'router.dart';

class ApplicantApp extends StatelessWidget {
  const ApplicantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LDSP Applicant',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: buildAppTheme(),
    );
  }
}
