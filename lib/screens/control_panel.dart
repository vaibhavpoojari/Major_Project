import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_monitoring.dart';
import 'emergency_contacts_screen.dart';
import 'accident_history_screen.dart';
import 'emergency_profile_screen.dart';
import 'offline_map_screen.dart';
import '../services/alert_service.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../widgets/emergency_ui_components.dart';
import '../widgets/health_monitor_widget.dart';
import 'login_screen.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final DatabaseService _dbService = DatabaseService();
  final AlertService _alertService = AlertService();

  final _emailUrlController = TextEditingController();
  final _textbeeApiKeyController = TextEditingController();
  final _textbeeDeviceIdController = TextEditingController();
  final _smtpEmailController = TextEditingController();
  final _smtpPasswordController = TextEditingController();

  bool _isEmailConfigured = false;
  bool _isTextbeeConfigured = false;
  int _countdownDuration = 20;

  Map<String, dynamic> get _driverProfile => _dbService.activeSessionUser ?? {
    'fullName': 'Prakyath',
    'email': 'shettyprakyathp@gmail.com',
    'bloodGroup': 'O+',
    'parentPhone': '+919113895413',
  };

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  void _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await DatabaseService.initDefaultConfigurations(prefs);

    final emailUrl = prefs.getString('email_dispatcher_url') ?? '';
    final textbeeApiKey = prefs.getString('textbee_api_key') ?? DatabaseService.defaultTextbeeApiKey;
    final textbeeDeviceId = prefs.getString('textbee_device_id') ?? DatabaseService.defaultTextbeeDeviceId;
    final smtpEmail = prefs.getString('smtp_email') ?? DatabaseService.defaultSmtpEmail;
    final smtpPassword = prefs.getString('smtp_password') ?? DatabaseService.defaultSmtpPassword;

    final countdown = prefs.getInt('sos_countdown_duration') ?? 20;

    if (mounted) {
      setState(() {
        _emailUrlController.text = emailUrl;
        _textbeeApiKeyController.text = textbeeApiKey;
        _textbeeDeviceIdController.text = textbeeDeviceId;
        _smtpEmailController.text = smtpEmail;
        _smtpPasswordController.text = smtpPassword;
        _isTextbeeConfigured = _textbeeApiKeyController.text.trim().isNotEmpty;
        _isEmailConfigured = _smtpEmailController.text.trim().isNotEmpty || emailUrl.trim().isNotEmpty;
        _countdownDuration = (countdown >= 15 && countdown <= 30) ? countdown : 20;
      });
    }
  }

  void _updateCountdownDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sos_countdown_duration', seconds);
    setState(() {
      _countdownDuration = seconds;
    });
  }

  @override
  void dispose() {
    _emailUrlController.dispose();
    _textbeeApiKeyController.dispose();
    _textbeeDeviceIdController.dispose();
    _smtpEmailController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }

  void _updateSmtpConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smtp_email', _smtpEmailController.text.trim());
    await prefs.setString('smtp_password', _smtpPasswordController.text.trim());
    await prefs.setString('email_dispatcher_url', _emailUrlController.text.trim());
    setState(() {
      _isEmailConfigured = _smtpEmailController.text.trim().isNotEmpty || _emailUrlController.text.trim().isNotEmpty;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email configuration saved successfully!"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _updateTextbeeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('textbee_api_key', _textbeeApiKeyController.text.trim());
    await prefs.setString('textbee_device_id', _textbeeDeviceIdController.text.trim());
    setState(() {
      _isTextbeeConfigured = _textbeeApiKeyController.text.trim().isNotEmpty;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("TextBee gateway configuration saved!"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _logout() {
    _dbService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalization.languageNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.security, size: 22, color: Color(0xFFE11D48)),
                const SizedBox(width: 10),
                Text('driver_hub'.tr),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: _logout,
                tooltip: "Sign Out",
              )
            ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Driver Profile Hero Card
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 320),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF26334D)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.person, size: 30, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _driverProfile['fullName'] ?? 'Driver Name',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _driverProfile['email'] ?? 'driver@email.com',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.35)),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "BLOOD",
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Color(0xFFFB7185), fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _driverProfile['bloodGroup'] ?? 'O+',
                                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28, color: Color(0xFF26334D)),
                        Row(
                          children: [
                            const Icon(Icons.contact_phone_outlined, size: 16, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 8),
                            const Text(
                              "Emergency Contact:",
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _driverProfile['parentPhone'] ?? 'Unconfigured',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // System Protection Live Matrix
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 70),
                  child: Column(
                    children: [
                      const SectionHeader(
                        title: "Emergency Protection Matrix",
                        subtitle: "Real-time dispatch channel availability",
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMatrixTile(
                              title: "TextBee SMS",
                              status: _isTextbeeConfigured ? "Online" : "Standby",
                              isReady: _isTextbeeConfigured,
                              icon: Icons.cell_tower,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMatrixTile(
                              title: "Native SIM SMS",
                              status: "Active (Direct)",
                              isReady: true,
                              icon: Icons.sim_card_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMatrixTile(
                              title: "SMTP Email",
                              status: _isEmailConfigured ? "Configured" : "Standby",
                              isReady: _isEmailConfigured,
                              icon: Icons.mail_outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMatrixTile(
                              title: "OSM Hospital GPS",
                              status: "Ready",
                              isReady: true,
                              icon: Icons.local_hospital_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Feature 6: Compact System Health Monitor
                const FadeSlideTransition(
                  delay: Duration(milliseconds: 100),
                  child: HealthMonitorWidget(),
                ),
                const SizedBox(height: 24),

                // Primary CTA: Launch Telematics & Accident Detection (Heartbeat Animated Pulse Card)
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 140),
                  child: InteractivePressable(
                    onTap: () => Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (_) => SensorMonitoring(alertService: _alertService),
                       ),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.38),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          EmergencyPulseIndicator(size: 28, color: Colors.white),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Launch Crash Telematics",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Continuous G-force monitoring & live crash trigger",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Feature Hub: Emergency Contacts, Accident History & Emergency Profile Navigation
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 170),
                  child: Column(
                    children: [
                      SectionHeader(
                        title: 'driver_hub'.tr,
                        subtitle: "Manage emergency contacts, accident history & driver profile",
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNavigationCard(
                              icon: Icons.contact_phone_outlined,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'emergency_contacts'.tr,
                              subtitle: 'emergency_contacts_desc'.tr,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmergencyContactsScreen(
                                    driverEmail: _driverProfile['email'] ?? 'driver@guard.com',
                                  ),
                                ),
                              ).then((_) => _loadConfigs()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNavigationCard(
                              icon: Icons.history_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'accident_history'.tr,
                              subtitle: 'accident_history_desc'.tr,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AccidentHistoryScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNavigationCard(
                              icon: Icons.medical_services_outlined,
                              iconColor: const Color(0xFFFB7185),
                              title: 'emergency_profile'.tr,
                              subtitle: 'emergency_profile_desc'.tr,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmergencyProfileScreen(
                                    driverEmail: _driverProfile['email'] ?? 'driver@guard.com',
                                  ),
                                ),
                              ).then((_) => _loadConfigs()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNavigationCard(
                              icon: Icons.map_outlined,
                              iconColor: const Color(0xFF10B981),
                              title: 'offline_maps'.tr,
                              subtitle: 'offline_maps_desc'.tr,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OfflineMapScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Feature 7 & Feature 1: System Settings (Language & Countdown Duration)
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 190),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 8),
                            Text(
                              'settings'.tr,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Language Selection Toggle
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'language'.tr,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'language_select'.tr,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                children: [
                                  _buildLanguageButton(AppLanguage.english),
                                  _buildLanguageButton(AppLanguage.kannada),
                                  _buildLanguageButton(AppLanguage.hindi),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28, color: Color(0xFF26334D)),

                        // Configurable Countdown Duration Slider (15 - 30 seconds)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'countdown_duration'.tr,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "15 - 30s override timer",
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                "$_countdownDuration s",
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFB7185),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _countdownDuration.toDouble(),
                          min: 15.0,
                          max: 30.0,
                          divisions: 15,
                          label: "$_countdownDuration s",
                          activeColor: const Color(0xFFE11D48),
                          inactiveColor: const Color(0xFF334155),
                          onChanged: (val) {
                            _updateCountdownDuration(val.round());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // TextBee SMS Gateway Card
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 210),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.cell_tower, size: 20, color: Color(0xFF38BDF8)),
                                SizedBox(width: 8),
                                Text(
                                  "TextBee SMS Gateway",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              label: _isTextbeeConfigured ? "Primary Ready" : "Standby",
                              type: _isTextbeeConfigured ? BadgeStatusType.active : BadgeStatusType.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Dispatches immediate emergency SMS via TextBee HTTP Gateway without delays.",
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _textbeeApiKeyController,
                          decoration: const InputDecoration(
                            labelText: "TextBee API Key",
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _textbeeDeviceIdController,
                          decoration: const InputDecoration(
                            labelText: "TextBee Device ID (Optional)",
                            prefixIcon: Icon(Icons.phone_android_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InteractivePressable(
                                onTap: _updateTextbeeConfig,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Save Gateway",
                                      style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InteractivePressable(
                                onTap: _sendTestSmsAction,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF34D399)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.sms_outlined, size: 16, color: Color(0xFF34D399)),
                                      SizedBox(width: 6),
                                      Text(
                                        "Test SMS",
                                        style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF34D399), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Hardware Direct Native SIM SMS (Fallback Info)
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 280),
                  child: Container(
                    padding: const EdgeInsets.all(18.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sim_card_outlined, color: Color(0xFF34D399), size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Direct Native SIM SMS (Hardware Fallback)",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "If TextBee is offline or unconfigured, Android SmsManager automatically dispatches emergency SMS directly via the device's cellular SIM without launching external apps.",
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Emergency Email Configuration
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 350),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.mark_email_read_outlined, size: 20, color: Color(0xFF38BDF8)),
                                SizedBox(width: 8),
                                Text(
                                  "Emergency Email & Webhook",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              label: _isEmailConfigured ? "SMTP Active" : "Standby",
                              type: _isEmailConfigured ? BadgeStatusType.info : BadgeStatusType.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Direct Gmail SMTP relay and optional HTTP webhook dispatch for instant emergency crash reports.",
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _smtpEmailController,
                          decoration: const InputDecoration(
                            labelText: "Sender Gmail Address",
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _smtpPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Gmail Password / App Password",
                            prefixIcon: Icon(Icons.password_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailUrlController,
                          decoration: const InputDecoration(
                            labelText: "Optional Dispatcher Webhook URL",
                            prefixIcon: Icon(Icons.link_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InteractivePressable(
                                onTap: _updateSmtpConfig,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Save Email Config",
                                      style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InteractivePressable(
                                onTap: _sendTestEmailAction,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF38BDF8)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_outlined, size: 16, color: Color(0xFF38BDF8)),
                                      SizedBox(width: 6),
                                      Text(
                                        "Test Email",
                                        style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
}

  Widget _buildMatrixTile({
    required String title,
    required String status,
    required bool isReady,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReady ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF26334D),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isReady ? const Color(0xFF34D399) : const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  children: [
                    if (isReady) ...[
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                    Text(
                      status,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: isReady ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendTestSmsAction() async {
    final driver = _driverProfile;
    final recipient = (driver['parentPhone'] ?? '').toString().trim();

    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No valid emergency phone found in driver profile.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sms_outlined, color: Color(0xFF34D399)),
            SizedBox(width: 10),
            Text("SMS Verification Test"),
          ],
        ),
        content: FutureBuilder<SmsDispatchResult>(
          future: _alertService.sendTestSms(recipientPhone: recipient),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF34D399)),
                    SizedBox(height: 16),
                    Text("Dispatching test SMS..."),
                  ],
                ),
              );
            }

            final result = snapshot.data;
            final bool isSuccess = result?.isSuccess == true;
            final String masked = result?.maskedRecipient ?? AlertService.maskPhoneNumber(recipient);
            final String method = result?.method ?? 'Unknown';
            final String status = result?.statusDisplay ?? 'Failed';
            final int elapsed = result?.elapsedMs ?? 0;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : Icons.error,
                        color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSuccess ? "SMS Dispatch Accepted" : "SMS Dispatch Failed",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFF26334D)),
                  Text("• Recipient: $masked", style: const TextStyle(color: Colors.white70)),
                  Text("• Provider / Method: $method", style: const TextStyle(color: Colors.white70)),
                  const Text("• Request Started: Yes", style: TextStyle(color: Colors.white70)),
                  Text("• Result: $status", style: const TextStyle(color: Colors.white70)),
                  Text("• Elapsed Time: $elapsed ms", style: const TextStyle(color: Colors.white70)),
                  if (result?.errorMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "• Error Details: ${result!.errorMessage}",
                      style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFF38BDF8))),
          )
        ],
      ),
    );
  }

  void _sendTestEmailAction() async {
    final driver = _driverProfile;
    final recipient = (driver['parentEmail'] ?? driver['email'] ?? '').toString().trim();

    if (recipient.isEmpty || !recipient.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No valid driver or parent email found in profile.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text("Email Verification Test"),
          ],
        ),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _alertService.sendTestEmail(recipientEmail: recipient),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    SizedBox(height: 16),
                    Text("Dispatching test email..."),
                  ],
                ),
              );
            }

            final result = snapshot.data ?? {};
            final bool isSuccess = result['isSuccess'] == true;
            final String method = result['method'] ?? 'Unknown';
            final String status = result['responseStatus'] ?? 'Unknown';
            final String body = result['responseBody'] ?? 'No body returned';

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : Icons.error,
                        color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSuccess ? "Email Delivered Successfully" : "Email Delivery Failed",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFF26334D)),
                  Text("• Recipient: $recipient", style: const TextStyle(color: Colors.white70)),
                  Text("• Provider / Method: $method", style: const TextStyle(color: Colors.white70)),
                  const Text("• Request Started: Yes", style: TextStyle(color: Colors.white70)),
                  Text("• Server Response: $status", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text("• Details: $body", style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFF38BDF8))),
          )
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InteractivePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF26334D)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF64748B), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(AppLanguage lang) {
    final bool isSelected = AppLocalization.currentLanguage == lang;
    return GestureDetector(
      onTap: () => AppLocalization.setLanguage(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          lang.displayName,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
