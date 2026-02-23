import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/forgot_password_email_screen.dart';
import 'package:ios_tiretest_ai/Screens/otp_verification.dart';
import 'package:ios_tiretest_ai/Screens/splash_screen.dart';
import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';


const String kBaseUrl = 'http://54.162.208.215/backend';
const String kGoogleLoginUrl = '$kBaseUrl/api/google-login';

const kWebClientId =
    '51634811181-jg539oa4982i8da5ee4tefrc93qdcqnd.apps.googleusercontent.com';
const kIosClientId =
    '51634811181-31i98nff6qra35idd89kknsc36qsspa5.apps.googleusercontent.com';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int tab = 0; // 0 = login, 1 = signup
  bool remember = true;

  // SEPARATE form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // login
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;

  // signup
  final _nameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _signupObscure = true;
  bool _confirmObscure = true;

  // Google Sign-In (classic API)
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    serverClientId: kWebClientId,
    clientId: Platform.isIOS ? kIosClientId : null,
  );
  bool _googleLoading = false;

  // Storage
  final box = GetStorage();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _nameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // =============== SEPARATE VALIDATIONS ===============

  String? _validateLoginEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email';
  }

  String? _validateSignupEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email address';
  }

  String? _validateLoginPassword(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Password is required';
    return null;
  }

  String? _validateSignupPassword(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Password is required';
    if (s.length < 6) return 'Use at least 6 characters';
    return null;
  }

  String? _required(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  // =============== SNACK RULE ===============
  // ✅ ONLY show snackbar for invalid/wrong credentials (login fail)
  bool _isInvalidCredentialsMessage(String msg) {
    final m = msg.trim().toLowerCase();
    if (m.contains('invalid') && m.contains('credential')) return true;
    if (m.contains('invalid email') || m.contains('invalid password')) return true;
    if (m.contains('wrong email') || m.contains('wrong password')) return true;
    if (m.contains('incorrect') && (m.contains('password') || m.contains('email'))) return true;
    if (m.contains('email or password') && (m.contains('invalid') || m.contains('incorrect') || m.contains('wrong'))) {
      return true;
    }
    if (m == 'invalid credentials' ||
        m == 'invalid credentials.' ||
        m == 'invalid email or password' ||
        m == 'invalid email or password.' ||
        m == 'incorrect email or password' ||
        m == 'incorrect email or password.') {
      return true;
    }
    return false;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // =============== SUBMIT HANDLERS ===============

  void _submitLogin() {
    if (!_loginFormKey.currentState!.validate()) return;

    final bloc = context.read<AuthBloc>();

    // ✅ clear previous error (important)
    bloc.add(const ClearAuthError());

    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim(); // ✅ FIX: trim password too

    // ignore: avoid_print
    print("LOGIN => email=$email pass=$pass");

    bloc.add(
      LoginRequested(
        email: email,
        password: pass,
      ),
    );
  }

  void _submitSignup() {
    if (!_signupFormKey.currentState!.validate()) return;

    final bloc = context.read<AuthBloc>();

    // ✅ clear previous error (important)
    bloc.add(const ClearAuthError());

    final full = _nameCtrl.text.trim();
    String first = full, last = '';
    final sp = full.split(RegExp(r'\s+'));
    if (sp.length > 1) {
      first = sp.first;
      last = sp.sublist(1).join(' ');
    }

    final email = _signupEmailCtrl.text.trim();
    final pass = _signupPassCtrl.text.trim(); // ✅ safe

    // ignore: avoid_print
    print("SIGNUP => first=$first last=$last email=$email pass=$pass");

    bloc.add(
      SignupRequested(
        firstName: first,
        lastName: last,
        email: email,
        password: pass,
      ),
    );
  }

  Future<void> _handleGoogleTap() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);

    try {
      gsi.GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final gsi.GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;
      final String? accessToken = auth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        _snack('Google auth failed: idToken not available.');
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final payload = {
        "idToken": idToken,
        "accessToken": accessToken ?? "",
        "email": account.email,
        "name": account.displayName ?? '',
        "googleId": account.id,
      };

      // ignore: avoid_print
      print("GOOGLE PAYLOAD => $payload");

      final res = await http.post(
        Uri.parse(kGoogleLoginUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final token = body['token'];
        final user = body['user'];

        if (token == null || user == null) {
          _snack('Invalid server response.');
        } else {
          await box.write('token', token);
          await box.write('userId', user['userId']);
          await box.write('email', user['email']);
          await box.write('loginProvider', 'google');

          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }
      } else {
        // ✅ no snack for general errors
        String msg = 'Login failed (${res.statusCode})';
        try {
          final d = jsonDecode(res.body);
          if (d['message'] != null) msg = d['message'].toString();
        } catch (_) {}
        print("GOOGLE LOGIN FAIL (no snack) => $msg");
      }
    } on PlatformException catch (e) {
      _snack('Google sign-in error: ${e.message ?? e.code}');
    } catch (e) {
      // ignore: avoid_print
      print("GOOGLE EXCEPTION => $e");
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.loginStatus != c.loginStatus ||
          p.signupStatus != c.signupStatus ||
          p.error != c.error,
      listener: (context, state) {
        // ✅ IMPORTANT FIX:
        // If login is SUCCESS, ignore any stale "invalid credentials" message
        // and navigate immediately.
        if (state.loginStatus == AuthStatus.success) {
          context.read<AuthBloc>().add(const ClearAuthError()); // ✅ clear stale error
          box.write("token", state.loginResponse?.token);

          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
          return;
        }

        // ✅ ONLY show snackbar if login actually FAILED and message is invalid creds
        if (state.loginStatus == AuthStatus.failure &&
            state.error != null &&
            state.error!.trim().isNotEmpty &&
            _isInvalidCredentialsMessage(state.error!)) {
          _snack(state.error!.trim());
          return;
        }

        // ✅ Keep your OTP navigation behavior EXACTLY same (no snack)
        if (state.error != null && state.error!.trim().isNotEmpty) {
          final msg = state.error!.trim();
          print("AUTH MESSAGE (no snack) => $msg");

          if (msg == "Signup successful. OTP sent successfully!") {
            context.read<AuthBloc>().add(const OtpIssuedNow());
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  targetText: _signupEmailCtrl.text.trim(),
                ),
              ),
            );
            return;
          }

          if (msg == "Email not verified. Please verify OTP first.") {
            context.read<AuthBloc>().add(const OtpIssuedNow());
            context.read<AuthBloc>().add(
                  ForgotPasswordVerifyEmailRequested(
                    email: _loginEmailCtrl.text.trim(),
                  ),
                );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  targetText: _loginEmailCtrl.text.trim(),
                ),
              ),
            );
            return;
          }
        }

        // signup success (unchanged)
        if (state.signupStatus == AuthStatus.success) {
          // unchanged
        }
      },
      builder: (context, state) {
        final loginLoading = state.loginStatus == AuthStatus.loading;
        final signupLoading = state.signupStatus == AuthStatus.loading;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F3F5),
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/bottom_bg.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(-1.0, 1.0),
                  color: Colors.black.withOpacity(0.10),
                ),
              ),
              Positioned.fill(
                child: Image.asset(
                  'assets/upper_bg.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width < 380 ? 16 : 22,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.75),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AuthToggle(
                                  activeIndex: tab,
                                  onChanged: (i) => setState(() => tab = i),
                                ),
                                const SizedBox(height: 18),

                                if (tab == 0)
                                  Form(
                                    key: _loginFormKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _InputCard(
                                          hint: 'Email',
                                          icon: 'assets/email_icon.png',
                                          controller: _loginEmailCtrl,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: _validateLoginEmail,
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Password',
                                          icon: 'assets/password_icon.png',
                                          controller: _loginPassCtrl,
                                          obscureText: _loginObscure,
                                          onToggleObscure: () => setState(
                                            () => _loginObscure = !_loginObscure,
                                          ),
                                          validator: _validateLoginPassword,
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: TextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ForgotPasswordEmailScreen(),
                                                    ),
                                                  );
                                                },
                                                child: const Text(
                                                  'Forgot password',
                                                  style: TextStyle(
                                                    fontFamily: 'ClashGrotesk',
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: 43,
                                          width: MediaQuery.of(context).size.width * 0.35,
                                          child: _PrimaryGradientButton(
                                            text: loginLoading
                                                ? 'Please wait...'
                                                : 'Login'.toUpperCase(),
                                            onPressed: loginLoading ? null : _submitLogin,
                                            loading: loginLoading,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        const CenterLabelDivider(label: 'Or login with'),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Google',
                                                asset: 'assets/google-logo.png',
                                                loading: _googleLoading,
                                                onTap: _handleGoogleTap,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Apple',
                                                asset: 'assets/apple-logo.png',
                                                onTap: () {},
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _FooterSwitch(
                                          prompt: "Don’t have an account? ",
                                          action: "Create an account",
                                          onTap: () => setState(() => tab = 1),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Form(
                                    key: _signupFormKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _InputCard(
                                          hint: 'Name',
                                          icon: 'assets/name_icon.png',
                                          controller: _nameCtrl,
                                          validator: (v) => _required(v, 'Name'),
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Email Address',
                                          icon: 'assets/email_icon.png',
                                          controller: _signupEmailCtrl,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: _validateSignupEmail,
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Password',
                                          icon: 'assets/password_icon.png',
                                          controller: _signupPassCtrl,
                                          obscureText: _signupObscure,
                                          onToggleObscure: () => setState(
                                            () => _signupObscure = !_signupObscure,
                                          ),
                                          validator: _validateSignupPassword,
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Confirm Password',
                                          icon: 'assets/password_icon.png',
                                          controller: _confirmCtrl,
                                          obscureText: _confirmObscure,
                                          onToggleObscure: () => setState(
                                            () => _confirmObscure = !_confirmObscure,
                                          ),
                                          validator: (v) {
                                            final err = _validateSignupPassword(v);
                                            if (err != null) return err;
                                            if ((v ?? '') != _signupPassCtrl.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 43,
                                          width: MediaQuery.of(context).size.width * 0.35,
                                          child: _PrimaryGradientButton(
                                            text: signupLoading
                                                ? 'Please wait...'
                                                : 'SignUp'.toUpperCase(),
                                            onPressed: signupLoading ? null : _submitSignup,
                                            loading: signupLoading,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        const CenterLabelDivider(label: 'Or login with'),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Google',
                                                asset: 'assets/google-logo.png',
                                                loading: _googleLoading,
                                                onTap: _handleGoogleTap,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Apple',
                                                asset: 'assets/apple-logo.png',
                                                onTap: () {},
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _FooterSwitch(
                                          prompt: "Already have an account? ",
                                          action: "Login",
                                          onTap: () => setState(() => tab = 0),
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ===================== WIDGETS (unchanged) ===================== */

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.activeIndex, required this.onChanged});
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: AnimatedContainer(
                height: 48,
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: activeIndex == 0 ? _grad : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onChanged(0),
                  child: Center(
                    child: Text(
                      'Login'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: activeIndex == 0
                            ? Colors.white
                            : const Color(0xFF0AA2FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AnimatedContainer(
                height: 48,
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: activeIndex == 1 ? _grad : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onChanged(1),
                  child: Center(
                    child: Text(
                      'SignUp'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: activeIndex == 1
                            ? Colors.white
                            : const Color(0xFF0AA2FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.hint,
    required this.icon,
    this.controller,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.onToggleObscure,
  });

  final String hint;
  final String icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Image.asset(
            icon,
            height: 17,
            width: 17,
            color: const Color(0xFF1B1B1B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.8 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _grad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.label,
    required this.asset,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final String asset;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Image.asset(asset, height: 22, width: 22),
              const SizedBox(width: 10),
              Text(
                loading ? 'Please wait…' : label,
                style: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 16,
                  color: Color(0xFF1B1B1B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterSwitch extends StatelessWidget {
  const _FooterSwitch({
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14.5,
            color: Color(0xFF1B1B1B),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5,
              color: Color(0xFF1E9BFF),
            ),
          ),
        ),
      ],
    );
  }
}

class CenterLabelDivider extends StatelessWidget {
  const CenterLabelDivider({
    super.key,
    required this.label,
    this.lineColor = const Color(0xFFBDBDBD),
    this.textColor = const Color(0xFF616161),
    this.thickness = 1.0,
    this.dotSize = 6.0,
    this.gap = 10.0,
    this.textStyle,
  });

  final String label;
  final Color lineColor;
  final Color textColor;
  final double thickness;
  final double dotSize;
  final double gap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ts = textStyle ??
        const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF616161),
          fontFamily: 'ClashGrotesk',
        );

    Widget dot() => Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
        );

    return Row(
      children: [
        Expanded(
          child: Divider(color: lineColor, thickness: thickness, height: dotSize),
        ),
        SizedBox(width: gap),
        dot(),
        const SizedBox(width: 8),
        Text(label, style: ts),
        const SizedBox(width: 8),
        dot(),
        SizedBox(width: gap),
        Expanded(
          child: Divider(color: lineColor, thickness: thickness, height: dotSize),
        ),
      ],
    );
  }
}


/*

const String kBaseUrl = 'http://54.162.208.215/backend';
const String kGoogleLoginUrl = '$kBaseUrl/api/google-login';

const kWebClientId =
    '51634811181-jg539oa4982i8da5ee4tefrc93qdcqnd.apps.googleusercontent.com';
const kIosClientId =
    '51634811181-31i98nff6qra35idd89kknsc36qsspa5.apps.googleusercontent.com';
late final GoogleSignIn googleSignIn;






class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int tab = 0; // 0 = login, 1 = signup
  bool remember = true;

  // SEPARATE form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // login
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;

  // signup
  final _nameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _signupObscure = true;
  bool _confirmObscure = true;

  // Google Sign-In (classic API)
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    serverClientId: kWebClientId,
    clientId: Platform.isIOS ? kIosClientId : null,
  );
  bool _googleLoading = false;

  // Storage
  final box = GetStorage();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _nameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // =============== SEPARATE VALIDATIONS ===============

  String? _validateLoginEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email';
  }

  String? _validateSignupEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email address';
  }

  String? _validateLoginPassword(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    return null;
  }

  String? _validateSignupPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 6) return 'Use at least 6 characters';
    return null;
  }

  String? _required(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  // =============== SUBMIT HANDLERS ===============

  void _submitLogin() {
    if (!_loginFormKey.currentState!.validate()) return;

    final bloc = context.read<AuthBloc>();

    // ✅ clear previous error (important)
    bloc.add(const ClearAuthError());

    // ignore: avoid_print
    print("LOGIN => email=${_loginEmailCtrl.text.trim()} pass=${_loginPassCtrl.text}");

    bloc.add(
      LoginRequested(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPassCtrl.text,
      ),
    );
  }

  void _submitSignup() {
    if (!_signupFormKey.currentState!.validate()) return;

    final bloc = context.read<AuthBloc>();

    // ✅ clear previous error (important)
    bloc.add(const ClearAuthError());

    final full = _nameCtrl.text.trim();
    String first = full, last = '';
    final sp = full.split(RegExp(r'\s+'));
    if (sp.length > 1) {
      first = sp.first;
      last = sp.sublist(1).join(' ');
    }

    // ignore: avoid_print
    print("SIGNUP => first=$first last=$last email=${_signupEmailCtrl.text.trim()} pass=${_signupPassCtrl.text}");

    bloc.add(
      SignupRequested(
        firstName: first,
        lastName: last,
        email: _signupEmailCtrl.text.trim(),
        password: _signupPassCtrl.text,
      ),
    );

    // ❌ REMOVED: do NOT switch tab here
    // setState(() => tab = 0);
  }

  Future<void> _handleGoogleTap() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);

    try {
      gsi.GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final gsi.GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;
      final String? accessToken = auth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        _snack('Google auth failed: idToken not available.');
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final payload = {
        "idToken": idToken,
        "accessToken": accessToken ?? "",
        "email": account.email,
        "name": account.displayName ?? '',
        "googleId": account.id,
      };

      // ignore: avoid_print
      print("GOOGLE PAYLOAD => $payload");

      final res = await http.post(
        Uri.parse(kGoogleLoginUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final token = body['token'];
        final user = body['user'];

        if (token == null || user == null) {
          _snack('Invalid server response.');
        } else {
          await box.write('token', token);
          await box.write('userId', user['userId']);
          await box.write('email', user['email']);
          await box.write('loginProvider', 'google');

          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }
      } else {
        String msg = 'Login failed (${res.statusCode})';
        try {
          final d = jsonDecode(res.body);
          if (d['message'] != null) msg = d['message'].toString();
        } catch (_) {}
        _snack(msg);
      }
    } on PlatformException catch (e) {
      _snack('Google sign-in error: ${e.message ?? e.code}');
    } catch (e) {
      // ignore: avoid_print
      print("GOOGLE EXCEPTION => $e");
      _snack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.loginStatus != c.loginStatus ||
          p.signupStatus != c.signupStatus ||
          p.error != c.error,
      listener: (context, state) {
        // show error
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error!)));
              print("SIGNUP PRINT ${state.error!}");
                 print("SIGNUP PRINT ${state.error!}");
                    print("SIGNUP PRINT ${state.error!}");
//               if(state.error! == "OTP sent successfully!"){
// Navigator.push(context, MaterialPageRoute(builder: (context)=> OtpVerificationScreen(targetText: '')));
//               }
if (state.error == "Signup successful. OTP sent successfully!") {
  context.read<AuthBloc>().add(const OtpIssuedNow());

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OtpVerificationScreen(
        targetText: _signupEmailCtrl.text.trim(), // show email
      ),
    ),
  );
}

if (state.error == "Email not verified. Please verify OTP first.") {

  context.read<AuthBloc>().add(const OtpIssuedNow());
   context.read<AuthBloc>().add(ForgotPasswordVerifyEmailRequested(email:_loginEmailCtrl.text.trim()));

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OtpVerificationScreen(
        targetText: _loginEmailCtrl.text.trim(), 
      ),
    ),
  );
}

        }

        // login success
        if (state.loginStatus == AuthStatus.success) {
          box.write("token", state.loginResponse?.token);

          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }

   

        // ✅ signup success (ONLY HERE switch tab)
        if (state.signupStatus == AuthStatus.success) {
          // if(state.error == ""){

          // }
          print("IMRAN KHAN PTI ${state.error}");
             print("IMRAN KHAN PTI ${state.error}");
                print("IMRAN KHAN PTI ${state.error}");
                   print("IMRAN KHAN PTI ${state.error}");


          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Signup successful. Please login.')),
          // );

          // // ✅ switch to login after success
          // setState(() => tab = 0);

          // // ✅ optional: clear signup fields
          // _nameCtrl.clear();
          // _signupEmailCtrl.clear();
          // _signupPassCtrl.clear();
          // _confirmCtrl.clear();
        }
      },
      builder: (context, state) {
        final loginLoading = state.loginStatus == AuthStatus.loading;
        final signupLoading = state.signupStatus == AuthStatus.loading;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F3F5),
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/bottom_bg.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(-1.0, 1.0),
                  color: Colors.black.withOpacity(0.10),
                ),
              ),
              Positioned.fill(
                child: Image.asset(
                  'assets/upper_bg.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width < 380 ? 16 : 22,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.75),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AuthToggle(
                                  activeIndex: tab,
                                  onChanged: (i) => setState(() => tab = i),
                                ),
                                const SizedBox(height: 18),

                                if (tab == 0)
                                  Form(
                                    key: _loginFormKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _InputCard(
                                          hint: 'Email',
                                          icon: 'assets/email_icon.png',
                                          controller: _loginEmailCtrl,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: _validateLoginEmail,
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Password',
                                          icon: 'assets/password_icon.png',
                                          controller: _loginPassCtrl,
                                          obscureText: _loginObscure,
                                          onToggleObscure: () => setState(
                                            () => _loginObscure = !_loginObscure,
                                          ),
                                          validator: _validateLoginPassword,
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                          Padding(
  padding: const EdgeInsets.only(left: 8.0),
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ForgotPasswordEmailScreen(),
        ),
      );
    },
    child: const Text(
      'Forgot password',
      style: TextStyle(
        fontFamily: 'ClashGrotesk',
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
),

                                          ],
                                        ),
                                        SizedBox(
                                        height: 43,
                                          width: MediaQuery.of(context).size.width * 0.35,
                                          child: _PrimaryGradientButton(
                                            text: loginLoading ? 'Please wait...' : 'Login'.toUpperCase(),
                                            onPressed: loginLoading ? null : _submitLogin,
                                            loading: loginLoading,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        const CenterLabelDivider(label: 'Or login with'),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Google',
                                                asset: 'assets/google-logo.png',
                                                loading: _googleLoading,
                                                onTap: _handleGoogleTap,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Apple',
                                                asset: 'assets/apple-logo.png',
                                                onTap: () {},
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _FooterSwitch(
                                          prompt: "Don’t have an account? ",
                                          action: "Create an account",
                                          onTap: () => setState(() => tab = 1),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Form(
                                    key: _signupFormKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _InputCard(
                                          hint: 'Name',
                                          icon: 'assets/name_icon.png',
                                          controller: _nameCtrl,
                                          validator: (v) => _required(v, 'Name'),
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Email Address',
                                          icon: 'assets/email_icon.png',
                                          controller: _signupEmailCtrl,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: _validateSignupEmail,
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Password',
                                          icon: 'assets/password_icon.png',
                                          controller: _signupPassCtrl,
                                          obscureText: _signupObscure,
                                          onToggleObscure: () => setState(
                                            () => _signupObscure = !_signupObscure,
                                          ),
                                          validator: _validateSignupPassword,
                                        ),
                                        const SizedBox(height: 12),
                                        _InputCard(
                                          hint: 'Confirm Password',
                                          icon: 'assets/password_icon.png',
                                          controller: _confirmCtrl,
                                          obscureText: _confirmObscure,
                                          onToggleObscure: () => setState(
                                            () => _confirmObscure = !_confirmObscure,
                                          ),
                                          validator: (v) {
                                            final err = _validateSignupPassword(v);
                                            if (err != null) return err;
                                            if (v != _signupPassCtrl.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 43,
                                          width: MediaQuery.of(context).size.width * 0.35,
                                          child: _PrimaryGradientButton(
                                            text: signupLoading ? 'Please wait...' : 'SignUp'.toUpperCase(),
                                            onPressed: signupLoading ? null : _submitSignup,
                                            loading: signupLoading,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        const CenterLabelDivider(label: 'Or login with'),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Google',
                                                asset: 'assets/google-logo.png',
                                                loading: _googleLoading,
                                                onTap: _handleGoogleTap,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: _BrandButton(
                                                label: 'Apple',
                                                asset: 'assets/apple-logo.png',
                                                onTap: () {},
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _FooterSwitch(
                                          prompt: "Already have an account? ",
                                          action: "Login",
                                          onTap: () => setState(() => tab = 0),
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ===================== WIDGETS (unchanged) ===================== */

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.activeIndex, required this.onChanged});
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: AnimatedContainer(
                height: 48,
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: activeIndex == 0 ? _grad : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onChanged(0),
                  child: Center(
                    child: Text(
                      'Login'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: activeIndex == 0
                            ? Colors.white
                            : const Color(0xFF0AA2FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AnimatedContainer(
                height: 48,
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: activeIndex == 1 ? _grad : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onChanged(1),
                  child: Center(
                    child: Text(
                      'SignUp'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: activeIndex == 1
                            ? Colors.white
                            : const Color(0xFF0AA2FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.hint,
    required this.icon,
    this.controller,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.onToggleObscure,
  });

  final String hint;
  final String icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Image.asset(
            icon,
            height: 17,
            width: 17,
            color: const Color(0xFF1B1B1B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.8 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _grad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.label,
    required this.asset,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final String asset;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Image.asset(asset, height: 22, width: 22),
              const SizedBox(width: 10),
              Text(
                loading ? 'Please wait…' : label,
                style: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 16,
                  color: Color(0xFF1B1B1B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterSwitch extends StatelessWidget {
  const _FooterSwitch({
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14.5,
            color: Color(0xFF1B1B1B),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5,
              color: Color(0xFF1E9BFF),
            ),
          ),
        ),
      ],
    );
  }
}

class CenterLabelDivider extends StatelessWidget {
  const CenterLabelDivider({
    super.key,
    required this.label,
    this.lineColor = const Color(0xFFBDBDBD),
    this.textColor = const Color(0xFF616161),
    this.thickness = 1.0,
    this.dotSize = 6.0,
    this.gap = 10.0,
    this.textStyle,
  });

  final String label;
  final Color lineColor;
  final Color textColor;
  final double thickness;
  final double dotSize;
  final double gap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ts = textStyle ??
        const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF616161),
          fontFamily: 'ClashGrotesk',
        );

    Widget dot() => Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
        );

    return Row(
      children: [
        Expanded(
          child: Divider(color: lineColor, thickness: thickness, height: dotSize),
        ),
        SizedBox(width: gap),
        dot(),
        const SizedBox(width: 8),
        Text(label, style: ts),
        const SizedBox(width: 8),
        dot(),
        SizedBox(width: gap),
        Expanded(
          child: Divider(color: lineColor, thickness: thickness, height: dotSize),
        ),
      ],
    );
  }
}



*/







// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_sign_in/google_sign_in.dart' as gsi;
// import 'package:http/http.dart' as http;

// import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
// import 'package:ios_tiretest_ai/Screens/forgot_password_email_screen.dart';
// import 'package:ios_tiretest_ai/Screens/otp_verification.dart';
// import 'package:ios_tiretest_ai/Screens/splash_screen.dart';

// // ===================== CONFIG =====================

// const String kBaseUrl = 'http://54.162.208.215/backend';
// const String kGoogleLoginUrl = '$kBaseUrl/api/google-login';

// const kWebClientId =
//     '51634811181-jg539oa4982i8da5ee4tefrc93qdcqnd.apps.googleusercontent.com';
// const kIosClientId =
//     '51634811181-31i98nff6qra35idd89kknsc36qsspa5.apps.googleusercontent.com';

// class AuthScreen extends StatefulWidget {
//   const AuthScreen({super.key});
//   @override
//   State<AuthScreen> createState() => _AuthScreenState();
// }

// class _AuthScreenState extends State<AuthScreen> {
//   int tab = 0; // 0 = login, 1 = signup
//   bool remember = true;

//   // SEPARATE form keys
//   final _loginFormKey = GlobalKey<FormState>();
//   final _signupFormKey = GlobalKey<FormState>();

//   // login
//   final _loginEmailCtrl = TextEditingController();
//   final _loginPassCtrl = TextEditingController();
//   bool _loginObscure = true;

//   // signup
//   final _nameCtrl = TextEditingController();
//   final _signupEmailCtrl = TextEditingController();
//   final _signupPassCtrl = TextEditingController();
//   final _confirmCtrl = TextEditingController();
//   bool _signupObscure = true;
//   bool _confirmObscure = true;

//   // Google Sign-In
//   final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn(
//     scopes: const <String>['email', 'profile'],
//     serverClientId: kWebClientId,
//     clientId: Platform.isIOS ? kIosClientId : null,
//   );
//   bool _googleLoading = false;

//   // Storage
//   final box = GetStorage();

//   // ✅ ONLY ADDITION: stop auto-login after OTP verify
//   bool _successDialogShowing = false;
//   bool _blockAnyAutoLogin = false; // becomes true after OTP verify success

//   @override
//   void dispose() {
//     _loginEmailCtrl.dispose();
//     _loginPassCtrl.dispose();
//     _nameCtrl.dispose();
//     _signupEmailCtrl.dispose();
//     _signupPassCtrl.dispose();
//     _confirmCtrl.dispose();
//     super.dispose();
//   }

//   // ===================== VALIDATION =====================

//   String? _validateLoginEmail(String? v) {
//     final s = v?.trim() ?? '';
//     if (s.isEmpty) return 'Email is required';
//     final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
//     return ok ? null : 'Enter a valid email';
//   }

//   String? _validateSignupEmail(String? v) {
//     final s = v?.trim() ?? '';
//     if (s.isEmpty) return 'Email is required';
//     final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
//     return ok ? null : 'Enter a valid email address';
//   }

//   String? _validateLoginPassword(String? v) {
//     if ((v ?? '').isEmpty) return 'Password is required';
//     return null;
//   }

//   String? _validateSignupPassword(String? v) {
//     final s = v ?? '';
//     if (s.isEmpty) return 'Password is required';
//     if (s.length < 6) return 'Use at least 6 characters';
//     return null;
//   }

//   String? _required(String? v, String label) {
//     if ((v ?? '').trim().isEmpty) return '$label is required';
//     return null;
//   }

//   // ===================== HELPERS =====================

//   void _snack(String msg) =>
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

//   Future<void> _forceLogoutAndBlockAutoLogin() async {
//     // ✅ IMPORTANT: remove EVERYTHING that could keep user logged in
//     // (some apps read multiple keys across the project)
//     await box.remove('token');
//     await box.remove('auth_token');
//     await box.remove('access_token');
//     await box.remove('refresh_token');

//     await box.remove('userId');
//     await box.remove('email');
//     await box.remove('name');
//     await box.remove('loginProvider');

//     // ✅ block any later automatic navigation triggered by existing states
//     _blockAnyAutoLogin = true;
//   }

//   bool _isOtpVerifySuccessMessage(String? msg) {
//     if (msg == null) return false;
//     final m = msg.trim().toLowerCase();

//     // ✅ add more variants if your backend uses different text
//     return m == 'otp verified successfully' ||
//         m == 'otp verified successfully!' ||
//         m == 'account verified successfully' ||
//         m == 'account verified successfully!' ||
//         m.contains('verified successfully');
//   }

//   Future<void> _showAccountCreatedDialog() async {
//     if (!mounted || _successDialogShowing) return;
//     _successDialogShowing = true;

//     await showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) {
//         return AlertDialog(
//           title: const Text(
//             'Success',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           content: const Text(
//             'Account created successfully.\nPlease login now.',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(ctx).pop(),
//               child: const Text(
//                 'OK',
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );

//     _successDialogShowing = false;
//     if (!mounted) return;

//     // ✅ go to login tab (NO AUTO LOGIN)
//     setState(() => tab = 0);

//     // optional cleanup (was already in your comments, not functional change)
//     _nameCtrl.clear();
//     _signupEmailCtrl.clear();
//     _signupPassCtrl.clear();
//     _confirmCtrl.clear();
//   }

//   // ===================== SUBMIT HANDLERS =====================

//   void _submitLogin() {
//     if (!_loginFormKey.currentState!.validate()) return;

//     final bloc = context.read<AuthBloc>();
//     bloc.add(const ClearAuthError());

//     // ignore: avoid_print
//     print("LOGIN => email=${_loginEmailCtrl.text.trim()} pass=${_loginPassCtrl.text}");

//     bloc.add(
//       LoginRequested(
//         email: _loginEmailCtrl.text.trim(),
//         password: _loginPassCtrl.text,
//       ),
//     );
//   }

//   void _submitSignup() {
//     if (!_signupFormKey.currentState!.validate()) return;

//     final bloc = context.read<AuthBloc>();
//     bloc.add(const ClearAuthError());

//     final full = _nameCtrl.text.trim();
//     String first = full, last = '';
//     final sp = full.split(RegExp(r'\s+'));
//     if (sp.length > 1) {
//       first = sp.first;
//       last = sp.sublist(1).join(' ');
//     }

//     // ignore: avoid_print
//     print("SIGNUP => first=$first last=$last email=${_signupEmailCtrl.text.trim()} pass=${_signupPassCtrl.text}");

//     bloc.add(
//       SignupRequested(
//         firstName: first,
//         lastName: last,
//         email: _signupEmailCtrl.text.trim(),
//         password: _signupPassCtrl.text,
//       ),
//     );
//   }

//   Future<void> _handleGoogleTap() async {
//     if (_googleLoading) return;
//     setState(() => _googleLoading = true);

//     try {
//       gsi.GoogleSignInAccount? account = _googleSignIn.currentUser;
//       account ??= await _googleSignIn.signIn();

//       if (account == null) {
//         if (mounted) setState(() => _googleLoading = false);
//         return;
//       }

//       final gsi.GoogleSignInAuthentication auth = await account.authentication;

//       final String? idToken = auth.idToken;
//       final String? accessToken = auth.accessToken;

//       if (idToken == null || idToken.isEmpty) {
//         _snack('Google auth failed: idToken not available.');
//         if (mounted) setState(() => _googleLoading = false);
//         return;
//       }

//       final payload = {
//         "idToken": idToken,
//         "accessToken": accessToken ?? "",
//         "email": account.email,
//         "name": account.displayName ?? '',
//         "googleId": account.id,
//       };

//       // ignore: avoid_print
//       print("GOOGLE PAYLOAD => $payload");

//       final res = await http.post(
//         Uri.parse(kGoogleLoginUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(payload),
//       );

//       if (res.statusCode == 200) {
//         final body = jsonDecode(res.body);
//         final token = body['token'];
//         final user = body['user'];

//         if (token == null || user == null) {
//           _snack('Invalid server response.');
//         } else {
//           await box.write('token', token);
//           await box.write('userId', user['userId']);
//           await box.write('email', user['email']);
//           await box.write('loginProvider', 'google');

//           if (!mounted) return;
//           Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
//             MaterialPageRoute(builder: (_) => const SplashScreen()),
//             (route) => false,
//           );
//         }
//       } else {
//         String msg = 'Login failed (${res.statusCode})';
//         try {
//           final d = jsonDecode(res.body);
//           if (d['message'] != null) msg = d['message'].toString();
//         } catch (_) {}
//         _snack(msg);
//       }
//     } on PlatformException catch (e) {
//       _snack('Google sign-in error: ${e.message ?? e.code}');
//     } catch (e) {
//       // ignore: avoid_print
//       print("GOOGLE EXCEPTION => $e");
//       _snack('Unexpected error: $e');
//     } finally {
//       if (mounted) setState(() => _googleLoading = false);
//     }
//   }

//   // ===================== UI =====================

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;

//     return BlocConsumer<AuthBloc, AuthState>(
//       listenWhen: (p, c) =>
//           p.loginStatus != c.loginStatus ||
//           p.signupStatus != c.signupStatus ||
//           p.error != c.error,
//       listener: (context, state) async {
//         // ✅ OTP VERIFY SUCCESS => FORCE LOGOUT + SHOW DIALOG (NO LOGIN)
//         if (_isOtpVerifySuccessMessage(state.error)) {
//           await _forceLogoutAndBlockAutoLogin();
//           if (!mounted) return;

//           // clear error so it doesn't trigger again
//           context.read<AuthBloc>().add(const ClearAuthError());

//           await _showAccountCreatedDialog();
//           return;
//         }

//         // show error (your existing behavior)
//         if (state.error != null && state.error!.isNotEmpty) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(SnackBar(content: Text(state.error!)));

//           // ignore: avoid_print
//           print("SIGNUP PRINT ${state.error!}");
//           // ignore: avoid_print
//           print("SIGNUP PRINT ${state.error!}");
//           // ignore: avoid_print
//           print("SIGNUP PRINT ${state.error!}");

//           if (state.error == "Signup successful. OTP sent successfully!") {
//             context.read<AuthBloc>().add(const OtpIssuedNow());

//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => OtpVerificationScreen(
//                   targetText: _signupEmailCtrl.text.trim(),
//                 ),
//               ),
//             );
//             return;
//           }

//           if (state.error == "Email not verified. Please verify OTP first.") {
//             context.read<AuthBloc>().add(const OtpIssuedNow());
//             context
//                 .read<AuthBloc>()
//                 .add(ForgotPasswordVerifyEmailRequested(
//                   email: _loginEmailCtrl.text.trim(),
//                 ));

//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => OtpVerificationScreen(
//                   targetText: _loginEmailCtrl.text.trim(),
//                 ),
//               ),
//             );
//             return;
//           }
//         }

//         // ✅ login success (ONLY when user explicitly logs in)
//         // ✅ BUT block if OTP flow set the flag
//         if (state.loginStatus == AuthStatus.success && !_blockAnyAutoLogin) {
//           box.write("token", state.loginResponse?.token);

//           Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
//             MaterialPageRoute(builder: (_) => const SplashScreen()),
//             (route) => false,
//           );
//           return;
//         }

//         // signup success (unchanged)
//         if (state.signupStatus == AuthStatus.success) {
//           // unchanged
//           return;
//         }
//       },
//       builder: (context, state) {
//         final loginLoading = state.loginStatus == AuthStatus.loading;
//         final signupLoading = state.signupStatus == AuthStatus.loading;

//         return Scaffold(
//           backgroundColor: const Color(0xFFF2F3F5),
//           body: Stack(
//             children: [
//               Positioned.fill(
//                 child: Image.asset(
//                   'assets/bottom_bg.png',
//                   fit: BoxFit.cover,
//                   alignment: const Alignment(-1.0, 1.0),
//                   color: Colors.black.withOpacity(0.10),
//                 ),
//               ),
//               Positioned.fill(
//                 child: Image.asset(
//                   'assets/upper_bg.png',
//                   fit: BoxFit.cover,
//                   alignment: const Alignment(0, -0.2),
//                 ),
//               ),
//               SafeArea(
//                 child: Center(
//                   child: Padding(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: size.width < 380 ? 16 : 22,
//                     ),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(28),
//                       child: BackdropFilter(
//                         filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                         child: Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.45),
//                             borderRadius: BorderRadius.circular(28),
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.75),
//                               width: 1,
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.04),
//                                 blurRadius: 18,
//                                 offset: const Offset(0, 10),
//                               ),
//                             ],
//                           ),
//                           child: SingleChildScrollView(
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 _AuthToggle(
//                                   activeIndex: tab,
//                                   onChanged: (i) => setState(() => tab = i),
//                                 ),
//                                 const SizedBox(height: 18),

//                                 if (tab == 0)
//                                   Form(
//                                     key: _loginFormKey,
//                                     child: Column(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         _InputCard(
//                                           hint: 'Email',
//                                           icon: 'assets/email_icon.png',
//                                           controller: _loginEmailCtrl,
//                                           keyboardType:
//                                               TextInputType.emailAddress,
//                                           validator: _validateLoginEmail,
//                                         ),
//                                         const SizedBox(height: 12),
//                                         _InputCard(
//                                           hint: 'Password',
//                                           icon: 'assets/password_icon.png',
//                                           controller: _loginPassCtrl,
//                                           obscureText: _loginObscure,
//                                           onToggleObscure: () => setState(
//                                             () => _loginObscure =
//                                                 !_loginObscure,
//                                           ),
//                                           validator: _validateLoginPassword,
//                                         ),
//                                         const SizedBox(height: 7),
//                                         Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.end,
//                                           children: [
//                                             Padding(
//                                               padding: const EdgeInsets.only(
//                                                   left: 8.0),
//                                               child: TextButton(
//                                                 onPressed: () {
//                                                   Navigator.push(
//                                                     context,
//                                                     MaterialPageRoute(
//                                                       builder: (_) =>
//                                                           const ForgotPasswordEmailScreen(),
//                                                     ),
//                                                   );
//                                                 },
//                                                 child: const Text(
//                                                   'Forgot password',
//                                                   style: TextStyle(
//                                                     fontFamily:
//                                                         'ClashGrotesk',
//                                                     fontSize: 14.5,
//                                                     fontWeight:
//                                                         FontWeight.w700,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         SizedBox(
//                                           height: 43,
//                                           width: MediaQuery.of(context)
//                                                   .size
//                                                   .width *
//                                               0.35,
//                                           child: _PrimaryGradientButton(
//                                             text: loginLoading
//                                                 ? 'Please wait...'
//                                                 : 'LOGIN',
//                                             onPressed: loginLoading
//                                                 ? null
//                                                 : _submitLogin,
//                                             loading: loginLoading,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 18),
//                                         const CenterLabelDivider(
//                                             label: 'Or login with'),
//                                         const SizedBox(height: 14),
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: _BrandButton(
//                                                 label: 'Google',
//                                                 asset:
//                                                     'assets/google-logo.png',
//                                                 loading: _googleLoading,
//                                                 onTap: _handleGoogleTap,
//                                               ),
//                                             ),
//                                             const SizedBox(width: 14),
//                                             Expanded(
//                                               child: _BrandButton(
//                                                 label: 'Apple',
//                                                 asset: 'assets/apple-logo.png',
//                                                 onTap: () {},
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 18),
//                                         _FooterSwitch(
//                                           prompt:
//                                               "Don’t have an account? ",
//                                           action: "Create an account",
//                                           onTap: () =>
//                                               setState(() => tab = 1),
//                                         ),
//                                       ],
//                                     ),
//                                   )
//                                 else
//                                   Form(
//                                     key: _signupFormKey,
//                                     child: Column(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         _InputCard(
//                                           hint: 'Name',
//                                           icon: 'assets/name_icon.png',
//                                           controller: _nameCtrl,
//                                           validator: (v) =>
//                                               _required(v, 'Name'),
//                                         ),
//                                         const SizedBox(height: 12),
//                                         _InputCard(
//                                           hint: 'Email Address',
//                                           icon: 'assets/email_icon.png',
//                                           controller: _signupEmailCtrl,
//                                           keyboardType:
//                                               TextInputType.emailAddress,
//                                           validator: _validateSignupEmail,
//                                         ),
//                                         const SizedBox(height: 12),
//                                         _InputCard(
//                                           hint: 'Password',
//                                           icon: 'assets/password_icon.png',
//                                           controller: _signupPassCtrl,
//                                           obscureText: _signupObscure,
//                                           onToggleObscure: () => setState(
//                                             () => _signupObscure =
//                                                 !_signupObscure,
//                                           ),
//                                           validator: _validateSignupPassword,
//                                         ),
//                                         const SizedBox(height: 12),
//                                         _InputCard(
//                                           hint: 'Confirm Password',
//                                           icon: 'assets/password_icon.png',
//                                           controller: _confirmCtrl,
//                                           obscureText: _confirmObscure,
//                                           onToggleObscure: () => setState(
//                                             () => _confirmObscure =
//                                                 !_confirmObscure,
//                                           ),
//                                           validator: (v) {
//                                             final err =
//                                                 _validateSignupPassword(v);
//                                             if (err != null) return err;
//                                             if (v != _signupPassCtrl.text) {
//                                               return 'Passwords do not match';
//                                             }
//                                             return null;
//                                           },
//                                         ),
//                                         const SizedBox(height: 16),
//                                         SizedBox(
//                                           height: 43,
//                                           width: MediaQuery.of(context)
//                                                   .size
//                                                   .width *
//                                               0.35,
//                                           child: _PrimaryGradientButton(
//                                             text: signupLoading
//                                                 ? 'Please wait...'
//                                                 : 'SIGNUP',
//                                             onPressed: signupLoading
//                                                 ? null
//                                                 : _submitSignup,
//                                             loading: signupLoading,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 18),
//                                         const CenterLabelDivider(
//                                             label: 'Or login with'),
//                                         const SizedBox(height: 14),
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: _BrandButton(
//                                                 label: 'Google',
//                                                 asset:
//                                                     'assets/google-logo.png',
//                                                 loading: _googleLoading,
//                                                 onTap: _handleGoogleTap,
//                                               ),
//                                             ),
//                                             const SizedBox(width: 14),
//                                             Expanded(
//                                               child: _BrandButton(
//                                                 label: 'Apple',
//                                                 asset: 'assets/apple-logo.png',
//                                                 onTap: () {},
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 18),
//                                         _FooterSwitch(
//                                           prompt:
//                                               "Already have an account? ",
//                                           action: "Login",
//                                           onTap: () =>
//                                               setState(() => tab = 0),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// /* ===================== WIDGETS (unchanged) ===================== */

// class _AuthToggle extends StatelessWidget {
//   const _AuthToggle({required this.activeIndex, required this.onChanged});
//   final int activeIndex;
//   final ValueChanged<int> onChanged;

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 44,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(28),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 16,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(0),
//               child: AnimatedContainer(
//                 height: 48,
//                 duration: const Duration(milliseconds: 220),
//                 decoration: BoxDecoration(
//                   gradient: activeIndex == 0 ? _grad : null,
//                   borderRadius: BorderRadius.circular(22),
//                 ),
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(22),
//                   onTap: () => onChanged(0),
//                   child: Center(
//                     child: Text(
//                       'LOGIN'.toUpperCase(),
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 18,
//                         fontWeight: FontWeight.w900,
//                         color: activeIndex == 0
//                             ? Colors.white
//                             : const Color(0xFF0AA2FF),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(2),
//               child: AnimatedContainer(
//                 height: 48,
//                 duration: const Duration(milliseconds: 220),
//                 decoration: BoxDecoration(
//                   gradient: activeIndex == 1 ? _grad : null,
//                   borderRadius: BorderRadius.circular(22),
//                 ),
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(22),
//                   onTap: () => onChanged(1),
//                   child: Center(
//                     child: Text(
//                       'SignUp'.toUpperCase(),
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 18,
//                         fontWeight: FontWeight.w900,
//                         color: activeIndex == 1
//                             ? Colors.white
//                             : const Color(0xFF0AA2FF),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InputCard extends StatelessWidget {
//   const _InputCard({
//     required this.hint,
//     required this.icon,
//     this.controller,
//     this.keyboardType,
//     this.validator,
//     this.obscureText = false,
//     this.onToggleObscure,
//   });

//   final String hint;
//   final String icon;
//   final TextEditingController? controller;
//   final TextInputType? keyboardType;
//   final String? Function(String?)? validator;
//   final bool obscureText;
//   final VoidCallback? onToggleObscure;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 56,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           const SizedBox(width: 14),
//           Image.asset(
//             icon,
//             height: 17,
//             width: 17,
//             color: const Color(0xFF1B1B1B),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: TextFormField(
//               style: const TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 color: Colors.black,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 1,
//               ),
//               controller: controller,
//               keyboardType: keyboardType,
//               validator: validator,
//               obscureText: obscureText,
//               decoration: InputDecoration(
//                 hintText: hint,
//                 border: InputBorder.none,
//                 isCollapsed: true,
//                 hintStyle: const TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   color: Colors.black,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ),
//           if (onToggleObscure != null)
//             IconButton(
//               onPressed: onToggleObscure,
//               icon: Icon(
//                 obscureText
//                     ? Icons.visibility_off_outlined
//                     : Icons.visibility_outlined,
//                 size: 22,
//                 color: const Color(0xFF1B1B1B),
//               ),
//             ),
//           const SizedBox(width: 6),
//         ],
//       ),
//     );
//   }
// }

// class _PrimaryGradientButton extends StatelessWidget {
//   const _PrimaryGradientButton({
//     required this.text,
//     required this.onPressed,
//     this.loading = false,
//   });

//   final String text;
//   final VoidCallback? onPressed;
//   final bool loading;

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     final disabled = loading || onPressed == null;

//     return Opacity(
//       opacity: disabled ? 0.8 : 1,
//       child: Container(
//         height: 54,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(28),
//           gradient: _grad,
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFF7F53FD).withOpacity(0.25),
//               blurRadius: 18,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Material(
//           color: Colors.transparent,
//           child: InkWell(
//             borderRadius: BorderRadius.circular(28),
//             onTap: disabled ? null : onPressed,
//             child: Center(
//               child: loading
//                   ? const SizedBox(
//                       height: 20,
//                       width: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         valueColor:
//                             AlwaysStoppedAnimation<Color>(Colors.white),
//                       ),
//                     )
//                   : Text(
//                       text,
//                       style: const TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _BrandButton extends StatelessWidget {
//   const _BrandButton({
//     required this.label,
//     required this.asset,
//     required this.onTap,
//     this.loading = false,
//   });

//   final String label;
//   final String asset;
//   final VoidCallback onTap;
//   final bool loading;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(22),
//       elevation: 4,
//       shadowColor: Colors.black.withOpacity(0.12),
//       child: InkWell(
//         onTap: loading ? null : onTap,
//         borderRadius: BorderRadius.circular(18),
//         child: SizedBox(
//           height: 48,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               if (loading)
//                 const SizedBox(
//                   height: 20,
//                   width: 20,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 )
//               else
//                 Image.asset(asset, height: 22, width: 22),
//               const SizedBox(width: 10),
//               Text(
//                 loading ? 'Please wait…' : label,
//                 style: const TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontSize: 16,
//                   color: Color(0xFF1B1B1B),
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _FooterSwitch extends StatelessWidget {
//   const _FooterSwitch({
//     required this.prompt,
//     required this.action,
//     required this.onTap,
//   });

//   final String prompt;
//   final String action;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Wrap(
//       alignment: WrapAlignment.center,
//       crossAxisAlignment: WrapCrossAlignment.center,
//       children: [
//         Text(
//           prompt,
//           style: const TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontSize: 14.5,
//             color: Color(0xFF1B1B1B),
//           ),
//         ),
//         GestureDetector(
//           onTap: onTap,
//           child: Text(
//             action,
//             style: const TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5,
//               color: Color(0xFF1E9BFF),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class CenterLabelDivider extends StatelessWidget {
//   const CenterLabelDivider({
//     super.key,
//     required this.label,
//     this.lineColor = const Color(0xFFBDBDBD),
//     this.textColor = const Color(0xFF616161),
//     this.thickness = 1.0,
//     this.dotSize = 6.0,
//     this.gap = 10.0,
//     this.textStyle,
//   });

//   final String label;
//   final Color lineColor;
//   final Color textColor;
//   final double thickness;
//   final double dotSize;
//   final double gap;
//   final TextStyle? textStyle;

//   @override
//   Widget build(BuildContext context) {
//     final ts = textStyle ??
//         const TextStyle(
//           fontSize: 13.5,
//           fontWeight: FontWeight.w600,
//           color: Color(0xFF616161),
//           fontFamily: 'ClashGrotesk',
//         );

//     Widget dot() => Container(
//           width: dotSize,
//           height: dotSize,
//           decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
//         );

//     return Row(
//       children: [
//         Expanded(
//           child: Divider(
//               color: lineColor, thickness: thickness, height: dotSize),
//         ),
//         SizedBox(width: gap),
//         dot(),
//         const SizedBox(width: 8),
//         Text(label, style: ts),
//         const SizedBox(width: 8),
//         dot(),
//         SizedBox(width: gap),
//         Expanded(
//           child: Divider(
//               color: lineColor, thickness: thickness, height: dotSize),
//         ),
//       ],
//     );
//   }
// }
