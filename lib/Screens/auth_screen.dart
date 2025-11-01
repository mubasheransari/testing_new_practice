import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/home_screen.dart';
import 'package:ios_tiretest_ai/Screens/splash_screen.dart';
import 'package:ios_tiretest_ai/Widgets/gradient_text_widget.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int tab = 0; // 0 = Login, 1 = SignUp
  bool remember = true;

  final _formKey = GlobalKey<FormState>();

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final bloc = context.read<AuthBloc>();
    if (tab == 0) {
      // LOGIN
      bloc.add(
        LoginRequested(
          email: _loginEmailCtrl.text.trim(),
          password: _loginPassCtrl.text,
        ),
      );
    } else {
      // SIGNUP
      final full = _nameCtrl.text.trim();
      String first = full, last = '';
      final sp = full.split(RegExp(r'\s+'));
      if (sp.length > 1) {
        first = sp.first;
        last = sp.sublist(1).join(' ');
      }
      bloc.add(
        SignupRequested(
          firstName: first,
          lastName: last,
          email: _signupEmailCtrl.text.trim(),
          password: _signupPassCtrl.text,
        ),
      );
      setState(() => tab = 0);
    }
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email';
  }

  String? _required(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    if (v!.length < 6) return 'Use at least 6 characters';
    return null;
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
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
        if (state.loginStatus == AuthStatus.success) {
  
                         Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const SplashScreen()),
  (route) => false,
);
        }
        if (state.signupStatus == AuthStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signup successful. Please login.')),
          );
        }
      },
      builder: (context, state) {
        final loginLoading = state.loginStatus == AuthStatus.loading;
        final signupLoading = state.signupStatus == AuthStatus.loading;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F3F5),
          body: Stack(
            children: [
              // ======== BACKGROUND LAYERING ========
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

              // ======== GLASS/FROSTED PANEL ========
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
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _AuthToggle(
                                    activeIndex: tab,
                                    onChanged: (i) => setState(() => tab = i),
                                  ),
                                  const SizedBox(height: 18),

                                  if (tab == 0) ...[
                                    _InputCard(
                                      hint: 'Email',
                                      icon: 'assets/email_icon.png',
                                      controller: _loginEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateEmail,
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
                                      validator: _validatePassword,
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: TextButton(
                                            onPressed: () {
                                              // TODO: navigate to forgot password screen
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
                                    _PrimaryGradientButton(
                                      text: loginLoading
                                          ? 'Please wait...'
                                          : 'Login',
                                      onPressed: loginLoading ? null : _submit,
                                      loading: loginLoading,
                                    ),
                                    const SizedBox(height: 18),
                                    CenterLabelDivider(label: 'Or login with'),
                                    // const _DividerWithArrows(
                                    //     label: 'Or login with'),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _BrandButton(
                                            label: 'Google',
                                            asset: 'assets/google-logo.png',
                                            onTap: () {},
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
                                  ] else ...[
                                    // ---------- SIGNUP ----------
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
                                      validator: _validateEmail,
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
                                      validator: _validatePassword,
                                    ),
                                    const SizedBox(height: 12),
                                    _InputCard(
                                      hint: 'Confirm Password',
                                      icon: 'assets/password_icon.png',
                                      controller: _confirmCtrl,
                                      obscureText: _confirmObscure,
                                      onToggleObscure: () => setState(
                                        () =>
                                            _confirmObscure = !_confirmObscure,
                                      ),
                                      validator: (v) {
                                        final err = _validatePassword(v);
                                        if (err != null) return err;
                                        if (v != _signupPassCtrl.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _PrimaryGradientButton(
                                      text: signupLoading
                                          ? 'Please wait...'
                                          : 'SignUp',
                                      onPressed: signupLoading ? null : _submit,
                                      loading: signupLoading,
                                    ),
                                    const SizedBox(height: 18),
                                    CenterLabelDivider(label: 'Or login with'),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _BrandButton(
                                            label: 'Google',
                                            asset: 'assets/google-logo.png',
                                            onTap: () {},
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
                                    // const SizedBox(height: 18),
                                    // _FooterSwitch(
                                    //   prompt: "Don’t have an account? ",
                                    //   action: "Create an account",
                                    //   onTap: () => setState(() => tab = 1),
                                    // ),
                                    const SizedBox(height: 18),
                                    _FooterSwitch(
                                      prompt: "Already have an account? ",
                                      action: "Login",
                                      onTap: () => setState(() => tab = 0),
                                    ),
                                  ],
                                ],
                              ),
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

/* ===================== WIDGETS ===================== */

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
      height: 48,
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
              padding:  EdgeInsets.all(2),
              child: AnimatedContainer(
                height: 48,
                duration:  Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: activeIndex == 0 ? _grad : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onChanged(0),
                  child: Center(
                    child: activeIndex == 0
                            ?     Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color:  Colors.white,
                      ),
                    ):  GradientText(
                  "Login", 
                    gradient:  LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: 0.1,
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
                    child: activeIndex == 1
                            ?     Text(
                      'SignUp',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color:  Colors.white,
                      ),
                    ):  GradientText(
                  "SignUp", 
                    gradient:  LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: 0.1,
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

/// Rounded input card with optional password toggle.
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
          style:     TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1
                ),
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              obscureText: obscureText,
              decoration: InputDecoration(
              
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(
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
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
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
  });

  final String label;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(asset, height: 22, width: 22),
              const SizedBox(width: 10),
              Text(
                label,
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
        GradientText(
                 prompt, 
                    gradient:  LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    style:  TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14.5,
            color: Color(0xFF1B1B1B),
          ),
                  ),
        // Text(
        //   prompt,
          // style: const TextStyle(
          //   fontFamily: 'ClashGrotesk',
          //   fontSize: 14.5,
          //   color: Color(0xFF1B1B1B),
          // ),
        // ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5,
              color: Color(0xFF1E9BFF),
              // decoration: TextDecoration.underline,
              // decorationThickness: 1.4,
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
    this.lineColor = const Color(0xFFBDBDBD), // grey line
    this.textColor = const Color(0xFF616161), // slightly darker text
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
    final ts =
        textStyle ??
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
          child: Divider(
            color: lineColor,
            thickness: thickness,
            height: dotSize, // keeps vertical centering tidy
          ),
        ),
        SizedBox(width: gap),
        dot(),
        const SizedBox(width: 8),
        Text(label, style: ts),
        const SizedBox(width: 8),
        dot(),
        SizedBox(width: gap),
        Expanded(
          child: Divider(
            color: lineColor,
            thickness: thickness,
            height: dotSize,
          ),
        ),
      ],
    );
  }
}


// TODO: import your bloc
// import 'package:taskoon/blocs/auth/auth_bloc.dart';

// class AuthScreen extends StatefulWidget {
//   const AuthScreen({super.key});
//   @override
//   State<AuthScreen> createState() => _AuthScreenState();
// }

// class _AuthScreenState extends State<AuthScreen> {
//   int tab = 0; // 0 = Login, 1 = SignUp
//   bool remember = true;

//   final _formKey = GlobalKey<FormState>();

//   // login
//   final _loginEmailCtrl = TextEditingController();
//   final _loginPassCtrl = TextEditingController();
//   bool _loginObscure = true;

//   // signup (single "Name" field to match mock)
//   final _nameCtrl = TextEditingController();
//   final _signupEmailCtrl = TextEditingController();
//   final _signupPassCtrl = TextEditingController();
//   final _confirmCtrl = TextEditingController();
//   bool _signupObscure = true;
//   bool _confirmObscure = true;

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

//   void _submit() {
//     if (!_formKey.currentState!.validate()) return;

//    final bloc = context.read<AuthBloc>();
//     if (tab == 0) {
//       bloc.add(LoginRequested(
//         email: _loginEmailCtrl.text.trim(),
//         password: _loginPassCtrl.text,
//       ));
//     } else {
//       final full = _nameCtrl.text.trim();
//       String first = full, last = '';
//       final sp = full.split(RegExp(r'\s+'));
//       if (sp.length > 1) {
//         first = sp.first;
//         last = sp.sublist(1).join(' ');
//       }
//       bloc.add(SignupRequested(
//         firstName: first,
//         lastName: last,
//         email: _signupEmailCtrl.text.trim(),
//         password: _signupPassCtrl.text,
//       ));
//       setState(() => tab = 0);
//     }
//   }

//   String? _validateEmail(String? v) {
//     final s = v?.trim() ?? '';
//     if (s.isEmpty) return 'Email is required';
//     final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
//     return ok ? null : 'Enter a valid email';
//   }

//   String? _required(String? v, String label) {
//     if ((v ?? '').trim().isEmpty) return '$label is required';
//     return null;
//   }

//   String? _validatePassword(String? v) {
//     if ((v ?? '').isEmpty) return 'Password is required';
//     if (v!.length < 6) return 'Use at least 6 characters';
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F3F5),
//       body: Stack(
//         children: [
//           // ======== BACKGROUND LAYERING to match mock #3 ========
//           // Bottom-left dark pattern (fixed to bottom-left corner)
//           Positioned.fill(
//             child: Image.asset(
//               'assets/bottom_bg.png',
//               fit: BoxFit.cover,
//               alignment: const Alignment(-1.0, 1.0),
//               color: Colors.black.withOpacity(0.10),
//             // colorBlendMode: BlendMode.srcOver,
//             ),
//           ),
//           // Top wheel photo (anchored top-center)
//           Positioned.fill(
//             child: Image.asset(
//               'assets/upper_bg.png',
//               fit: BoxFit.cover,
//               alignment: const Alignment(0, -0.2),
//             // color: Colors.black.withOpacity(0.35),
//              // colorBlendMode: BlendMode.darken,
//             ),
//           ),
//           // Whitening veil to create the soft pale look in the mock
//           // Positioned.fill(
//           //   child: DecoratedBox(
//           //     decoration: BoxDecoration(
//           //       gradient: LinearGradient(
//           //         begin: Alignment.topCenter,
//           //         end: Alignment.bottomCenter,
//           //         stops: const [0.0, 0.35, 0.70, 1.0],
//           //         colors: [
//           //           Colors.white.withOpacity(0.70),
//           //           Colors.white.withOpacity(0.82),
//           //           Colors.white.withOpacity(0.90),
//           //           Colors.white.withOpacity(0.96),
//           //         ],
//           //       ),
//           //     ),
//           //   ),
//           // ),

