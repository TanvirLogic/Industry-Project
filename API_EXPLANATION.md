# API Flows — Eduverse

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  UI Layer (Screens / Widgets)                                    │
│  lib/features/<feature>/presentation/screens/                    │
│  lib/features/<feature>/presentation/widgets/                    │
└─────────────────────────┬────────────────────────────────────────┘
                          │ Consumer / context.watch / context.read
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│  Provider Layer (ChangeNotifier)                                 │
│  lib/features/<feature>/providers/                              │
│  ✓ Uses getNetworkCaller() directly (no repositories/usecases)  │
│  ✓ Manages: _isLoading, _errorMessage, _isSuccess, model data   │
└─────────────────────────┬────────────────────────────────────────┘
                          │ getNetworkCaller().get/post/put/delete
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│  Network Layer (NetworkCaller)                                   │
│  lib/global/core/services/network_caller.dart                   │
│  ✓ HTTP GET / POST / PUT / DELETE                                │
│  ✓ Auto Bearer token on non-public calls                        │
│  ✓ Auto 401 → refresh token → retry                             │
│  ✓ Auto 401 → logout (if refresh fails)                         │
│  ✓ AppLogger logging on every request/response                   │
│  ✓ Wraps response in NetworkResponse                            │
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
                  Backend API (REST)
