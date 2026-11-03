# Accident Guard – Smart Accident Detection and Emergency Response System

Accident Guard is a Flutter-based Android application designed to detect potential vehicle accidents using smartphone sensors and support emergency response through GPS tracking, SMS notifications and hospital discovery.

## Features

- **Accident Detection:** Monitors smartphone accelerometer data to identify potential accidents using a threshold of 35.0 m/s².
- **Impact Classification:** Identifies Frontal/Rear Collision, Side Impact (Lateral) and Rollover/Vertical Force based on sensor readings.
- **Emergency SOS:** Provides an emergency countdown with an "I AM SAFE" cancellation option.
- **GPS Tracking:** Retrieves geographical coordinates and generates Google Maps location links.
- **SMS Alerts:** Uses Android SIM-based SMS functionality to notify emergency contacts.
- **Hospital Discovery:** Identifies nearby hospitals using the OpenStreetMap Overpass API.
- **Email Notifications:** Supports SMTP-based emergency notifications.
- **Firebase Integration:** Uses Firebase Authentication, Cloud Firestore and Firebase Cloud Messaging.
- **Role-Based Access:** Provides separate Driver, Hospital and Admin interfaces.
- **Sensor Monitoring:** Displays real-time sensor readings through a circular force gauge.
- **Simulation Mode:** Supports manual accident simulation for testing.

## Technology Stack

| Component | Technology |
|---|---|
| Mobile Framework | Flutter |
| Programming Language | Dart |
| Native Android Integration | Kotlin |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Notifications | Firebase Cloud Messaging |
| Location Services | Geolocator |
| Hospital Discovery | OpenStreetMap Overpass API |
| SMS Integration | Android SmsManager |
| Email Service | SMTP |
| Local Storage | SharedPreferences |

## System Workflow

1. Collects accelerometer data from the smartphone.
2. Calculates acceleration magnitude.
3. Compares sensor readings against the accident detection threshold.
4. Identifies a potential accident event.
5. Initiates the emergency SOS countdown.
6. Retrieves the user's GPS location.
7. Sends emergency notifications through configured services.
8. Stores incident information.

## Offline Support

The application is designed to support essential emergency operations without mobile internet:

- GPS coordinates can be obtained through satellite signals.
- SIM-based SMS can operate without mobile data when cellular service and SMS functionality are available.
- Last-known location can be used when a fresh GPS fix is unavailable.

Offline map downloads, cached hospital information and persistent emergency retries are planned enhancements.

## Project Structure

```text
Accident-Guard/
├── android/
├── assets/
├── lib/
│   ├── screens/
│   ├── services/
│   ├── widgets/
│   └── main.dart
├── test/
├── pubspec.yaml
└── README.md
```

## Installation and Setup

**Prerequisites**
- Flutter SDK
- Dart SDK
- Android Studio
- Android SDK
- Firebase project configuration

**1. Clone the repository**

```bash
git clone https://github.com/vaibhavpoojari/Major_Project.git
```

**2. Navigate to the project**

```bash
cd Accident-Guard
```

**3. Install dependencies**

```bash
flutter pub get
```

**4. Configure Firebase**

Add your Firebase Android configuration file and configure the required Firebase services.

**5. Run the application**

```bash
flutter run
```

## Build APK

Generate an optimized ARM64 release APK:

```bash
flutter build apk --release --target-platform android-arm64
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Testing

Run static analysis:

```bash
flutter analyze
```

Run automated tests:

```bash
flutter test
```

## Future Enhancements

- Offline map support.
- Persistent emergency event storage.
- Automatic SMS retry.
- Accident history and analytics.
- Emergency contact management.
- GPS and network status monitoring.
- English, Kannada and Hindi localization.

## Limitations

- Accident detection depends on smartphone sensor readings and configured thresholds.
- GPS accuracy depends on satellite reception.
- SMS requires an active SIM and cellular network coverage.
- Hospital discovery through OpenStreetMap requires internet unless data is cached.
- Background execution depends on Android operating-system restrictions.

## Project Information

**Project:** Accident Guard  
**Platform:** Android  
**Framework:** Flutter  
**Language:** Dart  
**Architecture:** ARM64
