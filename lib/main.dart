import 'package:fiberlux_new_app/view/preticket_chat_screen.dart';

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
import 'widgets/remote_config_service.dart';
import 'package:flutter/services.dart';

// 👇 NUEVO: provider de notificaciones
import 'providers/notifications_provider.dart';

// 👇 NUEVO: navigatorKey global para usar contexto fuera de los widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

///////////////////////////////////////////////////////////////////////
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print('🔔 [BG] Mensaje en segundo plano recibido');
  print('🔔 [BG] messageId: ${message.messageId}');
  print('🔔 [BG] from: ${message.from}');
  print('🔔 [BG] notification.title: ${message.notification?.title}');
  print('🔔 [BG] notification.body: ${message.notification?.body}');
  print('🔔 [BG] data: ${message.data}');

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
}

Future getToken() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("Token: $token");
}

// 👇 Opcional: navegación según el contenido de la notificación
void handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;

  // Si mandas una ruta desde el backend, por ejemplo: "route": "/tickets"
  final route = data['route']?.toString();

  // Si más adelante quieres cosas específicas (chat, preticket, etc),
  // puedes leer otros campos aquí:
  // final preticketIdStr = data['preticket_id']?.toString();
  // final preticketId = preticketIdStr != null ? int.tryParse(preticketIdStr) : null;

  if (route != null && route.isNotEmpty) {
    navigatorKey.currentState?.pushNamed(route);
  } else {
    // Fallback: podrías abrir una pantalla de notificaciones internas, por ejemplo:
    // navigatorKey.currentState?.push(
    //   MaterialPageRoute(builder: (_) => NotificationsScreen()),
    // );
  }
}

void _handleNotificationNavigation(RemoteMessage message, BuildContext ctx) {
  final data = message.data;

  final type = data['type']?.toString();
  final preticketStr =
      data['preticket']?.toString() ?? data['preticket_id']?.toString();
  final preticketId = preticketStr != null ? int.tryParse(preticketStr) : null;

  debugPrint('🧭 [handleNav] type=$type, preticketId=$preticketId, data=$data');

  if (type == 'preticket_message' && preticketId != null && preticketId > 0) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => PreticketChatScreen(
          preticketId: preticketId,
          ticketCode: data['ticket_code']?.toString(), // si algún día lo mandas
        ),
      ),
    );
    return;
  }

  // aquí luego puedes rutear otros tipos por data['route']
}

/// 👇 NUEVO: enganchar FCM con el NotificationsProvider
void setupFcmListeners() {
  // 🔔 App en primer plano
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('🟢 [onMessage] Notificación recibida en primer plano');
    debugPrint('🟢 [onMessage] messageId: ${message.messageId}');
    debugPrint('🟢 [onMessage] from: ${message.from}');
    debugPrint(
      '🟢 [onMessage] notification.title: ${message.notification?.title}',
    );
    debugPrint(
      '🟢 [onMessage] notification.body: ${message.notification?.body}',
    );
    debugPrint('🟢 [onMessage] data: ${message.data}');

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    ctx.read<NotificationsProvider>().addFromRemoteMessage(message);
  });

  // 📲 Usuario toca la noti con la app en background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🟡 [onMessageOpenedApp] data: ${message.data}');
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    ctx.read<NotificationsProvider>().addFromRemoteMessage(message);
    _handleNotificationNavigation(message, ctx); // 👈 AQUÍ navegamos
  });

  // 🚀 App estaba CERRADA y se abrió tocando la noti
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message == null) return;
    debugPrint('🟠 [getInitialMessage] data: ${message.data}');
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    ctx.read<NotificationsProvider>().addFromRemoteMessage(message);
    _handleNotificationNavigation(message, ctx); // 👈 también aquí
  });
}

///////////////////////////////////////////////////////////////////////
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await RemoteConfigService.i.init();
  await setupPushNotifications();
  await getToken();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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

  Widget initialScreen;
  if (showOnboarding) {
    initialScreen = OnboardingScreen();
  } else if (isValidated) {
    initialScreen = const MainScreen();
  } else {
    initialScreen = const LoginScreen();
  }

  // 👉 Montamos la app
  runApp(MyApp(initialScreen: initialScreen, prefs: prefs));

  // 👉 Y AHORA enganchamos los listeners de FCM
  setupFcmListeners();

  // 👉 Además manejamos el caso en que la app se abrió desde cerrada por una notificación
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Opcional: también la guardas en el provider
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ctx.read<NotificationsProvider>().addFromRemoteMessage(initialMessage);
      }
      handleNotificationNavigation(initialMessage);
    }
  });
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
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: MaterialApp(
        title: 'Fiberlux App',
        navigatorKey: navigatorKey, // 👈 para usar en listeners FCM
        theme: ThemeData(
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.black,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
          ),
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
        debugShowCheckedModeBanner: false,
        home: SplashScreen(nextScreen: initialScreen),
      ),
    );
  }
}