```

### Navigation
- `app/app_routes.dart` — named routes via `onGenerateRoute`
- `app/app.dart` — `MultiProvider` wrapping the `MaterialApp`
- Auth screens are pushed/replaced directly; home is `MainNavShell` with `IndexedStack`

### Networking
- `getNetworkCaller({isPublic: false})` from `app/setup_network_caller.dart`
- Public (auth) calls: no Bearer token, no token refresh, no session clear
- Non-public (everything else): Bearer token, auto-refresh on 401, session clear on failure

---

## 1. Profile Management

### 1a. Fetch Profile (GET)

| Detail | Value |
|--------|-------|
| **URL** | `GET /api/v1/profile/me` |
| **Auth** | Bearer token required |
| **Provider** | `StudentProfileProvider.fetchProfile()` / `MentorProfileProvider.fetchProfile()` |
| **Response key** | `responseData['data']` |
| **Model** | `UserProfileModel.fromJson()` |

**Flow:**
1. Screen calls `fetchProfile()` (typically in `initState` + `addPostFrameCallback`)
2. Provider sets `_isLoading = true`, calls `getNetworkCaller().getRequest(url: Urls.profileUrl)`
3. On success: `_profile = UserProfileModel.fromJson(response.responseData['data'])`
4. On error: `_errorMessage = response.errorMessage`
5. `notifyListeners()` → UI rebuilds

**JSON structure parsed by `UserProfileModel.fromJson()`:**
```json
{
  "profile": {
    "id": 1,
    "name": "John Doe",
    "username": "johndoe",
    "email": "john@example.com",
    "phone": "01712345678",
    "dob": "1990-01-01",
    "gender": 1,
    "role": "STUDENT",
    "avatarUrl": "https://...",
    "coverUrl": "https://...",
    "bio": "Bio text",
    "profession": "Developer",
    "country": "Bangladesh",
    "socialLinks": [{"platform": "GitHub", "url": "https://..."}]
  },
  "social_platforms": ["GitHub", "LinkedIn", "Twitter"],
  "videos": [
    {"image": "url", "video": "url", "title": "My Video"}
  ],
  "courses": [
    {"image": "url", "title": "Course Name", "by": "Instructor", "progress": "70%"}
  ]
}
```

**Note:** The root `profile` object is extracted first; if absent `json` itself is treated as the profile.

**Widgets consuming `profile`:**
- `StudentProfileScreen` — header card, skills, videos, courses, social links sections
- `MentorProfileScreen` — hero banner, metrics bar, identity header, courses
- `HubScreen` — avatar, name, role chips
- `EditProfileScreen` — pre-fills all form fields from `_initControllers()`

### 1b. Update Profile (PUT)

| Detail | Value |
|--------|-------|
| **URL** | `PUT /api/v1/profile/update` |
| **Auth** | Bearer token required |
| **Provider** | `MentorProfileProvider.updateProfile()` / `EditProfileProvider.updateProfile()` |
| **Request body** | Flat JSON with only changed fields |
| **Response key** | `responseData['data']` → `UserProfileModel` |

**Flow:**
1. `EditProfileScreen` validates all fields locally (name ≥2 words, username ≥3 chars, phone regex, etc.)
2. On validation pass: builds `body` map with only non-null fields
3. Calls provider's `updateProfile(...)` with all form values
4. Provider builds body, calls `getNetworkCaller().putRequest(url: Urls.profileUpdateUrl, body: body)`
5. On success: calls `refreshProfile()` with parsed model, shows toast, pops screen
6. On error: shows `ToastService.showError()` with friendly message

**Request body example:**
```json
{
  "name": "John Doe",
  "username": "johndoe",
  "profession": "Developer",
  "dob": "1990-01-01",
  "bio": "Bio text",
  "country": "Bangladesh",
  "phone": "01712345678",
  "gender": 1,
  "socialLinks": [
    {"platform": "GitHub", "url": "https://github.com/..."}
  ]
}
```

**Two paths:**
- **Mentor:** `MentorProfileProvider` handles both save and toast
- **Student:** `EditProfileProvider` handles save; screen manually merges `updatedProfile` into `StudentProfileProvider` via `refreshProfile()`

### 1c. Profile Refresh (local)

| Provider | Method | What it does |
|----------|--------|-------------|
| `StudentProfileProvider.refreshProfile()` | Takes `UserProfileEntity` | Constructs full `UserProfileModel` and replaces `_profile` |
| `MentorProfileProvider.refreshProfile()` | Takes `UserProfileModel` | Replaces `_profile` directly |

Used after avatar/cover upload and profile update to keep UI in sync without a network call.

---

## 2. Avatar & Cover Upload (S3 Presigned URL Flow)

Both `AvatarUploadProvider` and `CoverUploadProvider` follow an identical 3-step flow. The only difference is crop aspect ratio (1:1 square for avatar, 16:9 for cover) and endpoint URLs.

### Step 1: Get Presigned Upload URL (POST)

| Detail | Avatar | Cover |
|--------|--------|-------|
| **URL** | `POST /api/v1/profile/avatar/upload-url` | `POST /api/v1/profile/cover/upload-url` |
| **Request body** | `{"filename": "image.jpg", "contentType": "image/jpeg"}` | Same |
| **Auth** | Bearer token required | Same |

**Response:**
```json
{
  "success": true,
  "data": {
    "uploadUrl": "https://...s3-presigned-url...",
    "fileUrl": "https://...cdn-url..."
  }
}
```

Both `uploadUrl` and `fileUrl` must be present. Null-checked before proceeding.

### Step 2: Stream Upload to S3 (PUT)

**Destination:** The `uploadUrl` from step 1 (S3 presigned URL, not our API)

**How it works:**
1. `_streamUpload()` creates a `http.StreamedRequest` with `Content-Type` header and `contentLength`
2. Reads the file as bytes, sends in 64KB chunks
3. `_uploadProgress` (0.0 → 1.0) is updated after each chunk
4. `notifyListeners()` allows UI to show a progress bar
5. On response status != 200: throws `HttpException`

### Step 3: Confirm Upload (PUT)

| Detail | Avatar | Cover |
|--------|--------|-------|
| **URL** | `PUT /api/v1/profile/avatar/confirm` | `PUT /api/v1/profile/cover/confirm` |
| **Request body** | `{"fileUrl": "https://...cdn-url..."}` | Same |
| **Auth** | Bearer token required | Same |

On success:
- `_uploadedAvatarUrl` / `_uploadedCoverUrl` is set
- `onUploadSuccess` callback fires with the new URL
- Toast: "Avatar updated successfully" / "Cover photo updated successfully"

### UI Integration

Both providers expose:
- `isLoading` / `isUploading` — for spinner/progress indicator
- `uploadProgress` — 0.0 to 1.0 for progress bar
- `uploadAvatarFromGallery()` / `uploadCoverFromGallery()` — full pick+crop+upload pipeline
- `uploadAvatarFromFile(XFile)` / `uploadCoverFromFile(XFile)` — upload a pre-cropped file

**Image picker flow:**
1. `ImagePicker.pickImage()` → gallery
2. `ImageCropper().cropImage()` → square (avatar) or 16:9 (cover)
3. `_uploadFile()` → presigned URL → S3 upload → confirm

Both providers have cancel-safe guards (`_isCropping` / `_isLoading`) to prevent double-taps.

---

## 3. Course Management

### 3a. Course List (GET)

| Detail | Value |
|--------|-------|
| **URL** | `GET /api/v1/courses/` |
| **Auth** | Bearer token required |
| **Provider** | `CourseListProvider.fetchCourses()` |
| **Response key** | `responseData['data']` cast to `List<dynamic>` |

**Implementation status:**
- The provider exists and calls the API, but `list Courses Screen` (`courses_screen.dart`) currently uses **hardcoded mock data** — no `Consumer` wrapping has been added yet
- `CourseListProvider` is registered in `app.dart` and available via `context.read<CourseListProvider>()`
- To wire it: wrap content in a `Consumer<CourseListProvider>`, call `fetchCourses()` in `initState`, iterate `_courses`

### 3b. Course Details (GET)

| Detail | Value |
|--------|-------|
| **URL** | `GET /api/v1/courses/{id}` |
| **Auth** | Bearer token required |
| **Provider** | `CourseDetailProvider.loadCourse(courseId)` |
| **Response key** | `responseData['data']` → `CourseModel.fromJson()` |

**Flow:**
1. `CourseDetailsScreen` creates a local `ChangeNotifierProvider` wrapping `CourseDetailProvider`
2. In `initState`, calls `loadCourse('1')` (hardcoded ID for now)
3. Provider sets `_isLoading = true`, calls `getRequest(url: Urls.courseDetailsUrl(courseId))`
4. On success: `_course = CourseModel.fromJson(response.responseData['data'])`
5. `Consumer<CourseDetailProvider>` shows skeleton while `course == null`, then full UI

**Current `CourseModel.fromJson()` only extracts:**
```dart
id, title, description, instructorName, instructorTitle
```
Additional fields (`level`, `language`, `price`, `rating`, `videosCount`, `resourcesCount`, `thumbnailUrl`, `modules`, `reviews`) are declared with defaults in the entity but not populated from JSON.

**Skeleton state:** `_CourseDetailsSkeleton` shows shimmer widgets while loading.

### 3c. Enrolled Course (GET)

| Detail | Value |
|--------|-------|
| **URL** | `GET /api/v1/courses/{id}/enrolled` |
| **Auth** | Bearer token required |
| **Provider** | `EnrolledCourseProvider.loadCourse(courseId)` |
| **Response key** | `responseData['data']` → `CourseModel.fromJson()` |

**Flow:** Identical to `CourseDetailProvider` but hits the `enrolled` endpoint. Currently hardcodes course ID `'1'`.

### 3d. Course Upload (Multi-Step)

| Detail | Value |
|--------|-------|
| **Provider** | `CourseUploadProvider` |
| **State machine** | `idle → uploadingUrls → uploadingImage → (uploadingVideo) → creatingCourse → done/error` |

**Step 1: Upload URLs (POST)**

| URL | `POST /api/v1/course/assets/upload` |
| Auth | Bearer token required |
| Request body | `{"thumbnailFilename": "thumb.jpg", "thumbnailContentType": "image/jpeg", "videoFilename": "intro.mp4", "videoContentType": "video/mp4"}` |

**Response (nested `data.data`):**
```json
{
  "success": true,
  "data": {
    "data": {
      "thumbnail": {
        "uploadUrl": "https://...s3-presigned...",
        "fileUrl": "https://...cdn..."
      },
      "video": {
        "uploadUrl": "https://...s3-presigned...",
        "fileUrl": "https://...cdn..."
      }
    }
  }
}
```

**Parsing in code:**
```dart
final raw = urlsResponse.responseData;
final wrapper = raw is Map ? raw['data'] : null;
final innerData = wrapper is Map ? wrapper['data'] ?? wrapper : wrapper;
```
This handles both `{data: {data: {...}}}` and `{data: {...}}` response variants.

Video is optional — if `_videoFile == null`, only thumbnail is uploaded.

**Step 2: Upload to S3 (PUT)**

Same streaming mechanism as avatar/cover (`_uploadToS3()`):
- `http.StreamedRequest` for progress tracking
- `_StreamedProgressRequest` custom `BaseRequest` subclass
- 6-hour timeout, chunked reads with percentage callbacks
- `http.Client` lifecycle managed via `_activeClient` for cancellation

**Step 3: Create Course (POST)**

| URL | `POST /api/v1/course` |
| Auth | Bearer token required |
| Request body | `{"title", "description", "shortDescription", "requirements", "thumbnailUrl", "introVideoUrl?", "language", "level": "BEGINNER|INTERMEDIATE|ADVANCED", "type": "FREE|PAID", "price": 0}` |

**Response:** Same nested `data.data` pattern as step 1. `_createdCourseId` extracted from the innermost data object.

**UI:**
- `UploadCourseScreen` (title, description, short description, requirements, language, level, price radio, type radio, thumbnail picker, video picker)
- `UploadVideoScreen` (description, requirements, language, level, thumbnail picker, video picker)
- `UploadZone` widget — dashed border area with drag/drop visual
- `AuthButton` shows dynamic `buttonText` from provider (e.g., "Uploading image 45%")

**Cancellation:** `cancel()` closes the active `http.Client` and resets state.

---

## 4. Manage Module (Local-Only)

| Detail | Value |
|--------|-------|
| **Screen** | `ManageModuleScreen` |
| **Provider** | None — all state is local (`_modules`, `_isEditing`, `_hasUnsavedChanges`) |
| **API calls** | None yet |

**Current state:** Manages modules and lessons entirely in-memory with local state. Modules have:
- `id`, `title`, `lessons`, `isExpanded`
- Lessons have: `id`, `title`, `duration`, `type` (video or resource)

**Features:**
- Reorder modules via `ReorderableListView`
- Reorder lessons within a module (drag handles)
- Add/delete modules and lessons
- Rename modules and lessons
- Swipe-to-delete with confirmation dialog
- Dismissible background shows delete icon

**`getSerializedOrder()`** produces:
```json
[
  {
    "module_id": 1,
    "sort_order": 0,
    "title": "Getting Started",
    "lessons": [
      {"lesson_id": 1, "sort_order": 0, "title": "Intro", "type": "video"}
    ]
  }
]
```
Ready to be sent to a future API endpoint.

---

## 5. Change Password

| Detail | Value |
|--------|-------|
| **URL** | `POST /api/v1/auth/change-password` |
| **Auth** | Bearer token required |
| **Provider** | `ChangePasswordProvider.changePassword(currentPassword, newPassword)` |
| **Request body** | `{"currentPassword": "...", "newPassword": "..."}` |
| **Response** | Success → toast "Password changed successfully" |

**Flow:**
1. `PasswordAndSecurityScreen` collects current + new password (with confirm match validation)
2. Calls `provider.changePassword(current, new)`
3. On success → toast + pop; on failure → toast with friendly error

---

## 6. Hub Screen (Dashboard Overview)

| Screen | Data Source | API |
|--------|------------|-----|
| `HubScreen` | `StudentProfileProvider` / `MentorProfileProvider` | `GET /profile/me` (fetched once) |
| `MentorDashboardScreen` | Greeting: `MentorProfileProvider`; Stats/Balance: hardcoded mock data | `GET /profile/me` for name only |

**HubScreen sections:**
- Profile header (avatar, name, role)
- Settings group cards:
  - **Edit Profile** → `EditProfileScreen`
  - **Password & Security** → `PasswordAndSecurityScreen`
  - **Wallet / Payments** → `PaymentsAndRevenueScreen` (mock)
  - **Notifications** → `NotificationsPage`
  - **Dark Mode** toggle → `ThemeProvider.toggleTheme()`
  - **Mentor Dashboard** (if role = MENTOR) → `MentorDashboardScreen`
  - **Logout** → confirmation dialog → `SignInProvider.logout()`

**MentorDashboardScreen sections:**
- `GreetingSection` — "Good Morning, {name}" from `MentorProfileProvider.profile?.name`
- `BalanceBanner` — hardcoded "৳32,688" with Withdraw button
- `MetricsGrid` — hardcoded counts (Total Courses: 12, Total Earning: ৳9640, Total Student: 1234, Reviews: 4.8)
- `CourseAccordion` — hardcoded mock courses with expandable revenue breakdown

---

## 7. Social Page

| Detail | Value |
|--------|-------|
| **Screen** | `SocialPage` (tab 0 in `MainNavShell`) |
| **API** | None yet — fully hardcoded mock data |
| **Data** | Posts with images, author info, like/comment counts, timestamps |

**Features (local-only):**
- Post cards with author avatar, name, time ago, content image, caption
- Like (heart toggle), comment, share action row
- Bottom sheet overlay for creating new posts (`PostOptionsOverlay`)

---

## 8. Auth Provider Logout

| Detail | Value |
|--------|-------|
| **URL** | `POST /api/v1/auth/logout` |
| **Auth** | Bearer token required |
| **Provider** | `SignInProvider.logout()` |
| **On success** | `AuthController.clearUserData()` → navigates to `/login` |

---

## Summary: API Endpoints

### Authenticated (Bearer token required)

| # | Method | URL | Provider | Status |
|---|--------|-----|----------|--------|
| 1 | `GET` | `/api/v1/profile/me` | `StudentProfileProvider` / `MentorProfileProvider` | ✅ Wired |
| 2 | `PUT` | `/api/v1/profile/update` | `EditProfileProvider` / `MentorProfileProvider` | ✅ Wired |
| 3 | `POST` | `/api/v1/profile/avatar/upload-url` | `AvatarUploadProvider` | ✅ Wired |
| 4 | `PUT` | `/api/v1/profile/avatar/confirm` | `AvatarUploadProvider` | ✅ Wired |
| 5 | `POST` | `/api/v1/profile/cover/upload-url` | `CoverUploadProvider` | ✅ Wired |
| 6 | `PUT` | `/api/v1/profile/cover/confirm` | `CoverUploadProvider` | ✅ Wired |
| 7 | `GET` | `/api/v1/courses/` | `CourseListProvider` | ⏳ Provider done, UI not wired |
| 8 | `GET` | `/api/v1/courses/{id}` | `CourseDetailProvider` | ✅ Wired (hardcoded ID) |
| 9 | `GET` | `/api/v1/courses/{id}/enrolled` | `EnrolledCourseProvider` | ✅ Wired (hardcoded ID) |
| 10 | `POST` | `/api/v1/course/assets/upload` | `CourseUploadProvider` | ✅ Wired |
| 11 | `POST` | `/api/v1/course` | `CourseUploadProvider` | ✅ Wired |
| 12 | `POST` | `/api/v1/auth/change-password` | `ChangePasswordProvider` | ✅ Wired |
| 13 | `POST` | `/api/v1/auth/logout` | `SignInProvider` | ✅ Wired |

### Public (no Bearer token)

| # | Method | URL | Provider | Status |
|---|--------|-----|----------|--------|
| 14 | `POST` | `/api/v1/auth/login` | `SignInProvider` | ✅ Wired |
| 15 | `POST` | `/api/v1/auth/register` | `SignUpProvider` | ✅ Wired |
| 16 | `POST` | `/api/v1/auth/google` | `SignInProvider` | ✅ Wired |
| 17 | `POST` | `/api/v1/auth/verify-email` | `VerifyOtpProvider` | ✅ Wired |
| 18 | `POST` | `/api/v1/auth/resend-email-verification` | `VerifyOtpProvider` | ✅ Wired |
| 19 | `POST` | `/api/v1/auth/refresh` | `SignInProvider` | ✅ Wired |
| 20 | `POST` | `/api/v1/auth/forgot-password` | `PasswordResetProvider` | ✅ Wired |
| 21 | `POST` | `/api/v1/auth/verify-reset-otp` | `PasswordResetProvider` | ✅ Wired |
| 22 | `POST` | `/api/v1/auth/reset-password` | `PasswordResetProvider` | ✅ Wired |

---

## Key Architecture Patterns

### Provider Pattern (all non-auth)
```dart
class ExampleProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  DataType? _data;

  Future<void> fetch() async {
    _isLoading = true; notifyListeners();
    final response = await getNetworkCaller().getRequest(url: Urls.exampleUrl);
    if (response.isSuccess) {
      _data = DataType.fromJson(response.responseData['data']);
    } else {
      _errorMessage = response.errorMessage;
    }
    _isLoading = false; notifyListeners();
  }
}
```

### Screen → Provider wiring
```dart
// Local provider (screen-scoped):
ChangeNotifierProvider(
  create: (_) => CourseDetailProvider(),
  child: Consumer<CourseDetailProvider>(
    builder: (context, provider, _) {
      if (provider.course == null) return Skeleton();
      return FullUI(course: provider.course!);
    },
  ),
)

// Global provider (app-scoped via app.dart):
context.read<MentorProfileProvider>().fetchProfile();
context.watch<StudentProfileProvider>().profile;
```

### S3 Upload Flow (3 steps)
1. **POST** our API → get `uploadUrl` + `fileUrl`
2. **PUT** to S3 presigned URL (streaming with progress)
3. **PUT** our API to confirm with `fileUrl`

### Null Safety for `responseData['data']`
Every provider guards: `response.responseData['data']` — the backend wraps primary data under a `data` key.

### Error Handling
- `NetworkCaller._processResponse`: extracts error message from `decodedErrorMSGKey` (configured as `'message'` in setup)
- Provider calls `ToastService.showError(response.errorMessage ?? 'Fallback message')`
- `ToastService.friendlyMessage()` sanitizes raw server text before display
- Raw API errors logged via `AppLogger.e()` for debugging
