import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_form_screen.dart';

class LupaPasswordScreen extends StatelessWidget {
  const LupaPasswordScreen({super.key, this.api});
  final ApiService? api;
  @override
  Widget build(BuildContext context) =>
      AuthFormScreen(mode: AuthFormMode.reset, api: api);
}