//           // ======== GLASS/FROSTED PANEL ========
//           SafeArea(
//             child: Center(
//               child: Padding(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: size.width < 380 ? 16 : 22,
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(28),
//                   child: BackdropFilter(
//                     filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                     child: Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.45), // more white (mock)
//                         borderRadius: BorderRadius.circular(28),
//                         border: Border.all(
//                           color: Colors.white.withOpacity(0.75),
//                           width: 1,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.04),
//                             blurRadius: 18,
//                             offset: const Offset(0, 10),
//                           ),
//                         ],
//                       ),
//                       child: Form(
//                         key: _formKey,
//                         child: SingleChildScrollView(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               _AuthToggle(
//                                 activeIndex: tab,
//                                 onChanged: (i) => setState(() => tab = i),
//                               ),
//                               const SizedBox(height: 18),
                          
//                               // ======== FIELDS (exact order as mock) ========
//                               if (tab == 0) ...[
//                                 _InputCard(
//                                   hint: 'Email',
//                                   icon: 'assets/email_icon.png',
//                                   controller: _nameCtrl,
//                                  // validator: (v) => _required(v, 'Name'),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _InputCard(
//                                   obscureText: true,
//                                   hint: 'Password',
//                                   icon: 'assets/password_icon.png',
//                                   controller: _loginEmailCtrl,
//                                   keyboardType: TextInputType.emailAddress,
//                                //   validator: _validateEmail,
//                                 ),
//                                 const SizedBox(height: 7),
//                                  Row(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//                                     // _CheckBoxSquare(checked: true, muted: true),
//                                     // const SizedBox(width: 8),
//                                     // const Text(
//                                     //   'Remember me',
//                                     //   style: TextStyle(
//                                     //     fontSize: 14.5,
//                                     //     color: Color(0xFF222222),
//                                     //   ),
//                                     // ),
//                                     // const Spacer(),
//                                     // const Spacer(),
//                                     Padding(
//                                       padding: const EdgeInsets.only(left:8.0),
//                                       child: TextButton(
//                                         // style: TextButton.styleFrom(
//                                         //   padding: EdgeInsets.zero,
//                                         //   foregroundColor: const Color(0xFF1B1B1B),
//                                         // ),
//                                         onPressed: () {},
//                                         child: const Text(
//                                           'Forgot password',
//                                           style: TextStyle(
//                                                    fontFamily: 'ClashGrotesk',
//                                             fontSize: 14.5,
//                                            fontWeight: FontWeight.w700
//                                            // color: Color(0xFF1B1B1B),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               //  const SizedBox(height: 12),
//                                 _PrimaryGradientButton(text: 'Login', onPressed: _submit),
//                                 const SizedBox(height: 18),
//                                 _DividerWithArrows(label: 'Or login with'),
//                                 const SizedBox(height: 14),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: _BrandButton(
//                                         label: 'Google',
//                                         asset: 'assets/google-logo.png',
//                                         onTap: () {},
//                                       ),
//                                     ),
//                                     const SizedBox(width: 14),
//                                     Expanded(
//                                       child: _BrandButton(
//                                         label: 'Apple',
//                                         asset: 'assets/apple-logo.png',
//                                         onTap: () {},
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 18),
//                                 _FooterSwitch(
//                                   prompt: "Don’t have an account? ",
//                                   action: "Create an account",
//                                   onTap: () => setState(() => tab = 1),
//                                 ),
//                               ] else ...[
//                                 _InputCard(
//                                   hint: 'Name',
//                                   icon: 'assets/name_icon.png',
//                                   controller: _nameCtrl,
//                                   validator: (v) => _required(v, 'Name'),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _InputCard(
                                
