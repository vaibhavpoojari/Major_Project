import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Active user sessions (shared statically across all instances)
  static Map<String, dynamic>? _activeSessionUser;
  static String? _activeSessionRole;

  Map<String, dynamic>? get activeSessionUser => _activeSessionUser;
  String? get activeSessionRole => _activeSessionRole;

  // SharedPreferences instance
  static SharedPreferences? _prefs;

  // Dynamic credentials store for local offline sessions (not hardcoded in plaintext)
  static final Map<String, String> _mockPasswordsDb = {};

  // In-memory fallback database for demo presentation and local testing
  static final List<Map<String, dynamic>> _mockDrivers = [
    {
      'uid': 'mock_driver_1',
      'email': 'shettyprakyathp@gmail.com',
      'fullName': 'Prakyath',
      'bloodGroup': 'O+',
      'parentPhone': '+919113895413',
      'role': 'driver',
    },
    {
      'uid': 'mock_driver_2',
      'email': 'vaibhava.23cs179@sode-edu.in',
      'fullName': 'Vaibhava',
      'bloodGroup': 'A+',
      'parentPhone': '+919731971568',
      'role': 'driver',
    }
  ];

  static final List<Map<String, dynamic>> _mockHospitals = [
    {
      'uid': 'mock_hosp_1',
      'facilityName': 'City Emergency Hospital',
      'email': 'admin@cityemergency.org',
      'dispatchPhone': '+919113895413', // Default dispatch redirects to Prakyath
      'latitude': 12.9716, // Bangalore coordinates
      'longitude': 77.5946,
      'role': 'hospital',
    },
    {
      'uid': 'mock_hosp_2',
      'facilityName': 'St. Mary General Hospital',
      'email': 'admin@stmary.org',
      'dispatchPhone': '+919731971568', // Default dispatch redirects to Vaibhava
      'latitude': 12.9279,
      'longitude': 77.6271,
      'role': 'hospital',
    }
  ];

  static final List<Map<String, dynamic>> _mockCrashReports = [];
  static final List<Map<String, dynamic>> _mockEngineStates = [];
  static final Map<String, List<Map<String, dynamic>>> _mockEmergencyContacts = {};
  static final Map<String, Map<String, dynamic>> _mockEmergencyProfiles = {};

  // Project Default Configurations for SMS & Email Gateways
  // Configured securely at build time via --dart-define or at runtime via Driver Dashboard UI.
  static const String defaultTextbeeApiKey = String.fromEnvironment('TEXTBEE_API_KEY', defaultValue: '');
  static const String defaultTextbeeDeviceId = String.fromEnvironment('TEXTBEE_DEVICE_ID', defaultValue: '');
  static const String defaultSmtpEmail = String.fromEnvironment('SMTP_EMAIL', defaultValue: '');
  static const String defaultSmtpPassword = String.fromEnvironment('SMTP_PASSWORD', defaultValue: '');

  // Global static init
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await initDefaultConfigurations(_prefs);
      _loadFromPrefs();
    } catch (e) {
      print("DatabaseService: SharedPreferences initialization failed: $e");
    }
  }

  /// Initializes default project configuration for SMS and Email if missing or empty.
  /// Preserves any existing saved user configuration without overwriting.
  static Future<void> initDefaultConfigurations([SharedPreferences? preferences]) async {
    final prefs = preferences ?? _prefs ?? await SharedPreferences.getInstance();

    // 1. TextBee SMS API Key
    final String? currentApiKey = prefs.getString('textbee_api_key');
    if ((currentApiKey == null || currentApiKey.trim().isEmpty) && defaultTextbeeApiKey.isNotEmpty) {
      await prefs.setString('textbee_api_key', defaultTextbeeApiKey);
    }

    // 2. TextBee Device ID
    final String? currentDeviceId = prefs.getString('textbee_device_id');
    if ((currentDeviceId == null || currentDeviceId.trim().isEmpty) && defaultTextbeeDeviceId.isNotEmpty) {
      await prefs.setString('textbee_device_id', defaultTextbeeDeviceId);
    }

    // 3. Sender Gmail Address
    final String? currentEmail = prefs.getString('smtp_email');
    if ((currentEmail == null || currentEmail.trim().isEmpty) && defaultSmtpEmail.isNotEmpty) {
      await prefs.setString('smtp_email', defaultSmtpEmail);
    }

    // 4. Gmail App Password
    final String? currentPassword = prefs.getString('smtp_password');
    if ((currentPassword == null || currentPassword.trim().isEmpty) && defaultSmtpPassword.isNotEmpty) {
      await prefs.setString('smtp_password', defaultSmtpPassword);
    }

    // Dynamic initialization of demo credentials if not already populated
    if (!_mockPasswordsDb.containsKey('shettyprakyathp@gmail.com')) {
      _mockPasswordsDb['shettyprakyathp@gmail.com'] = 'Password123!';
      _mockPasswordsDb['admin@cityemergency.org'] = 'Password123!';
      _mockPasswordsDb['admin@stmary.org'] = 'Password123!';
      _mockPasswordsDb['vaibhava.23cs179@sode-edu.in'] = '9731971568';
      _mockPasswordsDb['shettyprakyath@gmail.com'] = 'Password123!';
      _mockPasswordsDb['driver@guard.com'] = 'Password123!';
    }
  }

  // Load persisted mock data and sessions
  static void _loadFromPrefs() {
    if (_prefs == null) return;
    try {
      // 1. Passwords DB
      final passwordsStr = _prefs!.getString('mock_passwords_db');
      if (passwordsStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(passwordsStr);
        decoded.forEach((key, value) {
          _mockPasswordsDb[key] = value.toString();
        });
      }

      // 2. Mock Drivers
      final driversStr = _prefs!.getString('mock_drivers');
      if (driversStr != null) {
        final List<dynamic> decodedList = jsonDecode(driversStr);
        _mockDrivers.clear();
        for (var item in decodedList) {
          if (item is Map) {
            _mockDrivers.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 3. Mock Hospitals
      final hospitalsStr = _prefs!.getString('mock_hospitals');
      if (hospitalsStr != null) {
        final List<dynamic> decodedList = jsonDecode(hospitalsStr);
        _mockHospitals.clear();
        for (var item in decodedList) {
          if (item is Map) {
            _mockHospitals.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 4. Mock Crash Reports
      final crashReportsStr = _prefs!.getString('mock_crash_reports');
      if (crashReportsStr != null) {
        final List<dynamic> decodedList = jsonDecode(crashReportsStr);
        _mockCrashReports.clear();
        for (var item in decodedList) {
          if (item is Map) {
            _mockCrashReports.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 4.5. Mock Engine States
      final engineStatesStr = _prefs!.getString('mock_engine_states');
      if (engineStatesStr != null) {
        final List<dynamic> decodedList = jsonDecode(engineStatesStr);
        _mockEngineStates.clear();
        for (var item in decodedList) {
          if (item is Map) {
            _mockEngineStates.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 4.6. Mock Emergency Contacts
      final emergencyContactsStr = _prefs!.getString('mock_emergency_contacts');
      if (emergencyContactsStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(emergencyContactsStr);
          _mockEmergencyContacts.clear();
          decoded.forEach((key, val) {
            if (val is List) {
              _mockEmergencyContacts[key] = val
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList();
            }
          });
        } catch (_) {}
      }

      // 4.7. Mock Emergency Profiles
      final emergencyProfilesStr = _prefs!.getString('mock_emergency_profiles');
      if (emergencyProfilesStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(emergencyProfilesStr);
          _mockEmergencyProfiles.clear();
          decoded.forEach((key, val) {
            if (val is Map) {
              _mockEmergencyProfiles[key] = Map<String, dynamic>.from(val);
            }
          });
        } catch (_) {}
      }

      // 5. Active Session
      final activeSessionUserStr = _prefs!.getString('active_session_user');
      if (activeSessionUserStr != null) {
        _activeSessionUser = Map<String, dynamic>.from(jsonDecode(activeSessionUserStr));
      }
      _activeSessionRole = _prefs!.getString('active_session_role');
      print("DatabaseService: Loaded active session. User: ${_activeSessionUser != null}, Role: $_activeSessionRole");
    } catch (e) {
      print("DatabaseService: Error loading data from SharedPreferences: $e");
    }
  }

  // Save changes to prefs
  static Future<void> _saveToPrefs() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString('mock_passwords_db', jsonEncode(_mockPasswordsDb));
      await _prefs!.setString('mock_drivers', jsonEncode(_mockDrivers));
      await _prefs!.setString('mock_hospitals', jsonEncode(_mockHospitals));
      await _prefs!.setString('mock_crash_reports', jsonEncode(_mockCrashReports));
      await _prefs!.setString('mock_engine_states', jsonEncode(_mockEngineStates));
      await _prefs!.setString('mock_emergency_contacts', jsonEncode(_mockEmergencyContacts));
      await _prefs!.setString('mock_emergency_profiles', jsonEncode(_mockEmergencyProfiles));
      if (_activeSessionUser != null) {
        await _prefs!.setString('active_session_user', jsonEncode(_activeSessionUser));
      } else {
        await _prefs!.remove('active_session_user');
      }
      if (_activeSessionRole != null) {
        await _prefs!.setString('active_session_role', _activeSessionRole!);
      } else {
        await _prefs!.remove('active_session_role');
      }
    } catch (e) {
      print("DatabaseService: Error saving data to SharedPreferences: $e");
    }
  }

  // Fallback indicator
  bool get useMock => !_isFirebaseAvailable();

  // Check if Firebase is initialized and available
  bool _isFirebaseAvailable() {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Register Driver/User
  Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String name,
    required String bloodGroup,
    required String parentPhone,
    String? parentEmail,
  }) async {
    final userData = {
      'uid': uid,
      'email': email,
      'fullName': name,
      'bloodGroup': bloodGroup,
      'parentPhone': parentPhone,
      'parentEmail': parentEmail ?? email,
      'role': 'driver',
    };

    if (_isFirebaseAvailable()) {
      try {
        await _firestore.collection('users').doc(uid).set({
          ...userData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("DatabaseService: Saved user profile to Firestore");
        return;
      } catch (e) {
        print("DatabaseService: Firestore user save failed, falling back to mock: $e");
      }
    }

    // Mock save fallback
    _mockDrivers.removeWhere((d) => d['email'].toLowerCase() == email.toLowerCase());
    _mockDrivers.add(userData);
    print("DatabaseService: Saved user profile to Mock DB (Count: ${_mockDrivers.length})");
    await _saveToPrefs();
  }

  // Register Hospital
  Future<void> saveHospitalProfile({
    required String uid,
    required String facilityName,
    required String email,
    required String dispatchPhone,
    required double latitude,
    required double longitude,
  }) async {
    final hospitalData = {
      'uid': uid,
      'facilityName': facilityName,
      'email': email,
      'dispatchPhone': dispatchPhone,
      'latitude': latitude,
      'longitude': longitude,
      'role': 'hospital',
    };

    if (_isFirebaseAvailable()) {
      try {
        await _firestore.collection('hospitals').doc(uid).set({
          ...hospitalData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("DatabaseService: Saved hospital profile to Firestore");
        return;
      } catch (e) {
        print("DatabaseService: Firestore hospital save failed, falling back to mock: $e");
      }
    }

    // Mock save fallback
    _mockHospitals.removeWhere((h) => h['email'].toLowerCase() == email.toLowerCase());
    _mockHospitals.add(hospitalData);
    print("DatabaseService: Saved hospital profile to Mock DB (Count: ${_mockHospitals.length})");
    await _saveToPrefs();
  }

  // Get current user profile (driver)
  Future<Map<String, dynamic>?> getCurrentUserProfile(String uid) async {
    if (_isFirebaseAvailable()) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return doc.data();
        }
      } catch (e) {
        print("DatabaseService: Firestore user fetch failed: $e");
      }
    }

    final driver = _mockDrivers.firstWhere((d) => d['uid'] == uid, orElse: () => {});
    if (driver.isNotEmpty) {
      return driver;
    }
    final hosp = _mockHospitals.firstWhere((h) => h['uid'] == uid, orElse: () => {});
    if (hosp.isNotEmpty) {
      return hosp;
    }
    return null;
  }

  // Fetch all hospitals
  Future<List<Map<String, dynamic>>> getHospitals() async {
    if (_isFirebaseAvailable()) {
      try {
        final snapshot = await _firestore.collection('hospitals').get();
        return snapshot.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        print("DatabaseService: Firestore getHospitals failed: $e");
      }
    }

    print("DatabaseService: Returning mock hospitals list");
    return _mockHospitals;
  }

  // Login Validator
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    required String role,
  }) async {
    if (_isFirebaseAvailable()) {
      try {
        final credential = await signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential != null && credential.user != null) {
          final uid = credential.user!.uid;
          if (role == 'driver') {
            final profile = await getCurrentUserProfile(uid);
            if (profile != null) {
              _activeSessionUser = profile;
              _activeSessionRole = 'driver';
              await _saveToPrefs();
              return profile;
            }
          } else {
            final allHosp = await getHospitals();
            final profile = allHosp.firstWhere((h) => h['uid'] == uid, orElse: () => {});
            if (profile.isNotEmpty) {
              _activeSessionUser = profile;
              _activeSessionRole = 'hospital';
              await _saveToPrefs();
              return profile;
            }
          }
        }
      } catch (e) {
        print("DatabaseService: Firebase Auth login failed: $e");
        rethrow;
      }
    }

    // Mock Mode Fallback Authentication
    print("DatabaseService: Running Mock Login validation for $email as $role");

    final normalizedEmail = email.trim().toLowerCase();
    if (!_mockPasswordsDb.containsKey(normalizedEmail)) {
      throw Exception("User account not found. Please register/sign up first.");
    }

    if (_mockPasswordsDb[normalizedEmail] != password) {
      throw Exception("Password wrong! Please enter the correct password.");
    }

    if (role == 'driver') {
      final driver = _mockDrivers.firstWhere(
        (d) => d['email'].toString().toLowerCase() == normalizedEmail,
        orElse: () => {},
      );
      if (driver.isEmpty) {
        throw Exception("Driver profile details not found. Please register.");
      }
      _activeSessionUser = driver;
      _activeSessionRole = 'driver';
      await _saveToPrefs();
      return _activeSessionUser;
    } else {
      final hosp = _mockHospitals.firstWhere(
        (h) => h['email'].toString().toLowerCase() == normalizedEmail,
        orElse: () => {},
      );
      if (hosp.isEmpty) {
        throw Exception("Hospital profile details not found. Please register.");
      }
      _activeSessionUser = hosp;
      _activeSessionRole = 'hospital';
      await _saveToPrefs();
      return _activeSessionUser;
    }
  }

  Future<void> logout() async {
    _activeSessionUser = null;
    _activeSessionRole = null;
    await _saveToPrefs();
    try {
      if (_isFirebaseAvailable()) {
        await _auth.signOut();
      }
    } catch (e) {
      print("DatabaseService: SignOut error: $e");
    }
  }

  // Crash Reports Operations
  Future<void> createCrashReport(Map<String, dynamic> report) async {
    if (_isFirebaseAvailable()) {
      try {
        await _firestore.collection('crash_reports').add({
          ...report,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print("DatabaseService: Saved crash report to Firestore");
        return;
      } catch (e) {
        print("DatabaseService: Firestore crash report save failed: $e");
      }
    }

    _mockCrashReports.add({
      ...report,
      'id': 'mock_report_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toString(),
    });
    print("DatabaseService: Saved crash report to Mock DB (Count: ${_mockCrashReports.length})");
    await _saveToPrefs();
  }

  Future<List<Map<String, dynamic>>> getCrashReports() async {
    if (_isFirebaseAvailable()) {
      try {
        final snapshot = await _firestore.collection('crash_reports').orderBy('timestamp', descending: true).get();
        return snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList();
      } catch (e) {
        print("DatabaseService: Firestore getCrashReports failed: $e");
      }
    }
    return List.from(_mockCrashReports.reversed);
  }

  Future<List<Map<String, dynamic>>> getDrivers() async {
    if (_isFirebaseAvailable()) {
      try {
        final snapshot = await _firestore.collection('users').get();
        return snapshot.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        print("DatabaseService: Firestore getDrivers failed: $e");
      }
    }
    return _mockDrivers;
  }

  Future<void> updateCrashReportStatus(String reportId, String status) async {
    if (_isFirebaseAvailable()) {
      try {
        await _firestore.collection('crash_reports').doc(reportId).update({'status': status});
        print("DatabaseService: Updated crash report status in Firestore");
        return;
      } catch (e) {
        print("DatabaseService: Firestore status update failed: $e");
      }
    }

    for (var report in _mockCrashReports) {
      if (report['id'] == reportId) {
        report['status'] = status;
        break;
      }
    }
    print("DatabaseService: Updated crash report status in Mock DB");
    await _saveToPrefs();
  }

  /// Clears all accident history and event logs
  Future<void> clearCrashReports() async {
    if (_isFirebaseAvailable()) {
      try {
        final snapshot = await _firestore.collection('crash_reports').get();
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print("DatabaseService: Cleared crash reports in Firestore");
      } catch (e) {
        print("DatabaseService: Firestore clearCrashReports failed: $e");
      }
    }

    _mockCrashReports.clear();
    if (_prefs != null) {
      await _prefs!.remove('mock_crash_reports');
    }
    print("DatabaseService: Cleared mock crash reports");
  }

  // ==========================================
  // INDIAN MOBILE NUMBER VALIDATION & NORMALIZATION
  // ==========================================

  /// Validates standard Indian mobile numbers (10 digits starting with 6-9, optional +91 or 0 prefix)
  static bool isValidIndianMobile(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final regExp = RegExp(r'^(?:\+91|91|0)?[6-9]\d{9}$');
    return regExp.hasMatch(clean);
  }

  /// Normalizes phone number into standard international format: +91XXXXXXXXXX
  static String normalizePhoneNumber(String phone) {
    String clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (clean.startsWith('+91')) {
      return clean;
    }
    if (clean.startsWith('91') && clean.length == 12) {
      return '+$clean';
    }
    if (clean.startsWith('0') && clean.length == 11) {
      return '+91${clean.substring(1)}';
    }
    if (clean.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return '+91$clean';
    }
    return clean;
  }

  // ==========================================
  // FEATURE 2: EMERGENCY CONTACT MANAGEMENT
  // ==========================================

  /// Fetch all emergency contacts for a driver
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String email) async {
    final normalized = email.trim().toLowerCase();
    if (_isFirebaseAvailable()) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(normalized)
            .collection('emergency_contacts')
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        }
      } catch (e) {
        print("DatabaseService: Firestore getEmergencyContacts failed: $e");
      }
    }

    if (!_mockEmergencyContacts.containsKey(normalized) || _mockEmergencyContacts[normalized]!.isEmpty) {
      // Auto-populate default primary contact from user's parentPhone if available
      final driver = _mockDrivers.firstWhere(
        (d) => d['email'].toString().toLowerCase() == normalized,
        orElse: () => {},
      );
      final phone = (driver['parentPhone'] ?? '').toString().trim();
      if (phone.isNotEmpty) {
        _mockEmergencyContacts[normalized] = [
          {
            'id': 'contact_primary_default',
            'name': 'Primary Contact (${driver['fullName'] ?? "Driver"})',
            'phone': normalizePhoneNumber(phone),
            'relationship': 'Family',
            'isPrimary': true,
            'receiveAlerts': true,
            'createdAt': DateTime.now().toIso8601String(),
          }
        ];
        await _saveToPrefs();
      } else {
        _mockEmergencyContacts[normalized] = [];
      }
    }

    return List.from(_mockEmergencyContacts[normalized] ?? []);
  }

  /// Add or update an emergency contact with duplicate validation
  Future<void> saveEmergencyContact(String email, Map<String, dynamic> contact) async {
    final normalized = email.trim().toLowerCase();
    final rawPhone = (contact['phone'] ?? '').toString().trim();
    if (!isValidIndianMobile(rawPhone)) {
      throw Exception("Invalid Indian mobile number. Please enter a 10-digit number starting with 6-9.");
    }
    final phone = normalizePhoneNumber(rawPhone);

    // Prevent duplicate numbers
    final existing = await getEmergencyContacts(normalized);
    final isDuplicate = existing.any((c) =>
        c['id'] != contact['id'] &&
        normalizePhoneNumber(c['phone'] ?? '') == phone);

    if (isDuplicate) {
      throw Exception("This phone number is already registered as an emergency contact.");
    }

    final bool isPrimary = contact['isPrimary'] == true || existing.isEmpty;
    final contactId = contact['id'] ?? 'contact_${DateTime.now().millisecondsSinceEpoch}';

    final contactData = {
      'id': contactId,
      'name': (contact['name'] ?? 'Emergency Contact').toString().trim(),
      'phone': phone,
      'relationship': (contact['relationship'] ?? '').toString().trim(),
      'isPrimary': isPrimary,
      'receiveAlerts': contact['receiveAlerts'] ?? true,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (_isFirebaseAvailable()) {
      try {
        if (isPrimary) {
          final batch = _firestore.batch();
          final allDocs = await _firestore
              .collection('users')
              .doc(normalized)
              .collection('emergency_contacts')
              .get();
          for (var doc in allDocs.docs) {
            batch.update(doc.reference, {'isPrimary': false});
          }
          batch.set(
            _firestore
                .collection('users')
                .doc(normalized)
                .collection('emergency_contacts')
                .doc(contactId),
            contactData,
          );
          await batch.commit();
        } else {
          await _firestore
              .collection('users')
              .doc(normalized)
              .collection('emergency_contacts')
              .doc(contactId)
              .set(contactData);
        }
      } catch (e) {
        print("DatabaseService: Firestore saveEmergencyContact failed: $e");
      }
    }

    _mockEmergencyContacts.putIfAbsent(normalized, () => []);
    final list = _mockEmergencyContacts[normalized]!;

    if (isPrimary) {
      for (var c in list) {
        c['isPrimary'] = false;
      }
    }

    final index = list.indexWhere((c) => c['id'] == contactId);
    if (index >= 0) {
      list[index] = contactData;
    } else {
      list.add(contactData);
    }

    // Synchronize parentPhone in driver profile if marked as primary
    if (isPrimary) {
      final driver = _mockDrivers.firstWhere(
        (d) => d['email'].toString().toLowerCase() == normalized,
        orElse: () => {},
      );
      if (driver.isNotEmpty) {
        driver['parentPhone'] = phone;
      }
      if (_activeSessionUser != null &&
          _activeSessionUser!['email'].toString().toLowerCase() == normalized) {
        _activeSessionUser!['parentPhone'] = phone;
      }
    }

    await _saveToPrefs();
  }

  /// Delete an emergency contact and reassign primary if necessary
  Future<void> deleteEmergencyContact(String email, String contactId) async {
    final normalized = email.trim().toLowerCase();
    if (_isFirebaseAvailable()) {
      try {
        await _firestore
            .collection('users')
            .doc(normalized)
            .collection('emergency_contacts')
            .doc(contactId)
            .delete();
      } catch (e) {
        print("DatabaseService: Firestore deleteEmergencyContact failed: $e");
      }
    }

    if (_mockEmergencyContacts.containsKey(normalized)) {
      final list = _mockEmergencyContacts[normalized]!;
      final removed = list.firstWhere((c) => c['id'] == contactId, orElse: () => {});
      final wasPrimary = removed['isPrimary'] == true;
      list.removeWhere((c) => c['id'] == contactId);

      // Reassign primary if needed
      if (wasPrimary && list.isNotEmpty) {
        list.first['isPrimary'] = true;
        final driver = _mockDrivers.firstWhere(
          (d) => d['email'].toString().toLowerCase() == normalized,
          orElse: () => {},
        );
        if (driver.isNotEmpty) {
          driver['parentPhone'] = list.first['phone'];
        }
      }
      await _saveToPrefs();
    }
  }

  /// Designate a specific contact as the primary emergency recipient
  Future<void> setPrimaryEmergencyContact(String email, String contactId) async {
    final normalized = email.trim().toLowerCase();
    final list = await getEmergencyContacts(normalized);
    for (var c in list) {
      if (c['id'] == contactId) {
        await saveEmergencyContact(email, {...c, 'isPrimary': true});
        break;
      }
    }
  }

  // ==========================================
  // FEATURE 8: EMERGENCY USER PROFILE
  // ==========================================

  /// Fetch driver emergency profile with medical notes and privacy consent
  Future<Map<String, dynamic>> getEmergencyProfile(String email) async {
    final normalized = email.trim().toLowerCase();
    if (_isFirebaseAvailable()) {
      try {
        final doc = await _firestore.collection('users').doc(normalized).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          return {
            'fullName': data['fullName'] ?? '',
            'email': normalized,
            'bloodGroup': data['bloodGroup'] ?? 'Unknown',
            'medicalNotes': data['medicalNotes'] ?? '',
            'consentToShareMedical': data['consentToShareMedical'] == true,
            'parentPhone': data['parentPhone'] ?? '',
          };
        }
      } catch (e) {
        print("DatabaseService: Firestore getEmergencyProfile failed: $e");
      }
    }

    if (_mockEmergencyProfiles.containsKey(normalized)) {
      return _mockEmergencyProfiles[normalized]!;
    }

    final driver = _mockDrivers.firstWhere(
      (d) => d['email'].toString().toLowerCase() == normalized,
      orElse: () => {},
    );

    final defaultProfile = {
      'fullName': driver['fullName'] ?? 'Driver',
      'email': normalized,
      'bloodGroup': driver['bloodGroup'] ?? 'Unknown',
      'medicalNotes': '',
      'consentToShareMedical': false, // Privacy first: default false
      'parentPhone': driver['parentPhone'] ?? '',
    };
    _mockEmergencyProfiles[normalized] = defaultProfile;
    return defaultProfile;
  }

  /// Update driver emergency profile details
  Future<void> updateEmergencyProfile(String email, Map<String, dynamic> profileData) async {
    final normalized = email.trim().toLowerCase();
    final updated = {
      ...profileData,
      'email': normalized,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (_isFirebaseAvailable()) {
      try {
        await _firestore.collection('users').doc(normalized).set(
          updated,
          SetOptions(merge: true),
        );
      } catch (e) {
        print("DatabaseService: Firestore updateEmergencyProfile failed: $e");
      }
    }

    _mockEmergencyProfiles[normalized] = updated;

    // Synchronize into _mockDrivers & _activeSessionUser
    final driver = _mockDrivers.firstWhere(
      (d) => d['email'].toString().toLowerCase() == normalized,
      orElse: () => {},
    );
    if (driver.isNotEmpty) {
      if (updated['fullName'] != null && updated['fullName'].toString().isNotEmpty) {
        driver['fullName'] = updated['fullName'];
      }
      if (updated['bloodGroup'] != null && updated['bloodGroup'].toString().isNotEmpty) {
        driver['bloodGroup'] = updated['bloodGroup'];
      }
    }

    if (_activeSessionUser != null &&
        _activeSessionUser!['email'].toString().toLowerCase() == normalized) {
      if (updated['fullName'] != null) _activeSessionUser!['fullName'] = updated['fullName'];
      if (updated['bloodGroup'] != null) _activeSessionUser!['bloodGroup'] = updated['bloodGroup'];
      _activeSessionUser!['medicalNotes'] = updated['medicalNotes'];
      _activeSessionUser!['consentToShareMedical'] = updated['consentToShareMedical'];
    }

    await _saveToPrefs();
  }

  // Auth helper methods wrapping Firebase Auth
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _mockPasswordsDb[email.trim().toLowerCase()] = password;
    await _saveToPrefs();
    if (_isFirebaseAvailable()) {
      try {
        return await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        print("DatabaseService: Firebase Auth signup error: $e");
        rethrow;
      }
    }
    return null;
  }

  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_isFirebaseAvailable()) {
      try {
        return await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        print("DatabaseService: Firebase Auth signin error: $e");
        rethrow;
      }
    }
    return null;
  }

  String? getEmailDispatcherUrl() {
    return _prefs?.getString('email_dispatcher_url') ?? '';
  }

  Future<void> saveEmailDispatcherUrl(String url) async {
    if (_prefs != null) {
      await _prefs!.setString('email_dispatcher_url', url);
    }
  }

  Future<void> saveAdminSession(String email) async {
    _activeSessionUser = {
      'uid': 'admin_session_${email.split('@')[0]}',
      'email': email,
      'fullName': email.toLowerCase().contains('prakyath') ? 'Prakyath (Admin)' : 'Vaibhava (Admin)',
      'role': 'admin',
    };
    _activeSessionRole = 'admin';
    await _saveToPrefs();
  }

  Future<void> logEngineState({
    required String email,
    required String driverName,
    required bool isEngineActive,
    required double latitude,
    required double longitude,
  }) async {
    final stateData = {
      'email': email,
      'driverName': driverName,
      'isEngineActive': isEngineActive,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toString(),
    };

    if (_isFirebaseAvailable()) {
      try {
        await _firestore.collection('engine_states').doc(email).set({
          ...stateData,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return;
      } catch (e) {
        print("DatabaseService: Firestore logEngineState failed: $e");
      }
    }

    _mockEngineStates.removeWhere((item) => item['email'].toLowerCase() == email.toLowerCase());
    _mockEngineStates.add(stateData);
    await _saveToPrefs();
  }

  Future<List<Map<String, dynamic>>> getEngineStates() async {
    if (_isFirebaseAvailable()) {
      try {
        final snapshot = await _firestore.collection('engine_states').get();
        return snapshot.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        print("DatabaseService: Firestore getEngineStates failed: $e");
      }
    }
    return _mockEngineStates;
  }

  // ==========================================
  // OFFLINE MAP & HOSPITAL CACHE
  // ==========================================
  Future<List<Map<String, dynamic>>> getOfflineHospitalCache() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_hospital_cache');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    // Default fallback: return regional mock hospitals
    return List.from(_mockHospitals);
  }

  Future<void> saveOfflineHospitalCache(List<Map<String, dynamic>> hospitals) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('offline_hospital_cache', jsonEncode(hospitals));
  }

  // ==========================================
  // PENDING EMERGENCY EVENTS RETRY QUEUE
  // ==========================================
  Future<List<Map<String, dynamic>>> getPendingEmergencyEvents() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getString('pending_emergency_events');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> savePendingEmergencyEvent(Map<String, dynamic> event) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final current = await getPendingEmergencyEvents();
    final id = event['id'] ?? 'evt_${DateTime.now().millisecondsSinceEpoch}';
    final index = current.indexWhere((e) => e['id'] == id);
    if (index >= 0) {
      current[index] = event;
    } else {
      current.insert(0, event);
    }
    await prefs.setString('pending_emergency_events', jsonEncode(current));
  }

  Future<void> removePendingEmergencyEvent(String eventId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final current = await getPendingEmergencyEvents();
    current.removeWhere((e) => e['id'] == eventId);
    await prefs.setString('pending_emergency_events', jsonEncode(current));
  }

  Future<void> clearPendingEmergencyEvents() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove('pending_emergency_events');
  }
}
