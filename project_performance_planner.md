# Project Performance Planner — Eduverse

> Use this document when adding features, integrating APIs, or refactoring. It describes
> the app's current performance posture and the patterns to follow so the app stays smooth.

---

## 1. Current Architecture Overview

| Aspect | Current State |
|--------|---------------|
| State Management | Provider (ChangeNotifier + ProxyProvider) via `ProviderSetup` |
| Networking | `http` package, singleton `http.Client`, `AuthHttpClient` wraps/ intercepts 401s |
| HTTP Timeout | 30s (`AppConfig.requestTimeout`) |
| Retry | 401 token refresh only — no retry for timeouts / 5xx |
| Image Loading | Raw `NetworkImage` / `Image.network` — **no cache** |
| SVG Rendering | `flutter_svg` `SvgPicture.asset` used everywhere |
| JSON Parsing | Synchronous `json.decode` / `json.encode` on main isolate |
| App Lifecycle | **Not handled** — no `WidgetsBindingObserver` |
| Scrollables | Mix of builder / non-builder — acceptable for current data sizes |
| Controllers | `TextEditingController` / `FocusNode` — **all disposed** ✅ |
| Code Splitting | None — all routes eagerly imported |
| Tab Pages | `IndexedStack` — all 4 pages always in memory |
| Mock Data Prevalence | **Heavy** — 5+ modules use hardcoded mock data with no API integration |
| Background Upload | **Not supported** — all uploads are foreground-only, block UI thread |
| Video Player | `media_kit` for inline & full-screen — exists but **not wired** to any page navigation |
| Payment Gateway | **None** — no Stripe/SSLCommerz/bKash SDK; success page is static mock |
| Push Notifications | Local only (`flutter_local_notifications`) — **no FCM** |
| Course/Video Upload | **UI only** — UploadCoursePage and UploadVideoPage have no file picker, no provider, no API calls |
| Ads Infrastructure | **UI only** — AdsManagerPage and AdsCreatePage with hardcoded data, no API or ad SDK |

### Complete Page Inventory (25 routes)

| # | Route | Page | Status |
|---|-------|------|--------|
| 1 | `/` | `SplashPage` | ✅ Working — auto-login via token refresh |
| 2 | `/login` | `LoginPage` | ✅ Working — email/password + Google OAuth |
| 3 | `/register` | `RegisterPage` | ✅ Working — full form with role selection |
| 4 | `/forgot-password` | `ForgotPasswordPage` | ✅ Working — sends OTP to email |
| 5 | `/verification` | `VerificationPage` | ✅ Working — 6-digit email OTP |
| 6 | `/reset-verification` | `ResetVerificationPage` | ✅ Working — OTP for password reset |
| 7 | `/reset-password` | `SetNewPasswordPage` | ✅ Working — new password form |
| 8 | `/password-success` | `PasswordSuccessPage` | ✅ Working — success screen |
| 9 | `/home` | `MainNavShell` | ✅ Working — 4-tab shell (Social/Post/Courses/Hub) |
| 10 | `/profile` | `StudentProfilePage` | ✅ Working — real API data |
| 11 | `/mentor-profile` | `MentorProfilePage` | ✅ Working — real API data |
| 12 | `/edit-profile` | `EditProfilePage` | ✅ Working — saves via API |
| 13 | `/password-and-security` | `PasswordAndSecurityPage` | ✅ Working — change password/email via API |
| 14 | `/payments-and-revenue` | `PaymentsAndRevenuePage` | ⚠️ **Mock data** — no API integration |
| 15 | `/mentor-dashboard` | `MentorDashboardPage` | ⚠️ **Mock data** — no API integration |
| 16 | `/full-screen-image` | `FullScreenImageViewer` | ✅ Working — hero animation image viewer |
| 17 | `/upload-video-page` | `UploadVideoPage` | ❌ **UI only** — no file picker, no API |
| 18 | `/upload-course-page` | `UploadCoursePage` | ❌ **UI only** — no file picker, no API |
| 19 | `/course-details` | `CourseDetailsPage` | ⚠️ **Mock data** — mock course data |
| 20 | `/enrolled-course` | `EnrolledCoursePage` | ⚠️ **Mock data** — mock course data |
| 21 | `/payment-success` | `PaymentSuccessPage` | ❌ **Static mock** — no payment gateway |
| 22 | `/notifications` | `NotificationsPage` | ⚠️ **Mock data** — hardcoded sample notifications |
| 23 | `/manage-module` | `ManageModulePage` | ⚠️ **UI mostly** — drag-and-drop module/lesson reorder + serialization ready |
| 24 | `/ads-manager` | `AdsManagerPage` | ❌ **UI only** — hardcoded campaigns, no API |
| 25 | `/ads-create` | `AdsCreatePage` | ❌ **UI only** — no file picker, no payment |

### Feature Implementation Status

