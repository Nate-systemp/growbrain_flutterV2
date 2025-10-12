import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'set_session_screen.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:async';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({Key? key}) : super(key: key);

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 2; // 0: Back, 1: Profile, 2: Student List, 3: Analysis
  int _previousIndex = 2; // Track previous index for animation direction
  List<Map<String, dynamic>> students = [];
  bool _loadingStudents = false;
  int _studentsCount = 0;
  int _sessionsCount = 0;
  int _gamesCount = 0;
  Map<String, dynamic>? _viewingStudent;
  Map<String, dynamic>? _teacherProfile;
  bool _loadingProfile = false;
  String? _profileError;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _tabAnimationController;
  String _selectedMonth = 'All'; // Filter for performance trends

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'ST';
    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return names[0].substring(0, names[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: color.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  late Animation<double> _tabAnimation;
  Timer? _refreshTimer;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer for automatic refresh
    WidgetsBinding.instance.addObserver(this);

    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tabAnimationController, curve: Curves.easeInOut),
    );
    _tabAnimationController.forward();
    _previousIndex = _selectedIndex; // Initialize previous index

    // Initial data fetch
    _fetchStudents();
    _fetchTeacherProfile();
    _lastRefreshTime = DateTime.now();

    // Start periodic refresh timer (every 5 minutes)
    _startPeriodicRefresh();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabAnimationController.dispose();
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Refresh data when app comes back into focus
    if (state == AppLifecycleState.resumed) {
      _refreshDataIfNeeded();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _refreshDataIfNeeded();
      }
    });
  }

  void _refreshDataIfNeeded() {
    final now = DateTime.now();
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!).inMinutes >= 2) {
      _refreshAllData();
      _lastRefreshTime = now;
    }
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;

    // Refresh both students and teacher profile
    final futures = <Future>[];

    if (_selectedIndex == 1 || _selectedIndex == 2) {
      futures.add(_fetchTeacherProfile());
    }

    if (_selectedIndex == 2 || _selectedIndex == 4) {
      futures.add(_fetchStudents());
    }

    await Future.wait(futures);
  }

  void _switchTab(int newIndex) {
    if (newIndex != _selectedIndex) {
      // Add haptic feedback for better UX
      HapticFeedback.lightImpact();
      _tabAnimationController.reset();
      setState(() {
        _previousIndex = _selectedIndex;
        _selectedIndex = newIndex;
      });
      _tabAnimationController.forward();

      // Refresh data when switching to specific tabs
      _refreshDataOnTabSwitch(newIndex);
    }
  }

  void _refreshDataOnTabSwitch(int tabIndex) {
    switch (tabIndex) {
      case 1: // Teacher Profile
        _fetchTeacherProfile();
        break;
      case 2: // Student List
        _fetchStudents();
        break;
      case 4: // Analysis (needs student data)
        _fetchStudents();
        break;
    }
  }

  Future<void> _fetchStudents() async {
    if (!mounted) return;
    setState(() => _loadingStudents = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .get();
      students = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id; // Include the document ID
        return data;
      }).toList();
      // Update students count and derived stats
      _studentsCount = students.length;
      // Recompute sessions and games counts when students list changes
      unawaited(_computeProfileCounts());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch students: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStudents = false);
      }
    }
  }

  Future<void> _fetchTeacherProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        _teacherProfile = doc.data();
      } else {
        _profileError = 'Profile not found.';
      }
    } catch (e) {
      _profileError = 'Failed to load profile.';
    }
    setState(() {
      _loadingProfile = false;
    });
    // Ensure counts are up to date when profile is fetched
    unawaited(_computeProfileCounts());
  }

  // Compute total sessions (records) and unique games for the current teacher
  Future<void> _computeProfileCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final allRecords = await _fetchAllStudentRecords();
      final games = <String>{};
      for (final r in allRecords) {
        final game = (r['game'] ?? r['lastPlayed'])?.toString() ?? '';
        if (game.isNotEmpty) games.add(game);
      }
      if (mounted) {
        setState(() {
          _sessionsCount = allRecords.length;
          _gamesCount = games.length;
          // _studentsCount is managed by _fetchStudents
        });
      }
    } catch (e) {
      // ignore compute errors silently; UI will keep previous values
    }
  }

  String get _sectionLabel {
    switch (_selectedIndex) {
      case 2:
        return 'STUDENT LIST';
      case 1:
        return 'TEACHER PROFILE';
      case 4:
        return 'ANALYSIS';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_selectedIndex == 1) {
      // Enhanced Teacher Profile with pull-to-refresh
      if (_loadingProfile) {
        content = const Center(child: CircularProgressIndicator());
      } else if (_profileError != null) {
        content = RefreshIndicator(
          onRefresh: _fetchTeacherProfile,
          color: const Color(0xFF484F5C),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.4),
              Center(
                child: Text(
                  _profileError!,
                  style: const TextStyle(color: Colors.red, fontSize: 22),
                ),
              ),
            ],
          ),
        );
      } else {
        final profile = _teacherProfile;
        final name = profile?['name'] ?? 'N/A';
        final email = profile?['email'] ?? 'N/A';
        content = RefreshIndicator(
          onRefresh: _fetchTeacherProfile,
          color: const Color(0xFF484F5C),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: EnhancedTeacherProfile(
              name: name,
              email: email,
              studentsCount: _studentsCount,
              sessionsCount: _sessionsCount,
              gamesCount: _gamesCount,
              onLogout: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                            border: Border.all(
                              color: const Color(0xFFE1BEE7),
                              width: 1,
                            ),
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
                                  'You will need to log in again to access the teacher dashboard.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7B1FA2),
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                shadowColor: const Color(
                                  0xFFD32F2F,
                                ).withOpacity(0.3),
                              ),
                              child: const Text(
                                'Log Out',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                }
              },
            ),
          ),
        );
      }
    } else if (_selectedIndex == 2) {
      // Student List with pull-to-refresh
      final validStudents = students
          .where((s) => (s['fullName'] ?? '').toString().trim().isNotEmpty)
          .where(
            (s) =>
                _searchQuery.isEmpty ||
                (s['fullName'] ?? '').toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
      content = Padding(
        padding: const EdgeInsets.only(
          top: 80,
          left: 40,
          right: 40,
          bottom: 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 20),
              child: Center(
                child: Container(
                  width: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search student name...',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.search_rounded,
                          size: 24,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFFE8F5E8),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFFE8F5E8),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF4CAF50),
                          width: 3,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchStudents,
                color: const Color(0xFF484F5C),
                child: _loadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : validStudents.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: Text(
                              'No students found.',
                              style: TextStyle(
                                fontSize: 28,
                                color: Color(0xFF393C48),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: SizedBox(
                          width: 600,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: validStudents.length,
                            itemBuilder: (context, index) {
                              final student = validStudents[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE8F5E8),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withOpacity(0.15),
                                      blurRadius: 0,
                                      offset: const Offset(0, 6),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      // Student Name
                                      Expanded(
                                        child: Text(
                                          student['fullName'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            color: Color(0xFF2E7D32),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      // Action Buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildActionButton(
                                            'View Profile',
                                            Icons.person_outline,
                                            const Color(0xFF4CAF50),
                                            () => setState(
                                              () => _viewingStudent = student,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          _buildActionButton(
                                            'Records',
                                            Icons.assessment,
                                            const Color(0xFFFF9800),
                                            () => _showRecordsModal(student),
                                          ),
                                          const SizedBox(width: 12),
                                          _buildActionButton(
                                            'Set Session',
                                            Icons.schedule,
                                            const Color(0xFF2196F3),
                                            () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    SetSessionScreen(
                                                      student: student,
                                                    ),
                                              ),
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
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    } else if (_selectedIndex == 4) {
      // ANALYTICS DASHBOARD FOR ALL STUDENTS
      content = Padding(
        padding: const EdgeInsets.only(
          top: 120,
          left: 40,
          right: 40,
          bottom: 80,
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchAllStudentRecords(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allRecords = snapshot.data!;
            if (allRecords.isEmpty) {
              return const Center(
                child: Text(
                  'No records found.',
                  style: TextStyle(fontSize: 24),
                ),
              );
            }
            // Aggregate data
            final accuracyTrend =
                allRecords.where((r) => r['date'] != null).toList()
                  ..sort((a, b) {
                    final aDate = a['date'];
                    final bDate = b['date'];
                    DateTime aDt;
                    DateTime bDt;
                    if (aDate is Timestamp) {
                      aDt = aDate.toDate();
                    } else if (aDate is String) {
                      aDt = DateTime.tryParse(aDate) ?? DateTime(1970);
                    } else if (aDate is DateTime) {
                      aDt = aDate;
                    } else {
                      aDt = DateTime(1970);
                    }
                    if (bDate is Timestamp) {
                      bDt = bDate.toDate();
                    } else if (bDate is String) {
                      bDt = DateTime.tryParse(bDate) ?? DateTime(1970);
                    } else if (bDate is DateTime) {
                      bDt = bDate;
                    } else {
                      bDt = DateTime(1970);
                    }
                    return aDt.compareTo(bDt);
                  });
            final trendValues = accuracyTrend
                .map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0)
                .toList();
            // Per-student summary
            final Map<String, List<Map<String, dynamic>>> recordsByStudent = {};
            for (final r in allRecords) {
              final name = r['studentName'] ?? r['studentId'] ?? 'Unknown';
              recordsByStudent.putIfAbsent(name, () => []).add(r);
            }

            // Most Improved Student (largest positive change in accuracy)
            String? mostImprovedName;
            double mostImprovedValue = 0;
            for (final entry in recordsByStudent.entries) {
              final records = entry.value;
              if (records.length < 2) continue;
              records.sort((a, b) {
                final aDate = a['date'];
                final bDate = b['date'];
                DateTime aDt;
                DateTime bDt;
                if (aDate is Timestamp) {
                  aDt = aDate.toDate();
                } else if (aDate is String) {
                  aDt = DateTime.tryParse(aDate) ?? DateTime(1970);
                } else if (aDate is DateTime) {
                  aDt = aDate;
                } else {
                  aDt = DateTime(1970);
                }
                if (bDate is Timestamp) {
                  bDt = bDate.toDate();
                } else if (bDate is String) {
                  bDt = DateTime.tryParse(bDate) ?? DateTime(1970);
                } else if (bDate is DateTime) {
                  bDt = bDate;
                } else {
                  bDt = DateTime(1970);
                }
                return aDt.compareTo(bDt);
              });
              final first =
                  (records.first['accuracy'] as num?)?.toDouble() ?? 0.0;
              final last =
                  (records.last['accuracy'] as num?)?.toDouble() ?? 0.0;
              final improvement = last - first;
              if (improvement > mostImprovedValue) {
                mostImprovedValue = improvement;
                mostImprovedName = entry.key;
              }
            }

            // Best Streak (longest consecutive improvement in accuracy)
            String? bestStreakName;
            int bestStreakValue = 0;
            for (final entry in recordsByStudent.entries) {
              final records = entry.value;
              if (records.length < 2) continue;
              records.sort((a, b) {
                final aDate = a['date'];
                final bDate = b['date'];
                DateTime aDt;
                DateTime bDt;
                if (aDate is Timestamp) {
                  aDt = aDate.toDate();
                } else if (aDate is String) {
                  aDt = DateTime.tryParse(aDate) ?? DateTime(1970);
                } else if (aDate is DateTime) {
                  aDt = aDate;
                } else {
                  aDt = DateTime(1970);
                }
                if (bDate is Timestamp) {
                  bDt = bDate.toDate();
                } else if (bDate is String) {
                  bDt = DateTime.tryParse(bDate) ?? DateTime(1970);
                } else if (bDate is DateTime) {
                  bDt = bDate;
                } else {
                  bDt = DateTime(1970);
                }
                return aDt.compareTo(bDt);
              });
              int streak = 1;
              int maxStreak = 1;
              for (int i = 1; i < records.length; i++) {
                final prev =
                    (records[i - 1]['accuracy'] as num?)?.toDouble() ?? 0.0;
                final curr =
                    (records[i]['accuracy'] as num?)?.toDouble() ?? 0.0;
                if (curr > prev) {
                  streak++;
                  if (streak > maxStreak) maxStreak = streak;
                } else {
                  streak = 1;
                }
              }
              if (maxStreak > bestStreakValue) {
                bestStreakValue = maxStreak;
                bestStreakName = entry.key;
              }
            }

            // Calculate additional analytics
            // Game performance analysis
            final gamePerformance = <String, Map<String, double>>{};

            for (final record in allRecords) {
              final game = record['game'] ?? record['lastPlayed'] ?? 'Unknown';
              final accuracy = (record['accuracy'] as num?)?.toDouble() ?? 0.0;
              final completionTime =
                  (record['completionTime'] as num?)?.toDouble() ?? 0.0;

              if (!gamePerformance.containsKey(game)) {
                gamePerformance[game] = {
                  'totalAccuracy': 0,
                  'totalTime': 0,
                  'count': 0,
                };
              }
              gamePerformance[game]!['totalAccuracy'] =
                  (gamePerformance[game]!['totalAccuracy'] ?? 0) + accuracy;
              gamePerformance[game]!['totalTime'] =
                  (gamePerformance[game]!['totalTime'] ?? 0) + completionTime;
              gamePerformance[game]!['count'] =
                  (gamePerformance[game]!['count'] ?? 0) + 1;
            }

            // Calculate averages for each game
            final gameAverages = <String, Map<String, double>>{};
            gamePerformance.forEach((game, data) {
              final count = data['count'] ?? 1;
              gameAverages[game] = {
                'avgAccuracy': (data['totalAccuracy'] ?? 0) / count,
                'avgTime': (data['totalTime'] ?? 0) / count,
              };
            });

            // Difficulty analysis
            final difficultyPerformance = <String, Map<String, double>>{};
            for (final record in allRecords) {
              final difficulty = record['difficulty'] ?? 'Unknown';
              final accuracy = (record['accuracy'] as num?)?.toDouble() ?? 0.0;

              if (!difficultyPerformance.containsKey(difficulty)) {
                difficultyPerformance[difficulty] = {
                  'totalAccuracy': 0,
                  'count': 0,
                };
              }
              difficultyPerformance[difficulty]!['totalAccuracy'] =
                  (difficultyPerformance[difficulty]!['totalAccuracy'] ?? 0) +
                  accuracy;
              difficultyPerformance[difficulty]!['count'] =
                  (difficultyPerformance[difficulty]!['count'] ?? 0) + 1;
            }

            // Overall statistics
            final totalSessions = allRecords.length;
            final avgOverallAccuracy = allRecords.isNotEmpty
                ? allRecords
                          .map(
                            (r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0,
                          )
                          .reduce((a, b) => a + b) /
                      allRecords.length
                : 0.0;
            final avgOverallTime = allRecords.isNotEmpty
                ? allRecords
                          .map(
                            (r) =>
                                (r['completionTime'] as num?)?.toDouble() ??
                                0.0,
                          )
                          .reduce((a, b) => a + b) /
                      allRecords.length
                : 0.0;

            // Find best performing game
            String? bestGame;
            double bestGameAccuracy = 0;
            gameAverages.forEach((game, data) {
              if (data['avgAccuracy']! > bestGameAccuracy) {
                bestGameAccuracy = data['avgAccuracy']!;
                bestGame = game;
              }
            });

            // Find most challenging game (lowest accuracy)
            String? challengingGame;
            double lowestAccuracy = 100;
            gameAverages.forEach((game, data) {
              if (data['avgAccuracy']! < lowestAccuracy) {
                lowestAccuracy = data['avgAccuracy']!;
                challengingGame = game;
              }
            });

            return Container(
              color: Color(0xFFF8F9FA),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Clean Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: Color(0xFF374151),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Analytics Dashboard',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Simple Stats Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildMinimalStatCard(
                                  totalSessions.toString(),
                                  'Total Sessions',
                                  Icons.play_circle_outline,
                                  Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMinimalStatCard(
                                  '${avgOverallAccuracy.toStringAsFixed(1)}%',
                                  'Avg Accuracy',
                                  Icons.track_changes_outlined,
                                  Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMinimalStatCard(
                                  '${avgOverallTime.toStringAsFixed(1)}s',
                                  'Avg Time',
                                  Icons.timer_outlined,
                                  Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMinimalStatCard(
                                  recordsByStudent.length.toString(),
                                  'Students',
                                  Icons.people_outline,
                                  Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Performance Trends with Month Filter
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up_outlined,
                                color: Color(0xFF374151),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Performance Trends',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const Spacer(),
                              // Month Filter Dropdown
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedMonth,
                                    isDense: true,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    items: _getAvailableMonths(accuracyTrend)
                                        .map((String month) {
                                          return DropdownMenuItem<String>(
                                            value: month,
                                            child: Text(month),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedMonth = newValue ?? 'All';
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final filteredData = _filterTrendData(
                                accuracyTrend,
                                _selectedMonth,
                              );
                              final filteredValues = filteredData
                                  .map(
                                    (r) =>
                                        (r['accuracy'] as num?)?.toDouble() ??
                                        0.0,
                                  )
                                  .toList();
                              final filteredLabels = filteredData.map((r) {
                                if (r['date'] is Timestamp) {
                                  final date = (r['date'] as Timestamp)
                                      .toDate();
                                  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                } else if (r['date'] is String) {
                                  final date = DateTime.tryParse(r['date']);
                                  if (date != null) {
                                    return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                  }
                                }
                                return '';
                              }).toList();

                              return MinimalTrendChart(
                                values: filteredValues,
                                xLabels: filteredLabels,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Student Performance
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bar_chart_outlined,
                                      color: Color(0xFF374151),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Accuracy',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                MinimalBarChart(
                                  data: {
                                    for (final entry
                                        in recordsByStudent.entries)
                                      entry.key: entry.value.isNotEmpty
                                          ? entry.value
                                                    .map(
                                                      (r) =>
                                                          (r['accuracy']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                    )
                                                    .reduce((a, b) => a + b) /
                                                entry.value.length
                                          : 0.0,
                                  },
                                  maxValue: 100.0,
                                  suffix: '%',
                                  color: Color(0xFF10B981),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.speed_outlined,
                                      color: Color(0xFF374151),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Completion Time',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                MinimalBarChart(
                                  data: {
                                    for (final entry
                                        in recordsByStudent.entries)
                                      entry.key: entry.value.isNotEmpty
                                          ? entry.value
                                                    .map(
                                                      (r) =>
                                                          (r['completionTime']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                    )
                                                    .reduce((a, b) => a + b) /
                                                entry.value.length
                                          : 0.0,
                                  },
                                  maxValue: 60.0,
                                  suffix: 's',
                                  color: Color(0xFF8B5CF6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Game Performance Analysis
                    if (gameAverages.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.games_outlined,
                                  color: Color(0xFF374151),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Game Performance',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            MinimalGameChart(
                              gameData: {
                                for (final entry in gameAverages.entries)
                                  entry.key: entry.value['avgAccuracy'] ?? 0.0,
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Key Insights
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.insights_outlined,
                                color: Color(0xFF374151),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Key Insights',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Insight Cards
                          Row(
                            children: [
                              if (mostImprovedName != null)
                                Expanded(
                                  child: _buildMinimalInsightCard(
                                    'Most Improved',
                                    mostImprovedName,
                                    '+${mostImprovedValue.toStringAsFixed(1)}%',
                                    Icons.trending_up,
                                    Color(0xFF10B981),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              if (bestStreakName != null)
                                Expanded(
                                  child: _buildMinimalInsightCard(
                                    'Best Streak',
                                    bestStreakName,
                                    '$bestStreakValue sessions',
                                    Icons.emoji_events,
                                    Color(0xFFF59E0B),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              if (bestGame != null)
                                Expanded(
                                  child: _buildMinimalInsightCard(
                                    'Top Game',
                                    bestGame!,
                                    '${bestGameAccuracy.toStringAsFixed(1)}%',
                                    Icons.star,
                                    Color(0xFF3B82F6),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              if (challengingGame != null)
                                Expanded(
                                  child: _buildMinimalInsightCard(
                                    'Needs Focus',
                                    challengingGame!,
                                    '${lowestAccuracy.toStringAsFixed(1)}%',
                                    Icons.flag,
                                    Color(0xFFEF4444),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Student Progress List
                          Text(
                            'Student Overview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...recordsByStudent.entries.map((entry) {
                            final name = entry.key;
                            final records = entry.value;
                            final avgAcc = records.isNotEmpty
                                ? records
                                          .map(
                                            (r) =>
                                                (r['accuracy'] as num?)
                                                    ?.toDouble() ??
                                                0.0,
                                          )
                                          .reduce((a, b) => a + b) /
                                      records.length
                                : 0.0;
                            final avgComp = records.isNotEmpty
                                ? records
                                          .map(
                                            (r) =>
                                                (r['completionTime'] as num?)
                                                    ?.toDouble() ??
                                                0.0,
                                          )
                                          .reduce((a, b) => a + b) /
                                      records.length
                                : 0.0;

                            // Calculate trend for this student
                            String trendText = 'Stable';
                            Color trendColor = Color(0xFF6B7280);
                            IconData trendIcon = Icons.trending_flat;
                            if (records.length >= 2) {
                              final sorted = List.from(records)
                                ..sort((a, b) {
                                  final aDate =
                                      DateTime.tryParse(a['date'] ?? '') ??
                                      DateTime(1970);
                                  final bDate =
                                      DateTime.tryParse(b['date'] ?? '') ??
                                      DateTime(1970);
                                  return aDate.compareTo(bDate);
                                });
                              final firstAcc =
                                  (sorted.first['accuracy'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              final lastAcc =
                                  (sorted.last['accuracy'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              if (lastAcc > firstAcc + 5) {
                                trendText = 'Improving';
                                trendColor = Color(0xFF10B981);
                                trendIcon = Icons.trending_up;
                              } else if (lastAcc < firstAcc - 5) {
                                trendText = 'Declining';
                                trendColor = Color(0xFFEF4444);
                                trendIcon = Icons.trending_down;
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          '${records.length} sessions',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Metrics
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${avgAcc.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${avgComp.toStringAsFixed(1)}s',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(trendIcon, size: 16, color: trendColor),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    // Student Profile Modal
    if (_viewingStudent != null) {
      final studentToShow = _viewingStudent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => StudentProfileModal(
            student: studentToShow!,
            onClose: () => setState(() => _viewingStudent = null),
          ),
        );
        setState(() => _viewingStudent = null);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Persistent header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 32, bottom: 18),
              color: Colors.white,
              child: Center(
                child: Text(
                  'TEACHER MANAGEMENT',
                  style: const TextStyle(
                    fontSize: 33,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF393C48),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          // Back to games button
          Positioned(
            top: 16,
            right: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD740),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                shadowColor: Colors.black.withOpacity(0.1),
              ),
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
              },
              child: const Text('Back to home'),
            ),
          ),
          // Animated content area with improved transitions
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            reverseDuration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.0, 0.03), // Subtle vertical slide
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutQuart,
                        ),
                      ),
                  child: ScaleTransition(
                    scale:
                        Tween<double>(
                          begin: 0.98, // Very subtle scale
                          end: 1.0,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutQuart,
                          ),
                        ),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              key: ValueKey<int>(_selectedIndex),
              child: content,
            ),
          ),
          // Enhanced Bottom navigation bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavCircleIconButton(
                    icon: Icons.person_outline,
                    selected: _selectedIndex == 1,
                    onTap: () => _switchTab(1),
                  ),
                  const SizedBox(width: 40),
                  _NavCircleIconButton(
                    icon: Icons.list_alt,
                    selected: _selectedIndex == 2,
                    onTap: () => _switchTab(2),
                  ),
                  const SizedBox(width: 40),
                  _NavCircleIconButton(
                    icon: Icons.analytics_outlined,
                    selected: _selectedIndex == 4,
                    onTap: () => _switchTab(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordsModal(Map<String, dynamic> student) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final studentId = student['id']; // Use the document ID
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot load records: Student ID not found.'),
        ),
      );
      return;
    }

    // Fetch all records for history
    final recordsSnap = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(user.uid)
        .collection('students')
        .doc(studentId)
        .collection('records')
        .orderBy('date', descending: true)
        .get();
    final records = recordsSnap.docs.map((d) => d.data()).toList();

    if (records.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: const Center(
              child: Text('No records found.', style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
      );
      return;
    }

    _showCompactRecordsModal(student, records);
  }

  void _showCompactRecordsModal(
    Map<String, dynamic> student,
    List<Map<String, dynamic>> records,
  ) {
    String filterType = 'All'; // All, Game, Date, Focus
    String? selectedFilter;
    DateTime? selectedDate;

    void showModalWithFilters() {
      // Calculate summary statistics
      final avgAccuracy = records.isNotEmpty
          ? records
                    .map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a + b) /
                records.length
          : 0.0;

      final avgTime = records.isNotEmpty
          ? records
                    .map(
                      (r) => (r['completionTime'] as num?)?.toDouble() ?? 0.0,
                    )
                    .reduce((a, b) => a + b) /
                records.length
          : 0.0;

      final totalGames = records.length;
      final uniqueGames = records
          .map((r) => r['lastPlayed'] ?? 'Unknown')
          .toSet()
          .length;

      // Filter records based on selected filter
      List<Map<String, dynamic>> filteredRecords = records;

      if (filterType == 'Game' && selectedFilter != null) {
        filteredRecords = records
            .where((r) => r['lastPlayed'] == selectedFilter)
            .toList();
      } else if (filterType == 'Focus' && selectedFilter != null) {
        filteredRecords = records
            .where((r) => r['challengeFocus'] == selectedFilter)
            .toList();
      } else if (filterType == 'Date' && selectedDate != null) {
        filteredRecords = records.where((r) {
          final d = DateTime.tryParse(r['date'] ?? '')?.toLocal();
          return d != null &&
              d.year == selectedDate!.year &&
              d.month == selectedDate!.month &&
              d.day == selectedDate!.day;
        }).toList();
      }

      // Group records for better organization
      Map<String, List<Map<String, dynamic>>> groupedRecords = {};
      if (filterType == 'All') {
        // Group by game type
        for (final record in filteredRecords) {
          final game = record['lastPlayed'] ?? 'Unknown';
          groupedRecords.putIfAbsent(game, () => []).add(record);
        }
      } else {
        // Group by date if filtering by specific criteria
        for (final record in filteredRecords) {
          final date = DateTime.tryParse(record['date'] ?? '')?.toLocal();
          final dateKey = date != null
              ? '${date.day}/${date.month}/${date.year}'
              : 'Unknown Date';
          groupedRecords.putIfAbsent(dateKey, () => []).add(record);
        }
      }

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with title and chart button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${student['fullName'] ?? 'Student'}'s Records",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            showChartModal(filteredRecords, records);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFFE5E7EB)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bar_chart_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'View Charts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Summary Statistics
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Games',
                          totalGames.toString(),
                          Icons.games,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Accuracy',
                          '${avgAccuracy.toStringAsFixed(1)}%',
                          Icons.track_changes,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Time',
                          _formatCompletionTime(avgTime),
                          Icons.timer,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Games Types',
                          uniqueGames.toString(),
                          Icons.category,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Filter by:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildFilterChip('All', filterType == 'All', () {
                        filterType = 'All';
                        selectedFilter = null;
                        selectedDate = null;
                        Navigator.of(ctx).pop();
                        showModalWithFilters();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Game', filterType == 'Game', () {
                        filterType = 'Game';
                        _showFilterOptions(ctx, 'Game', records, (selected) {
                          selectedFilter = selected;
                          selectedDate = null;
                          Navigator.of(ctx).pop();
                          showModalWithFilters();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Focus', filterType == 'Focus', () {
                        filterType = 'Focus';
                        _showFilterOptions(ctx, 'Focus', records, (selected) {
                          selectedFilter = selected;
                          selectedDate = null;
                          Navigator.of(ctx).pop();
                          showModalWithFilters();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Date', filterType == 'Date', () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          filterType = 'Date';
                          selectedDate = picked;
                          selectedFilter = null;
                          Navigator.of(ctx).pop();
                          showModalWithFilters();
                        }
                      }),
                    ],
                  ),
                ),

                // Active Filter Display
                if (selectedFilter != null || selectedDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blueAccent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedFilter ??
                                    _formatDateFilter(selectedDate!),
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  filterType = 'All';
                                  selectedFilter = null;
                                  selectedDate = null;
                                  Navigator.of(ctx).pop();
                                  showModalWithFilters();
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${filteredRecords.length} records',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Records List
                Expanded(
                  child: filteredRecords.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No records found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          itemCount: groupedRecords.keys.length,
                          itemBuilder: (context, index) {
                            final groupKey = groupedRecords.keys.elementAt(
                              index,
                            );
                            final groupRecords = groupedRecords[groupKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Group Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          groupKey,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${groupRecords.length})',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Compact Records Grid
                                ...groupRecords.map(
                                  (record) => _buildCompactRecordCard(record),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
                ),

                // Footer with close button
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
      );
    }

    showModalWithFilters();
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Color(0xFF374151),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRecordCard(Map<String, dynamic> record) {
    final date = DateTime.tryParse(record['date'] ?? '')?.toLocal();
    final formattedDate = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : 'N/A';
    final formattedTime = date != null
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '';

    final accuracy = record['accuracy'] ?? 0;
    final accuracyColor = accuracy >= 80
        ? Colors.green
        : accuracy >= 60
        ? Colors.orange
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Game & Date
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['lastPlayed'] ?? 'Unknown Game',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$formattedDate $formattedTime',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Focus & Difficulty
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record['challengeFocus'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record['difficulty'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Performance
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${accuracy}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accuracyColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCompletionTime(record['completionTime']),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(
    BuildContext context,
    String filterType,
    List<Map<String, dynamic>> records,
    Function(String) onSelected,
  ) {
    List<String> options = [];

    if (filterType == 'Game') {
      options = records
          .map((r) => r['lastPlayed']?.toString() ?? 'Unknown')
          .toSet()
          .toList();
    } else if (filterType == 'Focus') {
      options = records
          .map((r) => r['challengeFocus']?.toString() ?? 'Unknown')
          .toSet()
          .toList()
          .where((option) => option.toLowerCase() != 'auditory processing')
          .toList();
    }

    options.sort();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon and title
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            filterType == 'Game'
                                ? Icons.games
                                : Icons.psychology,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select $filterType',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                'Choose from ${options.length} available options',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Options list with scroll indicators
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Stack(
                          children: [
                            // Scrollable content
                            Scrollbar(
                              thumbVisibility: true,
                              thickness: 4,
                              radius: const Radius.circular(2),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  children: [
                                    // Top scroll indicator
                                    if (options.length > 4)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                          border: const Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.keyboard_arrow_up,
                                              color: Colors.grey[400],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Scroll to see more options',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.grey[400],
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Options
                                    ...options.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final option = entry.value;
                                      final isLast =
                                          index == options.length - 1;
                                      final isFirst = index == 0;

                                      return Container(
                                        decoration: BoxDecoration(
                                          border: isLast
                                              ? null
                                              : const Border(
                                                  bottom: BorderSide(
                                                    color: Color(0xFFE5E7EB),
                                                    width: 1,
                                                  ),
                                                ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.vertical(
                                              top:
                                                  (isFirst &&
                                                      options.length <= 4)
                                                  ? const Radius.circular(16)
                                                  : Radius.zero,
                                              bottom: isLast
                                                  ? const Radius.circular(16)
                                                  : Radius.zero,
                                            ),
                                            onTap: () {
                                              Navigator.of(ctx).pop();
                                              onSelected(option);
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 16,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF3B82F6,
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      _getFilterOptionIcon(
                                                        filterType,
                                                        option,
                                                      ),
                                                      color: const Color(
                                                        0xFF3B82F6,
                                                      ),
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      option,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(
                                                          0xFF111827,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.arrow_forward_ios,
                                                    color: Color(0xFF9CA3AF),
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),

                                    // Bottom scroll indicator
                                    if (options.length > 4)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.swipe_vertical,
                                              color: Colors.grey[400],
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Swipe to scroll',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Fade indicators for scroll
                            if (options.length > 4) ...[
                              // Top fade
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom fade
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6B7280),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Positioned(
                top: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFilterOptionIcon(String filterType, String option) {
    if (filterType == 'Game') {
      switch (option.toLowerCase()) {
        case 'find me':
          return Icons.search;
        case 'light tap':
          return Icons.touch_app;
        case 'who moved?':
          return Icons.visibility;
        case 'match cards':
          return Icons.style;
        case 'tictactoe':
          return Icons.grid_3x3;
        case 'puzzle':
          return Icons.extension;
        case 'riddle game':
          return Icons.question_mark;
        case 'word grid':
          return Icons.grid_4x4;
        case 'scrabble':
          return Icons.grid_on;
        case 'anagram':
          return Icons.shuffle;
        case 'fruit shuffle':
          return Icons.apple;
        case 'object hunt':
          return Icons.search_off;
        default:
          return Icons.games;
      }
    } else if (filterType == 'Focus') {
      switch (option.toLowerCase()) {
        case 'attention':
          return Icons.visibility;
        case 'memory':
          return Icons.psychology;
        case 'logic':
          return Icons.lightbulb;
        case 'verbal':
          return Icons.record_voice_over;
        default:
          return Icons.category;
      }
    }
    return Icons.filter_list;
  }

  String _formatDateFilter(DateTime date) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  void showChartModal(
    List<Map<String, dynamic>> filteredRecords,
    List<Map<String, dynamic>> allRecords,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Performance Charts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Compact Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    child: CompactDonutChart(
                                      percent: filteredRecords.isNotEmpty
                                          ? (filteredRecords
                                                        .map(
                                                          (r) =>
                                                              (r['accuracy']
                                                                      as num?)
                                                                  ?.toDouble() ??
                                                              0.0,
                                                        )
                                                        .reduce(
                                                          (a, b) => a + b,
                                                        ) /
                                                    filteredRecords.length) /
                                                100.0
                                          : 0.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Accuracy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    filteredRecords.isNotEmpty
                                        ? '${(filteredRecords.map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / filteredRecords.length).toStringAsFixed(1)}%'
                                        : '--%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 20,
                                    child: CompactProgressBar(
                                      value: filteredRecords.isNotEmpty
                                          ? (filteredRecords
                                                    .map(
                                                      (r) =>
                                                          (r['completionTime']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                    )
                                                    .reduce((a, b) => a + b) /
                                                filteredRecords.length)
                                          : 0.0,
                                      maxValue: 60.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Avg Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    filteredRecords.isNotEmpty
                                        ? '${(filteredRecords.map((r) => (r['completionTime'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / filteredRecords.length).toStringAsFixed(1)}s'
                                        : '--s',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Compact Trend Chart
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accuracy Trend',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 80,
                              child: CompactLineChart(
                                values: filteredRecords.reversed
                                    .map(
                                      (r) =>
                                          (r['accuracy'] as num?)?.toDouble() ??
                                          0.0,
                                    )
                                    .toList(),
                                maxValue: 100.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Game Summary
                      if (filteredRecords.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session Summary',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Sessions:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    '${filteredRecords.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Best Score:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    '${filteredRecords.map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalInsightCard(
    String title,
    String name,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(
    String value,
    String label,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernInsightCard(
    String title,
    String name,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompletionTime(dynamic value) {
    if (value == null) return '-';
    int seconds;
    if (value is int) {
      seconds = value;
    } else if (value is String) {
      seconds = int.tryParse(value) ?? 0;
    } else {
      return '-';
    }
    if (seconds < 60) {
      return '$seconds second${seconds == 1 ? '' : 's'}';
    } else if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return s == 0
          ? '$m minute${m == 1 ? '' : 's'}'
          : '$m minute${m == 1 ? '' : 's'} $s second${s == 1 ? '' : 's'}';
    } else {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return m == 0
          ? '$h hour${h == 1 ? '' : 's'}'
          : '$h hour${h == 1 ? '' : 's'} $m minute${m == 1 ? '' : 's'}';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllStudentRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final studentsSnap = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(user.uid)
        .collection('students')
        .get();
    final List<Map<String, dynamic>> allRecords = [];
    for (final doc in studentsSnap.docs) {
      final studentId = doc.id;
      final studentName = doc.data()['fullName'] ?? studentId;
      final recordsSnap = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .collection('records')
          .get();
      for (final rec in recordsSnap.docs) {
        final data = rec.data();
        data['studentId'] = studentId;
        data['studentName'] = studentName;
        allRecords.add(data);
      }
    }
    return allRecords;
  }

  // Helper method to get available months from trend data
  List<String> _getAvailableMonths(List<Map<String, dynamic>> trendData) {
    final months = <String>{'All'};
    final monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    for (final record in trendData) {
      DateTime? date;
      if (record['date'] is Timestamp) {
        date = (record['date'] as Timestamp).toDate();
      } else if (record['date'] is String) {
        date = DateTime.tryParse(record['date']);
      }

      if (date != null) {
        final monthYear = '${monthNames[date.month]} ${date.year}';
        months.add(monthYear);
      }
    }

    final sortedMonths = months.toList();
    // Keep 'All' at the beginning, sort the rest
    final monthsWithoutAll = sortedMonths.where((m) => m != 'All').toList();
    monthsWithoutAll.sort((a, b) {
      // Extract year and month for proper sorting
      final aParts = a.split(' ');
      final bParts = b.split(' ');
      if (aParts.length == 2 && bParts.length == 2) {
        final aYear = int.tryParse(aParts[1]) ?? 0;
        final bYear = int.tryParse(bParts[1]) ?? 0;
        if (aYear != bYear) return bYear.compareTo(aYear); // Recent years first

        final aMonth = monthNames.indexOf(aParts[0]);
        final bMonth = monthNames.indexOf(bParts[0]);
        return bMonth.compareTo(aMonth); // Recent months first
      }
      return 0;
    });

    return ['All', ...monthsWithoutAll];
  }

  // Helper method to filter trend data by selected month
  List<Map<String, dynamic>> _filterTrendData(
    List<Map<String, dynamic>> trendData,
    String selectedMonth,
  ) {
    if (selectedMonth == 'All') {
      // Limit to last 30 data points for better visualization
      return trendData.length > 30
          ? trendData.sublist(trendData.length - 30)
          : trendData;
    }

    final monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final parts = selectedMonth.split(' ');
    if (parts.length != 2) return [];

    final targetMonth = monthNames.indexOf(parts[0]);
    final targetYear = int.tryParse(parts[1]);

    if (targetMonth == -1 || targetYear == null) return [];

    return trendData.where((record) {
      DateTime? date;
      if (record['date'] is Timestamp) {
        date = (record['date'] as Timestamp).toDate();
      } else if (record['date'] is String) {
        date = DateTime.tryParse(record['date']);
      }

      return date != null &&
          date.month == targetMonth &&
          date.year == targetYear;
    }).toList();
  }
}

class _NavCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCenter;
  final VoidCallback onTap;
  const _NavCircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCenter = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: isCenter ? 70 : 58,
            height: isCenter ? 70 : 58,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: isCenter ? 38 : 32,
              color: const Color(0xFF393C48),
            ),
          ),
        ),
        if (isCenter) const SizedBox(height: 8),
        if (isCenter)
          const Text(
            'STUDENT LIST',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: 1.2,
            ),
          ),
        if (!isCenter) const SizedBox(height: 18),
      ],
    );
  }
}

class AddStudentForm extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const AddStudentForm({required this.onSave, Key? key}) : super(key: key);

  @override
  State<AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends State<AddStudentForm> {
  final _formKey = GlobalKey<FormState>();
  String fullName = '';
  String age = '';
  String sex = '';
  bool attention = false;
  bool logic = false;
  bool memory = false;
  bool verbal = false;
  String guardianName = '';
  String contactNumber = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final labelStyle = const TextStyle(
      fontSize: 15,
      color: Color(0xFF393C48),
      fontWeight: FontWeight.w600,
    );
    final fieldHeight = 54.0;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF393C48), width: 3),
    );
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        margin: const EdgeInsets.only(top: 60, bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: fieldHeight,
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: 'Enter Full Name',
                              hintStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (v) => fullName = v,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF393C48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Full Name', style: labelStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: fieldHeight,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'Age',
                              hintStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: age.isEmpty ? null : age,
                            items: List.generate(8, (i) {
                              final val = (6 + i).toString();
                              return DropdownMenuItem(
                                value: val,
                                child: Text(val),
                              );
                            }),
                            onChanged: (v) => setState(() => age = v ?? ''),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF393C48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Age', style: labelStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: fieldHeight,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'Sex',
                              hintStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: sex.isEmpty ? null : sex,
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
                            ],
                            onChanged: (v) => setState(() => sex = v ?? ''),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF393C48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Sex', style: labelStyle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Student's Cognitive Needs\n(check if applicable)",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF393C48),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _CheckBox(
                    label: 'Attention',
                    value: attention,
                    onChanged: (v) => setState(() => attention = v),
                  ),
                  _CheckBox(
                    label: 'Logic',
                    value: logic,
                    onChanged: (v) => setState(() => logic = v),
                  ),
                  _CheckBox(
                    label: 'Memory',
                    value: memory,
                    onChanged: (v) => setState(() => memory = v),
                  ),
                  _CheckBox(
                    label: 'Verbal',
                    value: verbal,
                    onChanged: (v) => setState(() => verbal = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: fieldHeight,
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: 'Enter Guardian Name',
                              hintStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (v) => guardianName = v,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF393C48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Guardian Name', style: labelStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: fieldHeight,
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: 'Enter Contact Number',
                              hintStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (v) => contactNumber = v,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (!RegExp(r'^\d+$').hasMatch(v))
                                return 'Numbers only';
                              return null;
                            },
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF393C48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Contact Number', style: labelStyle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD740),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 38,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    onPressed: _saving
                        ? null
                        : () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              setState(() => _saving = true);
                              await widget.onSave({
                                'fullName': fullName,
                                'age': age,
                                'sex': sex,
                                'attention': attention,
                                'logic': logic,
                                'memory': memory,
                                'verbal': verbal,
                                'guardianName': guardianName,
                                'contactNumber': contactNumber,
                              });
                              setState(() => _saving = false);
                            }
                          },
                    child: _saving
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('Save Student'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final void Function(String) onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  const _StyledTextField({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.validator,
    this.keyboardType,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: _inputDecoration(hint),
          onChanged: onChanged,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 20,
            color: Color(0xFF393C48),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF393C48),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.grey,
      fontSize: 20,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF393C48), width: 3),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF393C48), width: 3),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF393C48), width: 3),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

class _CheckBox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckBox({
    required this.label,
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: const Color(0xFF393C48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF393C48),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _CurvedNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final String label;
  const _CurvedNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.label,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double iconSize = 44;
    final double circleSize = 84;
    final double navHeight = 148;
    final double labelFontSize = 34;
    final double radius = 44;
    final double width = MediaQuery.of(context).size.width;
    final double spacing = (width - 5 * radius * 2) / 4;
    final double centerY = radius;
    return SizedBox(
      height: navHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Arc background
          Positioned.fill(child: CustomPaint(painter: _ArcPainterPerfect())),
          // Icon circles (always scalloped, always centered)
          ...List.generate(5, (i) {
            final cx = radius + i * (2 * radius + spacing);
            int navIndex = i;
            // Swap index 1 and 2 for icon/logic
            if (i == 1)
              navIndex = 2;
            else if (i == 2)
              navIndex = 1;
            return Positioned(
              left: cx - circleSize / 2,
              top: centerY - circleSize / 2,
              child: _NavCircleButton2(
                icon: navIndex == 0
                    ? Icons.exit_to_app
                    : navIndex == 1
                    ? Icons.person
                    : navIndex == 2
                    ? Icons.list
                    : navIndex == 3
                    ? null
                    : null,
                svgAsset: navIndex == 3
                    ? 'assets/icons/add_student.svg'
                    : navIndex == 4
                    ? 'assets/icons/records.svg'
                    : null,
                selected: (navIndex == 0 ? false : selectedIndex == navIndex),
                onTap: () => onTap(navIndex),
                iconSize: iconSize,
                circleSize: circleSize,
                isCenter: navIndex == 2,
              ),
            );
          }),
          // Center label with underline (always under center circle)
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: Column(
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: labelFontSize,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: label.length * labelFontSize * 0.62,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
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

class _NavCircleButton2 extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;
  final double circleSize;
  final bool isCenter;
  const _NavCircleButton2({
    this.icon,
    this.svgAsset,
    required this.selected,
    required this.onTap,
    required this.iconSize,
    required this.circleSize,
    this.isCenter = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    if (svgAsset != null) {
      iconWidget = SvgPicture.asset(
        svgAsset!,
        width: iconSize,
        height: iconSize,
        color: selected ? const Color(0xFF484F5C) : Colors.white,
        placeholderBuilder: (context) => Icon(
          icon ?? Icons.help_outline,
          size: iconSize,
          color: selected ? const Color(0xFF484F5C) : Colors.white,
        ),
      );
    } else {
      iconWidget = Icon(
        icon,
        size: iconSize,
        color: selected ? const Color(0xFF484F5C) : Colors.white,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: circleSize,
        height: circleSize,
        margin: EdgeInsets.only(bottom: isCenter ? 54 : 38),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF484F5C),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 14,
              offset: const Offset(2, 7),
            ),
          ],
        ),
        child: Center(child: iconWidget),
      ),
    );
  }
}

class _ArcPainterPerfect extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF484F5C)
      ..style = PaintingStyle.fill;
    final double radius = 44;
    final double spacing = (size.width - 5 * radius * 2) / 4;
    final double barHeight = 60;
    final double y = 0.0;
    final double centerY = y + radius;

    // Draw scalloped (semicircle) top edge
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, centerY);
    for (int i = 0; i < 5; i++) {
      final cx = radius + i * (2 * radius + spacing);
      if (i > 0) {
        path.lineTo(cx - radius, centerY);
      }
      path.arcTo(
        Rect.fromCircle(center: Offset(cx, centerY), radius: radius),
        3.14159, // pi (left)
        -3.14159, // -pi (right)
        false,
      );
    }
    path.lineTo(size.width, centerY);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Draw white borders for circles
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    for (int i = 0; i < 5; i++) {
      final cx = radius + i * (2 * radius + spacing);
      canvas.drawCircle(Offset(cx, centerY), radius + 3.5, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StudentProfileModal extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onClose;
  const StudentProfileModal({
    required this.student,
    required this.onClose,
    Key? key,
  }) : super(key: key);

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'ST';
    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return names[0].substring(0, names[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getAvatarColor(String? name) {
    if (name == null || name.isEmpty) return Colors.grey;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[name.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final focus = [
      'Attention',
      'Logic',
      'Memory',
      'Verbal',
    ].where((k) => student[k.toLowerCase()] == true).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with avatar and title
                  Row(
                    children: [
                      // Profile Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _getAvatarColor(student['fullName']),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(student['fullName']),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Title and subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Student Profile',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2C3E50),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Student Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Information Cards
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Personal Information Card
                          _InfoCard(
                            title: 'Personal Information',
                            icon: Icons.person,
                            color: Colors.blue,
                            children: [
                              _InfoRow(
                                label: 'Full Name',
                                value: student['fullName'] ?? 'Not specified',
                                icon: Icons.badge,
                              ),
                              _InfoRow(
                                label: 'Age',
                                value:
                                    student['age']?.toString() ??
                                    'Not specified',
                                icon: Icons.cake,
                              ),
                              _InfoRow(
                                label: 'Gender',
                                value: student['sex'] ?? 'Not specified',
                                icon: Icons.wc,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Guardian Information Card
                          _InfoCard(
                            title: 'Guardian Information',
                            icon: Icons.family_restroom,
                            color: Colors.green,
                            children: [
                              _InfoRow(
                                label: 'Guardian Name',
                                value:
                                    student['guardianName'] ?? 'Not specified',
                                icon: Icons.person_outline,
                              ),
                              _InfoRow(
                                label: 'Contact Number',
                                value:
                                    student['contactNumber'] ?? 'Not specified',
                                icon: Icons.phone,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Challenge Focus Card
                          if (focus.isNotEmpty)
                            _InfoCard(
                              title: 'Challenge Focus Areas',
                              icon: Icons.psychology,
                              color: Colors.purple,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.purple.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: focus.map((area) {
                                      final colors = {
                                        'Attention': Colors.orange,
                                        'Logic': Colors.indigo,
                                        'Memory': Colors.teal,
                                        'Verbal': Colors.pink,
                                      };
                                      final color = colors[area] ?? Colors.grey;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: color.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getFocusIcon(area),
                                              size: 16,
                                              color: color,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              area,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
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
            ),

            // Enhanced Close button
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.of(context).pop();
                    onClose();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.close, color: Colors.red, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFocusIcon(String area) {
    switch (area) {
      case 'Attention':
        return Icons.visibility;
      case 'Logic':
        return Icons.psychology;
      case 'Memory':
        return Icons.memory;
      case 'Verbal':
        return Icons.record_voice_over;
      default:
        return Icons.star;
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedTeacherProfile extends StatelessWidget {
  final String name;
  final String email;
  final int studentsCount;
  final int sessionsCount;
  final int gamesCount;
  final VoidCallback onLogout;

  const EnhancedTeacherProfile({
    required this.name,
    required this.email,
    required this.studentsCount,
    required this.sessionsCount,
    required this.gamesCount,
    required this.onLogout,
    Key? key,
  }) : super(key: key);

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty || fullName == 'N/A') return 'T';
    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return names[0].substring(0, names[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Row(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Teacher Profile',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C3E50),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Educator Dashboard',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Logout text on the side
                    GestureDetector(
                      onTap: onLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!, width: 1),
                        ),
                        child: Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Information Cards
                Row(
                  children: [
                    // Personal Information Card
                    Expanded(
                      child: _TeacherInfoCard(
                        title: 'Personal Info',
                        icon: Icons.person,
                        color: Colors.blue,
                        children: [
                          _TeacherInfoRow(
                            label: 'Name',
                            value: name,
                            icon: Icons.badge,
                          ),
                          _TeacherInfoRow(
                            label: 'Role',
                            value: 'Teacher',
                            icon: Icons.school,
                          ),
                          _TeacherInfoRow(
                            label: 'Status',
                            value: 'Active',
                            icon: Icons.check_circle,
                            valueColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Account Information Card
                    Expanded(
                      child: _TeacherInfoCard(
                        title: 'Account Info',
                        icon: Icons.account_circle,
                        color: Colors.green,
                        children: [
                          _TeacherInfoRow(
                            label: 'Email',
                            value: email,
                            icon: Icons.email,
                          ),
                          _TeacherInfoRow(
                            label: 'Type',
                            value: 'Professional',
                            icon: Icons.verified_user,
                          ),
                          _TeacherInfoRow(
                            label: 'Password',
                            value: '••••••••',
                            icon: Icons.lock,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Students',
                        value: studentsCount.toString(),
                        icon: Icons.people,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Sessions',
                        value: sessionsCount.toString(),
                        icon: Icons.play_circle,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Games',
                        value: gamesCount.toString(),
                        icon: Icons.emoji_events,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _TeacherInfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _TeacherInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _TeacherInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF2C3E50),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Widget _placeholderChart(String label) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(label, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 8),
      SizedBox(
        width: 90,
        height: 90,
        child: CustomPaint(painter: _PieChartPainter()),
      ),
    ],
  );
}

class _PieChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue[700]!
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0,
      3.14 * 1.5,
      true,
      paint,
    );
    final paint2 = Paint()
      ..color = Colors.blue[200]!
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.14 * 1.5,
      3.14 * 0.5,
      true,
      paint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Donut chart for accuracy
class DonutChart extends StatelessWidget {
  final double percent; // 0.0 to 1.0
  const DonutChart({required this.percent, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // light mode
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // lighter shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(painter: _DonutChartPainter(percent)),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double percent;
  _DonutChartPainter(this.percent);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..color =
          Colors.grey[300]! // light mode
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawArc(rect, 0, 2 * 3.1416, false, bgPaint);
    canvas.drawArc(rect, -3.1416 / 2, 2 * 3.1416 * percent, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Bar chart for completion time
class BarChart extends StatelessWidget {
  final double value;
  final double maxValue;
  const BarChart({required this.value, required this.maxValue, Key? key})
    : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // light mode
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // lighter shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(painter: _BarChartPainter(value, maxValue)),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final double value;
  final double maxValue;
  _BarChartPainter(this.value, this.maxValue);
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color =
          Colors.grey[300]! // light mode
      ..style = PaintingStyle.fill;
    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xFFB721FF), Color(0xFFF472B6)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ),
      bgPaint,
    );
    final barWidth = (value / maxValue).clamp(0.0, 1.0) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, barWidth, size.height),
        const Radius.circular(8),
      ),
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Line chart for accuracy trend
class LineChart extends StatelessWidget {
  final List<double> values;
  final double maxValue;
  final List<String>? xLabels;
  final String? title;
  final IconData? titleIcon;
  const LineChart({
    required this.values,
    required this.maxValue,
    this.xLabels,
    this.title,
    this.titleIcon,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // light mode
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // lighter shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              children: [
                if (titleIcon != null)
                  Icon(titleIcon, color: Color(0xFF1976D2), size: 20),
                if (titleIcon != null) const SizedBox(width: 6),
                Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          if (title != null) const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 2.1,
            child: CustomPaint(
              painter: _LineChartPainter(values, maxValue, xLabels: xLabels),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final List<String>? xLabels;
  _LineChartPainter(this.values, this.maxValue, {this.xLabels});
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;
    int hLines = 6;
    int vLines = values.length - 1;
    for (int i = 0; i <= hLines; i++) {
      double y = size.height * i / hLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 0; i <= vLines; i++) {
      double x = size.width * i / vLines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Draw axis labels
    final labelStyle = TextStyle(color: Colors.grey[700], fontSize: 11);
    // Y axis labels (0 to maxValue)
    for (int i = 0; i <= hLines; i++) {
      double y = size.height * i / hLines;
      double value = maxValue - (maxValue * i / hLines);
      final tp = TextPainter(
        text: TextSpan(text: value.toInt().toString(), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width - 4, y - tp.height / 2));
    }
    // X axis labels (dates)
    if (xLabels != null && xLabels!.length == values.length) {
      for (int i = 0; i < xLabels!.length; i++) {
        double x =
            size.width * i / (values.length - 1 == 0 ? 1 : values.length - 1);
        final tp = TextPainter(
          text: TextSpan(text: xLabels![i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height + 4));
      }
    }
    // Draw line path
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x =
          i * size.width / (values.length - 1 == 0 ? 1 : values.length - 1);
      final y = size.height - (values[i] / maxValue * size.height);
      points.add(Offset(x, y));
    }
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final gradient = LinearGradient(
        colors: [
          Color(0xFF1976D2),
          Color(0xFF00E5FF),
        ], // blue gradient for light mode
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        )
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
      // Draw dots
      final dotPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      for (final pt in points) {
        canvas.drawCircle(pt, 6, dotPaint);
        final borderPaint = Paint()
          ..color = Colors.grey[700]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(pt, 6, borderPaint);
      }
    } else if (points.length == 1) {
      final paint = Paint()
        ..color = Color(0xFF1976D2)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(points.first, 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _NavFlatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavFlatButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: selected ? Colors.blueAccent : Colors.white,
        foregroundColor: selected ? Colors.white : const Color(0xFF393C48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        elevation: selected ? 2 : 0,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 28),
      label: Text(label),
    );
  }
}

class _NavCircleIconButton extends StatefulWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavCircleIconButton({
    required this.icon,
    required this.onTap,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  @override
  State<_NavCircleIconButton> createState() => _NavCircleIconButtonState();
}

class _NavCircleIconButtonState extends State<_NavCircleIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavCircleIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: widget.selected
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50),
                          const Color(0xFF2E7D32),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.selected ? null : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  if (widget.selected)
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 12 + (_glowAnimation.value * 6),
                      offset: const Offset(0, 4),
                    ),
                  // Additional glow effect when selected
                  if (widget.selected)
                    BoxShadow(
                      color: const Color(
                        0xFF4CAF50,
                      ).withOpacity(0.15 * _glowAnimation.value),
                      blurRadius: 24,
                      offset: const Offset(0, 0),
                    ),
                  // Subtle shadow for unselected state
                  if (!widget.selected)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
                border: Border.all(
                  color: widget.selected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE8F5E8),
                  width: widget.selected ? 3 : 2,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.selected),
                    size: 28,
                    color: widget.selected
                        ? Colors.white
                        : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Add this widget to the file:
class StudentBarChart extends StatelessWidget {
  final Map<String, double> values;
  final String title;
  final String valueSuffix;
  final double maxValue;
  final Color barColor;
  const StudentBarChart({
    required this.values,
    required this.title,
    required this.valueSuffix,
    required this.maxValue,
    required this.barColor,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 16),
          ...sorted.map((entry) {
            final percent = (entry.value / maxValue).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent,
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${entry.value.toStringAsFixed(1)}$valueSuffix',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// Add these widgets to the file:
class ModernLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> xLabels;
  final String title;
  final Color lineColor;
  const ModernLineChart({
    required this.values,
    required this.xLabels,
    required this.title,
    required this.lineColor,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _ModernLineChartPainter(values, xLabels, lineColor),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernLineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> xLabels;
  final Color lineColor;
  _ModernLineChartPainter(this.values, this.xLabels, this.lineColor);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final double minY = 0;
    final double maxY = 100;
    final double leftPad = 32;
    final double bottomPad = 32;
    final double topPad = 16;
    final double rightPad = 16;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      double y = topPad + chartHeight * i / 5;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }
    // Draw line
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x =
          leftPad +
          chartWidth * i / (values.length - 1 == 0 ? 1 : values.length - 1);
      final y = topPad + chartHeight * (1 - (values[i] - minY) / (maxY - minY));
      points.add(Offset(x, y));
    }
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [lineColor, Colors.cyanAccent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromPoints(points.first, points.last))
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
      // Draw dots
      final dotPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      for (final pt in points) {
        canvas.drawCircle(pt, 6, dotPaint);
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(pt, 6, borderPaint);
      }
    }
    // Draw x labels
    final labelStyle = TextStyle(color: Colors.grey[700], fontSize: 12);
    for (int i = 0; i < xLabels.length; i++) {
      final x =
          leftPad +
          chartWidth * i / (xLabels.length - 1 == 0 ? 1 : xLabels.length - 1);
      final tp = TextPainter(
        text: TextSpan(text: xLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 6));
    }
    // Draw y labels
    for (int i = 0; i <= 5; i++) {
      final yValue = maxY - (maxY - minY) * i / 5;
      final y = topPad + chartHeight * i / 5;
      final tp = TextPainter(
        text: TextSpan(text: yValue.toInt().toString(), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ModernVerticalBarChart extends StatelessWidget {
  final Map<String, double> values;
  final String title;
  final String valueSuffix;
  final double maxValue;
  final List<String> xLabels;
  final Color barColorStart;
  final Color barColorEnd;
  const ModernVerticalBarChart({
    required this.values,
    required this.title,
    required this.valueSuffix,
    required this.maxValue,
    required this.xLabels,
    required this.barColorStart,
    required this.barColorEnd,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final sorted = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < sorted.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              height:
                                  180 *
                                  (sorted[i].value / maxValue).clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [barColorStart, barColorEnd],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              width: 28,
                            ),
                            Positioned(
                              bottom:
                                  180 *
                                      (sorted[i].value / maxValue).clamp(
                                        0.0,
                                        1.0,
                                      ) +
                                  4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${sorted[i].value.toStringAsFixed(1)}$valueSuffix',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sorted[i].key,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
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

class ModernTrendChart extends StatelessWidget {
  final List<double> values;
  final List<String> xLabels;

  const ModernTrendChart({
    required this.values,
    required this.xLabels,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 250,
      child: CustomPaint(
        painter: ModernTrendChartPainter(values, xLabels),
        size: Size.infinite,
      ),
    );
  }
}

class ModernTrendChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> xLabels;

  ModernTrendChartPainter(this.values, this.xLabels);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF667eea).withOpacity(0.3),
          Color(0xFF667eea).withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    final padding = 40.0;

    final path = Path();
    final gradientPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x =
          padding + (i * (size.width - 2 * padding) / (values.length - 1));
      final normalizedValue = range > 0 ? (values[i] - minValue) / range : 0.5;
      final y =
          size.height -
          padding -
          (normalizedValue * (size.height - 2 * padding));

      if (i == 0) {
        path.moveTo(x, y);
        gradientPath.moveTo(x, size.height - padding);
        gradientPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        gradientPath.lineTo(x, y);
      }

      // Draw points
      final pointPaint = Paint()
        ..color = Color(0xFF667eea)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 6, pointPaint);

      // Draw white center
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3, whitePaint);
    }

    // Complete gradient path
    gradientPath.lineTo(size.width - padding, size.height - padding);
    gradientPath.close();

    // Draw gradient area
    canvas.drawPath(gradientPath, gradientPaint);

    // Draw line
    paint.shader = LinearGradient(
      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    // Draw labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < xLabels.length && i < values.length; i++) {
      final x =
          padding + (i * (size.width - 2 * padding) / (values.length - 1));

      textPainter.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ModernStudentChart extends StatelessWidget {
  final Map<String, double> data;
  final double maxValue;
  final String suffix;
  final Color color;

  const ModernStudentChart({
    required this.data,
    required this.maxValue,
    required this.suffix,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 300,
      child: SingleChildScrollView(
        child: Column(
          children: sortedEntries.map((entry) {
            final percentage = (entry.value / maxValue).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3142),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${entry.value.toStringAsFixed(1)}$suffix',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ModernGameChart extends StatelessWidget {
  final Map<String, Map<String, double>> gameData;

  const ModernGameChart({required this.gameData, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (gameData.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Text(
            'No game data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final sortedGames = gameData.entries.toList()
      ..sort(
        (a, b) => b.value['avgAccuracy']!.compareTo(a.value['avgAccuracy']!),
      );

    return Column(
      children: [
        // Top performers
        Row(
          children: [
            Expanded(
              child: _buildGameMetricCard(
                'Best Accuracy',
                sortedGames.first.key,
                '${sortedGames.first.value['avgAccuracy']!.toStringAsFixed(1)}%',
                [Color(0xFF11998e), Color(0xFF38ef7d)],
                Icons.star_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGameMetricCard(
                'Fastest Time',
                sortedGames
                    .reduce(
                      (a, b) =>
                          a.value['avgTime']! < b.value['avgTime']! ? a : b,
                    )
                    .key,
                '${sortedGames.reduce((a, b) => a.value['avgTime']! < b.value['avgTime']! ? a : b).value['avgTime']!.toStringAsFixed(1)}s',
                [Color(0xFF667eea), Color(0xFF764ba2)],
                Icons.speed_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Detailed game breakdown
        Container(
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: sortedGames.map((gameEntry) {
                final gameName = gameEntry.key;
                final accuracy = gameEntry.value['avgAccuracy']!;
                final time = gameEntry.value['avgTime']!;
                final accuracyPercent = (accuracy / 100).clamp(0.0, 1.0);
                final timePercent = (time / 60).clamp(0.0, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8F9FA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.games_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              gameName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Accuracy metric
                      Row(
                        children: [
                          Icon(
                            Icons.track_changes,
                            color: Color(0xFF11998e),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Accuracy:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${accuracy.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF11998e),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: accuracyPercent,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Time metric
                      Row(
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            color: Color(0xFF667eea),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Avg Time:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${time.toStringAsFixed(1)}s',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: timePercent,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameMetricCard(
    String title,
    String gameName,
    String value,
    List<Color> gradientColors,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            gameName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class GamePerformanceChart extends StatelessWidget {
  final Map<String, Map<String, double>> gameData;

  const GamePerformanceChart({required this.gameData, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (gameData.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Text(
            'No game data available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final sortedGames = gameData.entries.toList()
      ..sort(
        (a, b) => b.value['avgAccuracy']!.compareTo(a.value['avgAccuracy']!),
      );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGameMetricCard(
                'Best Performing Game',
                sortedGames.first.key,
                '${sortedGames.first.value['avgAccuracy']!.toStringAsFixed(1)}%',
                Colors.green,
                Icons.star,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGameMetricCard(
                'Fastest Average Game',
                sortedGames
                    .reduce(
                      (a, b) =>
                          a.value['avgTime']! < b.value['avgTime']! ? a : b,
                    )
                    .key,
                '${sortedGames.reduce((a, b) => a.value['avgTime']! < b.value['avgTime']! ? a : b).value['avgTime']!.toStringAsFixed(1)}s',
                Colors.blue,
                Icons.speed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              children: sortedGames.map((gameEntry) {
                final gameName = gameEntry.key;
                final accuracy = gameEntry.value['avgAccuracy']!;
                final time = gameEntry.value['avgTime']!;
                final accuracyPercent = (accuracy / 100).clamp(0.0, 1.0);
                final timePercent = (time / 60).clamp(
                  0.0,
                  1.0,
                ); // Assuming 60s max time

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Accuracy bar
                      Row(
                        children: [
                          const SizedBox(
                            width: 70,
                            child: Text(
                              'Accuracy:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: accuracyPercent,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green[400],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${accuracy.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Time bar
                      Row(
                        children: [
                          const SizedBox(
                            width: 70,
                            child: Text(
                              'Avg Time:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: timePercent,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[400],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${time.toStringAsFixed(1)}s',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameMetricCard(
    String title,
    String gameName,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            gameName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Minimal Chart Widgets
class MinimalTrendChart extends StatelessWidget {
  final List<double> values;
  final List<String> xLabels;

  const MinimalTrendChart({
    Key? key,
    required this.values,
    required this.xLabels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      child: CustomPaint(
        size: Size.infinite,
        painter: MinimalTrendPainter(values: values, xLabels: xLabels),
      ),
    );
  }
}

class MinimalTrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> xLabels;

  MinimalTrendPainter({required this.values, required this.xLabels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = Color(0xFF3B82F6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y =
          size.height -
          40 -
          ((values[i] - minValue) / range) * (size.height - 60);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw points
      canvas.drawCircle(Offset(x, y), 4, pointPaint);

      // Draw labels
      if (i < xLabels.length) {
        textPainter.text = TextSpan(
          text: xLabels[i],
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, size.height - 20),
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MinimalBarChart extends StatelessWidget {
  final Map<String, double> data;
  final double maxValue;
  final String suffix;
  final Color color;

  const MinimalBarChart({
    Key? key,
    required this.data,
    required this.maxValue,
    required this.suffix,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      child: CustomPaint(
        size: Size.infinite,
        painter: MinimalBarPainter(
          data: data,
          maxValue: maxValue,
          suffix: suffix,
          color: color,
        ),
      ),
    );
  }
}

class MinimalBarPainter extends CustomPainter {
  final Map<String, double> data;
  final double maxValue;
  final String suffix;
  final Color color;

  MinimalBarPainter({
    required this.data,
    required this.maxValue,
    required this.suffix,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final entries = data.entries.toList();
    final barWidth = (size.width - 40) / entries.length;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final barHeight = (entry.value / maxValue) * (size.height - 60);
      final x = 20 + i * barWidth + barWidth * 0.1;
      final y = size.height - 40 - barHeight;

      // Draw bar
      final rect = Rect.fromLTWH(x, y, barWidth * 0.8, barHeight);
      final paint = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4)),
        paint,
      );

      // Draw value text
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${entry.value.toStringAsFixed(1)}$suffix',
          style: TextStyle(
            color: Color(0xFF374151),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      valuePainter.layout();
      valuePainter.paint(
        canvas,
        Offset(x + barWidth * 0.4 - valuePainter.width / 2, y - 15),
      );

      // Draw label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: entry.key.length > 8
              ? '${entry.key.substring(0, 8)}...'
              : entry.key,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(x + barWidth * 0.4 - labelPainter.width / 2, size.height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MinimalGameChart extends StatelessWidget {
  final Map<String, double> gameData;

  const MinimalGameChart({Key? key, required this.gameData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic height based on number of games
    final itemHeight = 40.0; // Increased for better spacing
    final topPadding = 15.0;
    final bottomPadding = 15.0;
    final calculatedHeight =
        (gameData.length * itemHeight) + topPadding + bottomPadding;
    final maxHeight = 500.0; // Increased max height
    final finalHeight = calculatedHeight > maxHeight
        ? maxHeight
        : calculatedHeight;

    return Container(
      height: finalHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: CustomPaint(
        size: Size.infinite,
        painter: MinimalGamePainter(gameData: gameData),
      ),
    );
  }
}

class MinimalGamePainter extends CustomPainter {
  final Map<String, double> gameData;

  MinimalGamePainter({required this.gameData});

  @override
  void paint(Canvas canvas, Size size) {
    if (gameData.isEmpty) return;

    final entries = gameData.entries.toList();
    final itemHeight = 40.0; // Match the container's itemHeight
    final topPadding = 15.0;
    final nameWidth = 95.0; // Slightly wider for game names
    final percentWidth = 55.0; // Slightly wider for percentages
    final barStartX = nameWidth + 12;
    final barWidth = size.width - barStartX - percentWidth - 25;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final fillWidth = (entry.value / 100) * barWidth;
      final y = topPadding + i * itemHeight;

      // Draw bar background
      final bgRect = Rect.fromLTWH(
        barStartX,
        y + 11, // Centered vertically in the 40px item
        barWidth,
        18,
      );
      final bgPaint = Paint()..color = Color(0xFFF3F4F6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, Radius.circular(9)),
        bgPaint,
      );

      // Draw bar fill
      if (fillWidth > 0) {
        final rect = Rect.fromLTWH(barStartX, y + 11, fillWidth, 18);
        final paint = Paint()..color = Color(0xFF3B82F6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(9)),
          paint,
        );
      }

      // Draw game name (shortened)
      String gameName = entry.key;
      if (gameName.length > 11) {
        gameName = '${gameName.substring(0, 11)}...';
      }

      final namePainter = TextPainter(
        text: TextSpan(
          text: gameName,
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 12, // Slightly larger font
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      namePainter.layout(maxWidth: nameWidth);
      namePainter.paint(
        canvas,
        Offset(8, y + 15), // Centered vertically
      );

      // Draw percentage
      final percentPainter = TextPainter(
        text: TextSpan(
          text: '${entry.value.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Color(0xFF374151),
            fontSize: 11, // Slightly larger font
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      );
      percentPainter.layout();
      percentPainter.paint(
        canvas,
        Offset(
          size.width - percentWidth + 5,
          y + 15, // Centered vertically
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Compact Chart Components for Modal
class CompactDonutChart extends StatelessWidget {
  final double percent;

  const CompactDonutChart({Key? key, required this.percent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: CompactDonutPainter(percent: percent),
    );
  }
}

class CompactDonutPainter extends CustomPainter {
  final double percent;

  CompactDonutPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    // Background circle
    final bgPaint = Paint()
      ..color = Color(0xFFE5E7EB)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = Color(0xFF3B82F6)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CompactProgressBar extends StatelessWidget {
  final double value;
  final double maxValue;

  const CompactProgressBar({
    Key? key,
    required this.value,
    required this.maxValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: CompactProgressPainter(value: value, maxValue: maxValue),
    );
  }
}

class CompactProgressPainter extends CustomPainter {
  final double value;
  final double maxValue;

  CompactProgressPainter({required this.value, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Background bar
    final bgPaint = Paint()
      ..color = Color(0xFFE5E7EB)
      ..style = PaintingStyle.fill;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Progress bar
    final progressPaint = Paint()
      ..color = Color(0xFF10B981)
      ..style = PaintingStyle.fill;

    final progressWidth = (value / maxValue) * size.width;
    final progressRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, progressWidth, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(progressRect, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CompactLineChart extends StatelessWidget {
  final List<double> values;
  final double maxValue;

  const CompactLineChart({
    Key? key,
    required this.values,
    required this.maxValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: CompactLinePainter(values: values, maxValue: maxValue),
    );
  }
}

class CompactLinePainter extends CustomPainter {
  final List<double> values;
  final double maxValue;

  CompactLinePainter({required this.values, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.length < 2) return;

    final paint = Paint()
      ..color = Color(0xFF3B82F6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final path = Path();
    final padding = 10.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 4; i++) {
      final y = padding + (i / 4) * chartHeight;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw line
    for (int i = 0; i < values.length; i++) {
      final x = padding + (i / (values.length - 1)) * chartWidth;
      final y = padding + (1 - (values[i] / maxValue)) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw points (smaller)
      canvas.drawCircle(Offset(x, y), 2, pointPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
