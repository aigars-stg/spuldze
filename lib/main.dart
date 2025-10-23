import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'services/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final cacheManager = await CacheManager.getInstance();
  final apiService = EleringApiService();

  runApp(
    SpuldzeApp(
      cacheManager: cacheManager,
      apiService: apiService,
    ),
  );
}

class SpuldzeApp extends StatelessWidget {
  final CacheManager cacheManager;
  final EleringApiService apiService;

  const SpuldzeApp({
    super.key,
    required this.cacheManager,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PriceProvider(
        apiService: apiService,
        cacheManager: cacheManager,
      ),
      child: MaterialApp(
        title: 'Spuldze',
        debugShowCheckedModeBanner: false,

        // Material 3 theme configuration
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),

        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),

        themeMode: ThemeMode.system,

        // Localization configuration
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        supportedLocales: const [
          Locale('en', ''), // English
          Locale('lv', ''), // Latvian
        ],

        home: const HomeScreen(),
      ),
    );
  }
}