//                                   hint: 'Email Address',
//                                   icon: 'assets/email_icon.png',
//                                   controller: _signupEmailCtrl,
//                                   keyboardType: TextInputType.emailAddress,
//                                   validator: _validateEmail,
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _InputCard(
//                                   hint: 'Password',
//                                icon: 'assets/password_icon.png',
//                                   controller: _signupPassCtrl,
//                                   obscureText: _signupObscure,
//                                   onToggleObscure: () =>
//                                       setState(() => _signupObscure = !_signupObscure),
//                                   validator: _validatePassword,
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _InputCard(
//                                   hint: 'Confirm Password',
//                        icon: 'assets/password_icon.png',
//                                   controller: _confirmCtrl,
//                                   obscureText: _confirmObscure,
//                                   onToggleObscure: () =>
//                                       setState(() => _confirmObscure = !_confirmObscure),
//                                   validator: (v) {
//                                     final err = _validatePassword(v);
//                                     if (err != null) return err;
//                                     if (v != _signupPassCtrl.text) {
//                                       return 'Passwords do not match';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 //const SizedBox(height: 14),
//                                 // Row(
//                                 //   children: [
//                                 //     _CheckBoxSquare(checked: true, muted: true),
//                                 //     const SizedBox(width: 8),
//                                 //     const Text(
//                                 //       'Remember me',
//                                 //       style: TextStyle(
//                                 //         fontSize: 14.5,
//                                 //         color: Color(0xFF222222),
//                                 //       ),
//                                 //     ),
//                                 //     const Spacer(),
//                                 //     TextButton(
//                                 //       // style: TextButton.styleFrom(
//                                 //       //   padding: EdgeInsets.zero,
//                                 //       //   foregroundColor: const Color(0xFF1B1B1B),
//                                 //       // ),
//                                 //       onPressed: () {},
//                                 //       child: const Text(
//                                 //         'Forgot password',
//                                 //         style: TextStyle(
//                                 //                  fontFamily: 'ClashGrotesk',
//                                 //           fontSize: 14.5,
//                                 //          fontWeight: FontWeight.w700
//                                 //          // color: Color(0xFF1B1B1B),
//                                 //         ),
//                                 //       ),
//                                 //     ),
//                                 //   ],
//                                 // ),
//                                 const SizedBox(height: 12),
//                                 _PrimaryGradientButton(text: 'SignUp', onPressed: _submit),
//                                 const SizedBox(height: 18),
//                                 _DividerWithArrows(label: 'Or login with'),
//                                 const SizedBox(height: 14),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: _BrandButton(
//                                         label: 'Google',
//                                         asset: 'assets/google.png',
//                                         onTap: () {},
//                                       ),
//                                     ),
//                                     const SizedBox(width: 14),
//                                     Expanded(
//                                       child: _BrandButton(
//                                         label: 'Apple',
//                                         asset: 'assets/apple.png',
//                                         onTap: () {},
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 18),
//                                 _FooterSwitch(
//                                   prompt: "Don’t have an account? ",
//                                   action: "Login",
//                                   onTap: () => setState(() => tab = 0),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),
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

// /* ===================== WIDGETS ===================== */

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
//       height: 52,
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
//               padding: const EdgeInsets.all(6),
//               child: AnimatedContainer(
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
//                       'Login',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
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
//               padding: const EdgeInsets.all(6),
//               child: AnimatedContainer(
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
//                       'SignUp',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w500,
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

// /// Matches the rounded white input cards from the mock.
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
//           Image.asset(icon, height: 17,width: 17, color: const Color(0xFF1B1B1B)),
//         //  Icon(icon, size: 22, color: const Color(0xFF1B1B1B)),
//           const SizedBox(width: 10),
//           Expanded(
//             child: TextFormField(

//               controller: controller,
//               keyboardType: keyboardType,
//               validator: validator,
//               obscureText: obscureText,
//               decoration: InputDecoration(
                
//                 hintText: hint,
//                 border: InputBorder.none,
//                 isCollapsed: true,
//                 hintStyle: TextStyle(
//                      fontFamily: 'ClashGrotesk',
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
//   const _PrimaryGradientButton({required this.text, required this.onPressed});
//   final String text;
//   final VoidCallback onPressed;

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 54,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(28),
//         gradient: _grad,
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF7F53FD).withOpacity(0.25),
//             blurRadius: 18,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(28),
//           onTap: onPressed,
//           child: Center(
//             child: Text(
//               text,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 20,
//                 fontWeight: FontWeight.w500,
//               ),
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
//   });

