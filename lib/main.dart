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
                            icon: Icons.lightbulb_outline,
                            iconColor: Colors.amber,
                            label: 'Attention',
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Attention'),
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
                            icon: Icons.abc,
                            iconColor: Colors.redAccent,
                            label: 'Verbal',
                            customIcon: true,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Verbal'),
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
                            icon: Icons.style,
                            iconColor: Colors.redAccent,
                            label: 'Memory',
                            customIcon: true,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Memory'),
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
                            icon: Icons.psychology,
                            iconColor: Colors.deepOrangeAccent,
                            label: 'Logic',
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CategoryGamesScreen(category: 'Logic'),
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
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool customIcon;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _HomeCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.customIcon = false,
    required this.width,
    required this.height,
  this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(2, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: customIcon && label == 'Verbal'
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'A',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 60,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'B',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 60,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'C',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              fontSize: 60,
                            ),
                          ),
                        ],
                      )
                    : customIcon && label == 'Memory'
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.style, color: Colors.redAccent, size: 60),
                              const SizedBox(width: 4),
                              Icon(Icons.style, color: Colors.green, size: 60),
                            ],
                          )
                        : Icon(icon, color: iconColor, size: 90),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 38,
                  color: Color(0xFF444444),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
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
