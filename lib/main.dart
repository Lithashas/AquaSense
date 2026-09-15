import 'dart:async';

import 'package:flutter/material.dart';

import 'dashboard.dart';

void main() {
  runApp(const AquaSenseApp());
}

class AquaSenseApp extends StatefulWidget {
  const AquaSenseApp({super.key});

  @override
  State<AquaSenseApp> createState() => _AquaSenseAppState();
}

class _AquaSenseAppState extends State<AquaSenseApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _resetOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _resetOnResume = true;
    } else if (state == AppLifecycleState.resumed && _resetOnResume) {
      _resetOnResume = false;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'AquaSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12B8C4),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1FBFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF073B4C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shadowColor: const Color(0x26073B4C),
          surfaceTintColor: const Color(0xFFE2F8FA),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF087F8C),
          unselectedItemColor: Color(0xFF78909C),
          backgroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF087F8C),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF8FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEAF7F8),
                    Color(0xFFD5F1F2),
                    Color(0xFFB8E7E8),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF12B8C4).withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AquaSense',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF073B4C),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Smart Water Monitoring',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF087F8C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 180,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _goToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF12B8C4),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF087F8C).withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6BE0E2),
          Color(0xFF12B8C4),
          Color(0xFF087F8C),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final wavePath = Path()
      ..moveTo(0, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.18,
        size.width * 0.25,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.68,
        size.width * 0.5,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.18,
        size.width * 0.75,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.68,
        size.width,
        size.height * 0.42,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(wavePath, basePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..style = PaintingStyle.fill;

    final highlightPath = Path()
      ..moveTo(0, size.height * 0.52)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.28,
        size.width * 0.34,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.72,
        size.width * 0.66,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.24,
        size.width,
        size.height * 0.52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
