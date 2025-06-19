import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  SplashScreen({required this.nextScreen});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    print('🚀 initState: SplashScreen started');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('⏳ Post-frame callback triggered');
      Future.delayed(Duration(seconds: 2), () {
        if (!_hasNavigated && mounted) {
          print('⏱️ Splash done, navigating to next screen');
          _hasNavigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => widget.nextScreen),
          );
        } else {
          print('⚠️ Navigation already happened or widget not mounted');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    print('🖼️ build: Showing splash screen with logo');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/ttt_logo.png',
                height: 120,
              ),
              SizedBox(height: 20),
              Text(
                'The Training Theory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 10),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
