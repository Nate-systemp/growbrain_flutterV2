import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'intro_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teacher_pin_modal.dart';
import 'teacher_management.dart';
import 'category_games_screen.dart';
import 'utils/session_volume_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation to landscape only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide status bar for fullscreen experience
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  print('Before Firebase init');
  await Firebase.initializeApp();
  print('After Firebase init');

  // Initialize demo volumes (separate from session volumes)
  await SessionVolumeManager.instance.initializeDemoVolumes();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: user == null ? '/' : '/home',
      routes: {
        '/': (context) => const IntroScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<void> _preloadImages;

  @override
  void initState() {
    super.initState();
    _preloadImages = _preloadAllImages();
  }

  Future<void> _preloadAllImages() async {
    final imagePaths = [
      'assets/attention.png',
      'assets/verbal.png',
      'assets/memory.png',
      'assets/logic.png',
    ];

    await Future.wait(
      imagePaths.map((path) => precacheImage(AssetImage(path), context)),
    );
  }

  void _showTeacherPinModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TeacherPinModal(
        onSubmit: (pin, isCreate, [password]) {
          Navigator.of(context).pop();
          if (!isCreate) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TeacherManagementScreen(),
              ),
            );
          } else {
            // Show a snackbar for now
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'PIN created! (demo only) Password: ${password ?? ''}',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 20,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFFD32F2F),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to log out?',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF424242),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE1BEE7), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF7B1FA2),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You will need to log in again to access the app.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF7B1FA2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 2,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: const Color(0xFFD32F2F).withOpacity(0.3),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      ),
    );

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive values based on screen size
    final double cardWidth = screenWidth > 1000 ? 300 : screenWidth * 0.28;
    final double cardHeight = screenHeight > 700 ? 260 : screenHeight * 0.35;
    final double cardSpacing = screenWidth > 1000 ? 60 : screenWidth * 0.06;
    final double gridSidePadding = screenWidth * 0.05;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Logout button - responsive positioning (left side)
          Positioned(
            top: screenHeight * 0.05,
            left: screenWidth * 0.03,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.25,
                minWidth: 140,
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.02,
                  ),
                  textStyle: TextStyle(
                    fontSize: screenWidth > 1000 ? 18 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _logout,
                icon: Icon(Icons.logout, size: screenWidth > 1000 ? 24 : 20),
                label: const Text('Logout'),
              ),
            ),
          ),
          // For Teachers button - responsive positioning
          Positioned(
            top: screenHeight * 0.05,
            right: screenWidth * 0.03,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.25,
                minWidth: 180,
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.02,
                  ),
                  textStyle: TextStyle(
                    fontSize: screenWidth > 1000 ? 18 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _showTeacherPinModal,
                icon: Icon(
                  Icons.person_outline,
                  size: screenWidth > 1000 ? 24 : 20,
                ),
                label: const Text('For Teachers'),
              ),
            ),
          ),
          // Main grid
          FutureBuilder<void>(
            future: _preloadImages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4CAF50),
                          ),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading Games...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gridSidePadding),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: {
                      0: FixedColumnWidth(cardWidth),
                      1: FixedColumnWidth(cardWidth),
                    },
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              right: cardSpacing / 2,
                              bottom: cardSpacing / 2,
                            ),
                            child: _HomeCard(
                              imagePath: 'assets/attention.png',
                              label: 'Attention',
                              animationDelay: 0,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryGamesScreen(
                                      category: 'Attention',
                                      isDemoMode: true,
                                    ),
                                  ),
                                );
                              },
                              width: cardWidth,
                              height: cardHeight,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: cardSpacing / 2,
                              bottom: cardSpacing / 2,
                            ),
                            child: _HomeCard(
                              imagePath: 'assets/verbal.png',
                              label: 'Verbal',
                              animationDelay: 100,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryGamesScreen(
                                      category: 'Verbal',
                                      isDemoMode: true,
                                    ),
                                  ),
                                );
                              },
                              width: cardWidth,
                              height: cardHeight,
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              right: cardSpacing / 2,
                              top: cardSpacing / 2,
                            ),
                            child: _HomeCard(
                              imagePath: 'assets/memory.png',
                              label: 'Memory',
                              animationDelay: 200,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryGamesScreen(
                                      category: 'Memory',
                                      isDemoMode: true,
                                    ),
                                  ),
                                );
                              },
                              width: cardWidth,
                              height: cardHeight,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: cardSpacing / 2,
                              top: cardSpacing / 2,
                            ),
                            child: _HomeCard(
                              imagePath: 'assets/logic.png',
                              label: 'Logic',
                              animationDelay: 300,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryGamesScreen(
                                      category: 'Logic',
                                      isDemoMode: true,
                                    ),
                                  ),
                                );
                              },
                              width: cardWidth,
                              height: cardHeight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatefulWidget {
  final String? imagePath;
  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final int animationDelay;

  const _HomeCard({
    this.imagePath,
    required this.label,
    required this.width,
    required this.height,
    this.onTap,
    this.animationDelay = 0,
    Key? key,
  }) : super(key: key);

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start the animation after the specified delay
    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.imagePath != null
            ? Image.asset(
                widget.imagePath!,
                fit: BoxFit.contain,
                width: widget.width,
                height: widget.height,
                cacheWidth:
                    (widget.width * MediaQuery.of(context).devicePixelRatio)
                        .round(),
                cacheHeight:
                    (widget.height * MediaQuery.of(context).devicePixelRatio)
                        .round(),
                isAntiAlias: true,
                filterQuality: FilterQuality.high,
              )
            : Icon(Icons.help, color: Colors.grey, size: 90),
      ),
    );
  }
}

// Add a placeholder TeacherProfileScreen
class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF393C48),
      body: Center(
        child: Text(
          'Teacher Profile (placeholder)',
          style: const TextStyle(fontSize: 32, color: Colors.white),
        ),
      ),
    );
  }
}