| Feature Area | Student | Mentor | Backend API |
|-------------|---------|--------|-------------|
| **Profile View** | ✅ `StudentProfilePage` | ✅ `MentorProfilePage` | `GET profile/me` |
| **Profile Edit** | ✅ via `EditProfileProvider` | ✅ via `MentorProfileProvider` | `PUT profile/me` |
| **Avatar Upload** | ✅ S3 presigned + stream | ✅ Same flow | `POST profile/avatar/upload-url` + `PUT profile/avatar/confirm` |
| **Cover Upload** | ✅ Same pattern | ✅ Same flow | `POST profile/cover/upload-url` + `PUT profile/cover/confirm` |
| **Course View** | ⚠️ Mock data | ⚠️ Mock data | `GET course/:id` |
| **Enrolled Course** | ⚠️ Mock data | N/A | `GET enrolled-course/:id` |
| **Course Upload** | ❌ UI only | ❌ UI only | Not integrated |
| **Video Upload** | ❌ UI only | ❌ UI only | Not integrated |
| **Module Management** | N/A | ⚠️ UI mostly | Not fully integrated |
| **Payment** | ❌ Static mock | ❌ Static mock | No gateway SDK |
| **Revenue/Transactions** | N/A | ⚠️ Mock data | Not integrated |
| **Mentor Dashboard** | N/A | ⚠️ Mock data | Not integrated |
| **Ads Campaigns** | ⚠️ UI only | ⚠️ UI only | Not integrated |
| **Video Playback** | ✅ media_kit player exists | ✅ Same | 🔌 Not wired to any page |
| **Social Feed** | ⚠️ UI with search | N/A | Not integrated |
| **Notifications** | ⚠️ Mock data | ⚠️ Mock data | No FCM / push |
| **Auth (login/register/reset)** | ✅ Complete | ✅ Complete | Fully integrated |
| **Google Sign-In** | ✅ Complete | ✅ Complete | Fully integrated |
| **Password Change** | ✅ Complete | ✅ Complete | `POST auth/change-password` |
| **Dark Mode** | ✅ Complete | ✅ Complete | Persisted locally |

---

## 2. Prioritized Action Items

### P0 — Must Fix Before Production

#### 2.1 Add image caching via `cached_network_image` ✅ COMPLETED

`cached_network_image: ^3.4.1` is already in `pubspec.yaml` and actively used across 10+ files
(profile avatars, cover photos, course thumbnails, video thumbnails, review avatars).
All previously identified `NetworkImage`/`Image.network` usages have been migrated to
`CachedNetworkImageProvider`/`CachedNetworkImage`. No further action needed.

---

#### 2.2 Fix `SvgImage` widget — use `SvgPicture.asset` instead ✅ COMPLETED

The custom `SvgImage` widget (`lib/global/core/widgets/svg_image.dart`) has been removed.
All SVG rendering now uses `SvgPicture.asset()` from `flutter_svg` directly.

---

#### 2.3 Fix `Provider.of<AuthProvider>(context)` without `listen: false` in `register_page.dart:151`

This causes the **entire 600-line registration form** to rebuild on every `AuthProvider` state
change (loading spinner, validation errors, etc.).

```dart
// BAD — line 151:
final authProvider = Provider.of<AuthProvider>(context);

// GOOD:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
```

Then wrap only the parts that need to react (submit button loading state, error text) in
`Consumer<AuthProvider>` instead.

---

#### 2.4 Add app lifecycle handling via `WidgetsBindingObserver`

The app has no lifecycle awareness. A global observer should be added to:

- Refresh tokens when the app resumes from background.
- Pause/resume video playback.
- Save critical draft state (e.g., course upload form) on app pause.
- Clear sensitive data from memory when app is backgrounded.

**Files to create/update:**

| Action | Details |
|--------|---------|
| Create `lib/global/core/services/app_lifecycle_observer.dart` | Single `ChangeNotifier` that exposes `isPaused` / `isResumed` / `isDetached` |
| Register in `ProviderSetup._externalDependencies` | `Provider<AppLifecycleObserver>(create: (_) => AppLifecycleObserver()..start())` |
| Wire in `main.dart` | Wrap `MaterialApp` with `Consumer<AppLifecycleObserver>` to handle lifecycle |

**Pattern:**

```dart
class AppLifecycleObserver extends ChangeNotifier implements WidgetsBindingObserver {
  AppLifecycleState? _state;
  AppLifecycleState? get state => _state;

  void start() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    notifyListeners();
    if (state == AppLifecycleState.resumed) {
      // Trigger token refresh check
    } else if (state == AppLifecycleState.paused) {
      // Save drafts, pause videos
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

---

#### 2.5 Implement background upload infrastructure for course/video uploads

**Requirement**: Video uploads must continue when the app is backgrounded. Only initialization happens in-foreground.

**Architecture**:

```
┌─────────────────────────────────────────┐
│  Foreground                              │
│                                          │
│  1. User selects file (image_picker)     │
│  2. Request presigned S3 URL from API    │
│  3. Start foreground service notification│
│  4. Delegate upload to background isolate│
│  5. Show progress UI (0-100%)            │
└──────────────┬──────────────────────────┘
               │ app backgrounded
               ▼
┌─────────────────────────────────────────┐
│  Background Service                      │
│                                          │
│  - Continues uploading in chunks         │
│  - Shows persistent notification         │
│  - Handles network interruptions         │
│  - Stores upload state for resume        │
│  - Confirms upload with API on completion│
└─────────────────────────────────────────┘
```

**Implementation approach:**

| Step | Package | Details |
|------|---------|---------|
| 1 | `flutter_background_service` | Keep Dart isolate alive for upload continuation |
| 2 | `flutter_local_notifications` | Persistent "Uploading..." notification + progress |
| 3 | `workmanager` | Fallback for scheduling retry on failure |
| 4 | Existing S3 presigned URL pattern | Reuse `avatar_upload_provider.dart` streaming chunk logic |
| 5 | Upload state persistence | `shared_preferences` or SQLite for resume capability |

**Key behaviors:**

```dart
// ── Start background upload from foreground ──
Future<void> startUpload({
  required String filePath,
  required String presignedUrl,
  required String courseId,
}) async {
  // 1. Show foreground service notification
  await FlutterBackgroundService().startService();

  // 2. Send upload task to background isolate
  final task = UploadTask(
    filePath: filePath,
    presignedUrl: presignedUrl,
    chunkSize: 64 * 1024, // 64KB
    onProgress: (progress) {
      // Communicate progress back via MethodChannel or shared state
    },
  );

  // 3. Start upload in background
  await FlutterBackgroundService().invoke('upload', task.toMap());
}

