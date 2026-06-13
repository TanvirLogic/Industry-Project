# Restoration Plan — Full Functional Equality with Last GitHub Repo

## Goal
Restore every screen, API call, provider, widget, and piece of functionality so the current project works **identically** to the last commit on `origin/main` (`git@github.com:webdevelopermaruf/eduverse.git`).

---

## 1. Course Upload — FULLY MISSING (Highest Priority)

The remote had a fully functional course upload flow. The local has UI-only shells.

### Files to Restore (create at `lib/features/courses/`)

| # | File | Source |
|---|---|---|
| 1.1 | `lib/features/courses/providers/course_upload_provider.dart` | Remote `lib/features/courses/upload/presentation/providers/course_upload_provider.dart` |
| 1.2 | `lib/features/courses/presentation/screens/upload_course_screen.dart` | Remote `lib/features/courses/upload/presentation/pages/upload_course_page.dart` |
| 1.3 | `lib/features/courses/presentation/widgets/upload_zone.dart` | Remote `lib/features/courses/upload/presentation/widgets/upload_zone.dart` |

### What the remote CourseUploadProvider does:
- Multi-step upload: get presigned URLs → upload thumbnail to S3 → optionally upload video to S3 → create course
- Progress tracking via `_uploadProgress` and `notifyListeners()`
- Cancel support via `cancel()` method
- Image picker for thumbnail (`pickThumbnail()`)
- Video picker (`pickVideo()`)
- `uploadCourse()` method with form data (title, description, shortDescription, requirements, language, level, type, price)

