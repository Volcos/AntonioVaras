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
  bool _acceptedTerms = false;
  bool _acceptedTermsError = false;
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

    if (!_acceptedTerms) {
      setState(() => _acceptedTermsError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes aceptar los Términos, Condiciones y la Política de Privacidad de Datos para registrarte.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
                    const SizedBox(height: 20),

                    // Checklist Términos y Condiciones (Estándar Chile - Ley 19.628 / Internacional)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: _acceptedTermsError ? Colors.redAccent.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _acceptedTermsError
                            ? Border.all(color: Colors.redAccent)
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _acceptedTerms,
                              activeColor: Colors.pinkAccent,
                              side: BorderSide(
                                color: _acceptedTermsError ? Colors.redAccent : Colors.white60,
                                width: 2,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                  if (_acceptedTerms) _acceptedTermsError = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              children: [
                                const Text(
                                  'Acepto los ',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                GestureDetector(
                                  onTap: () => _showTermsDialog(context),
                                  child: const Text(
                                    'Términos y Condiciones',
                                    style: TextStyle(
                                      color: Colors.pinkAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' y la ',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                GestureDetector(
                                  onTap: () => _showPrivacyPolicyDialog(context),
                                  child: const Text(
                                    'Política de Privacidad de Datos',
                                    style: TextStyle(
                                      color: Colors.pinkAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' (Ley N.º 21.855 de Protección de Datos Personales en Chile).',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_acceptedTermsError)
                      const Padding(
                        padding: EdgeInsets.only(left: 36, top: 4),
                        child: Text(
                          'Debes aceptar los términos y condiciones para registrarte.',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 20),
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

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Términos y Condiciones de Uso',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Aceptación de los Términos\n'
                'Al registrarse en PanoramAPP, el usuario acepta estos términos regulados conforme a la legislación chilena aplicable e internacional.\n\n'
                '2. Registro de Usuario y Veracidad de Datos\n'
                'El usuario declara que los datos provistos (Nombre, RUT, Correo Electrónico) son auténticos y verídicos. Es responsabilidad del usuario mantener la confidencialidad de su contraseña.\n\n'
                '3. Uso Permitido de la Plataforma\n'
                'Queda prohibido el uso de la aplicación para difundir contenido ilegal, fraudulento, difamatorio o que vulnere derechos de propiedad intelectual de terceros.\n\n'
                '4. Organizadores de Eventos\n'
                'Los usuarios registrados como Organizadores declaran contar con los derechos y permisos necesarios para publicar y difundir información sobre los eventos publicados.\n\n'
                '5. Limitación de Responsabilidad\n'
                'PanoramAPP actúa como una plataforma informativa y de difusión. No se responsabiliza por cancelaciones o modificaciones de eventos realizadas por terceros organizadores.\n\n'
                '6. Modificaciones de los Términos\n'
                'Nos reservamos el derecho de modificar estos términos. Se notificará a los usuarios ante cambios sustanciales.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Política de Privacidad de Datos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Protección de Datos Personales (Chile - Ley N.º 21.855)\n\n'
                '1. Recolección de Datos\n'
                'PanoramAPP recolecta datos como Nombre, RUT y Correo Electrónico para la autenticación, seguridad y personalización de la experiencia del usuario.\n\n'
                '2. Finalidad del Tratamiento\n'
                'Los datos personales serán utilizados exclusivamente para:\n'
                ' • Gestionar su cuenta e identificación.\n'
                ' • Permitir el registro y creación de eventos.\n'
                ' • Enviar notificaciones sobre eventos de su interés.\n\n'
                '3. No Transferencia a Terceros\n'
                'Sus datos no serán vendidos, cedidos ni compartidos con terceros sin su consentimiento expreso, salvo requerimiento judicial o legal.\n\n'
                '4. Derechos ARCO y Principios de la Ley N.º 21.855\n'
                'Conforme a la Ley N.º 21.855 de Protección de Datos Personales en Chile, usted tiene derecho a acceder a sus datos, solicitar su modificación, portabilidad o exigir su eliminación del sistema en cualquier momento escribiendo a soporte.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }
}
