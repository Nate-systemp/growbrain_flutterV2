import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherPinModal extends StatefulWidget {
  final void Function(String pin, bool isCreate, [String? password]) onSubmit;
  const TeacherPinModal({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<TeacherPinModal> createState() => _TeacherPinModalState();
}

class _TeacherPinModalState extends State<TeacherPinModal> {
  final TextEditingController _pinController = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _checking = false;

  Future<void> _submitPin() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final pin = _pinController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not logged in.';
        _checking = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();
      final savedPin = doc.data()?['pin'];
      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please create one.';
          _checking = false;
        });
        return;
      }
      if (pin != savedPin) {
        setState(() {
          _error = 'Incorrect PIN.';
          _checking = false;
        });
        return;
      }
      widget.onSubmit(pin, false);
    } catch (e) {
      setState(() {
        _error = 'Failed to check PIN.';
        _checking = false;
      });
    }
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^[0-9]{6}').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }
    _submitPin();
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth = 420;
    return Center(
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: modalWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
                  child: Column(
                    children: [
                      // PIN Input Field
                      Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _error != null
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF4CAF50),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _pinController,
                          obscureText: _obscure,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            letterSpacing: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              letterSpacing: 12,
                              fontSize: 28,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 20,
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF666666),
                                  size: 22,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Error Message
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
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
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _checking
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _checking ? 0 : 4,
                      shadowColor: const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                    onPressed: _checking ? null : _submit,
                    child: _checking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login_rounded, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'ENTER',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1,
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
      ),
    );
  }
}