### What the remote upload_course_page.dart does:
- Form with title, short description, description, requirements fields
- Language dropdown (English, Bangla, Spanish, Arabic, Hindi)
- Thumbnail picker (connects to provider's `pickThumbnail()`)
- Video upload zone (connects to provider's `pickVideo()`)
- Level dropdown (BEGINNER, INTERMEDIATE, ADVANCED)
- Type radio (FREE / PAID) with conditional price field
- Submit button with progress text (e.g., "Uploading image 45%")
- Cancel Upload button
- On success: navigate to home, then push `/manage-module` with courseId

### API Endpoints Needed (add to `lib/app/urls.dart`):
```dart
static const String courseAssetsUploadUrl = '$_baseUrl/course/assets/upload';
static const String createCourseUrl = '$_baseUrl/course';
```

### Dependencies Required (add to `pubspec.yaml`):
- `http` (already present) — for S3 `StreamedRequest` upload
- `image_picker` (already present) — for thumbnail/video selection

### Register Provider in `lib/app/app.dart`:
```dart
ChangeNotifierProvider(create: (_) => CourseUploadProvider()),
```

---

## 2. Auth Screens — Verify Provider Mapping

Remote used a combined `AuthProvider` for login, register, Google sign-in, token refresh.
Local splits into `SignInProvider` + `SignUpProvider` + `VerifyOtpProvider` + `PasswordResetProvider`.

### Mapping to verify:

| Remote File | Local File | Status |
|---|---|---|
| `auth/presentation/pages/login_page.dart` | `auth/presentation/screens/sign_in_screen.dart` | Uses `SignInProvider` ✓ |
| `auth/presentation/pages/register_page.dart` | `auth/presentation/screens/sign_up_screen.dart` | Uses `SignUpProvider` ✓ |
| `auth/presentation/pages/verification_page.dart` | `auth/presentation/screens/verify_otp_screen.dart` | Uses `VerifyOtpProvider` ✓ |
| `auth/presentation/pages/forgot_password_page.dart` | `auth/presentation/screens/forgot_password_screen.dart` | Uses `PasswordResetProvider` ✓ |
| `auth/presentation/pages/set_new_password_page.dart` | `auth/presentation/screens/set_new_password_screen.dart` | Uses `PasswordResetProvider` ✓ |
| `auth/presentation/pages/password_success_page.dart` | `auth/presentation/screens/password_success_screen.dart` | Uses `SignInProvider` ✓ |
| `auth/presentation/pages/reset_verification_page.dart` | `auth/presentation/screens/reset_verification_screen.dart` | Uses `PasswordResetProvider` ✓ |

### AuthProvider methods that were split:
| Remote AuthProvider Method | Local Equivalent | Location |
|---|---|---|
| `login()` | `signIn()` | `sign_in_provider.dart` |
| `register()` | `signUp()` | `sign_up_provider.dart` |
| `logout()` | `logout()` | `sign_in_provider.dart` |
| `signInWithGoogle()` | `getGoogleIdToken()` + `completeGoogleSignIn()` | `sign_in_provider.dart` |
| `tryRefreshToken()` | `tryRefreshToken()` | `sign_in_provider.dart` |
| `getUserRole()` | `AuthController.userModel?.isMentor` | replaced with direct check |

---

## 3. Auth HTTP Header — Already Fixed

| File | Change |
|---|---|
| `lib/app/setup_network_caller.dart` | Changed `'token': AuthController.accessToken` → `'Authorization': 'Bearer ${AuthController.accessToken}'` ✓ |

---

## 4. Auto-Login / Splash Screen — Already Fixed

| File | Change |
|---|---|
| `lib/features/auth/presentation/screens/splash_screen.dart` | Added `await AuthController.getUserData()` before `tryRefreshToken()` ✓ |
| `lib/features/auth/providers/sign_in_provider.dart` | Removed wrong `?? AuthController.accessToken` fallback in `tryRefreshToken()` ✓ |

---

## 5. Screens That Need Content Parity Check

### 5.1 Edit Profile
| Remote | Local |
|---|---|
| `lib/features/profile/edit/presentation/profile_editing_page.dart` | `lib/features/profile/edit/presentation/screens/profile_editing_screen.dart` |
| `lib/features/profile/edit/presentation/widgets/social_link_form_block_ui.dart` | (check if exists locally) |
| `lib/features/profile/student/presentation/providers/edit_profile_provider.dart` | `lib/features/student/providers/edit_profile_provider.dart` |

**Action**: Verify remote `profile_editing_page.dart` has all functionality present in local `profile_editing_screen.dart`. If not, port missing pieces.

### 5.2 Hub Page
| Remote | Local |
|---|---|
| `lib/features/hub/presentation/pages/hub_page.dart` | `lib/features/hub/presentation/screens/hub_screen.dart` |

**Action**: Remote uses `AuthProvider.getUserRole()` + `AuthProvider.logout()`. Local uses `AuthController.userModel?.isMentor` + `SignInProvider.logout()`. Verify equivalence.

### 5.3 Manage Module
| Remote | Local |
|---|---|
| `lib/features/courses/manage/presentation/pages/manage_module_page.dart` | `lib/features/courses/presentation/screens/manage_module_screen.dart` |
| `lib/features/courses/manage/presentation/pages/upload_video_page.dart` | `lib/features/courses/presentation/screens/upload_video_screen.dart` |

**Action**: Compare for functional differences. Remote manage_module_page was 519 lines vs local 476 — similar but needs verification.

### 5.4 Main Nav Shell / Social / Notifications
| Remote | Local |
|---|---|
| `lib/features/home/presentation/pages/main_nav_shell.dart` | Same path — verify diff |
| `lib/features/social/presentation/pages/social_page.dart` | Same path — verify diff |
| `lib/features/notifications/presentation/pages/notifications_page.dart` | Same path — verify diff |

### 5.5 Course Detail & Enrolled Course Providers
Remote used constructor injection with use cases:
```dart
ChangeNotifierProvider(
  create: (context) => CourseDetailProvider(
    getCourseDetailsUseCase: context.read<GetCourseDetailsUseCase>(),
  ),
),
```

Local uses parameterless constructor:
```dart
ChangeNotifierProvider(create: (_) => CourseDetailProvider()),
```

**Action**: Verify local `CourseDetailProvider` and `EnrolledCourseProvider` fetch data correctly via `getNetworkCaller()` without requiring use cases.

---

## 6. Widget Files to Compare

| Remote | Local | Action |
|---|---|---|
| `lib/global/core/widgets/auth_button.dart` | Same path | Verify diff (remote 2222ch vs local 2048ch) |
| `lib/global/core/services/toast_service.dart` | Same path | Verify diff (remote 4882ch vs local 4720ch) |

---

## 7. API Endpoints Complete Inventory

### From Remote (`lib/global/core/config/app_config.dart`):
```
Base URL: http://108.181.195.154:3000/api/v1/
Google Client ID: 914828544219-v3sbd8bcui352873r4teffmcme2dtmqs.apps.googleusercontent.com
```

### From Remote (`lib/features/auth/data/datasources/auth_endpoints.dart`):
| Endpoint | Method |
|---|---|
| `auth/login` | POST |
| `auth/register` | POST |
| `auth/verify-email` | POST |
| `auth/resend-email-verification` | POST |
| `auth/refresh` | POST |
| `auth/logout` | POST |
| `auth/forgot-password` | POST |
| `auth/verify-reset-otp` | POST |
| `auth/reset-password` | POST |
| `auth/change-password` | POST |
| `auth/google` | POST |

### From Remote (`lib/features/courses/upload/data/datasources/course_upload_data_source.dart`):
| Endpoint | Method |
|---|---|
| `course/assets/upload` | POST |
| `course` | POST |

### Local `lib/app/urls.dart` already has ALL auth endpoints + profile endpoints.

**Missing from local** `urls.dart` (already added ✓):
- `course/assets/upload` → `Urls.courseAssetsUploadUrl`
- `course` → `Urls.createCourseUrl`

---

## 8. Files Deleted From Remote That Had Clean Architecture Code

These are NOT needed to restore — they were Clean Architecture boilerplate that was intentionally removed:

- All `data/datasources/*.dart` (replaced by direct `NetworkCaller` calls)
- All `data/repositories/*.dart` (same)
- All `domain/repositories/*.dart` (same)
- All `domain/usecases/*.dart` (same)
- `lib/global/core/data/base_remote_data_source.dart`
- `lib/global/core/data/base_repository.dart`
- `lib/global/core/error/failures.dart`
- `lib/global/core/usecase/usecase.dart`
- `lib/global/core/services/token_service.dart`
- `lib/global/core/services/secure_storage.dart`
- `lib/global/core/services/app_preferences.dart`
- `lib/global/core/services/auth_http_client.dart`
- `lib/global/core/services/notification_service.dart`
- `lib/global/core/di/provider_setup.dart`
- `lib/global/core/theme/app_theme.dart` (moved to `lib/app/app_theme.dart`)
- `lib/global/core/theme/theme_provider.dart` (moved to `lib/app/providers/theme_provider.dart`)
- `lib/global/core/routes/app_routes.dart` (moved to `lib/app/app_routes.dart`)

---

## 9. Verification Checklist

After all restoration, verify:

- [ ] `flutter analyze` — 0 errors, 0 warnings
- [ ] Login / Register / Google Sign-in works
- [ ] Auto-login (splash → refresh token → home) works
- [ ] Profile pages (student + mentor) load from API
- [ ] Edit profile saves changes
- [ ] Avatar upload (gallery + crop → S3 upload → confirm) works
- [ ] Cover photo upload works
- [ ] Course list loads from API
- [ ] Course details load from API
- [ ] Enrolled courses load from API
- [ ] **Course upload — full flow**: thumbnail picker → form submit → S3 upload → create course → navigate to manage module
- [ ] Password change works
- [ ] Forgot password / reset password flow works
- [ ] Hub page shows correct role-based UI
- [ ] Notifications page loads
- [ ] Social page renders
- [ ] Main navigation (bottom nav) works across all tabs
- [ ] Theme toggle (dark/light) persists
- [ ] Logout clears session and redirects to login