// ── Background isolate handler ──
void onBackgroundStart(ServiceInstance service) {
  service.on('upload').listen((taskData) async {
    final task = UploadTask.fromMap(taskData);
    try {
      await task.execute(
        onProgress: (p) => service.invoke('progress', {'percent': p}),
      );
      // Confirm with API
      await api.confirmUpload(task.courseId);
      service.invoke('completed', {'courseId': task.courseId});
    } catch (e) {
      // Save for retry via workmanager
      await Workmanager().registerOneOffTask('retry_${task.id}', 'uploadRetry');
      service.invoke('failed', {'taskId': task.id, 'error': e.toString()});
    }
  });
}
```

**Files to create:**

| File | Purpose |
|------|---------|
| `lib/global/core/services/upload/upload_task.dart` | `UploadTask` model with chunked upload logic |
| `lib/global/core/services/upload/background_upload_service.dart` | `flutter_background_service` wrapper |
| `lib/features/courses/presentation/providers/course_upload_provider.dart` | Provider for course + video upload orchestration |
| `lib/features/courses/domain/usecases/upload_course_usecase.dart` | Use case for course creation + file upload |
| `lib/features/courses/data/datasources/courses_upload_data_source.dart` | Data source for presigned URL + confirm endpoints |

**Endpoints needed (backend):**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `POST courses/upload-url` | Get presigned upload URL | Returns `{uploadUrl, fileKey}` for video/course thumbnail |
| `PUT courses/confirm` | Confirm upload | Notify backend that upload completed |
| `POST courses/create` | Create course | Create course record with video/file references |
| `POST courses/video` | Add video to course/module | Link uploaded video to module |

---

#### 2.6 Wire video player to all navigation entry points

**Problem**: `VideoPlayerScreen` exists as a full-featured media_kit player but most pages don't navigate to it.

**Entry points to wire:**

| Source | Action | Status |
|--------|--------|--------|
| `video_list_section.dart` (profile videos) | Already has fullscreen button | ✅ Working |
| `social_page.dart` video cards | Tap video card → full-screen player | ❌ Not wired |
| `course_details_page.dart` intro video | Tap thumbnail → full-screen player | ❌ Not wired |
| `enrolled_course_page.dart` lesson videos | Tap lesson → full-screen player | ❌ Not wired |
| `manage_module_page.dart` lesson preview | Tap play icon → full-screen player | ❌ Not wired |

**Pattern:**

```dart
// In social_page.dart video card tap handler:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VideoPlayerScreen(
      videoUrl: video.videoUrl,
      title: video.title ?? 'Video',
    ),
  ),
);
```

---

#### 2.7 Connect course upload & video upload forms to real APIs

**Problem**: `UploadCoursePage` and `UploadVideoPage` are UI-only with no file picker, no provider, no API calls.

**Implementation plan:**

| Component | Current | Target |
|-----------|---------|--------|
| `upload_zone.dart` | Styled container with no file picker | Wire `image_picker` / `file_picker` to select video files |
| `UploadVideoPage` | Empty `onPressed` | Connect to `CourseUploadProvider` → presigned URL → background upload |
| `UploadCoursePage` | Empty `onPressed` | Connect to `CourseUploadProvider` → create course → upload thumbnail → upload intro video |
| `course_upload_provider.dart` | Doesn't exist | Create with `_isUploading`, `_progress`, `_error`, `uploadCourse()`, `uploadVideo()` |

---

#### 2.8 Integrate PayStation payment gateway (WebView-based)

**Current**: `PaymentSuccessPage` shows static mock data. No payment SDK or provider.

**Architecture (4-phase flow):**

```
┌──────────────────────────────────────────────────────────┐
│  Phase 1 — Setup (your backend)                          │
│                                                          │
│  Flutter → POST /payment/init {courseId} → NestJS         │
│  NestJS: check course exists, user not enrolled           │
│  NestJS → PayStation: get auth token                      │
│  NestJS → PayStation: create payment link                 │
│  NestJS: save PENDING payment record in DB                │
│  NestJS ← returns {paymentUrl, sessionId} to Flutter      │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  Phase 2 — User pays (PayStation WebView)                │
│                                                          │
│  Flutter opens paymentUrl in WebView                      │
│  User sees PayStation UI (bKash, Nagad, Rocket, card)    │
│  User completes payment — all UI handled by PayStation    │
└──────────────────────┬───────────────────────────────────┘
                       │ (PayStation callback)
                       ▼
┌──────────────────────────────────────────────────────────┐
│  Phase 3 — Verification (your backend)                   │
│                                                          │
│  PayStation → POST callback URL {status, invoice, txId}  │
│  NestJS → PayStation: verifyTransaction (never trust      │
│    callback alone)                                        │
│  If verified SUCCESS:                                     │
│    - Update payment record to COMPLETED                   │
│    - Enroll student in course                             │
│    - Credit 75% to mentor's wallet                        │
│  Redirect to deep link: eduverse://payment/success        │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  Phase 4 — Return to app                                 │
│                                                          │
│  Flutter WebView catches eduverse://payment/success       │
│  → Closes WebView                                        │
│  → Navigates to enrolled course page                     │
└──────────────────────────────────────────────────────────┘
```

**Key difference from typical SDK approach:** No Flutter payment SDK is needed. The backend drives all PayStation communication. Flutter only needs to:
1. Call `POST /payment/init` to get the payment URL.
2. Open that URL in a `WebView`.
3. Catch the `eduverse://payment/success` deep link to know when to close the WebView.
4. Navigate to the course page.

**No payment UI to build** — PayStation handles all payment method selection and processing.

---

**Implementation steps:**

