import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/emergency_ui_components.dart';

class UserRegistration extends StatefulWidget {
  const UserRegistration({super.key});

  @override
  State<UserRegistration> createState() => _UserRegistrationState();
}

class _UserRegistrationState extends State<UserRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _parentPhoneController = TextEditingController(text: "+91");
  final _parentEmailController = TextEditingController();

  final DatabaseService _dbService = DatabaseService();

  String _selectedBloodGroup = 'O+';
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final RegExp _phoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
  final RegExp _passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*(),.?":{}|<>]).{8,}$');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _parentPhoneController.text.trim();
    final String parentEmail = _parentEmailController.text.trim();

    try {
      String uid = "mock_driver_${DateTime.now().millisecondsSinceEpoch}";

      try {
        final credential = await _dbService.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential != null && credential.user != null) {
          uid = credential.user!.uid;
        }
      } catch (e) {
        print("UserRegistration: Auth signup failed, continuing in mock mode: $e");
      }

      await _dbService.saveUserProfile(
        uid: uid,
        email: email,
        name: name,
        bloodGroup: _selectedBloodGroup,
        parentPhone: phone,
        parentEmail: parentEmail.isNotEmpty ? parentEmail : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Driver Profile Registered Successfully! UID: ${uid.substring(0, 12)}..."),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Registration failed: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Registration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0F19), Color(0xFF111827), Color(0xFF161E2E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  FadeSlideTransition(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      children: [
                        const Center(
                          child: StatusBadge(
                            label: "Protected Telematics Profile",
                            type: BadgeStatusType.active,
                            icon: Icons.shield_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            "Create Driver Account",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            "Emergency contacts are notified immediately during accident alerts",
                            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 1: Account Credentials
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 70),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161E2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF26334D)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: "Account Identity",
                            subtitle: "Your credentials for driver telematics access",
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            validator: (val) => val == null || val.trim().isEmpty ? "Please enter your full name" : null,
                            decoration: const InputDecoration(
                              labelText: "Driver Full Name",
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Please enter your email";
                              if (!val.contains('@') || !val.contains('.')) return "Enter a valid email";
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: "Email Address",
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Please enter your password";
                              if (!_passwordRegex.hasMatch(val)) {
                                return "Min 8 chars, 1 uppercase, 1 number & 1 special char";
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              helperText: "Must contain uppercase, digit, and symbol",
                              helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 2: Medical Profile (Blood Group)
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 140),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161E2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF26334D)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: "Medical Information",
                            subtitle: "Included in emergency SMS dispatched to hospital and parents",
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _bloodGroups.map((bg) {
                              final bool isSelected = _selectedBloodGroup == bg;
                              return InteractivePressable(
                                onTap: () => setState(() => _selectedBloodGroup = bg),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 70,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected ? null : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFFB7185) : const Color(0xFF334155),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      bg,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 3: Emergency Guardian & Parent Contact
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 210),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161E2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF26334D)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: "Emergency Parent / Guardian Contact",
                            subtitle: "Receives immediate SMS alert with exact live GPS location link",
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _parentPhoneController,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Please enter guardian phone number";
                              if (!_phoneRegex.hasMatch(val.trim())) {
                                return "Must include country code (e.g. +919876543210)";
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: "Parent Phone Number",
                              prefixIcon: Icon(Icons.phone_outlined),
                              helperText: "Include international code (+91 for India)",
                              helperStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _parentEmailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty && (!val.contains('@') || !val.contains('.'))) {
                                return "Please enter a valid email address";
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: "Parent Email Address (Optional)",
                              prefixIcon: Icon(Icons.mark_email_read_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 280),
                    child: InteractivePressable(
                      onTap: _isLoading ? null : _submitForm,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  "Register & Enable Protection",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
