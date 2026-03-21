import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'Data/storage/appConfig.dart';
import 'Data/api/apiClient.dart';
import 'Data/providers/appPreferencesProvider.dart';
import 'Data/providers/authProvider.dart';
import 'Data/repositories/appointmentRepository.dart';
import 'Data/repositories/authRepository.dart';
import 'Data/repositories/caseRepository.dart';
import 'Data/repositories/chatRepository.dart';
import 'Data/repositories/knowledgeRepository.dart';
import 'Data/repositories/lawyerRepository.dart';
import 'Data/repositories/lockerRepository.dart';
import 'Data/repositories/notificationRepository.dart';
import 'Data/repositories/paymentRepository.dart';
import 'Data/repositories/videoRepository.dart';
import 'Data/storage/secureStorage.dart';
import 'Models/user.dart';
import 'Screens/clientTabScreen.dart';
import 'Screens/lawyerTabScreen.dart';
import 'Screens/splashScreen.dart';
import 'Screens/welcomeScreen.dart';
import 'Theme/appTheme.dart';
import 'gen_l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LawPointBootstrap());
}

class LawPointBootstrap extends StatelessWidget {
  const LawPointBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SecureStorage>(create: (_) => SecureStorage()),
        ProxyProvider<SecureStorage, ApiClient>(
          update: (_, storage, __) => ApiClient(AppConfig.baseUrl, storage),
        ),
        ProxyProvider2<ApiClient, SecureStorage, AuthRepository>(
          update: (_, api, storage, __) => AuthRepository(api, storage),
        ),
        ProxyProvider<ApiClient, LawyerRepository>(
            update: (_, api, __) => LawyerRepository(api)),
        ProxyProvider<ApiClient, AppointmentRepository>(
            update: (_, api, __) => AppointmentRepository(api)),
        ProxyProvider<ApiClient, ChatRepository>(
            update: (_, api, __) => ChatRepository(api)),
        ProxyProvider<ApiClient, LockerRepository>(
            update: (_, api, __) => LockerRepository(api)),
        ProxyProvider<ApiClient, CaseRepository>(
            update: (_, api, __) => CaseRepository(api)),
        ProxyProvider<ApiClient, KnowledgeRepository>(
            update: (_, api, __) => KnowledgeRepository(api)),
        ProxyProvider<ApiClient, PaymentRepository>(
            update: (_, api, __) => PaymentRepository(api)),
        ProxyProvider<ApiClient, NotificationRepository>(
            update: (_, api, __) => NotificationRepository(api)),
        ProxyProvider<ApiClient, VideoRepository>(
            update: (_, api, __) => VideoRepository(api)),
        ChangeNotifierProvider<AppPreferencesProvider>(
          create: (_) => AppPreferencesProvider()..load(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>())..init(),
        ),
      ],
      child: const LawPointApp(),
    );
  }
}

class LawPointApp extends StatelessWidget {
  const LawPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferencesProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LawPoint',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: prefs.themeMode,
      locale: prefs.locale,
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.initializing) {
      return const SplashScreen();
    }

    if (auth.status == AuthStatus.unauthenticated || auth.user == null) {
      return const WelcomeScreen();
    }

    if (auth.user!.role == UserRole.lawyer) {
      return const LawyerTabScreen();
    }

    if (auth.user!.role == UserRole.admin) {
      return const WelcomeScreen(adminMode: true);
    }

    return const ClientTabScreen();
  }
}
