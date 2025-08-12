import 'package:flutter/material.dart';
import 'intro_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teacher_pin_modal.dart';
import 'teacher_management.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        '/register': (context) => const RegisterScreen(),
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

  @override
  Widget build(BuildContext context) {
    // Larger cards and buttons for tablet
    const double cardWidth = 300;
    const double cardHeight = 260;
    const double cardSpacing = 60;
    const double gridSidePadding = 48;
    const double teacherBtnTop = 36;
    const double teacherBtnRight = 48;
    const double backBtnLeft = 36;
    const double backBtnBottom = 48;
    return Scaffold(
      backgroundColor: const Color(0xFF5B6F4A),
      body: SafeArea(
        child: Stack(
          children: [
            // For Teachers button
            Positioned(
              top: teacherBtnTop,
              right: teacherBtnRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _showTeacherPinModal,
                icon: const Icon(Icons.person_outline, size: 32),
                label: const Text('For Teachers'),
              ),
            ),
            // Main grid
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: gridSidePadding,
                ),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FixedColumnWidth(cardWidth),
                    1: FixedColumnWidth(cardWidth),
                  },
                  children: [
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            right: cardSpacing / 2,
                            bottom: cardSpacing / 2,
                          ),
                          child: _HomeCard(
                            icon: Icons.lightbulb_outline,
                            iconColor: Colors.amber,
                            label: 'Attention',
                            width: cardWidth,
                            height: cardHeight,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: cardSpacing / 2,
                            bottom: cardSpacing / 2,
                          ),
                          child: _HomeCard(
                            icon: Icons.abc,
                            iconColor: Colors.redAccent,
                            label: 'Verbal',
                            customIcon: true,
                            width: cardWidth,
                            height: cardHeight,
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            right: cardSpacing / 2,
                            top: cardSpacing / 2,
                          ),
                          child: _HomeCard(
                            icon: Icons.style,
                            iconColor: Colors.redAccent,
                            label: 'Memory',
                            customIcon: true,
                            width: cardWidth,
                            height: cardHeight,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: cardSpacing / 2,
                            top: cardSpacing / 2,
                          ),
                          child: _HomeCard(
                            icon: Icons.psychology,
                            iconColor: Colors.deepOrangeAccent,
                            label: 'Logic',
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
            // LOG OUT button (lower left)
            Positioned(
              left: backBtnLeft,
              bottom: backBtnBottom,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD740),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 22,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Log out'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  }
                },
                child: const Text('LOG OUT'),
              ),
            ),
          ],
        ),
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

  const _HomeCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.customIcon = false,
    required this.width,
    required this.height,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
