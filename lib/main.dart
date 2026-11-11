import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

// Top-level background handler. It runs in a separate isolate, so it cannot
// touch widget state. It must be top-level and marked as an entry point.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('BACKGROUND handler: id=${message.messageId} data=${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Lab',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _lastHandler = 'none';
  int _receiptCount = 0;
  String _asset = 'default';
  String _diagnostic = '';
  String _token = 'loading...';

  @override
  void initState() {
    super.initState();
    _setupMessaging();
  }

  Future<void> _setupMessaging() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission();
    debugPrint('Permission status: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    debugPrint('FCM TOKEN: $token');
    if (mounted) setState(() => _token = token ?? 'null');

    // Foreground: app is open.
    FirebaseMessaging.onMessage.listen((m) => _handle(m, 'onMessage'));

    // Background tap: app was in the background and the notification was tapped.
    FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _handle(m, 'onMessageOpenedApp'));

    // Cold start: app was terminated and launched by tapping the notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handle(initial, 'getInitialMessage');
  }

  void _handle(RemoteMessage message, String handlerName) {
    final action = message.data['action'];
    final asset = message.data['asset'];

    // Only update the UI when the payload is valid. Otherwise keep the
    // previous state and show a diagnostic.
    final valid = action == 'update_ui' &&
        (asset == 'promo' || asset == 'default');

    if (!mounted) return;
    setState(() {
      _receiptCount++;
      _lastHandler = handlerName;
      if (valid) {
        _asset = asset!;
        _diagnostic = 'Accepted payload';
      } else {
        _diagnostic =
            'Rejected payload: action=$action asset=$asset (kept $_asset)';
      }
    });
    debugPrint('$handlerName valid=$valid count=$_receiptCount');
  }

  @override
  Widget build(BuildContext context) {
    final isPromo = _asset == 'promo';
    return Scaffold(
      appBar: AppBar(title: const Text('FCM Lab')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Last handler: $_lastHandler',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Receipt count: $_receiptCount',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Asset: $_asset', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Container(
                width: 160,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPromo ? Colors.orange : Colors.blueGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isPromo ? 'PROMO' : 'DEFAULT',
                    style: const TextStyle(color: Colors.white, fontSize: 20)),
              ),
              const SizedBox(height: 16),
              Text(_diagnostic, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SelectableText('Token: $_token',
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}