| Step | File / Change | Details |
|------|--------------|---------|
| 1 | Add `webview_flutter` to pubspec | `webview_flutter: ^4.x` — used only for PayStation payment page; no other WebView use case expected |
| 2 | Create `lib/features/courses/presentation/pages/payment_webview_page.dart` | Full-screen WebView that loads `paymentUrl`, intercepts `eduverse://` deep links via `NavigationDelegate`, and pops with result on success |
| 3 | Create `lib/features/courses/presentation/providers/payment_provider.dart` | `PaymentProvider` with `initiatePayment(courseId)` → calls API → returns `{paymentUrl, sessionId}` → opens WebView page |
| 4 | Create `lib/features/courses/domain/usecases/initiate_payment_usecase.dart` | `InitiatePaymentUseCase` — sends course ID to backend, returns payment session |
| 5 | Create `lib/features/courses/domain/usecases/check_enrollment_usecase.dart` | `CheckEnrollmentUseCase` — poll or GET call to check if enrollment completed after payment |
| 6 | Create `lib/features/courses/data/datasources/payment_remote_data_source.dart` | API calls: `POST payment/init` |
| 7 | Wire enrollment check in `course_details_page.dart` | "Enroll Now" / "Buy" button → `PaymentProvider.initiatePayment(courseId)` → WebView → deep link → navigate to `EnrolledCoursePage` |
| 8 | Update `PaymentSuccessPage` | Either remove or repurpose as a post-payment confirmation page shown after deep link handling |

---

**PaymentWebViewPage pattern:**

```dart
class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String sessionId;
  const PaymentWebViewPage({required this.paymentUrl, required this.sessionId});
  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          // Catch eduverse:// deep link → payment success
          if (request.url.startsWith('eduverse://payment/success')) {
            Navigator.pop(context, true); // close WebView with success
            return NavigationDecision.prevent;
          }
          if (request.url.startsWith('eduverse://payment/failed')) {
            Navigator.pop(context, false); // close WebView with failure
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

---

**PaymentProvider pattern:**

```dart
class PaymentProvider extends ChangeNotifier {
  bool _isProcessing = false;
  String? _errorMessage;

  Future<bool> initiatePayment(BuildContext context, String courseId) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    final result = await initiatePaymentUseCase(InitiatePaymentParams(courseId: courseId));
    return result.fold(
      (failure) {
        _isProcessing = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (session) async {
        _isProcessing = false;
        notifyListeners();
        // Open WebView
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewPage(
              paymentUrl: session.paymentUrl,
              sessionId: session.sessionId,
            ),
          ),
        );
        if (success == true) {
          // Optionally verify enrollment on the course page
          return true;
        }
        return false;
      },
    );
  }
}
```

---

**Endpoint needed (backends):**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `POST payment/init` | Initiate payment | Returns `{paymentUrl, sessionId}` after NestJS sets up PayStation session |
| `POST payment/verify` | Verify transaction | Called by NestJS → PayStation to confirm payment before enrolling |
| `GET payment/history` | Transaction history | For `PaymentsAndRevenuePage` |
| `GET mentor/revenue` | Mentor earnings | For `MentorDashboardPage` |

**Deep link scheme:**

| Deep Link | Meaning | Flutter Action |
|-----------|---------|---------------|
| `eduverse://payment/success?sessionId=xxx` | Payment confirmed | Close WebView, navigate to enrolled course |
| `eduverse://payment/failed?sessionId=xxx` | Payment failed/cancelled | Close WebView, show error message |
| `eduverse://payment/cancel` | User cancelled | Close WebView silently |

**Deep link note:** These are intercepted by `NavigationDelegate` inside the WebView, not by the OS. No Android/iOS deep link configuration is needed for this flow.

---

**WebView constraints & edge cases:**

| Concern | Handling |
|---------|----------|
| User closes WebView before payment completes | Treat as cancellation — no enrollment happens; payment record stays PENDING on backend |
| WebView loads slowly / times out | `WebViewController` has no built-in timeout; wrap the WebView push with `Navigator.push` + a timeout timer that shows a "Still waiting..." dialog after 60s |
| User presses back during payment | Confirm dialog: "Are you sure you want to cancel payment?" |
| Deep link not received (callback race) | Add a polling fallback in the WebView: every 5 seconds after page load, check if the URL contains `success` or `failed` query params |
| Payment success but enrollment not visible | The enrolled course page should fetch enrollment status on load from `GET enrolled-course/:id`; if not enrolled yet, show a spinner and retry |

---

#### 2.9 Move JSON parsing off the main isolate for large payloads

`json.decode(response.body)` and `json.encode(body)` in `BaseRemoteDataSource` run
synchronously on the UI thread. For large profiles with videos + courses + social links,
this can cause frame drops.

**Fix**: Use `compute()` (from `flutter/foundation.dart`) for decoding:

```dart
// In BaseRemoteDataSource, add:
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> get(String endpoint, ...) async {
  final response = await client.get(...).timeout(AppConfig.requestTimeout);
  // Use compute for JSON parsing
  return await compute(_parseJson, response.body);
}

static Map<String, dynamic> _parseJson(String body) {
  return json.decode(body) as Map<String, dynamic>;
}
```

**Note**: Only needed if profiles routinely exceed ~50KB of JSON. Monitor with actual API
responses before implementing — premature optimization adds complexity.

---

### P1 — Should Fix Before Feature Growth

#### 2.10 Submit module/lesson serialized order to backend API

**Feature**: `ManageModulePage` now supports drag-and-drop reordering for both modules and
lessons (videos/resources). The current order is serialized via `getSerializedOrder()` which
returns a structured list of module/lesson IDs and sort positions.

**Next step**: When the user taps "Save" or exits edit mode, POST the serialized order to
the backend:

