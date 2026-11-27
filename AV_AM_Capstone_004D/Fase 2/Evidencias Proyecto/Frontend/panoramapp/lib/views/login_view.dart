import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:capstone/service/auth_service.dart';
import 'package:capstone/service/push_notification_service.dart';
import 'package:capstone/views/Home.dart';
import 'package:capstone/views/register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.login(
        name: _nameController.text,
        password: _passwordController.text,
      );
      String? notificationError;
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await PushNotificationService.registerDevice(token);
        } catch (error) {
          notificationError = error.toString();
        }
      }
      if (!mounted) return;
      if (notificationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sesión iniciada, pero no se pudo registrar el dispositivo: '
              '$notificationError',
            ),
          ),
        );
      }
      Navigator.of(
        context,
      ).pushReplacement(CupertinoPageRoute(builder: (_) => const Home()));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TimeoutException
                ? 'El servidor tardó demasiado en responder.'
                : error is SocketException
                ? 'No hay conexión con el servidor.'
                : 'No fue posible conectar con el servidor: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      margin: const EdgeInsets.only(bottom: 28),
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE91E63), Color(0xFF263238)],
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.location_solid,
                        color: Colors.white,
                        size: 58,
                      ),
                    ),
                    const Text(
                      'PanoramAPP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inicia sesión para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Ingresa tu usuario';
                        return null;
                      },
                      decoration: _decoration('Usuario', CupertinoIcons.person),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Ingresa tu contraseña'
                          : null,
                      decoration: _decoration('Contraseña', CupertinoIcons.lock)
                          .copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? CupertinoIcons.eye_slash
                                    : CupertinoIcons.eye,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const RegisterView(),
                          ),
                        );
                      },
                      child: const Text(
                        'Crear cuenta',
                        style: TextStyle(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          CupertinoPageRoute(builder: (_) => const Home()),
                          (_) => false,
                        );
                      },
                      child: const Text(
                        'Continuar como invitado',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF202020),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.pinkAccent),
      ),
    );
  }
}
