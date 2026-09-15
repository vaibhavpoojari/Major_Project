import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../widgets/emergency_ui_components.dart';
import 'user_registration.dart';
import 'hospital_registration.dart';
import 'control_panel.dart';
import 'hospital_dashboard.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _shieldPulseController;
  late Animation<double> _shieldGlowAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _shieldPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _shieldGlowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shieldPulseController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionService.requestInitialPermissions();

      if (!mounted) return;
      if (_dbService.activeSessionUser != null) {
        final role = _dbService.activeSessionRole;
        if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ControlPanel()),
          );
        } else if (role == 'hospital') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HospitalDashboard()),
          );
        } else if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shieldPulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    final String role;
    if (_tabController.index == 0) {
      role = 'driver';
    } else if (_tabController.index == 1) {
      role = 'hospital';
    } else {
      role = 'admin';
    }

    try {
      if (role == 'admin') {
        final cleanEmail = email.toLowerCase();
        final bool isUser1 = cleanEmail == 'shettyprakyathp@gmail.com' && password == 'Password123!';
        final bool isUser2 = cleanEmail == 'vaibhava.23cs179@sode-edu.in' && password == '9731971568';

        if (!isUser1 && !isUser2) {
          throw Exception("Access Denied: Only authorized administrators are allowed.");
        }

        await _dbService.saveAdminSession(email);
      } else {
        await _dbService.login(
          email: email,
          password: password,
          role: role,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logged in successfully as ${role == 'driver' ? 'Driver' : role == 'hospital' ? 'Hospital Hub' : 'Admin'}!"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ControlPanel()),
          );
        } else if (role == 'hospital') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HospitalDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: ${e.toString().replaceAll('Exception:', '')}"),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shield Logo Entrance Animation with breathing glow
                      FadeSlideTransition(
                        duration: const Duration(milliseconds: 380),
                        offset: const Offset(0.0, -0.15),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _shieldGlowAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE11D48).withValues(alpha: 0.45 * _shieldGlowAnimation.value),
                                      blurRadius: 22 * _shieldGlowAnimation.value,
                                      spreadRadius: 2 * _shieldGlowAnimation.value,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.shield_outlined, size: 38, color: Colors.white),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const FadeSlideTransition(
                        delay: Duration(milliseconds: 80),
                        child: Center(
                          child: Text(
                            "ACCIDENT GUARD",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const FadeSlideTransition(
                        delay: Duration(milliseconds: 140),
                        child: Center(
                          child: Text(
                            "Real-Time Telematics & Emergency Response",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Animated Role Selection Tabs
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 180),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF26334D)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF94A3B8),
                            labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13),
                            tabs: const [
                              Tab(text: "Driver"),
                              Tab(text: "Hospital Hub"),
                              Tab(text: "Admin"),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Container Card
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 240),
                        child: Container(
                          padding: const EdgeInsets.all(22.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161E2E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF26334D)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: _tabController.index == 0 ? "Driver Portal" : _tabController.index == 1 ? "Dispatch Hub" : "Console",
                                    type: BadgeStatusType.info,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return "Please enter your email";
                                  if (!val.contains('@')) return "Enter a valid email address";
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
                                validator: (val) => val == null || val.isEmpty ? "Please enter your password" : null,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        key: ValueKey<bool>(_obscurePassword),
                                      ),
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              InteractivePressable(
                                onTap: _isLoading ? null : _submitLogin,
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
                                            "Authenticate & Access",
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
                              _buildReferenceLoginDetails(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Registration CTAs
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 300),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const UserRegistration()),
                                ),
                                child: const Text(
                                  "New Driver? Register",
                                  style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Text("•", style: TextStyle(color: Colors.white24)),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const HospitalRegistration()),
                                ),
                                child: const Text(
                                  "Register Hospital Hub",
                                  style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Safety guarantee footer
                      const SizedBox(height: 12),
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 360),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                "Direct SIM & TextBee Real-Time Dispatch Protected",
                                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
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
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceLoginDetails() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _tabController.index == 0
          ? const SizedBox.shrink(key: ValueKey('driver_none'))
          : _tabController.index == 1
              ? Container(
                  key: const ValueKey('hospital_hub_credentials'),
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF26334D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14, color: Color(0xFF38BDF8)),
                          SizedBox(width: 6),
                          Text(
                            "REFERENCE LOGIN DETAILS",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Hospital Hub",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Email: admin@cityemergency.org",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Text(
                        "Password: Password123!",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('admin_credentials'),
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF26334D)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFF38BDF8)),
                          SizedBox(width: 6),
                          Text(
                            "REFERENCE LOGIN DETAILS",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Admin 1",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Email: Shettyprakyathp@gmail.com",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        "Password: Password123!",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1, color: Color(0xFF26334D)),
                      ),
                      Text(
                        "Admin 2",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Email: vaibhava.23cs179@sode-edu.in",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        "Password: 9731971568",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