```dart
// Example payload for POST courses/:id/reorder
{
  "modules": [
    { "module_id": 1, "sort_order": 0, "lessons": [
      { "lesson_id": 5, "sort_order": 0 },
      { "lesson_id": 3, "sort_order": 1 }
    ]},
    { "module_id": 2, "sort_order": 1, "lessons": [
      { "lesson_id": 1, "sort_order": 0 }
    ]}
  ]
}
```

**Endpoint needed:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `PUT courses/:id/reorder` | Update module/lesson sort order | Accepts full ordering payload |

**Performance note**: `ReorderableListView` uses minimal rebuilds — only the moved item
and its new neighbors repaint. For large lists (>50 lessons), consider debouncing the
reorder callback to avoid excessive `setState` calls during rapid drags.

##### 2.10.1 Lesson row text wrapping (2 lines)

The lesson title inside the `Row` in `_ModuleCard` previously used unbounded width, causing
horizontal overflow on long titles. Fixed by wrapping the `GestureDetector(Text(...))` in an
`Expanded` widget and setting `maxLines: 2` with `TextOverflow.ellipsis`. The duration text
no longer needs a `Flexible` wrapper since the `Expanded` title takes all remaining space.

##### 2.10.2 Edit (pencil) icon triggers rename

Both the module header edit icon and the lesson row edit icon were static SVGs with no tap
handler. Wrapped each in a `GestureDetector` that calls `onShowRenameDialog`, matching the
behavior already present on the title text itself.

##### 2.10.3 Save button for drag-and-drop reorder

Added a `_hasUnsavedChanges` flag that is set to `true` whenever a module or lesson is
reordered via drag-and-drop. A "Save Changes" button appears above the "Add Module" button
in the bottom bar when the flag is `true`. Tapping "Save Changes":
1. Calls `getSerializedOrder()` to serialize the current module/lesson order.
2. Resets `_hasUnsavedChanges` to `false`.
3. Shows a `SnackBar` confirmation.

No API call is made until the user taps "Save Changes". The `_saveOrder` method is the
future integration point for `POST /courses/:id/reorder`.

---

#### 2.11 Add retry logic for transient network failures

Currently only 401s are retried. Timeouts, 5xx, and connection errors fail immediately.

**Approach 1** (recommended): Add retry in `BaseRemoteDataSource` with exponential backoff.

```dart
Future<Map<String, dynamic>> _retryableCall(
  Future<http.Response> Function() call,
  {int maxRetries = 2},
) async {
  for (var attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final response = await call().timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException catch (_) {
      if (attempt == maxRetries) rethrow;
      await Future.delayed(Duration(seconds: 1 << attempt)); // 1s, 2s
    } on TimeoutException catch (_) {
      if (attempt == maxRetries) rethrow;
      await Future.delayed(Duration(seconds: 1 << attempt));
    }
  }
  throw ServerFailure('Request failed after $maxRetries retries');
}
```

**Approach 2**: Use `retry` package for cleaner retry semantics.

---

#### 2.12 Extract inline `LinearGradient` and `TextStyle` objects to `const`

Multiple build methods recreate `LinearGradient` and `TextStyle` objects on every frame:

| Location | What |
|----------|------|
| `courses_page.dart` ~291-295 | `LinearGradient(colors: [0xFF2564EA, 0xFF134BBF])` |
| `course_details_page.dart` ~114-119 | LinearGradient for thumbnail overlay |
| `enrolled_course_page.dart` ~131-135 | LinearGradient for thumbnail overlay |
| ~~`auth_button.dart`~~ | ~~`LinearGradient` in every button build~~ ✅ Now uses solid `TextColor.appColor` — no gradient |
| All GoogleFonts usages in build | `GoogleFonts.urbanist(fontSize: ..., color: ...)` |

> **Note**: `auth_button.dart` was refactored from gradient to solid `TextColor.appColor`. The gradient extraction pattern below still applies to remaining gradient usages in course pages.

---

#### 2.13 Narrow `Consumer<T>` scope to prevent oversized rebuilds

Several pages wrap their entire body in a single `Consumer<T>`, causing the full page to
rebuild when any state changes.

| File | Current | Fix |
|------|---------|-----|
| `student_profile_page.dart` ~54 | `Consumer<StudentProfileProvider>` wraps entire `_ProfileBody` | Wrap only sections that depend on profile data (name, avatar, videos, courses). The page structure (titles, layout) shouldn't rebuild. |
| `mentor_profile_page.dart` ~64 | Same | Same |
| `course_details_page.dart` ~37 | `Consumer<CourseDetailProvider>` wraps entire body | Wrap only sections that depend on course data |
| `enrolled_course_page.dart` ~35 | Same | Same |
| `profile_editing_page.dart` ~269 | `Consumer<EditProfileProvider>` wraps entire form | Wrap only loading overlay and error text |
| `hub_page.dart` ~37-38 | `context.watch` for profile data rebuilds entire HubPage | Move to `Consumer` wrapping only `_HubHeader` |

---

#### 2.14 Replace mock data with real API integration (payments, dashboard, transactions)

**Pages using mock data:**

| Page | What's Mocked | Integration Priority |
|------|--------------|---------------------|
| `PaymentsAndRevenuePage` | All transactions (6 items), totals | P1 — needs `GET transactions/history` |
| `MentorDashboardPage` | Balance (৳32,688), metrics, course earnings | P1 — needs `GET mentor/revenue`, `GET mentor/courses/earnings` |
| `CourseDetailsPage` | Course details + reviews | P1 — needs `GET course/:id` |
| `EnrolledCoursePage` | Course progress + lessons | P1 — needs `GET enrolled-course/:id` |
| `NotificationsPage` | 7 sample notifications | P2 — needs `GET notifications` |
| `AdsManagerPage` | Campaign list + stats | P2 — needs `GET ads/campaigns` |
| `ManageModulePage` | Module/lesson structure | P2 — needs `GET course/:id/modules` |

