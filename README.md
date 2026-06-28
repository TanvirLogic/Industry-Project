# Eduverse — EdTech Mobile Application

Eduverse is an EdTech platform built with Flutter featuring advanced video upload capabilities with native background processing, crash-resilient state management, and real-time progress tracking. The system has undergone extensive improvements to handle uploads reliably even when the app is killed or restarted.

## Architecture: Feature-First with Provider

The platform follows a feature-first architecture with `Provider` + `ChangeNotifier` for state management. Providers call a `NetworkCaller` service directly (no repository/use-case abstraction layer).

```
lib/
├── features/
│   ├── auth/              # Login, register, password recovery, Google Sign-In
│   ├── splash/            # Auto-login via token refresh
│   ├── home/              # Main bottom-nav shell (Social/Post/Courses/Hub tabs)
│   ├── courses/           # Course details, enrolled courses, upload course/video, module management
│   ├── hub/               # Settings, mentor dashboard, payments/revenue, ads manager, password/security
│   ├── social/            # Video feed with search
│   ├── notifications/     # In-app notification list
│   ├── profile/
│   │   ├── student/       # Student profile view & edit
│   │   ├── mentor/        # Mentor profile view
│   │   ├── edit/          # Shared edit profile form
│   │   └── avatar/        # Avatar/cover photo upload (presigned S3)
│   └── posts/             # (placeholder)
└── global/core/
    ├── config/            # AppConfig (baseUrl, googleClientId, timeout)
    ├── constants/         # Image asset paths, text colors
    ├── routes/            # AppRoutes (25 named routes + onGenerateRoute)
    ├── services/          # NetworkCaller, LoggerService, ToastService, SecureStorage
    ├── theme/             # AppTheme (light + dark, Urbanist font)
    └── widgets/           # Shared widgets (AuthButton, ShimmerWidget, etc.)
```

### Tech Stack

| Technology | Usage |
|------------|-------|
| Flutter / Dart SDK ^3.11.1 | Framework |
| Provider (ChangeNotifier) | State Management |
| http | REST API client |
| flutter_secure_storage | Token persistence |
| shared_preferences | Email caching & preferences |
| google_sign_in | Google OAuth |
| flutter_svg | SVG icon rendering |
| google_fonts (Urbanist) | Typography |
| image_picker | Avatar/cover image selection |
| image_cropper | Avatar/cover crop UI |
| media_kit + media_kit_video | Video playback (mpv/FFmpeg native decoders) |
| logger | API request/response logging |
| cached_network_image | Image caching |
| url_launcher | Open external links |
| WorkManager | Native background uploads |
| background_downloader | Native file upload service |

## Feature Completion Status

| Feature Area | Status |
|-------------|---------|
| **Authentication** (login, register, OTP, password reset, Google Sign-In) | ✅ Real API calls |
| **Token refresh & auto-login** | ✅ Real |
| **Student & Mentor Profiles** (view) | ✅ Real API |
| **Edit Profile** (save) | ✅ Real API |
| **Avatar / Cover upload** (presigned S3) | ✅ Real |
| **Change Password** | ✅ Real API |
| **Course Details** | ✅ Real API |
| **Enrolled Course** | ✅ Real API |
| **Course Upload / Video Upload** | ✅ Fully functional with native background processing |
| **Module Management** | ✅ Fully functional with crash resilience |
| **Social Feed** | ⚠️ Mock data |
| **Notifications** | ❌ Static mock data |
| **Ads Manager** | ⚠️ UI mostly |
| **Mentor Dashboard** | ⚠️ Partial mock data |

## Routes

