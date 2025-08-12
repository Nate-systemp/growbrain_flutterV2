import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  int _step = 1;
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _controller;
  late Animation<Offset> _headerOffset;
  bool _showHeader = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeName;
  late Animation<double> _fadeEmail;
  late Animation<double> _fadeNextBtn;
  late Animation<double> _fadePassword;
  late Animation<double> _fadeConfirm;
  late Animation<double> _fadeRegisterBtn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerOffset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() => _showHeader = true);
      _controller.forward();
    });
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeName = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );
    _fadeEmail = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.18, 0.5, curve: Curves.easeIn),
    );
    _fadeNextBtn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.38, 0.7, curve: Curves.easeIn),
    );
    _fadePassword = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );
    _fadeConfirm = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.18, 0.5, curve: Curves.easeIn),
    );
    _fadeRegisterBtn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.38, 0.7, curve: Curves.easeIn),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _error = null;
    });
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _error = 'Please fill in all fields';
        _isLoading = false;
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _error = 'Passwords do not match';
        _isLoading = false;
      });
      return;
    }
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: password,
          );
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(userCredential.user!.uid)
          .set({
            'email': _emailController.text.trim(),
            'name': _nameController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Animated curved header
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                if (_headerOffset == null) {
                  return const SizedBox.shrink();
                }
                return SlideTransition(
                  position: _headerOffset,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              child: _showHeader
                  ? Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipPath(
                        clipper: _HeaderClipper(),
                        child: Container(
                          height: height * 0.38,
                          color: const Color(0xFF484F5C),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.only(top: height * 0.08),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'GrowBrain',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Assistive Android Game',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Left leaf
            Positioned(
              left: 32,
              top: height * 0.38,
              child: _LeafWidget(height: 90),
            ),
            // Right leaf
            Positioned(
              right: 32,
              top: height * 0.38,
              child: _LeafWidget(height: 90, flip: true),
            ),
            // Centered register form
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: height * 0.10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 120),
                    if (_step == 1) ...[
                      FadeTransition(
                        opacity: _fadeName,
                        child: SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Enter Full Name',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _fadeEmail,
                        child: SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Enter Email Address',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      FadeTransition(
                        opacity: _fadeNextBtn,
                        child: SizedBox(
                          width: 320,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF484F5C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              shadowColor: Colors.black.withOpacity(0.18),
                            ),
                            onPressed: _isLoading ? null : _nextStep,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Next'),
                          ),
                        ),
                      ),
                    ] else ...[
                      FadeTransition(
                        opacity: _fadePassword,
                        child: SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter Password',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _fadeConfirm,
                        child: SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF484F5C),
                                  width: 2.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      FadeTransition(
                        opacity: _fadeRegisterBtn,
                        child: SizedBox(
                          width: 320,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF484F5C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              shadowColor: Colors.black.withOpacity(0.18),
                            ),
                            onPressed: _isLoading ? null : _register,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Register'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Back button (lower left)
            Positioned(
              left: 24,
              bottom: 32,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  if (_step == 2) {
                    setState(() => _step = 1);
                  } else {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                label: const Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, st) {
      debugPrint('Error in RegisterScreen build: $e\n$st');
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Something went wrong. Please restart the app.',
            style: TextStyle(color: Colors.red, fontSize: 20),
          ),
        ),
      );
    }
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 1.2,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _LeafWidget extends StatelessWidget {
  final double height;
  final bool flip;
  const _LeafWidget({Key? key, required this.height, this.flip = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(flip ? 3.1416 : 0),
      child: Icon(Icons.eco, color: Colors.green[700], size: height),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Scattered icons and symbols
          Positioned(
            left: 40,
            top: height * 0.13,
            child: Row(
              children: const [
                Text(
                  'A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 28,
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  'B',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 28,
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  'C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 80,
            top: height * 0.32,
            child: const Icon(Icons.remove, color: Colors.orange, size: 24),
          ),
          Positioned(
            left: 120,
            top: height * 0.22,
            child: const Icon(Icons.add, color: Colors.amber, size: 28),
          ),
          Positioned(
            left: 60,
            bottom: height * 0.18,
            child: const Icon(Icons.percent, color: Colors.green, size: 26),
          ),
          Positioned(
            left: 160,
            bottom: height * 0.12,
            child: const Icon(Icons.diversity_3, color: Colors.teal, size: 28),
          ),
          Positioned(
            right: 60,
            top: height * 0.15,
            child: const Icon(
              Icons.lightbulb_outline,
              color: Colors.amber,
              size: 34,
            ),
          ),
          Positioned(
            right: 120,
            top: height * 0.32,
            child: const Icon(
              Icons.psychology,
              color: Colors.redAccent,
              size: 32,
            ),
          ),
          Positioned(
            right: 80,
            bottom: height * 0.18,
            child: const Icon(Icons.add, color: Colors.amber, size: 22),
          ),
          Positioned(
            right: 40,
            bottom: height * 0.10,
            child: const Icon(Icons.percent, color: Colors.green, size: 22),
          ),
          // Centered welcome text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Welcome to',
                  style: TextStyle(fontSize: 22, color: Colors.black87),
                ),
                SizedBox(height: 8),
                Text(
                  'GrowBrain',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF23272F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
