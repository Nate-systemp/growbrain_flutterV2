import 'package:flutter/material.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  void _navigateDirect(String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    try {
      final height = MediaQuery.of(context).size.height;
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Static curved header (no animation)
            Positioned(
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
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Assistive Android Game',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Left leaf
            Positioned(
              left: 32,
              top: height * 0.38,
              child: _LeafWidget(height: 120),
            ),
            // Right leaf
            Positioned(
              right: 32,
              top: height * 0.38,
              child: _LeafWidget(height: 120, flip: true),
            ),
            // Centered buttons
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: height * 0.18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 120),
                    SizedBox(
                      width: 320,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF484F5C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          shadowColor: Colors.black.withOpacity(0.18),
                        ),
                        onPressed: () => _navigateDirect('/login'),
                        child: const Text('LOGIN'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, st) {
      // In release mode, log error and show fallback
      debugPrint('Error in IntroScreen build: $e\n$st');
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
 