| Route | Page | Arguments |
|-------|------|-----------|
| `/` | SplashPage | — |
| `/login` | LoginPage | — |
| `/register` | RegisterPage | — |
| `/forgot-password` | ForgotPasswordPage | — |
| `/verification` | VerificationPage | `{email}` |
| `/reset-verification` | ResetVerificationPage | — |
| `/reset-password` | SetNewPasswordPage | — |
| `/password-success` | PasswordSuccessPage | `{title, subtitle, buttonText, email}` |
| `/home` | MainNavShell | — |
| `/profile` | StudentProfilePage | — |
| `/mentor-profile` | MentorProfilePage | — |
| `/edit-profile` | EditProfilePage | — |
| `/password-and-security` | PasswordAndSecurityPage | — |
| `/payments-and-revenue` | PaymentsAndRevenuePage | — |
| `/mentor-dashboard` | MentorDashboardPage | — |
| `/full-screen-image` | FullScreenImageViewer | `{imageUrl}` |
| `/upload-video-page` | UploadVideoPage | — |
| `/upload-course-page` | UploadCoursePage | — |
| `/course-details` | CourseDetailsPage | `{courseId}` |
| `/enrolled-course` | EnrolledCoursePage | `{courseId}` |
| `/payment-success` | PaymentSuccessPage | `{amount, courseName, trxId}` |
| `/notifications` | NotificationsPage | — |
| `/manage-module` | ManageModulePage | — |
| `/ads-manager` | AdsManagerPage | — |
| `/ads-create` | AdsCreatePage | — |

## API Configuration

- **Base URL:** `http://108.181.195.154:3000/api/v1/` (`AppConfig.baseUrl`)
- **Timeout:** 30 seconds (`AppConfig.requestTimeout`)
- **Auth endpoints:** Real, wired to backend
- **Course endpoints:** Real - all APIs connected to backend

## Video Upload Features

The Eduverse platform includes advanced video upload capabilities with comprehensive robustness:

### ✅ Advanced Upload System
- **Real-time progress tracking** with percentage-based progress bars and accurate text synchronization
- **Native background processing** via WorkManager for uploads that survive app kill
- **Crash resilience** with automatic recovery of interrupted uploads
- **Single notification service** that persists across app restarts with progress indicators
- **Strict FIFO queue order** preserved even across app restarts
- **Proactive native-status checking** every 15 seconds to detect completion without callbacks
- **Concurrent callback guard** preventing duplicate server requests

### ✅ Core Improvements Implemented
- **Buffer optimization** increased from 8KB to 64KB for better multi-GB video performance
- **Polling frequency** reduced from 5s to 1s for smoother UI updates
- **Native task recovery** on app restart with workerId preservation
- **Stale reset handling** for stuck uploads (>10 min in 'uploading' status)
- **Idempotent server callbacks** to avoid duplicate lesson creation
- **Resource link protection** with error handling for external URL launches
- **Crash-resistant navigation** with try-catch guards around video playback

### ✅ User Experience Features
- **Smart progress display** logic with correct text/bar synchronization:
  - `isActiveUpload && progress > 0` → determinate bar + "Uploading X%"
  - `isActiveUpload && progress == 0` → indeterminate bar + "Preparing..."
  - `!isActiveUpload && pending.uploadStatus == 'uploading'` → indeterminate bar + "Processing..."
  - `pending.uploadStatus == 'completed'` → full bar + "Upload complete"
  - `pending.uploadStatus == 'failed'` → indeterminate bar + "Upload failed"
- **Upload queue notifications** that provide persistent feedback during processing
- **ToastService integration** for user feedback on upload successes and failures

### ✅ File Management
- **File size handling** with automatic retries and proper cleanup
- **Presigned URL refresh** to handle expired URLs during queue waiting
- **Storage optimization** with WAL checkpointing every 200 progress ticks
- **Native database integration** via background_downloader for progress persistence

## Getting Started

1. `flutter pub get`
2. `flutter run`

## Testing

No tests currently exist.

## Documentation

- `API_EXPLANATION.md` — API integration patterns & flows
- `API_IMPLEMENTATION_GUIDE.md` — Implementation guide

## Key Implementation Details

The video upload system is built around several key components:

1. **UnifiedUploadQueueProvider**: Manages the upload queue, handles native callbacks, and processes items using FIFO order
2. **BackgroundUploaderService**: Handles native background uploads using WorkManager
3. **UploadQueueRepository**: SQLite-based persistence for upload state
4. **ModuleCard/_PendingLessonRow**: UI components that show accurate progress and status
5. **manage_module_screen.dart**: Screen with crash-resistant navigation and error handling

The system was enhanced through session-wide improvements covering native integration, callback management, progress tracking, and crash recovery scenarios.