//   final String label;
//   final String asset;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(22),
//       elevation: 4,
//       shadowColor: Colors.black.withOpacity(0.12),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(18),
//         child: SizedBox(
//           height: 48,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Image.asset(asset, height: 22, width: 22),
//               const SizedBox(width: 10),
//               Text(
//                 label,
//                 style: const TextStyle(
//                     fontFamily: 'ClashGrotesk',
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

// class _CheckBoxSquare extends StatelessWidget {
//   const _CheckBoxSquare({required this.checked, this.muted = false});
//   final bool checked;
//   final bool muted;

//   @override
//   Widget build(BuildContext context) {
//     final border = muted ? const Color(0xFFDADADA) : const Color(0xFF202020);
//     final fill = muted ? const Color(0xFFF3F3F3) : const Color(0xFF202020);
//     return Container(
//       height: 20,
//       width: 20,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(4),
//         border: Border.all(color: border, width: 1.4),
//         color: checked ? fill : Colors.transparent,
//       ),
//       child: checked
//           ? const Icon(Icons.check, size: 16, color: Colors.white)
//           : null,
//     );
//   }
// }

// class _DividerWithArrows extends StatelessWidget {
//   const _DividerWithArrows({required this.label});
//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     final line = Container(height: 1, color: Colors.black.withOpacity(0.30));
//     const arrowL = Icon(Icons.arrow_back_ios_new_rounded, size: 12);
//     const arrowR = Icon(Icons.arrow_forward_ios_rounded, size: 12);
//     return Row(
//       children: [
//         Expanded(child: line),
//         const SizedBox(width: 6),
//         const RotatedBox(quarterTurns: 2, child: arrowR),
//         const SizedBox(width: 4),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 13.5, color: Color(0xFF1B1B1B)),
//         ),
//         const SizedBox(width: 4),
//         const RotatedBox(quarterTurns: 0, child: arrowR),
//         const SizedBox(width: 6),
//         Expanded(child: line),
//       ],
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
//                    fontFamily: 'ClashGrotesk',
//             fontSize: 14.5,
//             color: Color(0xFF1B1B1B),
//           ),
//         ),
//         GestureDetector(
//           onTap: onTap,
//           child: Text(
//             action,
//             style: const TextStyle(
//                fontFamily: 'ClashGrotesk',
//               fontSize: 14.5,
//               color: Color(0xFF1E9BFF),
//               decoration: TextDecoration.underline,
//               decorationThickness: 1.4,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }




