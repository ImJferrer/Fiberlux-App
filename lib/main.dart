import 'onboarding/splashscreen.dart';
import 'providers/SessionProvider.dart';
import 'providers/googleUser_provider.dart';
import 'providers/graph_socket_provider.dart';
import 'providers/nox_data_provider.dart';
import 'view/home.dart';
import 'view/main_screen.dart';
import 'widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'view/login.dart';
import 'onboarding/onboarding.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'providers/loader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

///////////////////////////////////////////////////////////////////////
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

Future<void> setupPushNotifications() async {
  // Solicitar permiso automáticamente (iOS y Android 13+)
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User permission status: ${settings.authorizationStatus}');

  // Otras configuraciones adicionales pueden ir aquí
}

Future getToken() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("Token: $token");
}

///////////////////////////////////////////////////////////////////////
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupPushNotifications();
  await getToken();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  final prefs = await SharedPreferences.getInstance();

  final onboardingViewModel = OnboardingViewModel();
  final showOnboarding = !(await onboardingViewModel.isOnboardingComplete());
  final isValidated = prefs.getBool('isValidated') ?? false;

  debugPrint('🏷️ seenOnboarding=$showOnboarding, isValidated=$isValidated');
  // En este ejemplo, si el usuario ya ha pasado el onboarding y se loguea,
  // la pantalla siguiente será el MainScreen (con el navbar).
  Widget initialScreen;
  if (showOnboarding) {
    initialScreen = OnboardingScreen();
  } else if (isValidated) {
    initialScreen = const MainScreen(); // <<–– aquí vas al home
  } else {
    initialScreen = const LoginScreen();
  }

  runApp(MyApp(initialScreen: initialScreen, prefs: prefs));
}

///////////////////////////////////////////////////////////////////////
class MyApp extends StatelessWidget {
  final Widget initialScreen;
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.initialScreen, required this.prefs})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingViewModel()),
        ChangeNotifierProvider(create: (_) => LoaderProvider()),
        ChangeNotifierProvider(create: (_) => NoxDataProvider()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => SessionProvider(prefs)),
        ChangeNotifierProvider(create: (_) => GoogleUserProvider()),
        ChangeNotifierProvider(create: (_) => GraphSocketProvider()),
      ],
      child: MaterialApp(
        title: 'FiberLux App',
        theme: ThemeData(
          primarySwatch: Colors.purple,
          primaryColor: const Color(0xFFA4238E),
        ),
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              Consumer<LoaderProvider>(
                builder: (context, loaderProvider, _) {
                  return loaderProvider.isLoading
                      ? const CustomLoader()
                      : const SizedBox.shrink();
                },
              ),
            ],
          );
        },
        home: SplashScreen(
          nextScreen: initialScreen,
        ), // Comenzar con el splash screen
      ),
    );
  }
}
