import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'database_service.dart';
import 'hospital_service.dart';
import 'offline_queue_service.dart';

class SmsDispatchResult {
  final String recipient;
  final String maskedRecipient;
  final String method; // 'TextBee', 'Native SIM', 'None'
  final String status; // 'accepted', 'dispatched', 'delivered', 'failed'
  final String statusDisplay; // 'Dispatch accepted', 'Dispatched', 'Delivered', 'Failed'
  final bool isSuccess;
  final int elapsedMs;
  final String? errorMessage;
  final bool deliveryConfirmed;
  final int retryAttempts;
  final List<Map<String, dynamic>> attemptLogs;

  SmsDispatchResult({
    required this.recipient,
    required this.maskedRecipient,
    required this.method,
    required this.status,
    required this.statusDisplay,
    required this.isSuccess,
    required this.elapsedMs,
    this.errorMessage,
    this.deliveryConfirmed = false,
    this.retryAttempts = 0,
    this.attemptLogs = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'recipient': recipient,
      'maskedRecipient': maskedRecipient,
      'method': method,
      'status': status,
      'statusDisplay': statusDisplay,
      'isSuccess': isSuccess,
      'elapsedMs': elapsedMs,
      'errorMessage': errorMessage,
      'deliveryConfirmed': deliveryConfirmed,
      'retryAttempts': retryAttempts,
      'attemptLogs': attemptLogs,
    };
  }
}

class AlertService {
  final DatabaseService _dbService = DatabaseService();
  static const platform = MethodChannel(
    'com.example.accident_guard_system/sms',
  );

  Position? _cachedPosition;
  static bool _isBroadcasting = false;
  static DateTime? _lastBroadcastTime;

  bool get isBroadcasting => _isBroadcasting;
  static DateTime? get lastBroadcastTime => _lastBroadcastTime;

  /// Manual SOS Activation without waiting for crash force threshold
  Future<Map<String, dynamic>> sendManualSos({
    required Map<String, dynamic> userProfile,
    double? overrideLatitude,
    double? overrideLongitude,
  }) async {
    return sendEmergencyAlerts(
      userProfile: userProfile,
      crashType: 'Manual Emergency SOS Triggered',
      overrideLatitude: overrideLatitude,
      overrideLongitude: overrideLongitude,
      maxAcceleration: 0.0,
    );
  }

