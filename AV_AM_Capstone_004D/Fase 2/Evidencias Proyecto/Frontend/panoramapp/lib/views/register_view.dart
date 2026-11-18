import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:capstone/service/auth_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rut = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _userType = 2;
  bool _passwordVisible = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _rut.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _validRut(String rut) {
    final parts = rut.toUpperCase().split('-');
    if (parts.length != 2) return false;

    final number = parts.first;
    final providedDigit = parts.last;
    var sum = 0;
    var factor = 2;

    for (var index = number.length - 1; index >= 0; index--) {
      sum += int.parse(number[index]) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }

    final remainder = 11 - (sum % 11);
    final expectedDigit = remainder == 11
        ? '0'
        : remainder == 10
            ? 'K'
            : remainder.toString();
    return providedDigit == expectedDigit;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final createdUser = await AuthService.register(
        name: _name.text,
        rut: _rut.text,
        email: _email.text,
        password: _password.text,
        userType: _userType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Usuario creado correctamente'
            '${createdUser.id.isEmpty ? '.' : '. ID asignado: ${createdUser.id}.'}'
            ' Ya puedes iniciar sesión.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible crear el usuario.'),
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
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa tu nombre'
                              : null,
                      decoration: _decoration(
                        'Nombre de usuario',
                        CupertinoIcons.person,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _rut,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: Colors.white),
                      maxLength: 10,
                      onChanged: (value) {
                        var digits = value
                            .replaceAll(RegExp(r'[^0-9kK]'), '')
                            .toUpperCase();
                        if (digits.length > 9) {
                          digits = digits.substring(0, 9);
                        }
                        final formatted = digits.length > 8
                            ? '${digits.substring(0, 8)}-${digits.substring(8)}'
                            : digits;
                        if (formatted != value) {
                          _rut.value = TextEditingValue(
                            text: formatted,
                            selection:
                                TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Ingresa tu RUT';
                        if (!RegExp(r'^\d{8}-[\dkK]$').hasMatch(text)) {
                          return 'Formato requerido: XXXXXXXX-X';
                        }
                        if (!_validRut(text)) {
                          return 'Ingresa un RUT válido';
                        }
                        return null;
                      },
                      decoration: _decoration(
                        'RUT',
                        CupertinoIcons.creditcard,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Ingresa tu correo';
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                      decoration: _decoration(
                        'Correo electrónico',
                        CupertinoIcons.mail,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value == null || value.length < 6
                              ? 'La contraseña debe tener al menos 6 caracteres'
                              : null,
                      decoration: _decoration(
                        'Contraseña',
                        CupertinoIcons.lock,
                      ).copyWith(
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) => value != _password.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                      decoration: _decoration(
                        'Confirmar contraseña',
                        CupertinoIcons.lock,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tipo de cuenta',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 2,
                          label: Text('Cliente'),
                          icon: Icon(CupertinoIcons.person),
                        ),
                        ButtonSegment(
                          value: 3,
                          label: Text('Organizador'),
                          icon: Icon(CupertinoIcons.calendar),
                        ),
                      ],
                      selected: {_userType},
                      onSelectionChanged: (value) {
                        setState(() => _userType = value.first);
                      },
                      style: const ButtonStyle(
                        foregroundColor:
                            WidgetStatePropertyAll(Colors.white),
                        backgroundColor:
                            WidgetStatePropertyAll(Color(0xFF202020)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _register,
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
                              'Crear cuenta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
