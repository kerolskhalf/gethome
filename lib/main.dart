// lib/main.dart - FIXED VERSION with UserSession Loading
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/buyer_dashboard_screen.dart';
import 'screens/seller_dashboard_screen.dart';
import 'utils/user_session.dart';

void main() {
  runApp(const GetHomeApp());
}

class GetHomeApp extends StatelessWidget {
  const GetHomeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GetHome - Real Estate App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',

        // Enhanced theme for better UI consistency
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a237e),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF234E70),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF234E70)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1a237e), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),

      // FIXED: Use SplashScreen to load UserSession before showing main content
      home: const SplashScreen(),
    );
  }
}

// FIXED: New SplashScreen class to handle UserSession loading
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash screen for a minimum duration
    await Future.delayed(const Duration(seconds: 2));

    // Load user session from SharedPreferences
    bool hasSession = await UserSession.loadUserSession();

    if (!mounted) return;

    if (hasSession && UserSession.isLoggedIn()) {
      // User is logged in, navigate to appropriate dashboard
      print('=== USER SESSION LOADED ===');
      UserSession.debugPrintSession();

      final currentRole = UserSession.getCurrentUserRole().toLowerCase();
      print('Navigating to dashboard for role: $currentRole');

      if (currentRole == 'seller') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SellerDashboardFocused(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const BuyerDashboardScreen(),
          ),
        );
      }
    } else {
      // No valid session, go to login
      print('No valid session found, going to login');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a237e),
              Color(0xFF234E70),
              Color(0xFF305F80),
            ],
            stops: [0.2, 0.6, 0.9],
          ),
        ),
        child:  Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home_work,
                  size: 64,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 32),

              // App Name
              Text(
                'GetHome',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              SizedBox(height: 16),

              Text(
                'Your Real Estate Solution',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),

              SizedBox(height: 48),

              // Loading Indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}