---

### P2 — Fix When Time Permits

#### 2.15 Lazy-load tab pages instead of `IndexedStack`

`MainNavShell` uses `IndexedStack` which builds and keeps all 4 pages in memory.
For low-memory devices, consider strategy below.

**Option A**: Replace with `PageView` (no-op on tabs that aren't visible).

**Option B**: Keep `IndexedStack` but add `AutomaticKeepAliveClientMixin`-style
lazy initialization so expensive pages (HubPage with profile fetch) only load data
on first visit.

**Recommended**: Keep `IndexedStack` for now but ensure each page's `initState` is
minimal. The current approach is fine until the app has 6+ tabs or complex pages.

---

#### 2.16 Add shimmer / skeleton loading states for all API-driven pages

Currently, most pages show a `CircularProgressIndicator` while loading. Replace with
shimmer skeletons for a perceived-performance boost:

- `StudentProfilePage` — skeleton for header card + video row + course list
- `HubPage` — skeleton for header + settings groups
- `CoursesPage` — skeleton for course cards
- `SocialPage` — skeleton for posts

**Package**: `shimmer: ^3.0.0` (already commonly used with `cached_network_image`).

---

#### 2.17 Bypass `AuthHttpClient` for static assets / CDN images

The `AuthHttpClient` attaches a Bearer token to every outgoing request, including
`NetworkImage` requests to CDN URLs (avatars, course thumbnails, video posters).
This is unnecessary overhead and may cause CORS/preflight issues.

**Fix**: In `AuthHttpClient.send()`, add a bypass for known CDN domains:

```dart
static final _cdnDomains = RegExp(r'(cloudfront\.net|s3\.amazonaws\.com|unsplash\.com)');

@override
Future<http.StreamedResponse> send(http.BaseRequest request) {
  final url = request.url.toString();
  if (_cdnDomains.hasMatch(url)) {
    return _inner.send(request);
  }
  // ... normal auth flow
}
```

---

#### 2.18 Debounce search input in SocialPage

`social_page.dart` calls `setState` on every keystroke, rebuilding the entire page.
For search, add debouncing:

```dart
Timer? _debounce;

void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    // Trigger actual search
    setState(() => _searchQuery = query);
  });
}

@override
void dispose() {
  _debounce?.cancel();
  _searchController.dispose();
  super.dispose();
}
```

---

#### 2.19 Add FCM (Firebase Cloud Messaging) for push notifications

**Current**: Only local notifications via `flutter_local_notifications`. No push capability.

**Plan**:

| Step | Detail |
|------|--------|
| 1 | Add `firebase_messaging` + `firebase_core` to pubspec |
| 2 | Initialize Firebase in `main.dart` |
| 3 | Request notification permissions |
| 4 | Register FCM token with backend (`POST auth/register-device`) |
| 5 | Handle foreground messages (show local notification) |
| 6 | Handle background tap (navigate to notifications page) |
| 7 | Wire `onDidReceiveNotificationResponse` for local notification taps |

---

## 3. API Integration Patterns

Use these when implementing the full backend.

### 3.1 Data Fetching

```dart
// ── Provider method pattern ──
Future<void> fetchSomeData() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  final result = await someUseCase(Params(...));
  result.fold(
    (failure) {
      _isLoading = false;
      _errorMessage = failure.message;
      ToastService.showError(failure.message);
      notifyListeners();
    },
    (data) {
      _isLoading = false;
      _data = data;
      notifyListeners();
    },
  );
}
```

### 3.2 List Pagination

For any list that could grow beyond 50 items (courses, videos, reviews, posts):

```dart
class MyListProvider extends ChangeNotifier {
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<Item> _items = [];

  Future<void> fetchInitial() async { ... }

  Future<void> fetchMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    final result = await fetchItemsUseCase(PageParams(page: _page + 1));
    result.fold(
      (failure) { /* handle error */ },
      (page) {
        _page++;
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _isLoadingMore = false;
        notifyListeners();
      },
    );
  }
}
```

### 3.3 Optimistic Updates

For toggles, likes, follows — update the UI immediately, then revert on failure:

```dart
Future<void> toggleLike(String postId) async {
  final index = _posts.indexWhere((p) => p.id == postId);
  if (index == -1) return;

  final original = _posts[index];
  _posts[index] = original.copyWith(isLiked: !original.isLiked);
  notifyListeners();

  final result = await toggleLikeUseCase(ToggleLikeParams(postId));
  result.fold(
    (failure) {
      _posts[index] = original; // revert
      notifyListeners();
      ToastService.showError(failure.message);
    },
    (_) { /* keep optimistic update */ },
  );
}
```

### 3.4 Caching Strategy

| Data Type | Cache Strategy | TTL |
|-----------|---------------|-----|
| User profile (own) | In-memory (provider) + pull-to-refresh | Session |
| Courses list | In-memory + on-screen refresh | 5 min |
| Course details | In-memory + pull-to-refresh | Session |
| Social feed | In-memory + paginated | 2 min |
| Avatars / covers | `CachedNetworkImage` (disk cache) | Unlimited |
| Static assets | `CachedNetworkImage` | Unlimited |
| API responses (rarely-changing) | `in_memory_cache` package with TTL | 10-30 min |

### 3.5 Error Handling Priorities

| Error Type | User-facing Action | Technical Action |
|-----------|-------------------|-----------------|
| 401 Unauthorized | "Session expired — logging out" | Clear tokens, navigate to login |
| 403 Forbidden | "You don't have permission" | Show disabled UI |
| 404 Not Found | "Not found" | Show error state |
| 422 Validation | Show field-level errors | Keep form data |
| 429 Rate Limit | "Too many requests — try later" | Show countdown timer |
| 5xx Server Error | "Something went wrong — try again" | Show error + retry button |
| Timeout / Network | "Check your connection" | Show offline state + retry |
| SocketException | "No internet connection" | Show offline banner |

### 3.6 Background Upload Error Handling

| Scenario | User-facing Action | Technical Action |
|----------|-------------------|-----------------|
| Network lost during upload | Notification: "Upload paused — will resume" | Save checkpoint, retry with backoff |
| Upload failed after all retries | Notification: "Upload failed — tap to retry" | Store failed task, offer manual retry |
| App killed during upload | Notification on next launch: "Resume upload?" | Check for incomplete tasks on startup |
| Storage full | Error dialog: "Not enough storage" | Halt upload, surface error |
| File corrupted mid-upload | Error: "File error — please re-upload" | Delete incomplete upload, restart fresh |

---

## 4. Widget-Level Optimizations

### 4.1 Use `const` aggressively

```dart
// Extract theme colors once, not per build:
const _primaryGradient = LinearGradient(
  colors: [Color(0xFF2564EA), Color(0xFF134BBF)],
);

// Extract repeat text styles:
const _headingStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
const _bodyStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
```

### 4.2 Prefer `Consumer<T>` over `context.watch` for large trees

```dart
// BAD — entire page rebuilds on any profile change:
@override
Widget build(BuildContext context) {
  final profile = context.watch<StudentProfileProvider>().profile;
  return Column(children: [ /* 50+ widgets */ ]);
}

// GOOD — only the header rebuilds:
@override
Widget build(BuildContext context) {
  return Column(children: [
    Consumer<StudentProfileProvider>(
      builder: (_, provider, __) => _Header(profile: provider.profile),
    ),
    // ... rest don't rebuild
  ]);
}
```

### 4.3 Always use `listen: false` when reading providers in callbacks

```dart
// In button onPressed:
onPressed: () {
  // CORRECT:
  context.read<AuthProvider>().login(...);
  // WRONG (rebuilds parent on every state change):
  context.watch<AuthProvider>().login(...);
}
```

### 4.4 Use `ListView.builder` / `GridView.builder` for any list > 10 items

```dart
// BAD — all items built upfront:
Column(children: List.generate(items.length, (i) => ItemWidget(items[i])))

// GOOD — lazy, on-demand:
ListView.builder(itemCount: items.length, itemBuilder: (_, i) => ItemWidget(items[i]))
```

### 4.5 Disposed controllers

Always dispose in `State.dispose()`:

```dart
@override
void dispose() {
  _searchController.dispose();
  _focusNode.dispose();
  _animationController.dispose();
  super.dispose();
}
```

---

## 5. Monitoring & Profiling

### 5.1 Add performance markers before shipping

```dart
final stopwatch = Stopwatch()..start();
final result = await repository.fetchData();
stopwatch.stop();
LoggerService.log('fetchData took ${stopwatch.elapsedMilliseconds}ms');
```

### 5.2 Use Flutter DevTools regularly

| Tool | When |
|------|------|
| Performance overlay | During scrolling and list rendering |
| Memory view | After navigating through 5+ pages |
| Network tab | During initial load and pagination |
| Rebuild count | When adding new `Consumer` / `context.watch` |

### 5.3 Check for rebuild storms

Mark every `Consumer.builder` and `build()` method with a `print` during development:

```dart
builder: (context, provider, _) {
  debugPrint('Rebuilding: ProfileHeader');
  return Text(provider.profile?.name ?? '');
}
```

### 5.4 Monitor background upload performance

```dart
// Log upload throughput for different file sizes
final stopwatch = Stopwatch()..start();
await uploadChunk(file.copyWith(offset: offset, length: chunkSize));
stopwatch.stop();
final speed = chunkSize / (stopwatch.elapsedMilliseconds / 1000);
LoggerService.log('Upload speed: ${speed ~/ 1024} KB/s');
```

---

## 6. Dependency / Bundle Size

| Package | Size | Purpose | Keep? |
|---------|------|---------|-------|
| `dartz` | ~200KB | `Either<Failure, T>` | ✅ Keep — core architecture |
| `http` | ~120KB | Networking | ✅ Keep |
| `flutter_secure_storage` | ~80KB | Token storage | ✅ Keep |
| `shared_preferences` | ~60KB | Preferences | ✅ Keep |
| `google_fonts` | ~50KB | Urbanist font | ⚠️ Can be replaced with bundled .ttf for faster initial render |
| `flutter_svg` | ~180KB | SVG rendering | ✅ Keep — used everywhere for icons |
| `media_kit` + `media_kit_video` | ~800KB | Video playback (mpv/FFmpeg native) | ✅ Keep — core feature requirement |
| `media_kit_libs_android_video` | ~15MB | Native mpv libraries (Android) | ✅ Keep — required for video playback |
| `image_picker` | ~200KB | Photo selection | ✅ Keep |
| `image_cropper` | ~80KB | Crop UI | ✅ Keep |
| `google_sign_in` | ~300KB | Google auth | ✅ Keep |
| `dotted_border` | ~20KB | Crop overlay guide | ✅ Keep |
| `logger` | ~40KB | Debug logging | ⚠️ Remove or disable in release builds |
| `url_launcher` | ~60KB | Open social links | ✅ Keep |
| `flutter_local_notifications` | ~200KB | Local notifications | ✅ Keep — needed for upload progress + push |

**Planned additions:**

| Package | Size | Purpose | Priority |
|---------|------|---------|----------|
| `flutter_background_service` | ~80KB | Background upload continuation | P0 |
| `workmanager` | ~60KB | Upload retry scheduling | P0 |
| `flutter_stripe` or `sslcommerz_flutter` | ~300KB | Payment gateway | P1 |
| `firebase_messaging` | ~400KB | Push notifications | P2 |
| `shimmer` | ~30KB | Skeleton loading | P2 |
| `file_picker` | ~150KB | Course/video file selection | P0 |

> **Note**: `cached_network_image: ^3.4.1` has already been added and is actively used. `shimmer` is not in pubspec but a custom `ShimmerWidget` exists at `lib/global/core/widgets/shimmer_widget.dart`.



---

## 7. Quick Wins (Implement First)

| # | Task | Effort | Impact | Depends On |
|--|------|--------|--------|------------|
| 1 | Fix `Provider.of` without `listen: false` in register_page | 15min | High — stops 600-line rebuild on every keystroke | None |
| 2 | Extract inline `LinearGradient` / `TextStyle` to `const` | 1h | Medium — reduces GC pressure | None |
| 3 | Add app lifecycle observer | 1h | Medium — prepares for token refresh, video pause | None |
| 4 | Add debounce to social page search | 15min | Medium — reduces rebuilds during typing | None |
| 5 | Add retry with backoff to `BaseRemoteDataSource` | 1h | Medium — better UX on flaky connections | None |
| 6 | Wire existing `VideoPlayerScreen` to social & course video taps | 30min | Medium — enables video playback from all entry points | None |
| 7 | Connect upload_zone.dart to `file_picker` | 1h | High — enables file selection for course/video upload | `file_picker` package |

---

## Notification Feature (WIP)

### Current Behavior (Bell Icon — Top-Right of Courses Page)

| Interaction | Action |
|-------------|--------|
| **Tap** | Navigate to in-app `/notifications` page (`NotificationsPage`) |
| **Long press** | Fire system tray notification via `flutter_local_notifications` (`showTestNotification`) |

### In-App Notifications Page (`NotificationsPage`)

- Located at `lib/features/notifications/presentation/pages/notifications_page.dart`
- Route: `AppRoutes.notifications` (`/notifications`)
- Currently uses hardcoded dummy data (`_sampleNotifications`, `_NotificationItem`)
- Each card shows: `Images.eduverseLogo` as prefix icon, title, body, timestamp (time-ago), unread dot indicator
- Bottom card: "Test Push Notification" button to trigger a system notification

### System Notification Service (`NotificationService`)

- Singleton at `lib/global/core/services/notification_service.dart`
- Uses `flutter_local_notifications: ^18.0.0`
- Channel: `test_notifications` / "Test Notifications" (Importance: high)
- Small icon: `eduverse_logo` (white silhouette on `TextColor.appColor` circle, left-aligned)
- Style: `BigTextStyleInformation` for expandable body text
- Android permission: `requestNotificationsPermission()` called on init + before each `show()`
- `AndroidManifest.xml` app label: `"Eduverse"`

### Integration Plan (Future)

1. Replace dummy data with real data from Provider (API calls)
2. Add `unread_count` badge overlay on the bell icon (use `Stack` + `Positioned`)
3. Wire `onDidReceiveNotificationResponse` callback in `NotificationService.init()` to navigate to `/notifications` when user taps system notification
4. Add pull-to-refresh on `NotificationsPage` list
5. Add "Mark all as read" action
6. Paginate notification list (see §3.2 for pattern)
7. Add push notification support (FCM) once backend is ready

---

## 8. Anti-Patterns to Avoid in Future Code

| Anti-pattern | Why | Correct approach |
|-------------|-----|-----------------|
| `context.watch<T>()` at the top of a large `build()` | Rebuilds entire widget subtree on any state change | Use `Consumer<T>` wrapping only the dependent widgets |
| `Provider.of<T>(context)` (no `listen: false`) in `initState` / callbacks | Forces the parent widget to rebuild for no reason | Always add `listen: false` in callbacks |
| `ListView(children: [...])` with dynamic item count | All items built upfront, defeats lazy rendering | Use `ListView.builder` or `ListView.separated` |
| `Image.network()` without cache | Redownloads on every rebuild | Use `CachedNetworkImage` or `CachedNetworkImageProvider` |
| Creating controllers (`TextEditingController`, `AnimationController`) without `dispose()` | Memory leak | Always `dispose()` in `State.dispose()` |
| `json.decode()` / `json.encode()` for large payloads on main thread | Blocks UI, causes frame drops | Use `compute()` for payloads > 50KB |
| Not handling app lifecycle | Videos keep playing in background, tokens expire silently | Add `WidgetsBindingObserver` |
| Inline `LinearGradient()` / `TextStyle()` in build methods | Creates garbage objects on every rebuild | Extract to `const` at file/top level |
| No pagination for list endpoints | App loads infinite data on first request | Always implement `page` / `limit` / `hasMore` |
| Not wrapping `Consumer` around loading/error states | Full page rebuild for a small spinner | Wrap only the spinner/error in `Consumer` |
| **Building upload UI without file picker** | User can't select files, feature is dead code | Always wire `image_picker` / `file_picker` when building upload UI |
| **Mock data in production paths** | Hides missing API integration until runtime | Use `Either<Failure, T>` with proper error handling; mock data only in tests |
| **No retry for uploads** | Uploads fail silently on network glitch | Implement chunked upload with checkpoint resume + retry with backoff |
| **Foreground-only large uploads** | App killed = upload lost, terrible UX | Always delegate long uploads to `flutter_background_service` |
| **Creating new player instances per video** | Multiple simultaneous players waste memory | Reuse single player instance, swap media source |
| **Hardcoded strings visible to users** | Impossible to localize or update | Extract to constants or `.arb` files |