// class AuthScreen extends StatefulWidget {
//   const AuthScreen({super.key});
//   @override
//   State<AuthScreen> createState() => _AuthScreenState();
// }

// class _AuthScreenState extends State<AuthScreen> {
//   int tab = 0; // 0 = Login, 1 = SignUp
//   bool remember = true;

//   final _formKey = GlobalKey<FormState>();

//   // login
//   final _loginEmailCtrl = TextEditingController();
//   final _loginPassCtrl = TextEditingController();

//   // signup
//   final _firstNameCtrl = TextEditingController();
//   final _lastNameCtrl = TextEditingController();
//   final _signupEmailCtrl = TextEditingController();
//   final _signupPassCtrl = TextEditingController();
//   final _confirmCtrl = TextEditingController();

//   @override
//   void dispose() {
//     _loginEmailCtrl.dispose();
//     _loginPassCtrl.dispose();
//     _firstNameCtrl.dispose();
//     _lastNameCtrl.dispose();
//     _signupEmailCtrl.dispose();
//     _signupPassCtrl.dispose();
//     _confirmCtrl.dispose();
//     super.dispose();
//   }

//   void _submit() {
//     if (!_formKey.currentState!.validate()) return;
//     final bloc = context.read<AuthBloc>();

//     if (tab == 0) {
//       bloc.add(LoginRequested(
//         email: _loginEmailCtrl.text.trim(),
//         password: _loginPassCtrl.text,
//       ));
//     } else {
//       bloc.add(SignupRequested(
//         firstName: _firstNameCtrl.text.trim(),
//         lastName: _lastNameCtrl.text.trim(),
//         email: _signupEmailCtrl.text.trim(),
//         password: _signupPassCtrl.text,
//       ));
//     }
//   }

