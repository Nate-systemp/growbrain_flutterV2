import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'set_session_screen.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({Key? key}) : super(key: key);

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  int _selectedIndex =
      2; // 0: Back, 1: Profile, 2: Student List, 3: Add, 4: Analysis
  List<Map<String, dynamic>> students = [];
  bool _loadingStudents = false;
  Map<String, dynamic>? _viewingStudent;
  Map<String, dynamic>? _teacherProfile;
  bool _loadingProfile = false;
  String? _profileError;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _fetchTeacherProfile();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  Future<void> _fetchStudents() async {
    setState(() => _loadingStudents = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(user.uid)
        .collection('students')
        .get();
    students = snap.docs.map((d) => d.data()).toList();
    setState(() => _loadingStudents = false);
  }

  Future<void> _addStudent(Map<String, dynamic> student) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('teachers')
        .doc(user.uid)
        .collection('students')
        .add(student);
    await _fetchStudents();
    setState(() => _selectedIndex = 2);
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
  }

  String get _sectionLabel {
    switch (_selectedIndex) {
      case 2:
        return 'STUDENT LIST';
      case 1:
        return 'TEACHER PROFILE';
      case 3:
        return 'ADD STUDENT';
      case 4:
        return 'ANALYSIS';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_selectedIndex == 3) {
      // Add Student Form
      content = AddStudentForm(onSave: _addStudent);
    } else if (_selectedIndex == 1) {
      // Enhanced Teacher Profile
      if (_loadingProfile) {
        content = const Center(child: CircularProgressIndicator());
      } else if (_profileError != null) {
        content = Center(
          child: Text(
            _profileError!,
            style: const TextStyle(color: Colors.red, fontSize: 22),
          ),
        );
      } else {
        final profile = _teacherProfile;
        final name = profile?['name'] ?? 'N/A';
        final email = profile?['email'] ?? 'N/A';
        content = EnhancedTeacherProfile(
          name: name,
          email: email,
          onLogout: () async {
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
        );
      }
    } else if (_selectedIndex == 2) {
      // Student List
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
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search student name...',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(width: 1.2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 12,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loadingStudents
                  ? const Center(child: CircularProgressIndicator())
                  : validStudents.isEmpty
                  ? const Center(
                      child: Text(
                        'No students found.',
                        style: TextStyle(
                          fontSize: 28,
                          color: Color(0xFF393C48),
                        ),
                      ),
                    )
                  : Center(
                      child: SizedBox(
                        width: 600,
                        child: ListView.builder(
                          itemCount: validStudents.length,
                          itemBuilder: (context, index) {
                            final student = validStudents[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: Color(0xFF484F5C),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      student['fullName'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF393C48),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF393C48),
                                      elevation: 1,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() => _viewingStudent = student);
                                    },
                                    child: const Text('View'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF393C48),
                                      elevation: 1,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SetSessionScreen(
                                            student: student,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Set Session'),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.pie_chart,
                                      size: 28,
                                      color: Color(0xFF393C48),
                                    ),
                                    tooltip: 'View Records',
                                    onPressed: () {
                                      _showRecordsModal(student);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 28,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteStudent(student),
                                  ),
                                ],
                              ),
                            );
                          },
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
            final avgAccuracy = allRecords.isNotEmpty
                ? allRecords
                          .map(
                            (r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0,
                          )
                          .reduce((a, b) => a + b) /
                      allRecords.length
                : 0.0;
            final avgCompletion = allRecords.isNotEmpty
                ? allRecords
                          .map(
                            (r) =>
                                (r['completionTime'] as num?)?.toDouble() ??
                                0.0,
                          )
                          .reduce((a, b) => a + b) /
                      allRecords.length
                : 0.0;
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

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title at the very top
                  const Text(
                    'Analytics Dashboard',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  // Main charts below
                  ModernLineChart(
                    title: 'Average Accuracy Trend',
                    values: trendValues,
                    xLabels: [
                      for (final r in accuracyTrend)
                        (r['date'] is Timestamp)
                            ? (r['date'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .substring(5, 10)
                            : (r['date'] is String)
                            ? (DateTime.tryParse(
                                    r['date'],
                                  )?.toString().substring(5, 10) ??
                                  '')
                            : '',
                    ],
                    lineColor: Colors.orange,
                  ),
                  ModernVerticalBarChart(
                    title: 'Avg Completion Time per Student',
                    values: {
                      for (final entry in recordsByStudent.entries)
                        entry.key: entry.value.isNotEmpty
                            ? entry.value
                                      .map(
                                        (r) =>
                                            (r['completionTime'] as num?)
                                                ?.toDouble() ??
                                            0.0,
                                      )
                                      .reduce((a, b) => a + b) /
                                  entry.value.length
                            : 0.0,
                    },
                    valueSuffix: 's',
                    maxValue: 60.0,
                    xLabels: [
                      for (final entry in recordsByStudent.entries) entry.key,
                    ],
                    barColorStart: Colors.purple,
                    barColorEnd: Colors.pinkAccent,
                  ),
                  StudentBarChart(
                    title: 'Average Accuracy per Student',
                    values: {
                      for (final entry in recordsByStudent.entries)
                        entry.key: entry.value.isNotEmpty
                            ? entry.value
                                      .map(
                                        (r) =>
                                            (r['accuracy'] as num?)
                                                ?.toDouble() ??
                                            0.0,
                                      )
                                      .reduce((a, b) => a + b) /
                                  entry.value.length
                            : 0.0,
                    },
                    valueSuffix: '%',
                    maxValue: 100.0,
                    barColor: Colors.orange,
                  ),

                  const SizedBox(height: 32),
                  // Per-student summary
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Highlights',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (mostImprovedName != null)
                          Card(
                            color: Colors.green[50],
                            child: ListTile(
                              leading: const Icon(
                                Icons.trending_up,
                                color: Colors.green,
                              ),
                              title: Text('Most Improved'),
                              subtitle: Text(
                                '$mostImprovedName (+${mostImprovedValue.toStringAsFixed(1)}%)',
                              ),
                            ),
                          ),
                        if (bestStreakName != null)
                          Card(
                            color: Colors.orange[50],
                            child: ListTile(
                              leading: const Icon(
                                Icons.emoji_events,
                                color: Colors.orange,
                              ),
                              title: Text('Best Streak'),
                              subtitle: Text(
                                '$bestStreakName ($bestStreakValue consecutive improvements)',
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        const Text(
                          'Per Student Summary',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Accuracy: ${avgAcc.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 18),
                                Text(
                                  'Time: ${avgComp.toStringAsFixed(1)}s',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
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
              child: const Text('Back to games'),
            ),
          ),
          content,
          // Enhanced Bottom navigation bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavCircleIconButton(
                    icon: Icons.person,
                    selected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  const SizedBox(width: 36),
                  _NavCircleIconButton(
                    icon: Icons.list,
                    selected: _selectedIndex == 2,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                  const SizedBox(width: 36),
                  _NavCircleIconButton(
                    icon: Icons.add,
                    selected: _selectedIndex == 3,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                  const SizedBox(width: 36),
                  _NavCircleIconButton(
                    icon: Icons.bar_chart,
                    selected: _selectedIndex == 4,
                    onTap: () => setState(() => _selectedIndex = 4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final studentId = student['id'] ?? student['fullName'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student['fullName'] ?? 'this student'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .delete();
      setState(() {
        students.removeWhere((s) => (s['id'] ?? s['fullName']) == studentId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Student deleted.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete student.')),
      );
    }
  }

  void _showRecordsModal(Map<String, dynamic> student) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final studentId = student['id'] ?? student['fullName'];
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
              color: Colors.grey[200],
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
    DateTime? selectedDate;
    void showModalWithDate(DateTime? filterDate) {
      final filteredRecords = filterDate == null
          ? records
          : records.where((r) {
              final d = DateTime.tryParse(r['date'] ?? '')?.toLocal();
              return d != null &&
                  d.year == filterDate.year &&
                  d.month == filterDate.month &&
                  d.day == filterDate.day;
            }).toList();
      String getDateLabel() {
        if (filterDate == null) return 'All';
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
        return '${months[filterDate.month]} ${filterDate.day}, ${filterDate.year}';
      }

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 32,
          ),
          child: Container(
            width: 520,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "${student['fullName'] ?? 'Student'}'s Records",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF222B45),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(32),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                showChartModal(filteredRecords, records);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(
                                        0.18,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'View Chart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Pick Date:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: filterDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                );
                                Navigator.of(ctx).pop();
                                showModalWithDate(picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(
                                        0.12,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      getDateLabel(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (filterDate != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    showModalWithDate(null);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: filteredRecords.isEmpty
                            ? const Center(
                                child: Text(
                                  'No records for this date.',
                                  style: TextStyle(fontSize: 18),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredRecords.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 18),
                                itemBuilder: (context, i) {
                                  final record = filteredRecords[i];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 18,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Text(
                                                'Date',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Challenge Focus',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Difficulty',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Accuracy',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Completion Time',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Last Played',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                record['date'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                record['challengeFocus'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                record['difficulty'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                record['accuracy'] != null &&
                                                        record['accuracy']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? '${record['accuracy']}%'
                                                    : '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _formatCompletionTime(
                                                  record['completionTime'],
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                record['lastPlayed'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                // Floating close button
                Positioned(
                  bottom: 18,
                  right: 18,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
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

    showModalWithDate(selectedDate);
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
          width: 700,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blueAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Charts',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Average Accuracy Chart
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Average Accuracy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: SizedBox(
                                width: 160,
                                height: 160,
                                child: DonutChart(
                                  percent: filteredRecords.isNotEmpty
                                      ? (filteredRecords
                                                    .map(
                                                      (r) =>
                                                          (r['accuracy']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                    )
                                                    .reduce((a, b) => a + b) /
                                                filteredRecords.length) /
                                            100.0
                                      : 0.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                filteredRecords.isNotEmpty
                                    ? '${(filteredRecords.map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / filteredRecords.length).toStringAsFixed(1)}%'
                                    : '--%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Average Completion Time Chart
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Avg Completion Time',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: SizedBox(
                                width: 220,
                                height: 48,
                                child: BarChart(
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
                                  maxValue:
                                      60.0, // Assume 60s as max for scaling
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                filteredRecords.isNotEmpty
                                    ? '${(filteredRecords.map((r) => (r['completionTime'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / filteredRecords.length).toStringAsFixed(1)} s'
                                    : '-- s',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Accuracy Trend Chart
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Accuracy Trend',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AspectRatio(
                              aspectRatio: 2.1, // matches LineChart's default
                              child: LineChart(
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 32),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
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
                                value: student['age'] ?? 'Not specified',
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
        color: Colors.white,
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
  final VoidCallback onLogout;

  const EnhancedTeacherProfile({
    required this.name,
    required this.email,
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
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Row(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 60,
                      height: 60,
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Teacher Profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C3E50),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

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
                    const SizedBox(width: 12),

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
                const SizedBox(height: 16),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Students',
                        value: '12',
                        icon: Icons.people,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Sessions',
                        value: '8',
                        icon: Icons.play_circle,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Games',
                        value: '156',
                        icon: Icons.emoji_events,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Edit Profile Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        // TODO: Implement edit profile functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Edit profile feature coming soon!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Logout Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
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
        color: Colors.white,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
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
      padding: const EdgeInsets.all(12),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
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
        color: Colors.white, // light mode
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
        color: Colors.white, // light mode
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

class _NavCircleIconButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF484F5C) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFF484F5C).withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
          border: Border.all(
            color: selected ? const Color(0xFF484F5C) : const Color(0xFFB0B0B0),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 30,
            color: selected ? Colors.white : const Color(0xFF393C48),
          ),
        ),
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
        color: Colors.white,
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
        color: Colors.white,
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
        color: Colors.white,
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
