import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:project_8/Newpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> fetchData() async {
    final url = Uri.parse('https://dummyjson.com/auth/login');

    if (usernameController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      Get.snackbar("Error", "Please enter username and password",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    if (usernameController.text.trim() != "emilys" ||
        passwordController.text.trim() != "emilyspass") {
      Get.snackbar("Login Failed", "Wrong username or password",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveToken(data['token'] ?? "");
        Get.off(() => Newpage());
      } else {
        Get.snackbar("Login Failed", "Invalid credentials from server",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [

              /// 🔵 Top Curved Container
              Row(
                children: [
                  Container(
                    height: size.height * 0.30,
                    width: size.width * 0.75,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(1200),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "Login here",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: size.height * 0.08),

              /// 🟣 Bottom Login Section
              Container(
                height: size.height * 0.60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade800,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(130),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text("Username",
                        style: TextStyle(fontSize: 20, color: Colors.white)),
                    const SizedBox(height: 10),

                    _inputBox(
                      controller: usernameController,
                      hint: "Enter your username",
                      width: size.width,
                    ),

                    const SizedBox(height: 15),

                    const Text("Password",
                        style: TextStyle(fontSize: 20, color: Colors.white)),
                    const SizedBox(height: 10),

                    _inputBox(
                      controller: passwordController,
                      hint: "Enter your password",
                      width: size.width,
                      obscure: true,
                    ),

                    const SizedBox(height: 25),

                    Center(
                      child: ElevatedButton(
                        onPressed: fetchData,
                        child: const Text(
                          "LOGIN",
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 Reusable Input Box (same UI)
  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    required double width,
    bool obscure = false,
  }) {
    return Container(
      height: 45,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
        ),
      ),
    );
  }
}
