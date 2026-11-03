import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart';
import '../services/alert_service.dart';
import '../services/buzzer_service.dart';
import '../services/permission_service.dart';
import '../services/localization_service.dart';
import '../widgets/emergency_ui_components.dart';

class SensorMonitoring extends StatefulWidget {
  final AlertService alertService;
  const SensorMonitoring({super.key, required this.alertService});

  @override
  State<SensorMonitoring> createState() => _SensorMonitoringState();
}

class _SensorMonitoringState extends State<SensorMonitoring> with TickerProviderStateMixin {
  final SensorService _sensorService = SensorService();
  final DatabaseService _dbService = DatabaseService();

  // Active driver context
  Map<String, dynamic>? _selectedDriver;
  List<Map<String, dynamic>> _availableDrivers = [];

  // Live state telemetry
  double _currentForce = 0.0;
  double _maxForceObserved = 0.0;
  bool _isEngineActive = false;

  // Emergency state control
  bool _isEmergencyState = false;
  int _countdownSeconds = 20;
  int _configuredCountdown = 20;
  Timer? _countdownTimer;
  String _crashType = "Severe Collision";
  DateTime? _lastAlertTime;

  // Animation controller for emergency alert pulse
  late AnimationController _emergencyPulseController;
  late Animation<double> _pulseScaleAnimation;

