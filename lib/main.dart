import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_8/loginpage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        fontFamily: "assets/fonts/Poppins-BoldItalic.ttf",
      ),
      debugShowCheckedModeBanner: false,
      title: 'Splash Demo',
      home: const SplashView(),
    );
  }
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _State();
}

class _State extends State<SplashView> {

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      Get.off(Loginpage());
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.yellow,
        body: Center(
          child: SizedBox(
            height: screenHeight * 0.25, // responsive height
            width: screenWidth * 0.6,    // responsive width
            child: Image.asset(
              "assets/images/img_2.png",
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
