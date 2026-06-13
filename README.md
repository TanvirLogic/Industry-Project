# Eduverse — Modern EdTech Mobile Application

Eduverse is a production-grade EdTech platform built with Flutter, featuring a complete authentication ecosystem, user/mentor profiles with avatar upload, course management, video playback, mentor dashboard, ad campaigns, and a Clean Architecture foundation backed by a Node.js REST API.

## Architecture: Feature-First Clean Architecture

Feature-first Clean Architecture with three layers per feature, plus a shared global core.

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
│   └── posts/             # (placeholder for future social post feature)
└── global/core/
    ├── config/            # AppConfig (baseUrl, googleClientId, timeout)
    ├── constants/         # Image asset paths, text colors
    ├── data/              # BaseRepository, BaseRemoteDataSource mixins
    ├── di/                # ProviderSetup (centralized DI with ProxyProvider)
    ├── error/             # Failure classes (Equatable)
    ├── routes/            # AppRoutes (25 named routes + onGenerateRoute)
    ├── services/          # LoggerService, ToastService, SecureStorage, AppPreferences,
    │                      # AuthHttpClient (401 interceptor), TokenService, NotificationService
    ├── theme/             # AppTheme (light + dark, Urbanist font)
    └── widgets/           # Shared widgets (SvgImage, etc.)