  // Audit Logs
  final List<String> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _emergencyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseScaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _emergencyPulseController, curve: Curves.easeInOut),
    );
    _loadDrivers();
    _loadCountdownConfig();
    widget.alertService.requestSmsPermission();
    _addLog("Telematics initialized. Select driver profile to start monitoring.");
  }

  Future<void> _loadCountdownConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final duration = prefs.getInt('sos_countdown_duration') ?? 20;
      if (duration >= 15 && duration <= 30) {
        if (mounted) {
          setState(() {
            _configuredCountdown = duration;
            if (!_isEmergencyState) {
              _countdownSeconds = duration;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _addLog(String msg) {
    setState(() {
      _auditLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $msg");
    });
  }

  Future<void> _loadDrivers() async {
    try {
      final activeUser = _dbService.activeSessionUser;
      if (activeUser != null) {
        final freshProfile = await _dbService.getCurrentUserProfile(activeUser['uid'] ?? '');
        setState(() {
          _availableDrivers = [freshProfile ?? activeUser];
          _selectedDriver = freshProfile ?? activeUser;
        });
        _addLog("Active Driver profile loaded: ${_selectedDriver!['fullName']}");
      } else {
        final defaultDriver = {
          'uid': 'mock_driver_1',
          'email': 'shettyprakyathp@gmail.com',
          'fullName': 'Prakyath',
          'bloodGroup': 'O+',
          'parentPhone': '+919113895413',
          'parentEmail': 'shettyprakyathp@gmail.com',
          'role': 'driver',
        };
        setState(() {
          _availableDrivers = [defaultDriver];
          _selectedDriver = defaultDriver;
        });
        _addLog("Loaded default profile: Prakyath");
      }
    } catch (e) {
      print("SensorMonitoring: Load drivers error: $e");
    }
  }

  Future<void> _updateEngineState(bool isActive) async {
    if (_selectedDriver == null) return;
    double lat = 12.9716;
    double lng = 77.5946;
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 4));
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    await _dbService.logEngineState(
      email: _selectedDriver!['email'] ?? 'driver@guard.com',
      driverName: _selectedDriver!['fullName'] ?? 'Driver',
      isEngineActive: isActive,
      latitude: lat,
      longitude: lng,
    );
  }

  void _toggleSensorEngine() async {
    if (_isEngineActive) {
      _sensorService.stopListening();
      setState(() {
        _isEngineActive = false;
        _currentForce = 0.0;
      });
      _updateEngineState(false);
      _addLog("Telematics engine deactivated.");
    } else {
      if (_selectedDriver == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select a Driver profile first!")),
        );
        return;
      }

      await PermissionService.ensureLocationPermission(context);

      setState(() {
        _isEngineActive = true;
        _maxForceObserved = 0.0;
      });
      _updateEngineState(true);
      _addLog("Telematics engine active: stream analyzing vector acceleration...");

      _sensorService.startListening(
        onUpdate: (magnitude) {
          setState(() {
            _currentForce = magnitude;
            if (magnitude > _maxForceObserved) {
              _maxForceObserved = magnitude;
            }
          });
        },
        onCrashDetected: (magnitude, crashType) {
          _triggerEmergencyState(magnitude, crashType);
        },
      );
    }
  }

  void _triggerEmergencyState(double magnitude, String crashType) {
    if (_isEmergencyState) return;

    // Feature 1: Duplicate alert lockout guard (ignore sensor spikes within 5 seconds)
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!).inSeconds < 5) {
      _addLog("Cooldown active: duplicate accident trigger debounced.");
      return;
    }
    _lastAlertTime = DateTime.now();

    _sensorService.stopListening();
    widget.alertService.preFetchLocation();

    _emergencyPulseController.repeat(reverse: true);

    setState(() {
      _isEmergencyState = true;
      _isEngineActive = false;
      _currentForce = magnitude;
      _countdownSeconds = _configuredCountdown;
      _crashType = crashType;
    });

    _addLog("CRITICAL: $crashType detected (${magnitude.toStringAsFixed(2)} m/s²). Sounding buzzer. ${_configuredCountdown}s override timer active.");
    BuzzerService().startBuzzer();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
        _dispatchEmergencyBroadcast();
      }
    });
  }

  void _cancelEmergencyState() async {
    _countdownTimer?.cancel();
    _emergencyPulseController.reset();
    BuzzerService().stopBuzzer();
    setState(() {
      _isEmergencyState = false;
    });
    _lastAlertTime = DateTime.now();
    _addLog("USER OVERRIDE: 'I AM SAFE' verified. Alert cancelled. Monitoring resumed.");

    // Log safety override cancellation event in database
    try {
      if (_selectedDriver != null) {
        await _dbService.createCrashReport({
          'driverName': _selectedDriver!['fullName'] ?? 'Driver',
          'driverEmail': _selectedDriver!['email'] ?? '',
          'bloodGroup': _selectedDriver!['bloodGroup'] ?? 'Unknown',
          'latitude': 12.9716,
          'longitude': 77.5946,
          'crashType': _crashType,
          'maxAcceleration': _currentForce,
          'nearestHospital': 'Cancelled by User',
          'hospitalDistance': 'N/A',
          'hospitalPhone': 'N/A',
          'hospitalStatus': 'Cancelled',
          'smsStatus': 'Cancelled (Safe)',
          'alertStatus': 'Cancelled by Driver',
          'isCancelled': true,
          'status': 'Cancelled',
        });
      }
    } catch (_) {}

    _toggleSensorEngine();
  }

  Future<void> _dispatchEmergencyBroadcast() async {
    BuzzerService().stopBuzzer();
    _emergencyPulseController.reset();
    setState(() {
      _isEmergencyState = false;
    });

    _addLog("Countdown expired. Executing emergency alert broadcast pipeline...");

    try {
      final results = await widget.alertService.sendEmergencyAlerts(
        userProfile: _selectedDriver!,
        crashType: _crashType,
        maxAcceleration: _currentForce,
      );

      final List<dynamic> topHospList = results['topHospitals'] is List ? results['topHospitals'] as List : [];
      final String hospitalName = results['nearestHospital'] ?? 'Nearby hospital unavailable';
      final double? dist = results['distance'] as double?;
      final String distStr = dist != null ? "${dist.toStringAsFixed(2)} km" : "Distance unavailable";
      final String? address = results['hospitalAddress'];
      final String hospitalPhone = results['hospitalPhone'] ?? 'Hospital phone unavailable';
      final bool hasHospPhone = results['hasValidHospitalPhone'] == true;
      final bool parentSent = results['parentSent'] == true;
      final bool hospitalSent = results['hospitalSent'] == true;
      final bool emailSent = results['emailSent'] == true;

      final String gpsStr = results['lat'] != null ? "${results['lat']}, ${results['lng']}" : "Unavailable";

      _addLog("ACCIDENT GPS: $gpsStr");
      if (results['lat'] != null) {
        _addLog("SEARCHING HOSPITALS AROUND CURRENT LOCATION");
      }
      _addLog("NEAREST HOSPITAL: $hospitalName");
      _addLog("DISTANCE: $distStr");
      if (address != null && address.isNotEmpty) {
        _addLog("ADDRESS: $address");
      }
      _addLog("PHONE: $hospitalPhone");

      if (topHospList.isNotEmpty) {
        _addLog("Top ${topHospList.length} Nearby Suitable Facilities:");
        for (int i = 0; i < topHospList.length; i++) {
          final h = topHospList[i] is Map ? topHospList[i] as Map : {};
          final hName = h['facilityName'] ?? 'Unknown';
          final hDist = h['distanceKm'] != null ? "${(h['distanceKm'] as num).toStringAsFixed(2)} km" : "N/A";
          final hType = h['facilityType'] ?? 'Hospital';
          final hEmerg = h['emergencyCapability'] ?? 'Unavailable';
          final hOwner = h['ownership'] ?? 'Unavailable';
          _addLog("  • #${i + 1}: $hName ($hDist) | $hType | Emergency: $hEmerg | $hOwner");
        }
      }

      final String parentSmsStatus = results['parentSmsStatus'] ?? (parentSent ? 'Dispatched' : 'Failed');
      final String hospitalSmsStatus = results['hospitalSmsStatus'] ?? (hasHospPhone ? (hospitalSent ? 'Dispatched' : 'Failed') : 'Skipped (phone unavailable)');

      _addLog("Parent SMS: $parentSmsStatus (${results['parentPhone']})");
      if (hasHospPhone) {
        _addLog("Hospital SMS: $hospitalSmsStatus ($hospitalPhone)");
      } else {
        _addLog("Hospital SMS: Skipped (No phone in OpenStreetMap)");
      }
      _addLog(emailSent ? "Emergency Email alert dispatched" : "Email alert skipped or pending configuration");
      _addLog("Crash report recorded to emergency database");

      if (mounted) {
        _showEmergencyResultsDialog(
          gpsStr: gpsStr,
          hospitalName: hospitalName,
          distStr: distStr,
          topHospList: topHospList,
          parentSmsStatus: parentSmsStatus,
          hospitalSmsStatus: hospitalSmsStatus,
          emailSent: emailSent,
        );
      }
    } catch (e) {
      _addLog("Broadcast error: $e");
    }
  }

  void _showEmergencyResultsDialog({
    required String gpsStr,
    required String hospitalName,
    required String distStr,
    required List<dynamic> topHospList,
    required String parentSmsStatus,
    required String hospitalSmsStatus,
    required bool emailSent,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "EmergencyBroadcastDialog",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF26334D)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Text(
                "Emergency Broadcast Status",
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GPS Status Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 20, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Accident GPS: $gpsStr",
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top Discovered Hospitals
                  const Text(
                    "Top Nearby Hospitals (OSM):",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  if (topHospList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: Text(
                        "$hospitalName ($distStr)",
                        style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8)),
                      ),
                    )
                  else
                    ...topHospList.asMap().entries.map((entry) {
                      final int idx = entry.key + 1;
                      final hMap = entry.value is Map ? entry.value as Map : {};
                      final hName = hMap['facilityName'] ?? hospitalName;
                      final double? hDist = hMap['distanceKm'] is num ? (hMap['distanceKm'] as num).toDouble() : null;
                      final hType = hMap['facilityType'] ?? 'Hospital';
                      final hEmerg = hMap['emergencyCapability'] ?? 'Unavailable';
                      final hOwner = hMap['ownership'] ?? 'Unavailable';
                      final hPhone = (hMap['phone'] != null && hMap['phone'].toString().isNotEmpty) ? hMap['phone'].toString() : null;

                      return EmergencyHospitalCard(
                        rank: idx,
                        name: hName,
                        distanceKm: hDist,
                        facilityType: hType,
                        emergencyCapability: hEmerg,
                        ownership: hOwner,
                        phone: hPhone,
                      );
                    }),
                  const SizedBox(height: 14),

                  // Real-Time Dispatch Status
                  const Text(
                    "Real-Time Dispatch Summary:",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  _buildDispatchRow("Parent SMS", parentSmsStatus, parentSmsStatus == 'Dispatched' || parentSmsStatus == 'Accepted by SMS Gateway' || parentSmsStatus == 'Delivered'),
                  _buildDispatchRow("Hospital SMS", hospitalSmsStatus, hospitalSmsStatus == 'Dispatched' || hospitalSmsStatus == 'Accepted by SMS Gateway' || hospitalSmsStatus == 'Delivered'),
                  _buildDispatchRow("Email Notification", emailSent ? "Dispatched" : "Skipped", emailSent),
                  _buildDispatchRow("Cloud Firestore DB", "Incident Saved", true),
                ],
              ),
            ),
          ),
          actions: [
            InteractivePressable(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Dismiss Alerts",
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildDispatchRow(String channel, String status, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(channel, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8))),
          StatusBadge(
            label: status,
            type: isSuccess ? BadgeStatusType.active : BadgeStatusType.warning,
          ),
        ],
      ),
    );
  }

  void _simulateSpecificCrash(String type) {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a Driver profile first!")),
      );
      return;
    }
    _sensorService.simulateCrash(type, (mag, crashType) {
      _triggerEmergencyState(mag, crashType);
    });
  }

  void _triggerManualSos() {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a Driver profile first!")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
        title: Row(
          children: [
            const Icon(Icons.emergency_share, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'manual_sos'.tr,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          "Trigger emergency SOS broadcast immediately? This will activate the alert pipeline and alert your emergency contacts with your GPS location.",
          style: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr, style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _triggerEmergencyState(50.0, "Manual SOS Broadcast");
            },
            child: const Text('ACTIVATE NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _emergencyPulseController.dispose();
    _countdownTimer?.cancel();
    BuzzerService().stopBuzzer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 HIGH-VISIBILITY ACCIDENT DETECTED SCREEN OVERLAY 🚨
    if (_isEmergencyState) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0407), // Deep emergency dark red
        body: AnimatedBuilder(
          animation: _emergencyPulseController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1 * _pulseScaleAnimation.value,
                  colors: [
                    Color.lerp(
                      const Color(0xFFBE123C).withValues(alpha: 0.35),
                      const Color(0xFFE11D48).withValues(alpha: 0.52),
                      _emergencyPulseController.value,
                    )!,
                    const Color(0xFF0F0407),
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  // Pulsing Emergency Icon with Outer Glow Ring
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseScaleAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseScaleAnimation.value,
                        child: child,
                      ),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                          border: Border.all(color: const Color(0xFFE11D48), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.45),
                              blurRadius: 24,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.car_crash_rounded, color: Color(0xFFFB7185), size: 52),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Center(
                    child: Text(
                      'accident_detected'.tr,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        "$_crashType (${_currentForce.toStringAsFixed(1)} m/s²)",
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFB7185),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'countdown_prompt'.tr,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFCBD5E1)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Giant Ticking Timer with subtle scale tick
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Text(
                        "$_countdownSeconds",
                        key: ValueKey<int>(_countdownSeconds),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bypass Timer Button
                  InteractivePressable(
                    onTap: () {
                      _countdownTimer?.cancel();
                      _dispatchEmergencyBroadcast();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18, color: Color(0xFF0F172A)),
                          const SizedBox(width: 8),
                          Text(
                            'send_immediately'.tr,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Giant High-Visibility Safety Override Button
                  InteractivePressable(
                    onTap: _cancelEmergencyState,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'i_am_safe'.tr,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "TAP TO CANCEL EMERGENCY ALERTS",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 📡 TELEMETRY MONITORING CONSOLE 📡
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Crash Telematics"),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Driver Selection
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, color: Color(0xFF38BDF8), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _selectedDriver,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF161E2E),
                              items: _availableDrivers.map((driver) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: driver,
                                  child: Text(
                                    "${driver['fullName']} (${driver['bloodGroup'] ?? 'O+'})",
                                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedDriver = val);
                                _addLog("Driver context switched to ${_selectedDriver?['fullName']}");
                              },
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: _isEngineActive ? "Monitoring" : "Standby",
                          type: _isEngineActive ? BadgeStatusType.active : BadgeStatusType.neutral,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Live G-Force Telemetry Card with smooth dynamic transitions
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 80),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(22.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isEngineActive
                            ? (_currentForce >= SensorService.crashThreshold ? const Color(0xFFEF4444) : const Color(0xFF10B981).withValues(alpha: 0.45))
                            : const Color(0xFF26334D),
                        width: _currentForce >= SensorService.crashThreshold ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _currentForce >= SensorService.crashThreshold
                              ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "LIVE ACCELERATION VECTOR",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (_isEngineActive)
                              const EmergencyPulseIndicator(size: 16, color: Color(0xFF10B981))
                            else
                              const StatusBadge(label: "Idle", type: BadgeStatusType.neutral),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 120),
                              tween: Tween<double>(begin: 0.0, end: _currentForce),
                              builder: (context, val, child) {
                                return Text(
                                  val.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 54,
                                    fontWeight: FontWeight.w900,
                                    color: val >= SensorService.crashThreshold
                                        ? const Color(0xFFEF4444)
                                        : val >= 20.0
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF34D399),
                                    letterSpacing: -1,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "m/s²",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Visual G-force progress bar with smooth tweening
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 120),
                            tween: Tween<double>(begin: 0.0, end: (_currentForce / 50.0).clamp(0.0, 1.0)),
                            builder: (context, gaugeVal, child) {
                              return LinearProgressIndicator(
                                value: gaugeVal,
                                minHeight: 8,
                                backgroundColor: const Color(0xFF0F172A),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _currentForce >= SensorService.crashThreshold
                                      ? const Color(0xFFEF4444)
                                      : _currentForce >= 20.0
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFF26334D)),
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Peak Force: ${_maxForceObserved.toStringAsFixed(2)} m/s²",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                            Text(
                              "Threshold: ${SensorService.crashThreshold.toStringAsFixed(2)} m/s²",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFB7185)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Start/Stop Telematics Engine Toggle with InteractivePressable
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 140),
                  child: InteractivePressable(
                    onTap: _toggleSensorEngine,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isEngineActive
                              ? [const Color(0xFFE11D48), const Color(0xFFBE123C)]
                              : [const Color(0xFF10B981), const Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_isEngineActive ? const Color(0xFFE11D48) : const Color(0xFF10B981)).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEngineActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEngineActive ? "Stop Telematics Engine" : "Activate Crash Telematics",
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Manual Emergency SOS Button
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 170),
                  child: InteractivePressable(
                    onTap: _triggerManualSos,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emergency_share, color: Color(0xFFEF4444), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'manual_sos'.tr,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Simulation Vectors Card
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      const SectionHeader(
                        title: "Simulate Crash Vectors",
                        subtitle: "Trigger test crash events with full emergency pipeline",
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "Frontal",
                              type: "High Severity Frontal Collision",
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "Lateral",
                              type: "High Severity Side Impact (Lateral)",
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "Rollover",
                              type: "High Severity Rollover Force",
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Audit Logs Console
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 260),
                  child: Column(
                    children: [
                      const SectionHeader(
                        title: "Event Audit Logs",
                        subtitle: "Real-time timestamped event stream",
                      ),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF26334D)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          itemCount: _auditLogs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3.0),
                              child: Text(
                                _auditLogs[index],
                                style: const TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 11.5,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrashTestButton({
    required String label,
    required String type,
    required Color color,
  }) {
    return InteractivePressable(
      onTap: () => _simulateSpecificCrash(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
