import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'core/constants/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // راه‌اندازی Firebase
  await Firebase.initializeApp();

  // تنظیم orientation فقط Portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فتولند',
      debugShowCheckedModeBanner: false,

      // تنظیمات زبان فارسی
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),  // فارسی
        Locale('en', 'US'),  // انگلیسی fallback
      ],
      localizationsDelegates: const [

        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,

        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // تم برنامه
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,

        // تنظیمات فونت فارسی
        fontFamily: 'Vazirmatn', // بعداً فونت اضافه میکنیم
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Vazirmatn'),
        ),
        // تنظیمات AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // صفحه اول
      home: const SplashScreen(),
    );
  }
}