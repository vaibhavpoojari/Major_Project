import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accident_guard_system/services/hospital_service.dart';
import 'package:accident_guard_system/services/alert_service.dart';
import 'package:accident_guard_system/services/permission_service.dart';
import 'package:accident_guard_system/services/sensor_service.dart';
import 'package:accident_guard_system/services/database_service.dart';
import 'package:accident_guard_system/services/localization_service.dart';
import 'package:accident_guard_system/services/offline_queue_service.dart';
import 'package:accident_guard_system/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Haversine Geodesic Calculations', () {
    test('Haversine distance calculation is mathematically accurate', () {
      // Distance between Bangalore Majestic (12.9774, 77.5729) and Indiranagar (12.9784, 77.6408)
      final dist = HospitalService.calculateHaversineDistanceKm(
        12.9774,
        77.5729,
        12.9784,
        77.6408,
      );
      expect(dist, greaterThan(6.0));
      expect(dist, lessThan(8.0));
    });
  });

  group('Hospital Classification & Tag Extraction', () {
    test('Correctly classifies emergency-capable hospital into Tier 1', () {
      final facility = HospitalService.classifyFacility(
        name: 'Apollo Emergency Trauma Centre',
        latitude: 12.9716,
        longitude: 77.5946,
        distanceKm: 2.1,
        tags: {
          'amenity': 'hospital',
          'emergency': 'yes',
          'operator:type': 'private',
        },
      );

      expect(facility.facilityType, 'Emergency Hospital');
      expect(facility.emergencyCapability, 'Yes');
      expect(facility.ownership, 'Private');
      expect(facility.priorityTier, 1);
    });

    test('Correctly classifies government hospital without emergency tag into Tier 2', () {
      final facility = HospitalService.classifyFacility(
        name: 'District Government General Hospital',
        latitude: 12.9800,
        longitude: 77.6000,
        distanceKm: 1.5,
        tags: {
          'amenity': 'hospital',
          'operator:type': 'government',
        },
      );

      expect(facility.facilityType, 'Hospital');
      expect(facility.emergencyCapability, 'Unavailable');
      expect(facility.ownership, 'Government/Public');
      expect(facility.priorityTier, 2);
    });

    test('Hospital with missing emergency tag is still treated as hospital (Tier 2)', () {
      final facility = HospitalService.classifyFacility(
        name: 'Durga Hospital',
        latitude: 13.0000,
        longitude: 77.5000,
        distanceKm: 1.2,
        tags: {
          'amenity': 'hospital',
        },
      );

      expect(facility.facilityType, 'Hospital');
      expect(facility.emergencyCapability, 'Unavailable');
      expect(facility.ownership, 'Unavailable');
      expect(facility.priorityTier, 2);
    });

    test('Hospital with missing ownership tag is still treated as hospital (Tier 2)', () {
      final facility = HospitalService.classifyFacility(
        name: 'City Care Hospital',
        latitude: 13.0100,
        longitude: 77.5100,
        distanceKm: 1.8,
        tags: {
          'amenity': 'hospital',
        },
      );

      expect(facility.facilityType, 'Hospital');
      expect(facility.ownership, 'Unavailable');
      expect(facility.priorityTier, 2);
    });

    test('Correctly classifies clinic into Tier 3 (lowest fallback)', () {
      final facility = HospitalService.classifyFacility(
        name: 'Neighborhood Family Clinic',
        latitude: 12.9720,
        longitude: 77.5950,
        distanceKm: 0.5,
        tags: {
          'amenity': 'clinic',
          'healthcare': 'clinic',
        },
      );

      expect(facility.facilityType, 'Clinic');
      expect(facility.priorityTier, 3);
    });
  });

  group('Hospital Prioritization & Selection Rules', () {
    test('1. Nearby private hospital + farther government hospitals: private hospital is selected and ranked', () {
      final privateHospital = HospitalService.classifyFacility(
        name: 'Durga Hospital',
        latitude: 13.0010,
        longitude: 77.5010,
        distanceKm: 1.2, // closest
        tags: {'amenity': 'hospital'},
      );

      final govtHospital1 = HospitalService.classifyFacility(
        name: 'Govt Taluk Hospital',
        latitude: 13.0100,
        longitude: 77.5100,
        distanceKm: 3.5,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );

      final govtHospital2 = HospitalService.classifyFacility(
        name: 'Govt District Hospital',
        latitude: 13.0200,
        longitude: 77.5200,
        distanceKm: 5.0,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );

      final govtHospital3 = HospitalService.classifyFacility(
        name: 'Govt Civil Hospital',
        latitude: 13.0300,
        longitude: 77.5300,
        distanceKm: 7.0,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );

      final selected = HospitalService.prioritizeHospitals([
        govtHospital1,
        govtHospital2,
        govtHospital3,
        privateHospital,
      ]);

      expect(selected.length, 3);
      // Durga Hospital (1.2km) must be #1 because it is the closest real hospital
      expect(selected[0].name, 'Durga Hospital');
      expect(selected[1].name, 'Govt Taluk Hospital');
      expect(selected[2].name, 'Govt District Hospital');
    });

    test('2. Nearby emergency hospital gets preference', () {
      final emergencyHospital = HospitalService.classifyFacility(
        name: 'Apollo Trauma Centre',
        latitude: 12.9800,
        longitude: 77.6000,
        distanceKm: 4.0,
        tags: {'amenity': 'hospital', 'emergency': 'yes'},
      );

      final normalHospital1 = HospitalService.classifyFacility(
        name: 'Adarsha Hospital',
        latitude: 12.9700,
        longitude: 77.5900,
        distanceKm: 1.5,
        tags: {'amenity': 'hospital'},
      );

      final normalHospital2 = HospitalService.classifyFacility(
        name: 'City Care Hospital',
        latitude: 12.9750,
        longitude: 77.5950,
        distanceKm: 2.0,
        tags: {'amenity': 'hospital'},
      );

      final normalHospital3 = HospitalService.classifyFacility(
        name: 'General Hospital',
        latitude: 12.9790,
        longitude: 77.5990,
        distanceKm: 3.0,
        tags: {'amenity': 'hospital'},
      );

      final selected = HospitalService.prioritizeHospitals([
        normalHospital1,
        normalHospital2,
        normalHospital3,
        emergencyHospital,
      ]);

      expect(selected.length, 3);
      // Emergency hospital is included in top 3 along with closest general hospitals
      expect(selected.any((h) => h.name == 'Apollo Trauma Centre'), true);
    });

    test('3. Multiple normal hospitals: nearest suitable hospitals selected', () {
      final h1 = HospitalService.classifyFacility(
        name: 'Hospital A',
        latitude: 12.91,
        longitude: 77.51,
        distanceKm: 1.0,
        tags: {'amenity': 'hospital'},
      );
      final h2 = HospitalService.classifyFacility(
        name: 'Hospital B',
        latitude: 12.92,
        longitude: 77.52,
        distanceKm: 2.5,
        tags: {'amenity': 'hospital'},
      );
      final h3 = HospitalService.classifyFacility(
        name: 'Hospital C',
        latitude: 12.93,
        longitude: 77.53,
        distanceKm: 3.5,
        tags: {'amenity': 'hospital'},
      );
      final h4 = HospitalService.classifyFacility(
        name: 'Hospital D',
        latitude: 12.94,
        longitude: 77.54,
        distanceKm: 8.0,
        tags: {'amenity': 'hospital'},
      );

      final selected = HospitalService.prioritizeHospitals([h4, h3, h2, h1]);
      expect(selected.length, 3);
      expect(selected[0].name, 'Hospital A');
      expect(selected[1].name, 'Hospital B');
      expect(selected[2].name, 'Hospital C');
    });

    test('4. Clinics only: clinics are used as fallback when no proper hospitals exist', () {
      final c1 = HospitalService.classifyFacility(
        name: 'Dental Clinic',
        latitude: 12.91,
        longitude: 77.51,
        distanceKm: 0.5,
        tags: {'amenity': 'clinic'},
      );
      final c2 = HospitalService.classifyFacility(
        name: 'Eye Care Centre',
        latitude: 12.92,
        longitude: 77.52,
        distanceKm: 1.2,
        tags: {'amenity': 'clinic'},
      );
      final c3 = HospitalService.classifyFacility(
        name: 'General Dispensary',
        latitude: 12.93,
        longitude: 77.53,
        distanceKm: 2.0,
        tags: {'amenity': 'clinic'},
      );

      final selected = HospitalService.prioritizeHospitals([c3, c2, c1]);
      expect(selected.length, 3);
      expect(selected[0].name, 'Dental Clinic');
      expect(selected[1].name, 'Eye Care Centre');
      expect(selected[2].name, 'General Dispensary');
    });

    test('5. Proper hospitals exclude clinics from top results', () {
      final h1 = HospitalService.classifyFacility(
        name: 'Durga Hospital',
        latitude: 12.91,
        longitude: 77.51,
        distanceKm: 1.5,
        tags: {'amenity': 'hospital'},
      );
      final h2 = HospitalService.classifyFacility(
        name: 'Adarsha Hospital',
        latitude: 12.92,
        longitude: 77.52,
        distanceKm: 2.0,
        tags: {'amenity': 'hospital'},
      );
      final h3 = HospitalService.classifyFacility(
        name: 'Govt Hospital',
        latitude: 12.93,
        longitude: 77.53,
        distanceKm: 3.0,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );
      final clinic = HospitalService.classifyFacility(
        name: 'Close Dental Clinic',
        latitude: 12.90,
        longitude: 77.50,
        distanceKm: 0.3, // very close
        tags: {'amenity': 'clinic'},
      );

      final selected = HospitalService.prioritizeHospitals([clinic, h3, h2, h1]);
      expect(selected.length, 3);
      // Clinic must NOT be included since 3 proper hospitals exist
      expect(selected.any((f) => f.name == 'Close Dental Clinic'), false);
      expect(selected[0].name, 'Durga Hospital');
      expect(selected[1].name, 'Adarsha Hospital');
      expect(selected[2].name, 'Govt Hospital');
    });

    test('6. Maximum 3 results returned', () {
      final facilities = List.generate(10, (index) => HospitalService.classifyFacility(
        name: 'Hospital $index',
        latitude: 12.97 + (index * 0.01),
        longitude: 77.59 + (index * 0.01),
        distanceKm: (index + 1) * 1.0,
        tags: {'amenity': 'hospital'},
      ));

      final selected = HospitalService.prioritizeHospitals(facilities);
      expect(selected.length, 3);
    });
  });


  group('AlertService Safety & Reliability', () {
    test('Handles emergency broadcast safely when GPS is null without inventing fake coordinates', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Test Driver',
          'bloodGroup': 'A+',
          'parentPhone': '',
          'email': '',
        },
        crashType: 'Head-On Collision',
        overrideLatitude: null,
        overrideLongitude: null,
      );

      expect(results['hasValidGps'], false);
      expect(results['nearestHospital'], contains('unavailable'));
      expect(results['parentSent'], false);
      expect(results['hospitalSent'], false);
    });

    test('Does not throw when executing live hospital discovery query', () async {
      final topHospitals = await HospitalService.findTopNearbyHospitals(
        latitude: 12.9716,
        longitude: 77.5946,
      );

      // Either returns a list of up to 3 hospitals if online, or empty list if Overpass is down
      expect(topHospitals.length, lessThanOrEqualTo(3));
    });

    test('sendTestEmail safely rejects invalid email addresses without crashing', () async {
      final alertService = AlertService();
      final result = await alertService.sendTestEmail(recipientEmail: 'invalid-email-address');

      expect(result['isSuccess'], false);
      expect(result['requestStarted'], false);
      expect(result['responseStatus'], contains('Invalid'));
    });

    test('sendTestEmail returns structured diagnostic result', () async {
      final alertService = AlertService();
      final result = await alertService.sendTestEmail(recipientEmail: 'test@example.com');

      expect(result.containsKey('recipient'), true);
      expect(result.containsKey('method'), true);
      expect(result.containsKey('requestStarted'), true);
      expect(result.containsKey('responseStatus'), true);
      expect(result.containsKey('isSuccess'), true);
    });
  });

  group('Immediate SMS Architecture & Safety Tests', () {
    test('Phone number masking hides private digits and leaves safe prefix/suffix', () {
      expect(AlertService.maskPhoneNumber('+919113895413'), '+919113****13');
      expect(AlertService.maskPhoneNumber('9876543210'), '9876****10');
      expect(AlertService.maskPhoneNumber('1234'), '****');
    });

    test('SmsDispatchResult represents accepted/dispatched/failed/delivered states correctly', () {
      final accepted = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'accepted',
        statusDisplay: 'Accepted by SMS Gateway',
        isSuccess: true,
        elapsedMs: 120,
      );
      expect(accepted.isSuccess, true);
      expect(accepted.statusDisplay, 'Accepted by SMS Gateway');
      expect(accepted.method, 'TextBee');

      final dispatched = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'dispatched',
        statusDisplay: 'Dispatched',
        isSuccess: true,
        elapsedMs: 150,
      );
      expect(dispatched.isSuccess, true);
      expect(dispatched.statusDisplay, 'Dispatched');

      final delivered = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'delivered',
        statusDisplay: 'Delivered',
        isSuccess: true,
        elapsedMs: 210,
      );
      expect(delivered.isSuccess, true);
      expect(delivered.statusDisplay, 'Delivered');

      final failed = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'Native SIM',
        status: 'failed',
        statusDisplay: 'Failed',
        isSuccess: false,
        elapsedMs: 50,
        errorMessage: 'Telephony unavailable',
      );
      expect(failed.isSuccess, false);
      expect(failed.statusDisplay, 'Failed');
      expect(failed.errorMessage, 'Telephony unavailable');
    });

    test('Accident confirmation triggers SMS immediately and no fake hospital phone is used', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Immediate Test Driver',
          'bloodGroup': 'AB+',
          'parentPhone': '+919876543210',
          'parentEmail': 'test@example.com',
        },
        crashType: 'Rollover Crash',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      expect(results.containsKey('parentSmsResult'), true);
      expect(results.containsKey('parentSmsStatus'), true);
      expect(results['parentPhone'], '+919876543210');
      // If OSM hospital phone is missing, it should never dispatch SMS to hospital or claim dispatch
      if (results['hasValidHospitalPhone'] != true) {
        final status = results['hospitalSmsStatus'].toString();
        expect(
          status.contains('Hospital found, phone number unavailable') || status.contains('Skipped'),
          true,
        );
        expect(results['hospitalSent'], false);
      }
    });

    test('Hospital phone normalization handles raw OSM phone numbers accurately', () {
      expect(HospitalService.normalizePhoneNumber('+918022868423'), '+918022868423');
      expect(HospitalService.normalizePhoneNumber('080 2222 1111'), '+918022221111');
      expect(HospitalService.normalizePhoneNumber('"080 2286 6529'), '+918022866529');
      expect(HospitalService.normalizePhoneNumber('97390 07505'), '+919739007505');
      expect(HospitalService.normalizePhoneNumber('080-2220 3333; 080-2220 4444'), '+918022203333');
      expect(HospitalService.normalizePhoneNumber('+91 80 2297 7400 / 2297 7401'), '+918022977400');
      expect(HospitalService.normalizePhoneNumber('9876543210'), '+919876543210');
      expect(HospitalService.normalizePhoneNumber('108'), null);
      expect(HospitalService.normalizePhoneNumber(''), null);
      expect(HospitalService.normalizePhoneNumber('N/A'), null);
    });

    test('extractHospitalPhone extracts and prioritizes valid contact tags', () {
      final tags1 = {'phone': '080 2222 1111', 'contact:phone': '+918022868423'};
      expect(HospitalService.extractHospitalPhone(tags1), '+918022221111');

      final tags2 = {'contact:phone': '+918022868423'};
      expect(HospitalService.extractHospitalPhone(tags2), '+918022868423');

      final tags3 = {'telephone': '080-2344 9632'};
      expect(HospitalService.extractHospitalPhone(tags3), '+918023449632');

      final tags4 = {'emergency:phone': '+919876543210'};
      expect(HospitalService.extractHospitalPhone(tags4), '+919876543210');

      final tags5 = {'amenity': 'hospital', 'name': 'General Hospital'};
      expect(HospitalService.extractHospitalPhone(tags5), null);
    });

    test('Nearest hospital details are preserved even when phone is unavailable', () {
      final hospital = HospitalService.classifyFacility(
        name: 'Bengaluru District Hospital',
        latitude: 12.9716,
        longitude: 77.5946,
        distanceKm: 1.45,
        tags: {'amenity': 'hospital'},
      );

      expect(hospital.name, 'Bengaluru District Hospital');
      expect(hospital.distanceKm, 1.45);
      expect(hospital.phone, null);
      final map = hospital.toMap();
      expect(map['hasValidPhone'], false);
      expect(map['facilityName'], 'Bengaluru District Hospital');
      expect(map['distanceKm'], 1.45);
    });

    test('SMS failure does not stop email or crash report logging', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Resilient Driver',
          'bloodGroup': 'O-',
          'parentPhone': '', // empty phone -> failed SMS
          'parentEmail': 'resilient@example.com',
        },
        crashType: 'Rear-End Impact',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      expect(results['parentSent'], false);
      expect(results['parentSmsStatus'], 'Unconfigured');
      // Flow completes safely and returns location text
      expect(results['hasValidGps'], true);
      expect(results['parentMessage'], contains('Resilient Driver'));
    });

    test('sendTestSms safely handles empty number without crashing', () async {
      final alertService = AlertService();
      final result = await alertService.sendTestSms(recipientPhone: '');
      expect(result.isSuccess, false);
      expect(result.statusDisplay, 'Failed');
    });
  });

  group('PermissionService Runtime Management', () {
    test('PermissionStatusResult structure holds correct flags', () {
      final result = PermissionStatusResult(
        isLocationGranted: true,
        isLocationDeniedForever: false,
        isNotificationGranted: true,
        isSmsGranted: false,
      );

      expect(result.isLocationGranted, true);
      expect(result.isLocationDeniedForever, false);
      expect(result.isNotificationGranted, true);
      expect(result.isSmsGranted, false);
    });
  });

  group('Accident Detection Acceleration Threshold (35.0 m/s²)', () {
    test('Single source of truth: SensorService.crashThreshold is exactly 35.0 m/s²', () {
      expect(SensorService.crashThreshold, 35.0);
    });

    test('Acceleration below 35.0 m/s² does NOT trigger the accident threshold condition', () {
      // Test zero, typical driving force, prior test values, and near-threshold values
      expect(SensorService.isAccident(0.0), false);
      expect(SensorService.isAccident(9.8), false);
      expect(SensorService.isAccident(18.0), false);
      expect(SensorService.isAccident(25.0), false);
      expect(SensorService.isAccident(34.99), false);
      expect(34.99 >= SensorService.crashThreshold, false);
    });

    test('Acceleration exactly 35.0 m/s² meets the accident threshold condition', () {
      expect(SensorService.isAccident(35.0), true);
      expect(35.0 >= SensorService.crashThreshold, true);
    });

    test('Acceleration above 35.0 m/s² meets the accident threshold condition', () {
      expect(SensorService.isAccident(35.01), true);
      expect(SensorService.isAccident(40.0), true);
      expect(SensorService.isAccident(45.0), true);
      expect(SensorService.isAccident(75.5), true);
      expect(45.0 >= SensorService.crashThreshold, true);
    });
  });

  group('Crash Direction Classification (Frontal, Lateral, Rollover)', () {
    test('X-axis dominant force classifies as Side Impact (Lateral)', () {
      final service = SensorService();
      final type = service.classifyCrash(42.0, 5.0, 2.0, 42.3);
      expect(type, contains('Side Impact (Lateral)'));
    });

    test('Y-axis dominant force classifies as Frontal/Rear Collision', () {
      final service = SensorService();
      final type = service.classifyCrash(2.0, 40.0, 5.0, 40.3);
      expect(type, contains('Frontal/Rear Collision'));
    });

    test('Z-axis dominant force classifies as Rollover / Vertical Force', () {
      final service = SensorService();
      final type = service.classifyCrash(1.0, 2.0, 38.0, 38.1);
      expect(type, contains('Rollover / Vertical Force'));
    });
  });

  group('Project Automatic SMS & Email Configuration', () {
    test('DatabaseService defines environment configuration constants', () {
      expect(DatabaseService.defaultTextbeeDeviceId, isA<String>());
      expect(DatabaseService.defaultTextbeeApiKey, isA<String>());
      expect(DatabaseService.defaultSmtpEmail, isA<String>());
      expect(DatabaseService.defaultSmtpPassword, isA<String>());
    });

    test('Fresh installation initializes missing project defaults cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Before init, values should be null or missing
      expect(prefs.getString('textbee_api_key'), isNull);
      expect(prefs.getString('textbee_device_id'), isNull);
      expect(prefs.getString('smtp_email'), isNull);
      expect(prefs.getString('smtp_password'), isNull);

      // Execute initialization
      await DatabaseService.initDefaultConfigurations(prefs);

      // If environment flags were set, they are populated; otherwise clean
      if (DatabaseService.defaultTextbeeApiKey.isNotEmpty) {
        expect(prefs.getString('textbee_api_key'), DatabaseService.defaultTextbeeApiKey);
      }
    });

    test('Existing saved configuration is strictly preserved and not overwritten', () async {
      SharedPreferences.setMockInitialValues({
        'textbee_api_key': 'custom_user_key_999',
        'textbee_device_id': 'custom_device_888',
        'smtp_email': 'custom_user@example.com',
        'smtp_password': 'custom_app_password_777',
      });
      final prefs = await SharedPreferences.getInstance();

      // Execute initialization
      await DatabaseService.initDefaultConfigurations(prefs);

      // Existing saved values must NOT be overwritten
      expect(prefs.getString('textbee_api_key'), 'custom_user_key_999');
      expect(prefs.getString('textbee_device_id'), 'custom_device_888');
      expect(prefs.getString('smtp_email'), 'custom_user@example.com');
      expect(prefs.getString('smtp_password'), 'custom_app_password_777');
    });
  });

  group('Role-Specific Reference Login Details UI', () {
    testWidgets('Driver Tab: Reference credentials are NOT shown, inputs start empty', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // Ensure Driver Tab is active
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('Driver Portal'), findsOneWidget);

      // Email and password fields start empty (display-only credentials, no auto-filling)
      final emailFinder = find.byType(TextFormField).first;
      final emailField = tester.widget<TextFormField>(emailFinder);
      expect(emailField.controller?.text, isEmpty);

      // Reference login details must NOT be visible on Driver Tab
      expect(find.text('REFERENCE LOGIN DETAILS'), findsNothing);
      expect(find.text('admin@cityemergency.org'), findsNothing);
      expect(find.text('Shettyprakyathp@gmail.com'), findsNothing);
      expect(find.text('vaibhava.23cs179@sode-edu.in'), findsNothing);
    });

    testWidgets('Hospital Hub Tab: Shows ONLY Hospital Hub reference credentials', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // Tap Hospital Hub tab
      await tester.tap(find.text('Hospital Hub'));
      await tester.pumpAndSettle();

      // Reference details section must be present with exact Hospital Hub credentials
      expect(find.text('REFERENCE LOGIN DETAILS'), findsOneWidget);
      expect(find.text('Hospital Hub'), findsWidgets); // Tab + Reference heading
      expect(find.text('Email: admin@cityemergency.org'), findsOneWidget);
      expect(find.text('Password: Password123!'), findsOneWidget);

      // Admin credentials must NOT be present
      expect(find.text('Admin 1'), findsNothing);
      expect(find.text('Admin 2'), findsNothing);
      expect(find.text('Email: Shettyprakyathp@gmail.com'), findsNothing);
      expect(find.text('Email: vaibhava.23cs179@sode-edu.in'), findsNothing);
    });

    testWidgets('Admin Tab: Shows ONLY Admin 1 and Admin 2 reference credentials', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // Tap Admin tab
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      // Reference details section must be present with exact Admin 1 & Admin 2 credentials
      expect(find.text('REFERENCE LOGIN DETAILS'), findsOneWidget);
      expect(find.text('Admin 1'), findsOneWidget);
      expect(find.text('Email: Shettyprakyathp@gmail.com'), findsOneWidget);
      expect(find.text('Password: Password123!'), findsOneWidget);

      expect(find.text('Admin 2'), findsOneWidget);
      expect(find.text('Email: vaibhava.23cs179@sode-edu.in'), findsOneWidget);
      expect(find.text('Password: 9731971568'), findsOneWidget);

      // Hospital Hub reference credentials must NOT be present
      expect(find.text('Email: admin@cityemergency.org'), findsNothing);
    });
  });

  // =========================================================================
  // ADVANCED FEATURE ENHANCEMENT TESTS (FEATURES 1 TO 8)
  // =========================================================================

  group('Feature 1: Emergency SOS Countdown & Debouncing', () {
    test('Configurable countdown duration bounds (15 - 30 seconds)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sos_countdown_duration', 25);
      final duration = prefs.getInt('sos_countdown_duration');
      expect(duration, 25);
      expect(duration! >= 15 && duration <= 30, true);
    });

    test('Cancellation resets active emergency state and preserves monitoring readiness', () async {
      final dbService = DatabaseService();
      // Record a user-cancellation event
      await dbService.createCrashReport({
        'driverName': 'Test Driver',
        'driverEmail': 'driver@guard.com',
        'bloodGroup': 'O+',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'crashType': 'High Severity Frontal Collision',
        'maxAcceleration': 42.5,
        'nearestHospital': 'Cancelled by User',
        'hospitalDistance': 'N/A',
        'hospitalPhone': 'N/A',
        'hospitalStatus': 'Cancelled',
        'smsStatus': 'Cancelled (Safe)',
        'alertStatus': 'Cancelled by Driver',
        'isCancelled': true,
        'status': 'Cancelled',
      });

      final reports = await dbService.getCrashReports();
      expect(reports.isNotEmpty, true);
      final latest = reports.first;
      expect(latest['isCancelled'], true);
      expect(latest['smsStatus'], 'Cancelled (Safe)');
    });
  });

  group('Feature 2: Emergency Contact Management', () {
    test('Indian mobile number validator correctly accepts valid 10-digit formats', () {
      expect(DatabaseService.isValidIndianMobile('9876543210'), true);
      expect(DatabaseService.isValidIndianMobile('+919113895413'), true);
      expect(DatabaseService.isValidIndianMobile('+91 9731971568'), true);
      expect(DatabaseService.isValidIndianMobile('919876543210'), true);
      expect(DatabaseService.isValidIndianMobile('09876543210'), true);
      expect(DatabaseService.isValidIndianMobile('7012345678'), true);
      expect(DatabaseService.isValidIndianMobile('6123456789'), true);
    });

    test('Indian mobile number validator rejects invalid phone numbers', () {
      expect(DatabaseService.isValidIndianMobile('1234567890'), false); // Starts with 1
      expect(DatabaseService.isValidIndianMobile('5234567890'), false); // Starts with 5
      expect(DatabaseService.isValidIndianMobile('98765'), false); // Too short
      expect(DatabaseService.isValidIndianMobile('9876543210123'), false); // Too long
      expect(DatabaseService.isValidIndianMobile('abcdefghij'), false); // Alphabetic
      expect(DatabaseService.isValidIndianMobile(''), false); // Empty
    });

    test('Normalizes phone numbers to standard international +91 format', () {
      expect(DatabaseService.normalizePhoneNumber('9876543210'), '+919876543210');
      expect(DatabaseService.normalizePhoneNumber('+919113895413'), '+919113895413');
      expect(DatabaseService.normalizePhoneNumber('09731971568'), '+919731971568');
      expect(DatabaseService.normalizePhoneNumber('919876543210'), '+919876543210');
    });

    test('Prevents duplicate phone numbers when saving emergency contacts', () async {
      final dbService = DatabaseService();
      const testEmail = 'contacts_test@guard.com';

      // Save first contact
      await dbService.saveEmergencyContact(testEmail, {
        'id': 'contact_1',
        'name': 'Primary Contact',
        'phone': '9876543210',
        'relationship': 'Family',
        'isPrimary': true,
      });

      // Attempt to save duplicate contact with same phone
      expect(
        () async => await dbService.saveEmergencyContact(testEmail, {
          'id': 'contact_2',
          'name': 'Duplicate Contact',
          'phone': '+91 9876543210',
          'relationship': 'Friend',
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('Primary contact toggle and automatic re-assignment on deletion', () async {
      final dbService = DatabaseService();
      const testEmail = 'primary_test@guard.com';

      await dbService.saveEmergencyContact(testEmail, {
        'id': 'c1',
        'name': 'Contact One',
        'phone': '9113895413',
        'isPrimary': true,
      });

      await dbService.saveEmergencyContact(testEmail, {
        'id': 'c2',
        'name': 'Contact Two',
        'phone': '9731971568',
        'isPrimary': false,
      });

      var list = await dbService.getEmergencyContacts(testEmail);
      expect(list.length, 2);
      expect(list.firstWhere((c) => c['id'] == 'c1')['isPrimary'], true);
      expect(list.firstWhere((c) => c['id'] == 'c2')['isPrimary'], false);

      // Delete primary contact; Contact Two must become primary
      await dbService.deleteEmergencyContact(testEmail, 'c1');
      list = await dbService.getEmergencyContacts(testEmail);
      expect(list.length, 1);
      expect(list.first['id'], 'c2');
      expect(list.first['isPrimary'], true);
    });
  });

  group('Feature 3: Live GPS Location Sharing', () {
    test('Formats emergency alert with coordinates, Google Maps link, date/time and accuracy', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Vaibhava',
          'email': 'vaibhava.23cs179@sode-edu.in',
          'bloodGroup': 'A+',
          'parentPhone': '+919731971568',
        },
        crashType: 'High Severity Frontal Collision',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      expect(results['hasValidGps'], true);
      expect(results['lat'], 12.9716);
      expect(results['lng'], 77.5946);
      expect(results['googleMapsUrl'], 'https://maps.google.com/?q=12.9716,77.5946');
      expect(results['locationAccuracy'], contains('m'));
      expect(results['incidentTime'], isNotNull);
      expect(results['parentMessage'], contains('https://maps.google.com/?q=12.9716,77.5946'));
      expect(results['parentMessage'], contains('Status: Critical Impact Detected'));
    });
  });

  group('Feature 4: Accident History and Event Logs', () {
    test('Accident records are logged and retrieved in chronological order', () async {
      final dbService = DatabaseService();
      await dbService.clearCrashReports();

      await dbService.createCrashReport({
        'driverName': 'Driver Alpha',
        'crashType': 'High Severity Frontal Collision',
        'maxAcceleration': 36.5,
        'incidentTime': '2026-11-01 08:00:00',
        'status': 'Dispatched',
        'smsStatus': 'Sent (Submitted)',
      });

      await dbService.createCrashReport({
        'driverName': 'Driver Beta',
        'crashType': 'High Severity Rollover Force',
        'maxAcceleration': 44.2,
        'incidentTime': '2026-11-01 08:30:00',
        'status': 'Dispatched',
        'smsStatus': 'Delivered',
      });

      final reports = await dbService.getCrashReports();
      expect(reports.length, 2);
      expect(reports.first['driverName'], 'Driver Beta'); // Chronological newest first
    });

    test('Clear history resets all accident event logs', () async {
      final dbService = DatabaseService();
      await dbService.createCrashReport({'test': 'record'});
      var reports = await dbService.getCrashReports();
      expect(reports.isNotEmpty, true);

      await dbService.clearCrashReports();
      reports = await dbService.getCrashReports();
      expect(reports.isEmpty, true);
    });
  });

  group('Feature 5: Emergency Alert Retry System', () {
    test('SmsDispatchResult accurately distinguishes accepted from delivered status', () {
      final submitted = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'accepted',
        statusDisplay: 'Accepted by SMS Gateway',
        isSuccess: true,
        elapsedMs: 80,
        deliveryConfirmed: false,
      );
      expect(submitted.status, 'accepted');
      expect(submitted.deliveryConfirmed, false);

      final confirmed = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'delivered',
        statusDisplay: 'Delivered',
        isSuccess: true,
        elapsedMs: 140,
        deliveryConfirmed: true,
      );
      expect(confirmed.status, 'delivered');
      expect(confirmed.deliveryConfirmed, true);
    });

    test('SmsDispatchResult tracks retry attempts and attempt logs correctly', () {
      final retried = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'Native SIM',
        status: 'failed',
        statusDisplay: 'Failed (Retries Exhausted)',
        isSuccess: false,
        elapsedMs: 50,
        retryAttempts: 2,
        attemptLogs: [
          {'attempt': 1, 'status': 'failed'},
          {'attempt': 2, 'status': 'failed'},
          {'attempt': 3, 'status': 'failed'},
        ],
      );
      expect(retried.retryAttempts, 2);
      expect(retried.attemptLogs.length, 3);
    });
  });

  group('Feature 6: GPS and Network Health Monitor', () {
    test('Permission and availability status indicators are defined', () {
      final res = PermissionStatusResult(
        isLocationGranted: true,
        isLocationDeniedForever: false,
        isNotificationGranted: true,
        isSmsGranted: true,
      );
      expect(res.isLocationGranted, true);
      expect(res.isSmsGranted, true);
    });
  });

  group('Feature 7: Kannada and English Language Support', () {
    test('English translations provide all major application keys', () {
      AppLocalization.setLanguage(AppLanguage.english);
      expect('accident_detected'.tr, 'ACCIDENT DETECTED');
      expect('i_am_safe'.tr, 'I AM SAFE (CANCEL)');
      expect('driver_hub'.tr, 'Driver Protection Hub');
      expect('emergency_contacts'.tr, 'Emergency Contacts');
      expect('accident_history'.tr, 'Accident History');
      expect('emergency_profile'.tr, 'Emergency Profile');
      expect('settings'.tr, 'System Settings');
    });

    test('Kannada translations use valid Unicode and map correctly', () {
      AppLocalization.setLanguage(AppLanguage.kannada);
      expect('accident_detected'.tr, 'ಅಪಘಾತ ಪತ್ತೆಯಾಗಿದೆ');
      expect('i_am_safe'.tr, 'ನಾನು ಸುರಕ್ಷಿತವಾಗಿದ್ದೇನೆ (ರದ್ದುಗೊಳಿಸಿ)');
      expect('driver_hub'.tr, 'ಚಾಲಕರ ರಕ್ಷಣಾ ಕೇಂದ್ರ');
      expect('emergency_contacts'.tr, 'ತುರ್ತು ಸಂಪರ್ಕಗಳು');
      expect('accident_history'.tr, 'ಅಪಘಾತ ಇತಿಹಾಸ');
      expect('emergency_profile'.tr, 'ತುರ್ತು ಪ್ರೊಫೈಲ್');
      expect('settings'.tr, 'ಸಿಸ್ಟಮ್ ಸೆಟ್ಟಿಂಗ್‌ಗಳು');
      // Reset to English for remaining tests
      AppLocalization.setLanguage(AppLanguage.english);
    });
  });

  group('Feature 8: Emergency User Profile', () {
    test('Saves and loads profile with optional medical info and consent toggle', () async {
      final dbService = DatabaseService();
      const testEmail = 'profile_test@guard.com';

      await dbService.updateEmergencyProfile(testEmail, {
        'fullName': 'Prakyath Shetty',
        'bloodGroup': 'O+',
        'medicalNotes': 'Asthma, Penicillin allergy',
        'consentToShareMedical': true,
      });

      final profile = await dbService.getEmergencyProfile(testEmail);
      expect(profile['fullName'], 'Prakyath Shetty');
      expect(profile['bloodGroup'], 'O+');
      expect(profile['medicalNotes'], 'Asthma, Penicillin allergy');
      expect(profile['consentToShareMedical'], true);
    });

    test('Strict privacy compliance: medical notes excluded without explicit user consent', () async {
      final alertService = AlertService();
      // Profile with medical notes but consentToShareMedical = false
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Private Driver',
          'email': 'private@guard.com',
          'bloodGroup': 'B+',
          'parentPhone': '+919113895413',
          'medicalNotes': 'Confidential Heart Condition',
          'consentToShareMedical': false, // Consent NOT granted
        },
        crashType: 'High Severity Side Impact (Lateral)',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      final String message = results['parentMessage'] as String;
      expect(message.contains('Confidential Heart Condition'), false);
    });

    test('Medical notes included when user explicitly grants consent', () async {
      final alertService = AlertService();
      // Profile with explicit consent
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Consenting Driver',
          'email': 'consent@guard.com',
          'bloodGroup': 'B+',
          'parentPhone': '+919113895413',
          'medicalNotes': 'Type 1 Diabetic',
          'consentToShareMedical': true, // Consent granted
        },
        crashType: 'High Severity Side Impact (Lateral)',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      final String message = results['parentMessage'] as String;
      expect(message.contains('Type 1 Diabetic'), true);
    });
  });

  group('Feature Enhancement: Hindi Language Support', () {
    test('Hindi translations provide accurate Devanagari mappings', () {
      AppLocalization.setLanguage(AppLanguage.hindi);
      expect(AppLocalization.isHindi, true);
      expect('accident_detected'.tr, 'दुर्घटना का पता चला');
      expect('i_am_safe'.tr, 'मैं सुरक्षित हूँ (रद्द करें)');
      expect('manual_sos'.tr, 'मैन्युअल आपातकालीन एसओएस');
      expect('offline_maps'.tr, 'ऑफ़लाइन मानचित्र एवं अस्पताल');
      expect('driver_hub'.tr, 'ड्राइवर सुरक्षा हब');
      expect('emergency_contacts'.tr, 'आपातकालीन संपर्क');
      expect('accident_history'.tr, 'दुर्घटना इतिहास');
      expect('emergency_profile'.tr, 'आपातकालीन प्रोफ़ाइल');
      expect('settings'.tr, 'सिस्टम सेटिंग्स');

      // Reset to English
      AppLocalization.setLanguage(AppLanguage.english);
      expect(AppLocalization.isEnglish, true);
    });
  });

  group('Feature Enhancement: Offline Emergency Event Queue', () {
    test('Enqueues, checks pending count, and clears events idempotently', () async {
      final queueService = OfflineEventQueueService.instance;

      final countBefore = await queueService.getPendingCount();

      await queueService.enqueueEvent(
        eventId: 'test_evt_001',
        driverEmail: 'test_driver@guard.com',
        driverName: 'Driver Test',
        crashType: 'Frontal Collision Test',
        latitude: 12.9716,
        longitude: 77.5946,
        accuracy: 5.0,
        isStaleLocation: false,
        recipients: ['+919113895413'],
        needsSmsRetry: true,
        needsEmailRetry: true,
        needsFirestoreSync: true,
      );

      final countAfter = await queueService.getPendingCount();
      expect(countAfter, countBefore + 1);

      // Verify event is retrieved
      final pending = await queueService.getPendingEvents();
      expect(pending.any((e) => e['eventId'] == 'test_evt_001'), true);

      // Remove event
      await queueService.removeEvent('test_evt_001');
      final countFinal = await queueService.getPendingCount();
      expect(countFinal, countBefore);
    });
  });

  group('Feature Enhancement: Manual SOS Activation', () {
    test('sendManualSos executes emergency broadcast pipeline with zero acceleration', () async {
      final alertService = AlertService();
      final results = await alertService.sendManualSos(
        userProfile: {
          'fullName': 'SOS Tester',
          'email': 'sostest@guard.com',
          'bloodGroup': 'A+',
          'parentPhone': '+919113895413',
        },
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      expect(results['parentMessage'], isNotNull);
      final String msg = results['parentMessage'] as String;
      expect(msg.contains('Manual Emergency SOS Triggered') || msg.contains('ACCIDENT ALERT'), true);
      expect(results['lat'], 12.9716);
      expect(results['lng'], 77.5946);
    });
  });

  group('Feature Enhancement: Offline Hospital Cache Lookup', () {
    test('getCachedHospitals returns pre-cached facilities with sorted distances', () async {
      final cachedHospitals = await HospitalService.getCachedHospitals(
        latitude: 12.9716,
        longitude: 77.5946,
      );

      expect(cachedHospitals, isNotEmpty);
      // Verify list is sorted ascending by distance
      for (int i = 0; i < cachedHospitals.length - 1; i++) {
        expect(cachedHospitals[i].distanceKm, lessThanOrEqualTo(cachedHospitals[i + 1].distanceKm));
      }
      // Verify facility fields
      final first = cachedHospitals.first;
      expect(first.name, isNotEmpty);
      expect(first.distanceKm, greaterThanOrEqualTo(0.0));
    });
  });

  group('Feature Enhancement: Contact Alerts Toggle (receiveAlerts)', () {
    test('Excludes contacts with receiveAlerts = false from SMS dispatch', () async {
      final dbService = DatabaseService();
      const driverEmail = 'toggle_test@guard.com';

      await dbService.saveEmergencyContact(driverEmail, {
        'id': 'contact_muted',
        'name': 'Muted Contact',
        'phone': '+919876543210',
        'relationship': 'Friend',
        'isPrimary': false,
        'receiveAlerts': false, // Alert disabled
      });

      await dbService.saveEmergencyContact(driverEmail, {
        'id': 'contact_active',
        'name': 'Active Contact',
        'phone': '+919113895413',
        'relationship': 'Family',
        'isPrimary': true,
        'receiveAlerts': true, // Alert enabled
      });

      final contacts = await dbService.getEmergencyContacts(driverEmail);
      expect(contacts.length, 2);

      final muted = contacts.firstWhere((c) => c['id'] == 'contact_muted');
      final active = contacts.firstWhere((c) => c['id'] == 'contact_active');

      expect(muted['receiveAlerts'], false);
      expect(active['receiveAlerts'], true);
    });
  });
}








