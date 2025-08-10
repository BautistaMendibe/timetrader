import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../routes.dart';
import '../widgets/top_snack_bar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuth() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isLoginMode) {
          // Login
          await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        } else {
          // Create account
          await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Ocurrió un error';

        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No se encontró una cuenta con este email';
            break;
          case 'wrong-password':
            errorMessage = 'Contraseña incorrecta';
            break;
          case 'email-already-in-use':
            errorMessage = 'Ya existe una cuenta con este email';
            break;
          case 'weak-password':
            errorMessage = 'La contraseña es demasiado débil';
            break;
          case 'invalid-email':
            errorMessage = 'Email inválido';
            break;
        }

        if (mounted) {
          TopSnackBar.showError(context: context, message: errorMessage);
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.showError(context: context, message: 'Error de conexión');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Primero, verificar si el usuario ya está autenticado
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
          'No se pudieron obtener los tokens de autenticación de Google',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al iniciar sesión con Google';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'Ya existe una cuenta con este email usando otro método de autenticación';
          break;
        case 'invalid-credential':
          errorMessage = 'Credenciales de Google inválidas';
          break;
        case 'operation-not-allowed':
          errorMessage = 'El inicio de sesión con Google no está habilitado';
          break;
        case 'user-disabled':
          errorMessage = 'La cuenta de usuario ha sido deshabilitada';
          break;
        case 'user-not-found':
          errorMessage = 'No se encontró la cuenta de usuario';
          break;
        case 'wrong-password':
          errorMessage = 'Contraseña incorrecta';
          break;
        case 'invalid-verification-code':
          errorMessage = 'Código de verificación inválido';
          break;
        case 'invalid-verification-id':
          errorMessage = 'ID de verificación inválido';
          break;
        default:
          errorMessage = 'Error de autenticación: ${e.code}';
      }

      if (mounted) {
        TopSnackBar.showError(context: context, message: errorMessage);
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');

      String errorMessage = 'Error al conectar con Google';

      if (e.toString().contains('network')) {
        errorMessage = 'Error de conexión a internet';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Inicio de sesión cancelado';
      } else if (e.toString().contains('popup')) {
        errorMessage = 'Error al abrir la ventana de Google';
      }

      if (mounted) {
        TopSnackBar.showError(context: context, message: errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48, // 48 for padding
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo and Title
                      Image.asset(
                        'assets/imgs/icono.png',
                        height: 80,
                        width: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'TimeTrader',
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Practica cualquier set up en segundos,\ndirectamente desde tu móvil',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Form Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF475569),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontFamily: 'Inter',
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'Inter',
                                ),
                                prefixIcon: const Icon(
                                  Icons.email,
                                  color: Color(0xFF94A3B8),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu email';
                                }
                                if (!value.contains('@')) {
                                  return 'Por favor ingresa un email válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontFamily: 'Inter',
                              ),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'Inter',
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xFF94A3B8),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu contraseña';
                                }
                                if (value.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Auth Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  shadowColor: const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.3),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF0F172A),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLoginMode
                                            ? 'Iniciar Sesión'
                                            : 'Crear Cuenta',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'O',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Google Sign-In Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _handleGoogleSignIn,
                                icon: Image.asset(
                                  'assets/imgs/icono-google.png',
                                  height: 24,
                                ),
                                label: const Text(
                                  'Continuar con Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFF8FAFC),
                                  side: const BorderSide(
                                    color: Color(0xFF475569),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle Mode Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _toggleMode,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF22C55E),
                                  side: const BorderSide(
                                    color: Color(0xFF22C55E),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                                child: Text(
                                  _isLoginMode
                                      ? 'Crear Cuenta'
                                      : 'Ya tengo cuenta',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}
