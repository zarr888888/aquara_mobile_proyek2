import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_form_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.api, this.onAuthenticated});
  final ApiService? api;
  final VoidCallback? onAuthenticated;
  @override
  Widget build(BuildContext context) => AuthFormScreen(
    mode: AuthFormMode.login,
    api: api,
    onAuthenticated: onAuthenticated,
  );
}
