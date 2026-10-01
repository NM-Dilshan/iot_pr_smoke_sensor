import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/session_gate.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_user_profile_repository.dart';
import 'services/firestore_test_history_repository.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeStartApp());
}

Future<Widget>? _productionStartup;
Future<Widget> initializeSafeStart() =>
    _productionStartup ??= _initializeFirebase().catchError((Object error) {
      _productionStartup = null;
      throw error;
    });

Future<Widget> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuthService(FirebaseAuth.instance, firestore);
  return SessionGate(
    auth: auth,
    profiles: (uid) =>
        FirestoreUserProfileRepository(firestore, uid, auth.email!),
    history: (uid) => FirestoreTestHistoryRepository(firestore, uid),
  );
}

class SafeStartApp extends StatefulWidget {
  const SafeStartApp({super.key, this.initialize = initializeSafeStart});
  final Future<Widget> Function() initialize;
  @override
  State<SafeStartApp> createState() => _SafeStartAppState();
}

class _SafeStartAppState extends State<SafeStartApp> {
  late Future<Widget> _startup;
  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<Widget> _initialize() async {
    final results = await Future.wait<Object>([
      widget.initialize().timeout(const Duration(seconds: 25)),
      Future<void>.delayed(const Duration(milliseconds: 2600))
          .then((_) => true),
    ]);
    return results.first as Widget;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: snapshot.hasError
            ? Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SafeStart could not connect to Firebase. Please try again.',
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _startup = _initialize();
                        }),
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              )
            : const SplashScreen(navigate: false),
      );
    },
  );
}