//   String? _validateEmail(String? v) {
//     final s = v?.trim() ?? '';
//     if (s.isEmpty) return 'Email is required';
//     final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
//     return ok ? null : 'Enter a valid email';
//   }

//   String? _validateNotEmpty(String? v, String label) {
//     if ((v ?? '').trim().isEmpty) return '$label is required';
//     return null;
//   }

//   String? _validatePassword(String? v) {
//     if ((v ?? '').isEmpty) return 'Password is required';
//     if (v!.length < 6) return 'Use at least 6 characters';
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;

//     return BlocListener<AuthBloc, AuthState>(
//       listenWhen: (p, c) =>
//           p.loginStatus != c.loginStatus ||
//           p.signupStatus != c.signupStatus ||
//           p.error != c.error,
//       listener: (context, state) {
//         if (state.error != null && state.error!.isNotEmpty) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(SnackBar(content: Text(state.error!)));
//         }

//         if (state.loginStatus == AuthStatus.success &&
//             (state.loginResponse?.token.isNotEmpty ?? false)) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               content:
//                   Text(state.loginResponse?.message ?? 'Login successful')));
//           // TODO: Navigate to your home screen
//         }

//         if (state.signupStatus == AuthStatus.success &&
//             (state.signupResponse?.isValid ?? false)) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               content:
//                   Text(state.signupResponse?.message ?? 'Signup successful')));
//           setState(() => tab = 0); // go to Login after signup
//         }
//       },
//       child: Scaffold(
//         body: Stack(
//           children: [
//             // Background
//             Positioned.fill(
//               child: Image.asset(
//                 'assets/upper_bg.png',
//                 fit: BoxFit.cover,
//                 alignment: const Alignment(0, -0.2),
//               ),
//             ),
//               Positioned.fill(
//               child: Image.asset(
//                 'assets/bottom_bg.png',
//                 fit: BoxFit.cover,
//                 alignment: const Alignment(-0.2, -0.2),
//               ),
//             ),
//             Positioned.fill(
//               child: DecoratedBox(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.45),
//                       Colors.white.withOpacity(0.80),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//             // Panel
//             SafeArea(
//               child: Center(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: size.width < 380 ? 18 : 24,
//                   ),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(28),
//                     child: BackdropFilter(
//                       filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                       child: Container(
//                         padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.10),
//                           borderRadius: BorderRadius.circular(28),
//                           // border: Border.all(
//                           //   color: Colors.white.withOpacity(0.85),
//                           //   width: 1,
//                           // ),
//                         ),
//                         width: double.infinity,
//                         child: Form(
//                           key: _formKey,
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               _AuthToggle(
//                                 activeIndex: tab,
//                                 onChanged: (i) => setState(() => tab = i),
//                               ),
//                               const SizedBox(height: 18),

//                               // Fields
//                               if (tab == 0) ...[
//                                 _GlassField(
//                                   controller: _loginEmailCtrl,
//                                   hint: 'Email Address',
//                                   icon: Icons.mail_outline,
//                                   keyboardType: TextInputType.emailAddress,
//                                   validator: _validateEmail,
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _GlassField(
//                                   controller: _loginPassCtrl,
//                                   hint: 'Password',
//                                   icon: Icons.lock_outline,
//                                   obscureText: true,
//                                   validator: _validatePassword,
//                                 ),
//                               ] else ...[
//                                 _GlassField(
//                                   controller: _firstNameCtrl,
//                                   hint: 'First name',
//                                   icon: Icons.person_outline,
//                                   validator: (v) =>
//                                       _validateNotEmpty(v, 'First name'),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _GlassField(
//                                   controller: _lastNameCtrl,
//                                   hint: 'Last name',
//                                   icon: Icons.person_outline,
//                                   validator: (v) =>
//                                       _validateNotEmpty(v, 'Last name'),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _GlassField(
//                                   controller: _signupEmailCtrl,
//                                   hint: 'Email Address',
//                                   icon: Icons.mail_outline,
//                                   keyboardType: TextInputType.emailAddress,
//                                   validator: _validateEmail,
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _GlassField(
//                                   controller: _signupPassCtrl,
//                                   hint: 'Password',
//                                   icon: Icons.lock_outline,
//                                   obscureText: true,
//                                   validator: _validatePassword,
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _GlassField(
//                                   controller: _confirmCtrl,
//                                   hint: 'Confirm Password',
//                                   icon: Icons.lock_outline,
//                                   obscureText: true,
//                                   validator: (v) {
//                                     final err = _validatePassword(v);
//                                     if (err != null) return err;
//                                     if (v != _signupPassCtrl.text) {
//                                       return 'Passwords do not match';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                               ],
//                               const SizedBox(height: 14),

//                               // Remember/Forgot (login only)
//                               if (tab == 0)
//                                 Row(
//                                   children: [
//                                     GestureDetector(
//                                       onTap: () =>
//                                           setState(() => remember = !remember),
//                                       child: Row(
//                                         children: [
//                                           Container(
//                                             height: 20,
//                                             width: 20,
//                                             decoration: BoxDecoration(
//                                               borderRadius:
//                                                   BorderRadius.circular(4),
//                                               border: Border.all(
//                                                 color:
//                                                     const Color(0xFF202020),
//                                                 width: 1.4,
//                                               ),
//                                               color: remember
//                                                   ? const Color(0xFF202020)
//                                                   : Colors.transparent,
//                                             ),
//                                             child: remember
//                                                 ? const Icon(Icons.check,
//                                                     size: 16,
//                                                     color: Colors.white)
//                                                 : null,
//                                           ),
//                                           const SizedBox(width: 8),
//                                           const Text(
//                                             'Remember me',
//                                             style: TextStyle(
//                                               fontSize: 14.5,
//                                               color: Color(0xFF202020),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     const Spacer(),
//                                     TextButton(
//                                       style: TextButton.styleFrom(
//                                         padding: EdgeInsets.zero,
//                                         foregroundColor:
//                                             const Color(0xFF1B1B1B),
//                                       ),
//                                       onPressed: () {
//                                         // TODO: Forgot password screen
//                                       },
//                                       child: const Text(
//                                         'Forgot password',
//                                         style: TextStyle(
//                                           fontSize: 14.5,
//                                           color: Color(0xFF1B1B1B),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               if (tab == 0) const SizedBox(height: 12),

//                               // Submit button
//                               BlocBuilder<AuthBloc, AuthState>(
//                                 buildWhen: (p, c) =>
//                                     p.loginStatus != c.loginStatus ||
//                                     p.signupStatus != c.signupStatus,
//                                 builder: (context, state) {
//                                   final isLoading = tab == 0
//                                       ? state.loginStatus ==
//                                           AuthStatus.loading
//                                       : state.signupStatus ==
//                                           AuthStatus.loading;
//                                   return _GradientButton(
//                                     text: tab == 0 ? 'Login' : 'Sign Up',
//                                     onPressed: isLoading ? null : _submit,
//                                     isLoading: isLoading,
//                                   );
//                                 },
//                               ),

//                               const SizedBox(height: 20),

//                               // Social (login only)
//                               if (tab == 0) ...[
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: Container(
//                                         height: 1,
//                                         color:
//                                             Colors.black.withOpacity(0.35),
//                                       ),
//                                     ),
//                                     const Padding(
//                                       padding: EdgeInsets.symmetric(
//                                           horizontal: 10),
//                                       child: Text(
//                                         'Or login with',
//                                         style: TextStyle(
//                                           fontSize: 13.5,
//                                           color: Color(0xFF1B1B1B),
//                                         ),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Container(
//                                         height: 1,
//                                         color:
//                                             Colors.black.withOpacity(0.35),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 14),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: _BrandButton(
//                                         label: 'Google',
//                                         asset: 'assets/google.png',
//                                         onTap: () {}, // TODO
//                                       ),
//                                     ),
//                                     const SizedBox(width: 14),
//                                     Expanded(
//                                       child: _BrandButton(
//                                         label: 'Apple',
//                                         asset: 'assets/apple.png',
//                                         onTap: () {}, // TODO
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 18),
//                               ],

//                               // Footer switch
//                               Wrap(
//                                 crossAxisAlignment:
//                                     WrapCrossAlignment.center,
//                                 children: [
//                                   Text(
//                                     tab == 0
//                                         ? "Don’t have an account? "
//                                         : "Already have an account? ",
//                                     style: const TextStyle(
//                                       fontSize: 14.5,
//                                       color: Color(0xFF1B1B1B),
//                                     ),
//                                   ),
//                                   GestureDetector(
//                                     onTap: () => setState(
//                                         () => tab = tab == 0 ? 1 : 0),
//                                     child: Text(
//                                       tab == 0
//                                           ? 'Create an account'
//                                           : 'Login',
//                                       style: const TextStyle(
//                                         fontSize: 14.5,
//                                         color: Color(0xFF1E9BFF),
//                                         decoration: TextDecoration.underline,
//                                         decorationThickness: 1.4,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ---------- Widgets ----------

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
//       height: 56,
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
//               padding: const EdgeInsets.all(6),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 220),
//                 decoration: BoxDecoration(
//                   gradient: activeIndex == 0 ? _grad : null,
//                   color: activeIndex == 0 ? null : Colors.transparent,
//                   borderRadius: BorderRadius.circular(22),
//                 ),
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(22),
//                   onTap: () => onChanged(0),
//                   child: Center(
//                     child: Text(
//                       'Login',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
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
//               padding: const EdgeInsets.all(6),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 220),
//                 decoration: BoxDecoration(
//                   gradient: activeIndex == 1 ? _grad : null,
//                   color: activeIndex == 1 ? null : Colors.transparent,
//                   borderRadius: BorderRadius.circular(22),
//                 ),
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(22),
//                   onTap: () => onChanged(1),
//                   child: Center(
//                     child: Text(
//                       'SignUp',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
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

// class _GlassField extends StatelessWidget {
//   const _GlassField({
//     required this.hint,
//     required this.icon,
//     this.controller,
//     this.obscureText = false,
//     this.keyboardType,
//     this.validator,
//   });

//   final String hint;
//   final IconData icon;
//   final TextEditingController? controller;
//   final bool obscureText;
//   final TextInputType? keyboardType;
//   final String? Function(String?)? validator;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 56,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           const SizedBox(width: 14),
//           Icon(icon, size: 22, color: const Color(0xFF1B1B1B)),
//           const SizedBox(width: 10),
//           Expanded(
//             child: TextFormField(
//               controller: controller,
//               obscureText: obscureText,
//               keyboardType: keyboardType,
//               validator: validator,
//               decoration: InputDecoration(
//                 hintText: hint,
//                 border: InputBorder.none,
//                 hintStyle: TextStyle(
//                   color: Colors.black.withOpacity(0.35),
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//         ],
//       ),
//     );
//   }
// }

// class _GradientButton extends StatelessWidget {
//   const _GradientButton({
//     required this.text,
//     required this.onPressed,
//     this.isLoading = false,
//   });

//   final String text;
//   final VoidCallback? onPressed;
//   final bool isLoading;

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     final enabled = onPressed != null && !isLoading;
//     return Opacity(
//       opacity: enabled ? 1 : 0.7,
//       child: Container(
//         height: 56,
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
//             onTap: enabled ? onPressed : null,
//             child: Center(
//               child: isLoading
//                   ? const SizedBox(
//                       height: 22,
//                       width: 22,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : Text(
//                       text,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
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
//   });

//   final String label;
//   final String asset;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(18),
//       elevation: 4,
//       shadowColor: Colors.black.withOpacity(0.12),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(18),
//         child: SizedBox(
//           height: 54,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Image.asset(asset, height: 22, width: 22),
//               const SizedBox(width: 10),
//               Text(
//                 label,
//                 style: const TextStyle(
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





