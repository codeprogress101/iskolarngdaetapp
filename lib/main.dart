import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/services/local_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');

    final supabaseUrl = _readEnvValue(<String>[
      'SUPABASE_URL',
      'LDSS_SUPABASE_URL',
    ]);
    final supabaseAnonKey = _readEnvValue(<String>[
      'SUPABASE_ANON_KEY',
      'LDSS_SUPABASE_ANON_KEY',
    ]);

    _validateSupabaseUrl(supabaseUrl);
    if (supabaseAnonKey.isEmpty) {
      throw const FormatException(
        'Supabase anon key is missing. Set SUPABASE_ANON_KEY or LDSS_SUPABASE_ANON_KEY in .env.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    await LocalNotificationsService.instance.initialize();

    runApp(const ApplicantApp());
  } catch (e, st) {
    debugPrint('Startup configuration error: $e');
    debugPrintStack(stackTrace: st);
    runApp(
      StartupErrorApp(
        message: e.toString().replaceFirst('FormatException: ', ''),
      ),
    );
  }
}

String _readEnvValue(List<String> keys) {
  for (final key in keys) {
    final value = (dotenv.env[key] ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

void _validateSupabaseUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
    throw const FormatException(
      'Supabase URL is invalid or missing. Set SUPABASE_URL or LDSS_SUPABASE_URL in .env.',
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Configuration Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
