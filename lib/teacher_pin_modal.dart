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
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _obscurePassword = true;
  bool _isCreate = false;
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

  Future<void> _createPin() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final pin = _pinController.text.trim();
    final password = _passwordController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not logged in.';
        _checking = false;
      });
      return;
    }
    try {
      // Optionally, check password here if needed
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .update({'pin': pin});
      widget.onSubmit(pin, true, password);
    } catch (e) {
      setState(() {
        _error = 'Failed to save PIN.';
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
    if (_isCreate) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) {
        setState(() => _error = 'Password is required');
        return;
      }
      _createPin();
    } else {
      _submitPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth = 420;
    return Center(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: modalWidth,
          padding: const EdgeInsets.fromLTRB(36, 24, 36, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCreate ? 'Create Pin' : 'Enter Pin',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF393C48),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Teacher only',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 32),
                    splashRadius: 22,
                    padding: const EdgeInsets.only(top: 2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _pinController,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '******',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isCreate)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (!_isCreate)
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isCreate = true;
                      _error = null;
                    }),
                    child: const Text(
                      'Create PIN',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF393C48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      _isCreate ? 'CREATE' : 'ENTER',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1,
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
}
 