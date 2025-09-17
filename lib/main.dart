import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'intro_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teacher_pin_modal.dart';
import 'teacher_management.dart';
import 'category_games_screen.dart';

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
      backgroundColor: const Color(0xFF5B6F4A),
      body: Stack(
        children: [
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
                icon: Icon(
                  Icons.logout, 
                  size: screenWidth > 1000 ? 24 : 20,
                ),
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
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: gridSidePadding,
                ),
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
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Attention', isDemoMode: true),
                              ));
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
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Verbal', isDemoMode: true),
                              ));
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
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Memory', isDemoMode: true),
                              ));
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
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Logic', isDemoMode: true),
                              ));
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
            ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String? imagePath;
  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _HomeCard({
    this.imagePath,
    required this.label,
    required this.width,
    required this.height,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: imagePath != null
          ? Image.asset(
              imagePath!,
              fit: BoxFit.contain,
              width: width,
              height: height,
            )
          : Icon(Icons.help, color: Colors.grey, size: 90),
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