```

### Tech Stack

| Technology | Usage |
|------------|-------|
| Flutter / Dart SDK ^3.11.1 | Framework |
| Provider (ChangeNotifier + ProxyProvider) | State Management & DI |
| dartz (Either<Failure, Type>) | Functional error handling |
| http | REST API client |
| flutter_secure_storage | Token persistence |
| shared_preferences | Email caching & preferences |
| google_sign_in | Google OAuth |
| flutter_svg | SVG icon rendering |
| google_fonts (Urbanist w500/w600) | Typography |
| image_picker | Avatar/cover image selection |
| image_cropper | Avatar/cover crop UI |
| media_kit + media_kit_video | Video playback (mpv/FFmpeg native decoders) |
| media_kit_libs_android_video | Native mpv libraries for Android |
| flutter_local_notifications | Push notification display |
| logger | API request/response logging |
| equatable | Value equality for entities & failures |
| cached_network_image | Image caching (NetworkImage replacement) |
| url_launcher | Open external links |

## Features

### Authentication (10 API Endpoints)

Complete auth lifecycle managed by **3 focused providers**:

| Provider | Responsibilities |
|----------|-----------------|
| `AuthProvider` | Login, Register, Logout, Google Sign-In, Token Refresh, role persistence |
| `EmailVerificationProvider` | Verify email OTP, resend code, 30s honest cooldown timer |
| `PasswordResetProvider` | Forgot password, verify reset OTP, reset password, 30s timer |

| Endpoint | Description |
|----------|-------------|
| `POST auth/login` | Authenticate user, returns tokens + role |
| `POST auth/register` | Create account (phone optional, omitted from payload when empty) |
| `POST auth/verify-email` | Activate account with 6-digit OTP, returns tokens |
| `POST auth/resend-email-verification` | Resend OTP with 30s cooldown |
| `POST auth/refresh` | Swap refresh token for new pair |
| `POST auth/logout` | Server-side session invalidation |
| `POST auth/forgot-password` | Request password reset code |
| `POST auth/verify-reset-otp` | Validate password reset OTP |
| `POST auth/reset-password` | Set new password |
| `POST auth/google` | Google Sign-In with role (STUDENT/MENTOR) |

**Key behaviors:**
- **Login auto-fill:** Dual-layer strategy — SharedPreferences cache + route arguments
- **Unverified redirect:** EMAIL_NOT_VERIFIED on login → auto-redirect to verification page
- **Smart registration errors:** Email-already-exists → field-level validation with auto-focus + conditional login button
- **Name auto-capitalization:** Real-time formatting with cursor preservation
- **Auto-login:** Splash screen silently refreshes tokens on startup
- **Role-based routing:** STUDENT → `/profile`, MENTOR → `/mentor-profile`
- **AuthHttpClient:** Automatic 401 interception with coalesced concurrent token refresh

### User Profiles (Student & Mentor)

| Feature | Student | Mentor |
|---------|---------|--------|
| Profile view | `/profile` — card layout | `/mentor-profile` — hero banner layout |
| API endpoint | `GET/PUT profile/me` | `GET/PUT profile/me` |
| Avatar upload | Presigned S3 URL → stream upload → confirm | Same flow |
| Cover photo | Support (editable) | Support (editable) |
| Bio | 80 char max | 300 char max |
| Videos | Horizontal scrollable list with inline playback | Same |
| Courses | Completed courses list | Completed courses with Manage Module button |
| Social links | Dynamic add/remove with swipe-to-delete | Same |
| Edit | `/edit-profile` form | Same (via MentorProfileProvider) |

### Avatar & Cover Upload

4-step upload flow via presigned S3 URLs:
1. Pick image (512×512 avatar / 1200×400 cover) via `image_picker`
2. Crop (1:1 square for avatar / 16:9 for cover) via `image_cropper`
3. Get presigned upload URL from API
4. Upload file directly to S3 via HTTP PUT in 64KB chunks with progress tracking

### Course Management

| Page | Purpose | Status |
|------|---------|--------|
| `/course-details` | Course overview with tabs (Overview/Module/Reviews) + enrollment bar | ⚠️ Mock data |
| `/enrolled-course` | Enrolled course with progress bar + lesson list | ⚠️ Mock data |
| `/upload-course-page` | Create course form (title, desc, thumbnail, intro video, level, price, status) | ❌ UI only |
| `/upload-video-page` | Upload video with title | ❌ UI only |
| `/manage-module` | Add/rename modules, add video/resource lessons | ⚠️ UI mostly |
| `/payment-success` | Post-enrollment success confirmation | ❌ Static mock |

### Hub (Settings & Dashboard)

| Page | Purpose |
|------|---------|
| `/` (Hub tab) | Settings menu: profile, password/security, dashboard, payments, ads, dark mode, notifications |
| `/password-and-security` | Change password + change email |
| `/mentor-dashboard` | Balance banner, metrics, course accordions with earnings |
| `/payments-and-revenue` | Transaction history with filters |
| `/ads-manager` | Ad campaign list with active/completed filters |
| `/ads-create` | Create ad campaign (title, type, budget, CTA) |

### Video Playback

- **Engine:** `media_kit` (mpv/FFmpeg native decoders, replaces ExoPlayer/Media3)
- **Full-screen player:** `VideoPlayerScreen` with play/pause, 10s skip, progress slider, auto-hide controls
- **Inline player:** `VideosHorizontalListView` in profile pages — tap to play, fullscreen button, auto-hide controls
- **Format support:** MP4, MOV, WebM, AVI, MKV via native decoders

### Notifications

- **Local notifications:** `flutter_local_notifications` for test/demo notifications
- **In-app list:** `/notifications` page with sample notifications (mock data)
- **Entry:** Bell icon in Courses page header (tap → in-app page, long-press → system notification)

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

## Dependency Injection (16+ Providers, 18+ Use Cases)

Layered `ProxyProvider` chain in `ProviderSetup`:

```
http.Client
  → AuthHttpClient (401 interceptor)
  → AuthRemoteDataSource, StudentRemoteDataSource, MentorRemoteDataSource,
     AvatarRemoteDataSource, CoursesRemoteDataSource
  → AuthRepository, StudentRepository, MentorRepository, AvatarRepository, CoursesRepository
  → 18+ Use Cases
  → 8 UI Providers + ThemeProvider + ChangePasswordProvider
```

## API Configuration

- **Base URL:** `http://108.181.195.154:3000/api/v1/` (`AppConfig.baseUrl`)
- **Timeout:** 30 seconds (`AppConfig.requestTimeout`)
- **Response format:** Standardized JSON envelope — `{success, statusCode, message, data, errors}`

## Getting Started

1. `flutter pub get`
2. `flutter run`

## Testing

- Widget tests for `StudentProfilePage` (loading, error, data states)
- Test fixtures in `test/fixtures/profile_fixtures.dart`

## Documentation

- `AI_CODING_GUIDE.md` — Architecture patterns & conventions for feature implementation
- `common_design.md` — UI design system (colors, typography, components)
- `API_IMPLEMENTATION_GUIDE.md` — API integration patterns & recipes
- `project_performance_planner.md` — Performance optimizations, feature roadmap, background upload architecture