  Future<void> preFetchLocation() async {
    print("AlertService: Starting background GPS pre-fetch...");
    try {
      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      print(
        "AlertService: Background GPS pre-fetched successfully: $_cachedPosition",
      );
    } catch (e) {
      print("AlertService: GPS pre-fetch failed, trying last known: $e");
      try {
        _cachedPosition = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }
  }

  Future<void> requestSmsPermission() async {
    try {
      await platform.invokeMethod('requestSmsPermission');
    } catch (e) {
      print("AlertService: SMS permission request error: $e");
    }
  }

  /// Mask a phone number for safe diagnostic logging (e.g. +91 91138****13)
  static String maskPhoneNumber(String phone) {
    final clean = phone.trim();
    if (clean.length <= 4) return "****";
    if (clean.length <= 8) {
      return "${clean.substring(0, 2)}****${clean.substring(clean.length - 2)}";
    }
    final prefix = clean.substring(0, clean.length - 6);
    final suffix = clean.substring(clean.length - 2);
    return "$prefix****$suffix";
  }

  /// Core routine: Trigger immediate emergency SMS dispatch to parent/contacts without blocking,
  /// query nearest real hospital via OpenStreetMap concurrently, and dispatch hospital alerts as soon as ready.
  Future<Map<String, dynamic>> sendEmergencyAlerts({
    required Map<String, dynamic> userProfile,
    required String crashType,
    double? overrideLatitude,
    double? overrideLongitude,
    double? maxAcceleration,
  }) async {
    // Atomic lockout guard to prevent duplicate concurrent broadcast executions
    if (_isBroadcasting) {
      print("AlertService: Emergency alert broadcast already in progress. Ignoring duplicate trigger.");
      return {
        'status': 'duplicate_prevented',
        'isSuccess': false,
        'message': 'Duplicate emergency alert prevented by atomic safety lock.',
      };
    }
    _isBroadcasting = true;
    _lastBroadcastTime = DateTime.now();

    try {
      print(
        "AlertService: Starting immediate emergency alert sequence for crash type: $crashType",
      );

      // 1. Acquire current LIVE GPS Location
      double? lat = overrideLatitude;
      double? lng = overrideLongitude;
      double? accuracy;
      bool isStaleGps = false;

      if (lat != null && lng != null) {
        lat = double.parse(lat.toStringAsFixed(5));
        lng = double.parse(lng.toStringAsFixed(5));
        accuracy = 5.0; // Simulated test override accuracy
      } else {
        Position? position;
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            print("AlertService: Location services disabled on device, checking last known position.");
          }

          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final cached = _cachedPosition;
            if (cached != null) {
              position = cached;
              accuracy = cached.accuracy;
              if (DateTime.now().difference(cached.timestamp).inMinutes > 5) {
                isStaleGps = true;
              }
              print("AlertService: Acquired pre-fetched background GPS: ${cached.latitude}, ${cached.longitude} (Accuracy: ±${cached.accuracy.toStringAsFixed(1)}m)");
              _cachedPosition = null;
            } else {
              try {
                position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 6),
                );
                accuracy = position.accuracy;
              } catch (e) {
                print("AlertService: Live GPS fast lock timed out ($e), attempting last known GPS position...");
                try {
                  position = await Geolocator.getLastKnownPosition();
                  if (position != null) {
                    accuracy = position.accuracy;
                    if (DateTime.now().difference(position.timestamp).inMinutes > 5) {
                      isStaleGps = true;
                    }
                  }
                } catch (_) {}
              }
            }
          } else {
            print("AlertService: GPS permission denied, attempting last known position.");
            try {
              position = await Geolocator.getLastKnownPosition();
              if (position != null) {
                accuracy = position.accuracy;
              }
            } catch (_) {}
          }
        } catch (e) {
          print("AlertService: GPS fetch error: $e");
        }

        final pos = position;
        if (pos != null) {
          lat = double.parse(pos.latitude.toStringAsFixed(5));
          lng = double.parse(pos.longitude.toStringAsFixed(5));
        }
      }

      final bool hasValidGps = (lat != null && lng != null);
      final double? actualLat = lat;
      final double? actualLng = lng;

      if (hasValidGps && actualLat != null && actualLng != null) {
        print("ACCIDENT GPS: $actualLat, $actualLng (Accuracy: ±${accuracy?.toStringAsFixed(1) ?? 'N/A'}m${isStaleGps ? ' - STALE' : ''})");
      } else {
        print("ACCIDENT GPS: Unavailable");
      }

      // 2. Format Message Payloads with Enhanced Live GPS and Date/Time
      final String nowFormatted = DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19);
      final String mapsLink = (hasValidGps && actualLat != null && actualLng != null)
          ? "https://maps.google.com/?q=$actualLat,$actualLng"
          : "GPS signal unavailable";
      final String coordsDisplay = (hasValidGps && actualLat != null && actualLng != null)
          ? "Lat: $actualLat, Lng: $actualLng"
          : "Unavailable";
      final String accuracyDisplay = (accuracy != null && accuracy > 0)
          ? "±${accuracy.toStringAsFixed(1)}m"
          : "Approximate";

      final String name = userProfile['fullName'] ?? "Driver";
      final String bloodGroup = userProfile['bloodGroup'] ?? "Unknown";
      final String driverEmail = (userProfile['email'] ?? '').toString().trim();
      final String parentPhone = (userProfile['parentPhone'] ?? "").toString().trim();
      final String parentEmail = (userProfile['parentEmail'] ?? userProfile['email'] ?? "").toString().trim();

      // Check explicit medical consent
      final bool consentMedical = userProfile['consentToShareMedical'] == true;
      final String medicalNotes = (consentMedical &&
              userProfile['medicalNotes'] != null &&
              userProfile['medicalNotes'].toString().trim().isNotEmpty)
          ? "\nMedical Notes: ${userProfile['medicalNotes']}"
          : "";

      final String locationText = (hasValidGps && actualLat != null && actualLng != null)
          ? "Location: $mapsLink ($coordsDisplay)\nAccuracy: $accuracyDisplay"
          : "Location: GPS signal unavailable";

      final String parentMsg =
          "EMERGENCY ALERT!\n"
          "A possible accident has been detected ($crashType).\n"
          "$locationText\n"
          "Time: $nowFormatted\n"
          "Status: Critical Impact Detected\n"
          "Driver: $name (Blood: $bloodGroup)$medicalNotes\n"
          "Please contact the person immediately.";

      final String hospitalMsg =
          "EMERGENCY AMBULANCE DISPATCH REQUEST!\n"
          "Crash Type: $crashType\n"
          "$locationText\n"
          "Time: $nowFormatted\n"
          "Status: Critical Impact Detected\n"
          "Patient: $name (Blood: $bloodGroup)$medicalNotes\n"
          "Immediate medical rescue required.";

      // 3. STEP A: MULTI-CONTACT EMERGENCY SMS DISPATCH WITH RETRY SYSTEM
      final Future<List<SmsDispatchResult>> contactsSmsFuture = () async {
        List<Map<String, dynamic>> contacts = [];
        if (driverEmail.isNotEmpty) {
          try {
            contacts = await _dbService.getEmergencyContacts(driverEmail);
          } catch (_) {}
        }

        // Fallback to parentPhone if no contacts configured
        if (contacts.isEmpty && parentPhone.isNotEmpty) {
          contacts = [
            {
              'id': 'legacy_parent',
              'name': 'Primary Contact',
              'phone': DatabaseService.normalizePhoneNumber(parentPhone),
              'isPrimary': true,
            }
          ];
        }

        if (contacts.isEmpty) {
          return [
            SmsDispatchResult(
              recipient: '',
              maskedRecipient: 'Unconfigured',
              method: 'None',
              status: 'failed',
              statusDisplay: 'Unconfigured',
              isSuccess: false,
              elapsedMs: 0,
              errorMessage: 'No emergency contacts configured',
            )
          ];
        }

        // Sort: primary contact first
        contacts.sort((a, b) {
          if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
          if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
          return 0;
        });

        final List<SmsDispatchResult> dispatchResults = [];
        for (var contact in contacts) {
          // Feature 3: Only dispatch to contacts selected for alerts
          if (contact['receiveAlerts'] == false) continue;

          final phone = (contact['phone'] ?? '').toString().trim();
          if (phone.isNotEmpty) {
            final res = await _sendSmsWithRetry(phone, parentMsg);
            dispatchResults.add(res);
          }
        }
        return dispatchResults;
      }();

    // 4. STEP B: CONCURRENT HOSPITAL DISCOVERY & HOSPITAL ALERT CHAIN
    final Future<Map<String, dynamic>> hospitalChainFuture = () async {
      List<HospitalModel> topHospitals = [];
      HospitalModel? nearestHospital;
      String hospitalName = "Nearby hospital unavailable";
      double? hospitalDistance;
      String? hospitalAddress;
      String? hospitalPhone;
      String? hospitalEmail;
      bool hasValidHospitalPhone = false;
      String hospitalLookupMessage = "";

      if (hasValidGps && actualLat != null && actualLng != null) {
        print("SEARCHING HOSPITALS AROUND CURRENT LOCATION");
        final searchResult = await HospitalService.searchNearbyHospitals(
          latitude: actualLat,
          longitude: actualLng,
        );

        topHospitals = searchResult.hospitals;
        hospitalLookupMessage = searchResult.statusMessage;
        nearestHospital = topHospitals.isNotEmpty ? topHospitals.first : null;

        if (nearestHospital != null) {
          hospitalName = nearestHospital.name;
          hospitalDistance = nearestHospital.distanceKm;
          hospitalAddress = nearestHospital.address;
          hospitalPhone = nearestHospital.phone;
          hospitalEmail = nearestHospital.email;
          hasValidHospitalPhone = hospitalPhone != null && hospitalPhone.trim().isNotEmpty;
        } else {
          switch (searchResult.status) {
            case HospitalLookupStatus.timeout:
              hospitalName = "Nearby hospital lookup timed out";
              break;
            case HospitalLookupStatus.apiError:
              hospitalName = "Hospital lookup failed (API error)";
              break;
            case HospitalLookupStatus.networkError:
              hospitalName = "Hospital lookup failed (Network error)";
              break;
            case HospitalLookupStatus.noResults:
              hospitalName = "No healthcare facilities found within 25 km";
              break;
            case HospitalLookupStatus.success:
              hospitalName = "Nearby hospital unavailable";
              break;
          }
        }
      } else {
        hospitalName = "Nearby hospital unavailable (GPS signal unavailable)";
        hospitalLookupMessage = "GPS signal unavailable";
      }

      print("NEAREST HOSPITAL: $hospitalName");
      print("DISTANCE: ${hospitalDistance != null ? '${hospitalDistance.toStringAsFixed(2)} km' : 'Unavailable'}");
      print("PHONE: ${hasValidHospitalPhone && hospitalPhone != null ? maskPhoneNumber(hospitalPhone) : (nearestHospital != null ? 'Hospital found, phone number unavailable' : 'Unavailable')}");

      // Hospital SMS Task (ONLY dispatched if valid phone exists from OSM)
      SmsDispatchResult? hospitalSmsResult;
      String hospitalSmsStatus;

      if (hasValidHospitalPhone && hospitalPhone != null && hospitalPhone.isNotEmpty) {
        hospitalSmsResult = await _sendSingleSms(hospitalPhone, hospitalMsg);
        hospitalSmsStatus = hospitalSmsResult.statusDisplay;
      } else {
        if (nearestHospital != null) {
          hospitalSmsStatus = "Hospital found, phone number unavailable";
          print("AlertService: Skipping hospital SMS: Hospital found (${nearestHospital.name}), phone number unavailable in OSM directory.");
        } else {
          if (hospitalName.contains('timed out')) {
            hospitalSmsStatus = "Skipped (Lookup timed out)";
          } else if (hospitalName.contains('failed')) {
            hospitalSmsStatus = "Skipped (API lookup failed)";
          } else if (hospitalName.contains('No healthcare')) {
            hospitalSmsStatus = "Skipped (No nearby hospital found)";
          } else {
            hospitalSmsStatus = "Skipped (Hospital unavailable)";
          }
          print("AlertService: Skipping hospital SMS: $hospitalName.");
        }
      }

      // Hospital Email Task
      bool hospitalEmailSent = false;
      if (hospitalEmail != null && hospitalEmail.isNotEmpty && hospitalEmail.contains('@')) {
        hospitalEmailSent = await _sendEmail(
          recipientEmail: hospitalEmail,
          subject: "🚨 EMERGENCY ACCIDENT ALERT: $name",
          body: hospitalMsg,
        );
      }

      return {
        'topHospitals': topHospitals,
        'nearestHospital': nearestHospital,
        'hospitalName': hospitalName,
        'hospitalDistance': hospitalDistance,
        'hospitalAddress': hospitalAddress,
        'hospitalPhone': hospitalPhone,
        'hospitalEmail': hospitalEmail,
        'hasValidHospitalPhone': hasValidHospitalPhone,
        'hospitalSmsResult': hospitalSmsResult,
        'hospitalSmsStatus': hospitalSmsStatus,
        'hospitalEmailSent': hospitalEmailSent,
        'hospitalLookupMessage': hospitalLookupMessage,
      };
    }();

    // 5. STEP C: CONCURRENT PARENT EMAIL & DATABASE LOGGING
    final Future<bool> parentEmailFuture = () async {
      if (parentEmail.isNotEmpty && parentEmail.contains('@')) {
        return await _sendEmail(
          recipientEmail: parentEmail,
          subject: "🚨 CRITICAL ACCIDENT ALERT: $name",
          body: parentMsg,
        );
      }
      return false;
    }();

    // 6. EXECUTE ALL INDEPENDENT TASKS CONCURRENTLY
    final results = await Future.wait([
      contactsSmsFuture,
      hospitalChainFuture,
      parentEmailFuture,
    ]);

    final List<SmsDispatchResult> allContactSmsResults = results[0] as List<SmsDispatchResult>;
    final SmsDispatchResult parentSmsResult = allContactSmsResults.isNotEmpty
        ? allContactSmsResults.first
        : SmsDispatchResult(
            recipient: parentPhone,
            maskedRecipient: maskPhoneNumber(parentPhone),
            method: 'None',
            status: 'failed',
            statusDisplay: 'Unconfigured',
            isSuccess: false,
            elapsedMs: 0,
            errorMessage: 'No contact configured',
          );
    final Map<String, dynamic> hospData = results[1] as Map<String, dynamic>;
    final bool parentEmailSent = results[2] as bool;

    final List<HospitalModel> topHospitals = hospData['topHospitals'] as List<HospitalModel>;
    final HospitalModel? nearestHospital = hospData['nearestHospital'] as HospitalModel?;
    final String hospitalName = hospData['hospitalName'] as String;
    final double? hospitalDistance = hospData['hospitalDistance'] as double?;
    final String? hospitalAddress = hospData['hospitalAddress'] as String?;
    final String? hospitalPhone = hospData['hospitalPhone'] as String?;
    final bool hasValidHospitalPhone = hospData['hasValidHospitalPhone'] as bool;
    final SmsDispatchResult? hospitalSmsResult = hospData['hospitalSmsResult'] as SmsDispatchResult?;
    final String hospitalSmsStatus = hospData['hospitalSmsStatus'] as String;
    final bool hospitalEmailSent = hospData['hospitalEmailSent'] as bool;

    final bool parentSent = parentSmsResult.isSuccess;
    final bool hospitalSent = hospitalSmsResult?.isSuccess ?? false;
    final bool emailSent = parentEmailSent || hospitalEmailSent;

    final String distanceStr = hospitalDistance != null
        ? "${hospitalDistance.toStringAsFixed(2)} km"
        : (nearestHospital != null
            ? "Distance unavailable"
            : (hospitalName.contains('timed out')
                ? "Lookup timed out"
                : (hospitalName.contains('failed') ? "API error" : "Distance unavailable")));

    // Compute overall SMS status separating submission from confirmed delivery
    final bool anySmsDelivered = allContactSmsResults.any((r) => r.status == 'delivered');
    final bool anySmsSent = allContactSmsResults.any((r) => r.isSuccess);
    final String overallSmsStatus = anySmsDelivered
        ? 'Delivered'
        : (anySmsSent ? 'Sent (Submitted)' : (allContactSmsResults.isEmpty ? 'Unconfigured' : 'Failed'));

    // Log complete crash report and event details to database
    try {
      await _dbService.createCrashReport({
        'driverName': name,
        'driverEmail': driverEmail,
        'bloodGroup': bloodGroup,
        'latitude': actualLat,
        'longitude': actualLng,
        'locationAccuracy': accuracyDisplay,
        'googleMapsUrl': mapsLink,
        'incidentTime': nowFormatted,
        'crashType': crashType,
        'maxAcceleration': maxAcceleration ?? 35.0,
        'nearestHospital': hospitalName,
        'hospitalDistance': hospitalDistance != null ? "${hospitalDistance.toStringAsFixed(2)} km" : "N/A",
        'hospitalPhone': hasValidHospitalPhone && hospitalPhone != null ? hospitalPhone : "Unavailable",
        'hospitalStatus': hospitalSent ? 'Notified (SMS)' : (hospitalEmailSent ? 'Notified (Email)' : hospitalSmsStatus),
        'smsStatus': overallSmsStatus,
        'smsDispatchResults': allContactSmsResults.map((r) => r.toMap()).toList(),
        'alertStatus': 'Dispatched',
        'status': 'Pending',
      });
    } catch (e) {
      print("AlertService: Failed to create database crash report: $e");
    }

    // If SMS dispatch failed or device is offline, enqueue in persistent OfflineEventQueueService
    if (allContactSmsResults.every((r) => !r.isSuccess)) {
      try {
        await OfflineEventQueueService.instance.enqueueEvent(
          eventId: "evt_${DateTime.now().millisecondsSinceEpoch}_$driverEmail",
          driverEmail: driverEmail,
          driverName: name,
          crashType: crashType,
          latitude: actualLat ?? 0.0,
          longitude: actualLng ?? 0.0,
          accuracy: accuracy ?? 10.0,
          isStaleLocation: isStaleGps,
          recipients: allContactSmsResults.map((r) => r.recipient).toList(),
          needsSmsRetry: true,
          needsEmailRetry: !emailSent,
          needsFirestoreSync: true,
          medicalNotes: medicalNotes,
        );
      } catch (_) {}
    }

    return {
      'lat': actualLat,
      'lng': actualLng,
      'hasValidGps': hasValidGps,
      'locationAccuracy': accuracyDisplay,
      'googleMapsUrl': mapsLink,
      'incidentTime': nowFormatted,
      'maxAcceleration': maxAcceleration ?? 35.0,
      'nearestHospital': hospitalName,
      'distance': hospitalDistance,
      'distanceStr': distanceStr,
      'hospitalAddress': hospitalAddress,
      'hospitalPhone': hasValidHospitalPhone
          ? hospitalPhone
          : (nearestHospital != null ? 'Hospital found, phone number unavailable' : 'Hospital phone unavailable'),
      'hasValidHospitalPhone': hasValidHospitalPhone,
      'topHospitals': topHospitals.map((h) => h.toMap()).toList(),
      'parentPhone': parentPhone,
      'parentMessage': parentMsg,
      'hospitalMessage': hospitalMsg,
      'parentSent': parentSent,
      'hospitalSent': hospitalSent,
      'parentSmsResult': parentSmsResult.toMap(),
      'hospitalSmsResult': hospitalSmsResult?.toMap(),
      'allContactSmsResults': allContactSmsResults.map((r) => r.toMap()).toList(),
      'parentSmsStatus': parentSmsResult.statusDisplay,
      'hospitalSmsStatus': hospitalSmsStatus,
      'overallSmsStatus': overallSmsStatus,
      'emailSent': emailSent,
      'parentEmailSent': parentEmailSent,
      'hospitalEmailSent': hospitalEmailSent,
      'hospitalNotified': hospitalSent || hospitalEmailSent,
      'parentEmail': parentEmail,
      'hospitalEmail': hospData['hospitalEmail'] ?? '',
    };
    } finally {
      _isBroadcasting = false;
    }
  }


  /// Public test helper for verifying email configuration without triggering an accident
  Future<Map<String, dynamic>> sendTestEmail({
    required String recipientEmail,
  }) async {
    const String subject = "🚨 TEST: Accident Guard System Email Verification";
    const String body = "This is a verified test email from the Accident Guard System.\n"
        "Your emergency email notifications are configured and functioning properly.";

    return await _executeEmailDispatch(
      recipientEmail: recipientEmail,
      subject: subject,
      body: body,
    );
  }

  /// Public test helper for verifying SMS configuration without triggering an accident
  Future<SmsDispatchResult> sendTestSms({
    required String recipientPhone,
  }) async {
    const String testMsg = "🚨 TEST: Accident Guard System SMS Verification. Live emergency SMS service active.";
    return await _sendSingleSms(recipientPhone, testMsg);
  }

  /// Internal Email dispatcher: checks for Webhook/Dispatcher URL or uses Gmail SMTP via mailer
  Future<bool> _sendEmail({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    final result = await _executeEmailDispatch(
      recipientEmail: recipientEmail,
      subject: subject,
      body: body,
    );
    return result['isSuccess'] == true;
  }

  Future<Map<String, dynamic>> _executeEmailDispatch({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    print("EMAIL START");
    print("EMAIL RECIPIENT: $recipientEmail");

    if (recipientEmail.trim().isEmpty || !recipientEmail.contains('@')) {
      print("EMAIL FAILED (Invalid email address format)");
      return {
        'recipient': recipientEmail,
        'method': 'Unknown',
        'requestStarted': false,
        'responseStatus': 'Invalid Email Format',
        'responseBody': 'Recipient address is empty or not a valid email address.',
        'isSuccess': false,
      };
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Try Custom Email Webhook / REST Dispatcher URL if configured
    final String? webhookUrl = prefs.getString('email_dispatcher_url');
    if (webhookUrl != null &&
        webhookUrl.trim().isNotEmpty &&
        webhookUrl.startsWith('http')) {
      final methodStr = "HTTPS Webhook ($webhookUrl)";
      print("EMAIL METHOD: $methodStr");
      print("EMAIL REQUEST START");
      try {
        final response = await http
            .post(
              Uri.parse(webhookUrl.trim()),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'to': recipientEmail.trim(),
                'subject': subject,
                'text': body,
              }),
            )
            .timeout(const Duration(seconds: 8));

        print("EMAIL RESPONSE STATUS: ${response.statusCode}");
        print("EMAIL RESPONSE BODY: ${response.body}");

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print("EMAIL SUCCESS");
          return {
            'recipient': recipientEmail,
            'method': methodStr,
            'requestStarted': true,
            'responseStatus': '${response.statusCode} OK',
            'responseBody': response.body.isNotEmpty ? response.body : 'Payload accepted by server',
            'isSuccess': true,
          };
        } else {
          print("AlertService: Webhook returned non-2xx status code (${response.statusCode}). Attempting SMTP fallback...");
        }
      } catch (e) {
        print("EMAIL RESPONSE STATUS: Error ($e)");
        print("AlertService: Webhook request failed. Attempting SMTP fallback...");
      }
    }

    // 2. Direct SMTP via mailer package (Gmail / Custom SMTP)
    const methodStr = "Direct SMTP (smtp.gmail.com)";
    print("EMAIL METHOD: $methodStr");
    final String username = (prefs.getString('smtp_email') ?? DatabaseService.defaultSmtpEmail).trim();
    final String password = (prefs.getString('smtp_password') ?? DatabaseService.defaultSmtpPassword).trim();

    if (username.isEmpty || password.isEmpty) {
      print("EMAIL FAILED (SMTP Credentials Unconfigured)");
      return {
        'recipient': recipientEmail,
        'method': methodStr,
        'requestStarted': false,
        'responseStatus': 'Unconfigured',
        'responseBody': 'Gmail sender address or App Password is not configured in Driver Dashboard.',
        'isSuccess': false,
      };
    }

    final String cleanUsername = username;
    final String cleanPassword = password.replaceAll(' ', '');

    final message = Message()
      ..from = Address(cleanUsername, 'Accident Guard System')
      ..recipients.add(recipientEmail.trim())
      ..subject = subject
      ..text = body;

    // Try Port 465 (SSL)
    print("EMAIL REQUEST START (Port 465 SSL)");
    try {
      final smtpServer465 = gmail(cleanUsername, cleanPassword);
      await send(
        message,
        smtpServer465,
      ).timeout(const Duration(seconds: 8));
      print("EMAIL RESPONSE STATUS: 250 OK");
      print("EMAIL SUCCESS");
      return {
        'recipient': recipientEmail,
        'method': '$methodStr (Port 465 SSL)',
        'requestStarted': true,
        'responseStatus': '250 OK',
        'responseBody': 'Message accepted by SMTP server',
        'isSuccess': true,
      };
    } catch (e) {
      print("EMAIL RESPONSE STATUS: Port 465 Failed (Connection/Auth)");
      print("EMAIL REQUEST START (Port 587 STARTTLS Fallback)");

      // Try Port 587 (STARTTLS)
      try {
        final smtpServer587 = SmtpServer(
          'smtp.gmail.com',
          port: 587,
          username: cleanUsername,
          password: cleanPassword,
        );
        await send(
          message,
          smtpServer587,
        ).timeout(const Duration(seconds: 8));
        print("EMAIL RESPONSE STATUS: 250 OK");
        print("EMAIL SUCCESS");
        return {
          'recipient': recipientEmail,
          'method': '$methodStr (Port 587 STARTTLS)',
          'requestStarted': true,
          'responseStatus': '250 OK',
          'responseBody': 'Message accepted by SMTP server',
          'isSuccess': true,
        };
      } catch (err) {
        print("EMAIL RESPONSE STATUS: Port 587 Failed (Connection/Auth)");
        print("EMAIL FAILED");
        return {
          'recipient': recipientEmail,
          'method': methodStr,
          'requestStarted': true,
          'responseStatus': 'SMTP Connection / Authentication Failed',
          'responseBody': 'Unable to connect to SMTP server. Verify Gmail App Password.',
          'isSuccess': false,
        };
      }
    }
  }

  /// Retry-enabled SMS dispatcher with delivery logs, attempt tracking, and retry delays
  Future<SmsDispatchResult> _sendSmsWithRetry(
    String phoneNumber,
    String message, {
    int maxRetries = 2,
    Duration retryInterval = const Duration(seconds: 2),
  }) async {
    final List<Map<String, dynamic>> attemptLogs = [];
    SmsDispatchResult? lastResult;

    for (int attempt = 1; attempt <= (maxRetries + 1); attempt++) {
      final attemptTime = DateTime.now().toIso8601String();
      final result = await _sendSingleSms(phoneNumber, message);
      lastResult = result;

      attemptLogs.add({
        'attempt': attempt,
        'timestamp': attemptTime,
        'status': result.status,
        'statusDisplay': result.statusDisplay,
        'method': result.method,
        'isSuccess': result.isSuccess,
        'elapsedMs': result.elapsedMs,
        'errorMessage': result.errorMessage,
        'deliveryConfirmed': result.deliveryConfirmed,
      });

      if (result.isSuccess) {
        return SmsDispatchResult(
          recipient: result.recipient,
          maskedRecipient: result.maskedRecipient,
          method: result.method,
          status: result.status,
          statusDisplay: result.statusDisplay,
          isSuccess: true,
          elapsedMs: result.elapsedMs,
          errorMessage: result.errorMessage,
          deliveryConfirmed: result.deliveryConfirmed,
          retryAttempts: attempt - 1,
          attemptLogs: attemptLogs,
        );
      }

      if (attempt <= maxRetries) {
        print("AlertService: SMS dispatch to ${result.maskedRecipient} failed (Attempt $attempt). Retrying in ${retryInterval.inSeconds}s...");
        await Future.delayed(retryInterval);
      }
    }

    return SmsDispatchResult(
      recipient: lastResult?.recipient ?? phoneNumber,
      maskedRecipient: lastResult?.maskedRecipient ?? maskPhoneNumber(phoneNumber),
      method: lastResult?.method ?? 'None',
      status: 'failed',
      statusDisplay: 'Failed (Retries Exhausted)',
      isSuccess: false,
      elapsedMs: lastResult?.elapsedMs ?? 0,
      errorMessage: lastResult?.errorMessage ?? 'Max retries exhausted without response',
      deliveryConfirmed: false,
      retryAttempts: maxRetries,
      attemptLogs: attemptLogs,
    );
  }

  /// Internal Immediate SMS dispatcher: Primary TextBee API -> Fallback Native Android SIM
  Future<SmsDispatchResult> _sendSingleSms(String phoneNumber, String message) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String requestTime = DateTime.now().toIso8601String();

    String formatted = phoneNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    if (formatted.isEmpty) {
      return SmsDispatchResult(
        recipient: phoneNumber,
        maskedRecipient: 'Empty',
        method: 'None',
        status: 'failed',
        statusDisplay: 'Failed',
        isSuccess: false,
        elapsedMs: 0,
        errorMessage: 'Empty phone number',
      );
    }

    if (formatted.length == 10 && !formatted.startsWith('+')) {
      formatted = '+91$formatted';
    }

    final String masked = maskPhoneNumber(formatted);

    // 1. Primary: Textbee Gateway API (Immediate request, no scheduling)
    try {
      final prefs = await SharedPreferences.getInstance();
      final String textbeeApiKey = (prefs.getString('textbee_api_key') ?? DatabaseService.defaultTextbeeApiKey).trim();
      final String textbeeDeviceId = (prefs.getString('textbee_device_id') ?? DatabaseService.defaultTextbeeDeviceId).trim();

      if (textbeeApiKey.isNotEmpty) {
        print("SMS DISPATCH START");
        print("Recipient: $masked");
        print("Method: TextBee");
        print("Request time: $requestTime");

        final url = textbeeDeviceId.isNotEmpty
            ? "https://api.textbee.dev/api/v1/gateway/devices/$textbeeDeviceId/send-sms"
            : "https://api.textbee.dev/api/v1/gateway/send-sms";

        final Map<String, dynamic> payload = {
          "recipients": [formatted],
          "message": message,
        };

        if (textbeeDeviceId.isNotEmpty) {
          payload["deviceId"] = textbeeDeviceId;
        }

        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                "Content-Type": "application/json",
                "x-api-key": textbeeApiKey,
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 5));

        stopwatch.stop();
        final int elapsed = stopwatch.elapsedMilliseconds;

        if (response.statusCode == 200 || response.statusCode == 201) {
          String status = 'accepted';
          String statusDisplay = 'Accepted by SMS Gateway';

          try {
            final dynamic bodyJson = jsonDecode(response.body);
            if (bodyJson is Map<String, dynamic>) {
              final String rawStatus = (bodyJson['status'] ??
                      bodyJson['data']?['status'] ??
                      bodyJson['state'] ??
                      bodyJson['deliveryStatus'] ??
                      '')
                  .toString()
                  .toLowerCase()
                  .trim();
              final String rawMessage = (bodyJson['message'] ?? '').toString().toLowerCase().trim();
              final bool isDelivered = rawStatus == 'delivered' || (bodyJson['delivered'] == true);

              if (isDelivered) {
                status = 'delivered';
                statusDisplay = 'Delivered';
              } else if (rawStatus == 'dispatched' ||
                  rawStatus == 'sent' ||
                  rawStatus == 'completed' ||
                  rawMessage.contains('dispatched') ||
                  rawMessage.contains('message sent') ||
                  rawMessage.contains('sms sent')) {
                status = 'dispatched';
                statusDisplay = 'Dispatched';
              } else if (rawStatus == 'failed' ||
                  rawStatus == 'error' ||
                  bodyJson['success'] == false ||
                  rawMessage.contains('failed')) {
                status = 'failed';
                statusDisplay = 'Failed';
              } else {
                status = 'accepted';
                statusDisplay = 'Accepted by SMS Gateway';
              }
            }
          } catch (_) {
            status = 'accepted';
            statusDisplay = 'Accepted by SMS Gateway';
          }

          if (status == 'failed') {
            print("Result: failed (${response.statusCode})");
            print("Elapsed time: $elapsed ms");
          } else {
            print("Result: $status ($statusDisplay)");
            print("Elapsed time: $elapsed ms");
            return SmsDispatchResult(
              recipient: formatted,
              maskedRecipient: masked,
              method: 'TextBee',
              status: status,
              statusDisplay: statusDisplay,
              isSuccess: true,
              elapsedMs: elapsed,
            );
          }
        } else {
          print("Result: failed (${response.statusCode})");
          print("Elapsed time: $elapsed ms");
        }
      }
    } catch (e) {
      print("AlertService: TextBee Gateway error: $e");
    }

    // 2. Fallback: Native Android SIM SmsManager via MethodChannel
    final Stopwatch nativeStopwatch = Stopwatch()..start();
    final String nativeTime = DateTime.now().toIso8601String();
    print("SMS DISPATCH START");
    print("Recipient: $masked");
    print("Method: Native SIM");
    print("Request time: $nativeTime");

    try {
      await platform.invokeMethod('sendSms', {
        'phoneNumber': formatted,
        'message': message,
      });

      nativeStopwatch.stop();
      final int elapsed = nativeStopwatch.elapsedMilliseconds;

      print("Result: submitted");
      print("Elapsed time: $elapsed ms");

      return SmsDispatchResult(
        recipient: formatted,
        maskedRecipient: masked,
        method: 'Native SIM',
        status: 'submitted',
        statusDisplay: 'Submitted (Cellular Baseband)',
        isSuccess: true,
        elapsedMs: elapsed,
        deliveryConfirmed: false,
      );
    } catch (e) {
      nativeStopwatch.stop();
      final int elapsed = nativeStopwatch.elapsedMilliseconds;

      print("Result: failed ($e)");
      print("Elapsed time: $elapsed ms");

      return SmsDispatchResult(
        recipient: formatted,
        maskedRecipient: masked,
        method: 'Native SIM',
        status: 'failed',
        statusDisplay: 'Failed',
        isSuccess: false,
        elapsedMs: elapsed,
        errorMessage: e.toString(),
      );
    }
  }
}
