import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart';
import '../services/alert_service.dart';
import '../services/buzzer_service.dart';
import '../services/permission_service.dart';
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
  double _currentX = 0.0;
  double _currentY = 0.0;
  double _currentZ = 0.0;
  double _maxForceObserved = 0.0;
  bool _isEngineActive = false;

  // Real-time vector buffer for graphical waveform
  final List<SensorVectorReading> _vectorBuffer = [];
  static const int _maxBufferSize = 50;

  // Emergency state control
  bool _isEmergencyState = false;
  int _countdownSeconds = 30;
  Timer? _countdownTimer;
  String _crashType = "High Acceleration Vector Impact";

  // Animation controller for emergency alert pulse
  late AnimationController _emergencyPulseController;
  late Animation<double> _pulseScaleAnimation;

  // Audit Logs
  final List<String> _auditLogs = [];

  // Activity Test Recorder & Benchmarks
  static const List<Map<String, String>> _benchmarkScenarios = [
    {
      'key': 'walking',
      'title': 'Walking',
      'subtitle': 'Normal pedestrian gait',
      'expected': '1.5 – 4.5 m/s²',
    },
    {
      'key': 'safe_drop',
      'title': 'Safe Phone-Drop',
      'subtitle': 'Drop onto cushion / bed',
      'expected': '15 – 28 m/s²',
    },
    {
      'key': 'braking',
      'title': 'Simulated Braking',
      'subtitle': 'Rapid vehicle stop motion',
      'expected': '8 – 18 m/s²',
    },
    {
      'key': 'pothole',
      'title': 'Simulated Pothole',
      'subtitle': 'Sharp vertical jolt / bump',
      'expected': '12 – 24 m/s²',
    },
    {
      'key': 'controlled_impact',
      'title': 'Controlled Impact',
      'subtitle': 'Threshold trigger test (≥35 m/s²)',
      'expected': '≥ 35.0 m/s²',
    },
  ];

  Map<String, Map<String, dynamic>> _benchmarkRecords = {};
  String _selectedBenchmarkKey = 'walking';
  bool _isRecordingBenchmark = false;
  int _benchmarkTimerSeconds = 0;
  Timer? _benchmarkTimer;
  double _recordingPeakForce = 0.0;
  double _recordingPeakX = 0.0;
  double _recordingPeakY = 0.0;
  double _recordingPeakZ = 0.0;

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
    _loadBenchmarks();
    widget.alertService.requestSmsPermission();
    _addLog("Telematics initialized. Select driver profile to start monitoring.");
  }

  void _addLog(String msg) {
    if (mounted) {
      setState(() {
        _auditLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $msg");
      });
    }
  }

  Future<void> _loadBenchmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('sensor_activity_benchmarks');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _benchmarkRecords = decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveBenchmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sensor_activity_benchmarks', jsonEncode(_benchmarkRecords));
    } catch (_) {}
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
        _currentX = 0.0;
        _currentY = 0.0;
        _currentZ = 0.0;
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
      _addLog("Telematics engine active: continuous 3-axis accelerometer vector stream running.");

      _sensorService.startListening(
        onVectorUpdate: (x, y, z, magnitude) {
          if (mounted) {
            setState(() {
              _currentX = x;
              _currentY = y;
              _currentZ = z;
              _currentForce = magnitude;
              if (magnitude > _maxForceObserved) {
                _maxForceObserved = magnitude;
              }

              // Update circular vector buffer for real-time waveform graph
              final reading = SensorVectorReading(
                x: x,
                y: y,
                z: z,
                magnitude: magnitude,
                timestamp: DateTime.now(),
              );
              _vectorBuffer.add(reading);
              if (_vectorBuffer.length > _maxBufferSize) {
                _vectorBuffer.removeAt(0);
              }

              // Accumulate in active benchmark recording window if running
              if (_isRecordingBenchmark) {
                if (magnitude > _recordingPeakForce) {
                  _recordingPeakForce = magnitude;
                  _recordingPeakX = x;
                  _recordingPeakY = y;
                  _recordingPeakZ = z;
                }
              }
            });
          }
        },
        onCrashDetected: (magnitude, crashType) {
          _triggerEmergencyState(magnitude, crashType);
        },
      );
    }
  }

  void _startBenchmarkRecording() {
    if (!_isEngineActive) {
      _toggleSensorEngine();
    }

    final scenario = _benchmarkScenarios.firstWhere((s) => s['key'] == _selectedBenchmarkKey);
    setState(() {
      _isRecordingBenchmark = true;
      _benchmarkTimerSeconds = 3;
      _recordingPeakForce = _currentForce;
      _recordingPeakX = _currentX;
      _recordingPeakY = _currentY;
      _recordingPeakZ = _currentZ;
    });

    _addLog("RECORDING TEST: '${scenario['title']}' for 3s. Perform physical test motion now...");

    _benchmarkTimer?.cancel();
    _benchmarkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_benchmarkTimerSeconds > 1) {
        setState(() {
          _benchmarkTimerSeconds--;
        });
      } else {
        timer.cancel();
        _finalizeBenchmarkRecording();
      }
    });
  }

  void _finalizeBenchmarkRecording() {
    final scenario = _benchmarkScenarios.firstWhere((s) => s['key'] == _selectedBenchmarkKey);
    final bool isTriggered = _recordingPeakForce >= SensorService.crashThreshold;
    final nowStr = DateTime.now().toString().substring(11, 19);

    setState(() {
      _isRecordingBenchmark = false;
      _benchmarkRecords[_selectedBenchmarkKey] = {
        'activityName': scenario['title']!,
        'peakForce': _recordingPeakForce,
        'peakX': _recordingPeakX,
        'peakY': _recordingPeakY,
        'peakZ': _recordingPeakZ,
        'timestamp': nowStr,
        'isTriggered': isTriggered,
        'status': isTriggered ? 'Triggered (≥35 m/s²)' : 'Safe (Sub-threshold)',
      };
    });

    _saveBenchmarks();
    _addLog("TEST RECORDED: ${scenario['title']} | Peak: ${_recordingPeakForce.toStringAsFixed(2)} m/s² (X: ${_recordingPeakX.toStringAsFixed(1)}, Y: ${_recordingPeakY.toStringAsFixed(1)}, Z: ${_recordingPeakZ.toStringAsFixed(1)}) | Result: ${isTriggered ? 'Threshold Crossed' : 'Safe'}");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Recorded '${scenario['title']}': Peak ${_recordingPeakForce.toStringAsFixed(2)} m/s²"),
        backgroundColor: isTriggered ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
  }

  void _clearBenchmarks() async {
    setState(() {
      _benchmarkRecords.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sensor_activity_benchmarks');
    _addLog("Benchmark history cleared. Ready for fresh on-device tests.");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Benchmark records cleared.")),
      );
    }
  }

  void _triggerEmergencyState(double magnitude, String crashType) {
    if (_isEmergencyState) return;

    _sensorService.stopListening();
    widget.alertService.preFetchLocation();

    _emergencyPulseController.repeat(reverse: true);

    setState(() {
      _isEmergencyState = true;
      _isEngineActive = false;
      _currentForce = magnitude;
      _countdownSeconds = 30;
      _crashType = crashType;
    });

    _addLog("CRITICAL: $crashType detected (${magnitude.toStringAsFixed(2)} m/s²). Sounding buzzer. 30s override timer active.");
    BuzzerService().startBuzzer();

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

  void _cancelEmergencyState() {
    _countdownTimer?.cancel();
    _emergencyPulseController.reset();
    BuzzerService().stopBuzzer();
    setState(() {
      _isEmergencyState = false;
    });
    _addLog("USER OVERRIDE: 'I AM SAFE' verified. Alert cancelled. Monitoring resumed.");
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
      );

      final List<dynamic> topHospList = results['topHospitals'] is List ? results['topHospitals'] as List : [];
      final String hospitalName = results['nearestHospital'] ?? 'Nearby hospital unavailable';
      final double? dist = results['distance'] as double?;
      final String distStr = dist != null
          ? "${dist.toStringAsFixed(2)} km"
          : (results['distanceStr'] ?? "Distance unavailable");
      final String? address = results['hospitalAddress'];
      final String hospitalPhone = results['hospitalPhone'] ?? 'Hospital found, phone number unavailable';
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
      final String hospitalSmsStatus = results['hospitalSmsStatus'] ??
          (hasHospPhone ? (hospitalSent ? 'Dispatched' : 'Failed') : 'Hospital found, phone number unavailable');

      _addLog("Parent SMS: $parentSmsStatus (${results['parentPhone']})");
      if (hasHospPhone) {
        _addLog("Hospital SMS: $hospitalSmsStatus ($hospitalPhone)");
      } else if (topHospList.isNotEmpty) {
        _addLog("Hospital SMS: Skipped (Hospital found, phone number unavailable)");
      } else {
        _addLog("Hospital SMS: $hospitalSmsStatus");
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
          hasHospPhone: hasHospPhone,
          hospitalSent: hospitalSent,
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
    required bool hasHospPhone,
    required bool hospitalSent,
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
              Expanded(
                child: Text(
                  "Emergency Broadcast Status",
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
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

                  // Factual Real-Time Dispatch Status
                  const Text(
                    "Factual Dispatch Summary:",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),

                  _buildDispatchRow(
                    "Parent SMS",
                    parentSmsStatus,
                    parentSmsStatus.contains('Delivered') || parentSmsStatus.contains('Dispatched')
                        ? BadgeStatusType.active
                        : (parentSmsStatus.contains('Accepted') ? BadgeStatusType.warning : BadgeStatusType.critical),
                  ),
                  _buildDispatchRow(
                    "Hospital SMS",
                    hospitalSmsStatus,
                    hasHospPhone && hospitalSent
                        ? BadgeStatusType.active
                        : (hasHospPhone && hospitalSmsStatus.contains('Accepted') ? BadgeStatusType.warning : BadgeStatusType.neutral),
                  ),
                  _buildDispatchRow(
                    "Email Alert",
                    emailSent ? "Dispatched" : "Skipped",
                    emailSent ? BadgeStatusType.active : BadgeStatusType.neutral,
                  ),
                  _buildDispatchRow("Cloud Incident Log", "Saved", BadgeStatusType.active),

                  if (!hasHospPhone) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Facility has no phone number in OpenStreetMap directory. Direct automated hospital SMS was skipped. In actual emergencies, dial 112 directly for ambulance dispatch.",
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFFFDE68A), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildDispatchRow(String channel, String status, BadgeStatusType badgeType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(channel, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8))),
          StatusBadge(
            label: status,
            type: badgeType,
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

  void _showComparisonDialog() {
    showDialog(
      context: context,
      builder: (_) => const EmergencySystemComparisonDialog(),
    );
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _emergencyPulseController.dispose();
    _countdownTimer?.cancel();
    _benchmarkTimer?.cancel();
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

                  const Center(
                    child: Text(
                      "ACCIDENT DETECTED",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
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

                  const Center(
                    child: Text(
                      "Automated emergency broadcast in:",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFCBD5E1)),
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text(
                            "Send Immediately (Bypass Timer)",
                            style: TextStyle(
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
                      child: const Column(
                        children: [
                          Text(
                            "I AM SAFE",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                          Text(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF38BDF8)),
            tooltip: "Compare 112 & Built-In Detection",
            onPressed: _showComparisonDialog,
          ),
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
                const SizedBox(height: 16),

                // 🌟 Android Screen-Off & Background Execution Advisory
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 50),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isEngineActive ? Icons.screen_lock_portrait_rounded : Icons.info_outline,
                          size: 20,
                          color: _isEngineActive ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Continuous Telematics Notice (Screen-On Required)",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Due to Android OS battery saving architecture, accelerometer sensors halt when the phone screen is powered off. For continuous trip protection, keep the phone display active or placed in a vehicle mount.",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  color: Color(0xFF94A3B8),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 📈 Real-Time 3-Axis (X/Y/Z) Accelerometer Waveform Graph
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 70),
                  child: RealtimeAccelerometerGraph(
                    buffer: _vectorBuffer,
                    currentX: _currentX,
                    currentY: _currentY,
                    currentZ: _currentZ,
                    currentMagnitude: _currentForce,
                    threshold: SensorService.crashThreshold,
                  ),
                ),
                const SizedBox(height: 16),

                // Live G-Force Telemetry Card with Peak Metrics
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 90),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20.0),
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
                              "COMBINED VECTOR ACCELERATION",
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
                        const SizedBox(height: 16),
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
                                    fontSize: 50,
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
                        const SizedBox(height: 14),

                        // Visual progress bar
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
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFF26334D)),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Peak Force: ${_maxForceObserved.toStringAsFixed(2)} m/s²",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                            Text(
                              "Threshold: ${SensorService.crashThreshold.toStringAsFixed(1)} m/s²",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFB7185)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start/Stop Telematics Engine Toggle
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 110),
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
                const SizedBox(height: 24),

                // 🔬 SENSOR ACTIVITY TEST RECORDER & BENCHMARKS
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 140),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF26334D)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 12,
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
                                Icon(Icons.timer_outlined, size: 20, color: Color(0xFF38BDF8)),
                                SizedBox(width: 8),
                                Text(
                                  "Sensor Activity Benchmarks",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            if (_benchmarkRecords.isNotEmpty)
                              GestureDetector(
                                onTap: _clearBenchmarks,
                                child: const Text(
                                  "Clear",
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFFFB7185), fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Select an activity and record live phone acceleration across walking, drop, braking, potholes, and controlled impacts:",
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),

                        // Activity selector chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _benchmarkScenarios.map((sc) {
                              final isSel = _selectedBenchmarkKey == sc['key'];
                              return GestureDetector(
                                onTap: _isRecordingBenchmark
                                    ? null
                                    : () {
                                        setState(() => _selectedBenchmarkKey = sc['key']!);
                                      },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF26334D),
                                    ),
                                  ),
                                  child: Text(
                                    sc['title']!,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12.5,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Record Button for Selected Activity
                        InteractivePressable(
                          onTap: _isRecordingBenchmark ? null : _startBenchmarkRecording,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isRecordingBenchmark
                                    ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                    : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isRecordingBenchmark ? Icons.hourglass_top_rounded : Icons.fiber_manual_record_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isRecordingBenchmark
                                      ? "Sampling... (${_benchmarkTimerSeconds}s) Move Phone Now"
                                      : "Record Test: ${_benchmarkScenarios.firstWhere((s) => s['key'] == _selectedBenchmarkKey)['title']}",
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Benchmark Table / List of All 5 Scenarios
                        const Text(
                          "Device Test Results:",
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),

                        ..._benchmarkScenarios.map((sc) {
                          final rec = _benchmarkRecords[sc['key']];
                          final hasData = rec != null;
                          final peakForce = hasData ? (rec['peakForce'] as num).toDouble() : null;
                          final peakX = hasData ? (rec['peakX'] as num).toDouble() : 0.0;
                          final peakY = hasData ? (rec['peakY'] as num).toDouble() : 0.0;
                          final peakZ = hasData ? (rec['peakZ'] as num).toDouble() : 0.0;
                          final status = hasData ? (rec['status'] ?? 'Safe') : 'Pending Phone Test';
                          final isTriggered = hasData ? (rec['isTriggered'] == true) : false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasData
                                    ? (isTriggered ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFF10B981).withValues(alpha: 0.4))
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sc['title']!,
                                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Expected: ${sc['expected']}",
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      if (hasData) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          "X: ${peakX.toStringAsFixed(1)} | Y: ${peakY.toStringAsFixed(1)} | Z: ${peakZ.toStringAsFixed(1)} m/s² [${rec['timestamp']}]",
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Color(0xFF38BDF8)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      hasData ? "${peakForce!.toStringAsFixed(2)} m/s²" : "—",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: hasData
                                            ? (isTriggered ? const Color(0xFFEF4444) : const Color(0xFF34D399))
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    StatusBadge(
                                      label: status,
                                      type: hasData
                                          ? (isTriggered ? BadgeStatusType.critical : BadgeStatusType.active)
                                          : BadgeStatusType.neutral,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 🎯 Primary Vector Simulation Cards (Updated X/Y/Z Terminology)
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 180),
                  child: Column(
                    children: [
                      const SectionHeader(
                        title: "Simulate Acceleration Vectors",
                        subtitle: "Trigger test crash events with multi-axis vector classification",
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "X-Axis Vector",
                              type: "High Severity Primary X-Axis Vector Impact (+X Lateral)",
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "Y-Axis Vector",
                              type: "High Severity Primary Y-Axis Vector Impact (+Y Longitudinal)",
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "Z-Axis Vector",
                              type: "High Severity Primary Z-Axis Vector Impact (+Z Normal)",
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCrashTestButton(
                              label: "Multi-Axis Peak",
                              type: "High Severity Multi-Axis Force Impact",
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ⚖️ Comparison Action Button
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 200),
                  child: InteractivePressable(
                    onTap: _showComparisonDialog,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161E2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.compare_arrows_rounded, color: Color(0xFF38BDF8), size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Emergency System Comparison",
                                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Compare Accident Guard with Built-In Phone Detection & India 112",
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Audit Logs Console
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 220),
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
