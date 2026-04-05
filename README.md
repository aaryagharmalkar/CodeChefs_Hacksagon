# dem_app (NeuroCare Flutter Client)

Production Flutter client for early dementia screening workflows in NeuroCare.

This app combines cognitive, speech, and mobility assessments, then aggregates results for clinician-friendly reporting.

## Table of Contents

- Product Scope
- Architecture
- Project Structure
- Feature Modules
- Assessment Journey
- Setup and Run
- Configuration and Environment
- API Integration Points
- Permissions
- Build and Release
- Troubleshooting
- Security and Data Handling

## Product Scope

NeuraCare mobile client supports:

- Authentication and onboarding
- MMSE cognitive screening
- Voice risk scoring (ML API)
- Cookie Theft speech analysis
- TUG mobility flow integration UI
- Reports and profile views
- Medication and doctor-assistance screens

This app provides screening assistance and workflow orchestration. It is not a medical diagnosis tool.

## Architecture

Layered architecture (UI -> State -> Service -> Network):

1. Presentation Layer
	- Screen widgets under `lib/screens/**`
	- Reusable widgets under `lib/widgets/**`
2. State Layer
	- `provider` ViewModels/ChangeNotifiers
	- Session aggregation via `AppSession`
3. Service Layer
	- Feature services under `lib/services/**`
4. Network Layer
	- API clients under `lib/core/network/**`
5. Routing Layer
	- Centralized route map in `lib/routes/app_router.dart`

Runtime data flow:

- User input -> Screen/ViewModel -> Service/API call -> response mapping -> AppSession score store -> report/upload routes.

## Project Structure

```text
dem_app/
|- lib/
|  |- app.dart
|  |- main.dart
|  |- core/
|  |  |- network/
|  |  |- theme/
|  |  `- utils/
|  |- models/
|  |- providers/
|  |- routes/
|  |- screens/
|  |  |- assessment/
|  |  |  |- voice/
|  |  |  `- tug_test_screen.dart
|  |  |- auth/
|  |  |- dashboard/
|  |  |- reports/
|  |  `- ...
|  |- services/
|  `- widgets/
|- android/ ios/ web/ windows/ macos/ linux/
`- pubspec.yaml
```

## Feature Modules

### Auth and Session

- Login and token persistence via `flutter_secure_storage`
- Basic auth provider in `lib/providers/auth_provider.dart`

### Cognitive (MMSE)

- Multi-section question flow with scoring and guided UI

### Voice Analysis

- Audio recording and ML upload
- Processing/results screens under `lib/screens/assessment/voice/`
- ViewModel orchestration in `voice_check_viewmodel.dart`

### Cookie Theft

- Prompted image-based speech recording
- Multipart upload via `AssessmentService`
- Dementia probability and markers capture

### TUG Mobility

- Flutter-side TUG screen with camera + websocket integration hooks
- Optional external Python websocket backend integration

## Assessment Journey

Default journey as currently wired in route map:

1. Splash -> Onboarding -> Auth -> Dashboard
2. Assessment Overview -> MMSE
3. Voice Analysis -> Voice Processing -> Voice Results
4. Cookie Theft and/or TUG depending on current feature logic
5. Assessment Results -> Reports

All routes are declared in `lib/routes/app_router.dart`.

## Setup and Run

### Prerequisites

- Flutter SDK compatible with Dart `^3.11.3`
- Android Studio/Xcode toolchains
- Physical device or emulator

### Install and run

```bash
flutter pub get
flutter run
```

### Quality gates

```bash
flutter analyze
flutter test
```

## Configuration and Environment

The app currently contains hardcoded URLs in multiple files. For production:

1. Move API and websocket endpoints into environment-based config (`--dart-define` or config class).
2. Maintain separate values for local, staging, and production.
3. Avoid committing sensitive hosts/tokens in source.

Recommended `--dart-define` keys:

- `API_BASE_URL`
- `VOICE_ML_BASE_URL`
- `TUG_WS_URL`

## API Integration Points

Common integration files:

- Voice ML: `lib/core/network/voice_ml_api.dart`
- Cookie Theft assessment: `lib/services/assessment_service.dart`
- Report/session upload path used in assessment result pages

Expected contracts:

- Voice: multipart audio + clinical fields (`ac`, `nth`, `htn`) -> risk response
- Cookie Theft: multipart audio + patient identifier -> transcript/metrics/markers
- Report upload: aggregated JSON payload from `AppSession`

## Permissions

Feature-dependent runtime permissions:

- Microphone
- Camera
- Location
- Storage/file access (as needed)

Ensure platform manifests (`AndroidManifest.xml`, iOS plist) match runtime permission flows.

## Build and Release

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

Release checklist:

1. Endpoint config externalized
2. No debug logging of sensitive user data
3. Permission prompts tested end-to-end
4. Error-handling and retries validated on poor networks
5. Full assessment flow smoke-tested on target devices

## Troubleshooting

### API calls fail on device but work on host machine

- Verify device can reach backend host/IP
- Use emulator-specific host mapping where needed
- Check firewall and port exposure

### Voice upload timeouts

- Increase timeout for cold starts
- Validate server health and file size constraints

### TUG websocket issues

- Ensure websocket URL is reachable from device
- Verify payload contract matches backend decoder
- Confirm no plain HTTP client is hitting websocket port

## Security and Data Handling

- Treat recordings and risk scores as sensitive health-adjacent data
- Use HTTPS/TLS for all production endpoints
- Store only required data and avoid PHI in logs
- Keep auth tokens in secure storage and handle expiry/refresh properly

---

For repository-level documentation (including Python model-testing and websocket server context), see `../README.md`.