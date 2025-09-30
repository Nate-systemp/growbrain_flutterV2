import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherPinModal extends StatefulWidget {
  final void Function(String pin, bool isCreate, [String? password]) onSubmit;
  final VoidCallback? onLogout;
  final bool showLogout;
  const TeacherPinModal({Key? key, required this.onSubmit, this.onLogout, this.showLogout = false}) : super(key: key);

  @override
  State<TeacherPinModal> createState() => _TeacherPinModalState();
}

class _TeacherPinModalState extends State<TeacherPinModal> {
  // using only _pin to represent entered digits
  String? _error;
  bool _checking = false;
  String _pin = '';

  // Visual feedback flags
  bool _wrongPin = false;
  bool _correctPin = false; // NEW: show success green briefly

  Future<void> _submitPin() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final pin = _pin.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not logged in.';
        _checking = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('teachers').doc(user.uid).get();

      // Handle missing document gracefully
      if (!doc.exists) {
        setState(() {
          _error = 'No PIN set. Please create one.';
          _checking = false;
        });
        return;
      }

      final data = doc.data();
      final savedPin = data?['pin'];
      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please create one.';
          _checking = false;
        });
        return;
      }
      if (pin != savedPin) {
        // Incorrect PIN: show red boxes instead of error banner
        setState(() {
          _wrongPin = true;
          _correctPin = false;
          _checking = false;
        });
        // Briefly show red, then reset input
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            _wrongPin = false;
            _pin = '';
          });
        });
        return;
      }

      // Success: briefly show green, then proceed
      setState(() {
        _correctPin = true;
        // keep _checking true to block inputs during success flash
        _checking = true;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        widget.onSubmit(pin, false);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to check PIN.';
        _checking = false;
      });
    }
  }

  void _submit() {
    final pin = _pin.trim();
    // Enforce exactly 6 digits (anchor the regex)
    if (pin.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }
    _submitPin();
  }

  // Numpad helpers
  void _addDigit(String d) {
    if (_pin.length >= 6 || _checking) return;
    setState(() {
      _wrongPin = false; // clear visual error when typing again
      _correctPin = false; // clear success state if editing starts
      _pin += d;
      _error = null;
    });
    if (_pin.length == 6) {
      _submit();
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() {
      _wrongPin = false; // clear visual error when editing
      _correctPin = false; // clear success state if editing starts
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  // Responsive PIN boxes: auto-fit width via LayoutBuilder
  Widget _buildPinBoxes() {
    const total = 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        // target sizes
        const maxBox = 86.0;
        const minBox = 36.0;

        // We aim for fixed gaps; if needed, reduce box to fit
        // Start with desired gap; if too tight, compute new gap from remainder to distribute space evenly
        double gap = 12.0;

        // First try with maxBox size; if doesn't fit, scale box down
        double box = maxBox;
        final neededWidthMax = total * box + (total - 1) * gap;
        if (neededWidthMax > constraints.maxWidth) {
          // compute box that will fit given gap, but not below minBox
          final rawBox = (constraints.maxWidth - (total - 1) * gap) / total;
          box = rawBox.clamp(minBox, maxBox);
          // if even with minBox it doesn't fit, reduce gap to fit exactly
          final neededWidthMin = total * box + (total - 1) * gap;
          if (neededWidthMin > constraints.maxWidth) {
            final availableForGaps = (constraints.maxWidth - total * box);
            gap = availableForGaps > 0 ? availableForGaps / (total - 1) : 4.0;
          }
        }

        // Colors based on state
        const green = Color(0xFF4CAF50);
        const greenDark = Color(0xFF2E7D32);
        const greenBg = Color(0xFFE8F5E9); // success background
        const grey = Color(0xFFE0E0E0);
        const red = Color(0xFFD32F2F);
        const redBg = Color(0xFFFFEBEE);

        final isSuccess = _correctPin;
        final isError = _wrongPin;

        return SizedBox(
          width: constraints.maxWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final filled = i < _pin.length;

              final Color borderColor = isSuccess
                  ? greenDark
                  : (isError ? red : (filled ? green : grey));
              final Color textColor = isSuccess
                  ? greenDark
                  : (isError ? red : greenDark);
              final Color bgColor = isSuccess
                  ? greenBg
                  : (isError ? redBg : Colors.white);

              final display = filled ? '•' : '_';
              final item = Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isError ? red : Colors.black).withOpacity(isError ? 0.06 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  display,
                  style: TextStyle(
                    fontSize: filled ? (box * 0.5) : (box * 0.40),
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 2,
                  ),
                ),
              );
              if (i == total - 1) return item;
              return Padding(
                padding: EdgeInsets.only(right: gap),
                child: item,
              );
            }),
          ),
        );
      },
    );
  }

  Widget _numButton({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    double size = 64.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: const Color(0xFFFFD740),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Icon(icon, color: const Color(0xFF5B6F4A), size: size * 0.40)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5B6F4A),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad({double buttonSize = 64.0}) {
    const hGap = 12.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _numButton(label: '1', onTap: () => _addDigit('1'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(label: '2', onTap: () => _addDigit('2'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(label: '3', onTap: () => _addDigit('3'), size: buttonSize),
        ]),
        const SizedBox(height: hGap),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _numButton(label: '4', onTap: () => _addDigit('4'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(label: '5', onTap: () => _addDigit('5'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(label: '6', onTap: () => _addDigit('6'), size: buttonSize),
        ]),
        const SizedBox(height: hGap),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _numButton(label: '7', onTap: () => _addDigit('7'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(label: '8', onTap: () => _addDigit('8'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(label: '9', onTap: () => _addDigit('9'), size: buttonSize),
        ]),
        const SizedBox(height: hGap),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _numButton(label: '0', onTap: () => _addDigit('0'), size: buttonSize),
          const SizedBox(width: hGap),
          _numButton(icon: Icons.backspace_rounded, onTap: _backspace, size: buttonSize),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double modalWidth = math.min(860.0, size.width * 0.90);
    final double modalHeight = math.min(520.0, size.height * 0.85);
    final bool isNarrow = modalWidth < 600.0; // threshold for stacking layout
    final double numpadButtonSize = isNarrow ? 56.0 : 64.0;

    return Center(
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section
                  Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title and Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter PIN',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Teacher Access Only',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close Button
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFCDD2),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFD32F2F),
                            size: 24,
                          ),
                          splashRadius: 20,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // PIN Input Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8F5E8),
                        width: 2,
                      ),
                    ),
                    child: isNarrow
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // PIN boxes on top
                              Align(
                                alignment: Alignment.center,
                                child: _buildPinBoxes(),
                              ),
                              const SizedBox(height: 20),
                              // Numpad below
                              _buildNumpad(buttonSize: numpadButtonSize),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                _errorBanner(_error!),
                              ],
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Center(child: _buildPinBoxes()),
                                  ),
                                  const SizedBox(width: 24),
                                  _buildNumpad(buttonSize: numpadButtonSize),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                _errorBanner(_error!),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Action Button removed: auto-submit when PIN reaches 6 digits
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFCDD2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD32F2F),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}