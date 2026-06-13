# Architecture Conversion Planner — Eduverse

## Goal

Convert the current **Clean Architecture** (data/domain/presentation + use cases + repositories + Either/Failure) into the **simplified Feature-First Architecture** described in `t_code.md`.

**No functionality changes.** The app must work identically at every step.

---

## Current → Target

| Aspect | Current (Complex) | Target (Simple) |
|--------|-------------------|-----------------|
| `domain/` layer | Entities + Use Cases + Abstract Repos | ❌ Removed entirely |
| `data/` layer | datasources/ + models/ + repositories/ | Only `models/` |
| Network call path | Screen → Provider → UseCase → Repository(→ safeCall) → DataSource(→ BaseRemoteDataSource) | Screen → Provider → `NetworkCaller` |
| Models | Entity (domain) + Model (data) extends Entity | Single model class in `data/models/` |
| Error handling | `Either<Failure, T>` with `safeCall()` | `NetworkResponse.isSuccess` boolean |
| Token management | TokenService + SecureStorage + AuthHttpClient (interceptor) | `AuthController` static class (SharedPreferences) |
| Pages | `presentation/pages/` | `presentation/screens/` |
| Namespace | `global/core/` (dispersed) | `app/` + `core/` (clean split) |
| Routing | `AppRoutes` with `onGenerateRoute` | Same — but screens have `static const String name` |
| UI state | Provider (ChangeNotifier) | Same pattern but simpler |
| DI | ProxyProvider chain in `provider_setup.dart` | `MultiProvider` directly in `main.dart` (inside `AppName`) |

---

## Master Plan — 8 Phases

```
Phase 1: Foundation — Create `app/` + `core/` layers
Phase 2: AuthController — Simplify token management
Phase 3: Feature-by-feature migration (auth first, then profile, then others)
Phase 4: Remove domain/ layer from every feature
Phase 5: Simplify data/ layer (remove datasources/ and repositories/, keep only models/)
Phase 6: Rename pages/ → screens/ + add static name constants
Phase 7: Simplify main.dart + routing
Phase 8: Cleanup and final test
```

---

## Phase 1: Foundation — Create `app/` + `core/` Layers

### Step 1.1 — Create `app/app_colors.dart`

Move from `TextColor` and scatter theme colors into a single place.

```dart
class AppColors {
  static const Color themeColor = Color(0xFF134BBF);
  static const Color primaryText = Color(0xFF2D3748);
  static const Color subText = Color(0xFF6B7280);
}
```

**Action:** Create `lib/app/app_colors.dart`. Keep `lib/global/core/constants/text/text_color.dart` untouched during this phase (remove later).

### Step 1.2 — Create `app/urls.dart`

Move all endpoint constants from `AuthEndpoints` and scatter data sources into a single file.

```dart
class Urls {
  static const String _baseUrl = 'http://108.181.195.154:3000/api/v1';
  static const String signInUrl = '$_baseUrl/auth/login';
  static const String signUpUrl = '$_baseUrl/auth/register';
  static const String googleAuthUrl = '$_baseUrl/auth/google';
  static String productDetails(String id) => '$_baseUrl/products/$id';
  // ... etc
}
```

**Action:** Create `lib/app/urls.dart`. Keep existing endpoint files for now.

### Step 1.3 — Create `app/asset_paths.dart`

Wrapping `Images` class content.

```dart
class AssetPaths {
  static const String googleIcon = 'assets/images/app/Google.png';
  static const String eduverseLogo = 'assets/images/app/eduverse_logo.png';
  // ... etc
}
```

**Action:** Create `lib/app/asset_paths.dart`.

### Step 1.4 — Create `app/constants.dart`

```dart
class Constants {
  // Any app-wide constants
}
```

**Action:** Create `lib/app/constants.dart`.

### Step 1.5 — Create `app/app_theme.dart`

Read the current `lib/global/core/theme/app_theme.dart` and create a simplified version.

```dart
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.themeColor,
    // ... rest from current app_theme.dart
  );
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.themeColor,
    // ...
  );
}
```

**Action:** Create `lib/app/app_theme.dart`. Uses `AppColors.themeColor`.

### Step 1.6 — Create `core/services/network_caller.dart`

Create the simplified HTTP client. This replaces `BaseRemoteDataSource` + `AuthHttpClient`.

```dart
class NetworkCaller {
  final VoidCallback onUnauthorize;
  final Map<String, String>? headers;

  Future<NetworkResponse> getRequest({required String url}) async { ... }
  Future<NetworkResponse> postRequest({required String url, Map<String, dynamic>? body}) async { ... }
  Future<NetworkResponse> putRequest({required String url, Map<String, dynamic>? body}) async { ... }
}
```

**Key behavior:**
- Auto-attach `token` from `AuthController.accessToken` in headers
- On 401 → call `onUnauthorize`
- Return `NetworkResponse(isSuccess, responseCode, responseData, errorMessage)`

**Action:** Create `lib/core/services/network_caller.dart`.

### Step 1.7 — Create `core/models/network_response.dart`

```dart
class NetworkResponse {
  final bool isSuccess;
  final int responseCode;
  final dynamic responseData;
  final String? errorMessage;

  NetworkResponse({ ... });
}
```

**Action:** Create `lib/core/models/network_response.dart`.

### Step 1.8 — Create `app/setup_network_caller.dart`

```dart
NetworkCaller getNetworkCaller() {
  return NetworkCaller(
    headers: {
      'Content-type': 'application/json',
      'token': AuthController.accessToken ?? '',
    },
    onUnauthorize: () {
      // Navigate to login
      AuthController.clearUserData();
      AppName.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    },
  );
}
```

**Action:** Create `lib/app/setup_network_caller.dart`.

### Step 1.9 — Create `app/providers/theme_provider.dart`

Read current `lib/global/core/theme/theme_provider.dart` and create a version matching the t_code.md pattern.

**Action:** Create `lib/app/providers/theme_provider.dart`.

### Step 1.10 — Verify Phase 1

```bash
flutter analyze
flutter test
```

No existing files were modified — only new files created. Everything must still compile and work.

---

## Phase 2: AuthController — Simplify Token Management

### Step 2.1 — Create `AuthController`

Create `lib/features/auth/data/models/auth_controller.dart` as a static class that replaces `TokenService` + `SecureStorage` + `AuthHttpClient` token logic.

```dart
class AuthController {
  static const _tokenKey = 'access-token';
  static const _userKey = 'user-data';
  static UserModel? userModel;
  static String? accessToken;

  static Future<void> saveUserData(String token, UserModel model) async { ... }
  static Future<void> getUserData() async { ... }
  static Future<bool> isLoggedIn() async { ... }
  static Future<void> clearUserData() async { ... }
}
```

**Action:** Create `lib/features/auth/data/models/auth_controller.dart`.

### Step 2.2 — Update `getNetworkCaller()`

Update `setup_network_caller.dart` to read `AuthController.accessToken` instead of `TokenService`.

**Action:** Edit `lib/app/setup_network_caller.dart`.

### Step 2.3 — Verify Phase 2

```bash
flutter analyze
flutter test
```

---

## Phase 3: Feature-by-Feature Migration

### Rule for each feature:

1. **Create new provider** in `features/{feature}/providers/` that uses `NetworkCaller` directly (no use cases, no repositories)
2. **Keep old provider** working alongside — new provider is used by new screen, old provider is used by old screen
3. **When all screens in a feature use new providers**, delete the old ones

### Step 3.1 — Auth Feature (first, most critical)

**New files to create:**

| File | Purpose |
|------|---------|
| `features/auth/providers/sign_in_provider.dart` | Login via NetworkCaller, save to AuthController |
| `features/auth/providers/sign_up_provider.dart` | Register via NetworkCaller |
| `features/auth/providers/verify_otp_provider.dart` | Verify OTP via NetworkCaller |

**SignInProvider template:**
```dart
class SignInProvider extends ChangeNotifier {
  bool _inProgress = false;
  bool get inProgress => _inProgress;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> signIn(String email, String password) async {
    bool isSuccess = false;
    _inProgress = true;
    notifyListeners();

    final response = await getNetworkCaller().postRequest(
      url: Urls.signInUrl,
      body: {'email': email, 'password': password},
    );

    if (response.isSuccess) {
      final data = response.responseData['data'];
      final user = UserModel.fromJson(data['user']);
      await AuthController.saveUserData(data['accessToken'], user);
      isSuccess = true;
      _errorMessage = null;
    } else {
      _errorMessage = response.errorMessage;
    }

    _inProgress = false;
    notifyListeners();
    return isSuccess;
  }
}
```

### Step 3.2 — Student Profile Feature

**New files to create:**

| File | Purpose |
|------|---------|
| `features/student/providers/student_profile_provider.dart` | Fetch profile via NetworkCaller |
| `features/student/providers/edit_profile_provider.dart` | Update profile via NetworkCaller |

### Step 3.3 — Mentor Profile Feature

**New files to create:**

| File | Purpose |
|------|---------|
| `features/mentor/providers/mentor_profile_provider.dart` | Fetch/update mentor profile via NetworkCaller |

### Step 3.4 — Avatar Upload Feature

**New files to create:**

| File | Purpose |
|------|---------|
| `features/avatar/providers/avatar_upload_provider.dart` | 3-step upload via NetworkCaller |
| `features/avatar/providers/cover_upload_provider.dart` | 3-step cover upload via NetworkCaller |

### Step 3.5 — Courses Feature

**New files to create:**

| File | Purpose |
|------|---------|
| `features/courses/providers/course_list_provider.dart` | Fetch course list |
| `features/courses/providers/course_details_provider.dart` | Fetch course details |
| `features/courses/providers/enrolled_course_provider.dart` | Fetch enrolled courses |

### Step 3.6 — Hub Feature

**New files to create:**

| File | Purpose |
|------|---------|
| `features/hub/providers/change_password_provider.dart` | Change password |

### Step 3.7 — Verify after each feature

After creating new providers for a feature, verify with:
```bash
flutter analyze
```

---

## Phase 4: Remove `domain/` Layer

### Step 4.1 — Delete all `domain/entities/` files

Entities are replaced by direct use of models.

**Files to delete:**
- `lib/features/auth/domain/entities/user_entity.dart`
- `lib/features/courses/domain/entities/course_entity.dart`
- `lib/features/courses/domain/entities/module_entity.dart`
- `lib/features/courses/domain/entities/lesson_entity.dart`
- `lib/features/courses/domain/entities/review_entity.dart`
- `lib/features/student/domain/entities/user_profile_entity.dart`
- `lib/features/hub/domain/entities/` (if any)

**Update models:** Models currently `extends Entity`. Remove the `extends` and fold all fields + `fromJson` directly into the model.

Example: `UserModel` currently `extends UserEntity`. Convert to standalone class:
```dart
class UserModel {
  final String id;
  final String email;
  // ... all fields directly in model

  UserModel({required this.id, required this.email, ...});

  factory UserModel.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

### Step 4.2 — Delete all `domain/repositories/` files

**Files to delete:**
- `lib/features/auth/domain/repositories/auth_repository.dart`
- `lib/features/student/domain/repositories/student_repository.dart`
- `lib/features/mentor/domain/repositories/mentor_repository.dart`
- `lib/features/courses/domain/repositories/courses_repository.dart`
- `lib/features/avatar/domain/repositories/avatar_repository.dart`
- `lib/features/hub/domain/repositories/` (if any)

### Step 4.3 — Delete all `domain/usecases/` files

**Files to delete (22 files):**
- Auth: login, register, verify_email, resend_email_verification, logout, forgot_password, verify_reset_otp, reset_password, sign_in_with_google, refresh_token
- Courses: get_course_details, get_enrolled_course
- Student: get_profile, update_profile
- Mentor: get_mentor_profile, update_mentor_profile
- Avatar: get_avatar_upload_url, confirm_avatar_upload, get_cover_upload_url, confirm_cover_upload
- Hub: change_password

### Step 4.4 — Verify Phase 4

```bash
flutter analyze
```

Expected: Errors from deleted files. The `domain/` folders are removed but still referenced by old providers. Fix by ensuring **all old providers have been replaced** by new ones first.

---

## Phase 5: Simplify `data/` Layer

### Step 5.1 — Delete all `data/datasources/` files

**Files to delete:**
- `lib/features/auth/data/datasources/auth_remote_data_source.dart`
- `lib/features/auth/data/datasources/auth_endpoints.dart`
- `lib/features/courses/data/datasources/courses_remote_data_source.dart`
- `lib/features/student/data/datasources/student_remote_data_source.dart`
- `lib/features/mentor/data/datasources/mentor_remote_data_source.dart`
- `lib/features/avatar/data/datasources/avatar_remote_data_source.dart`

### Step 5.2 — Delete all `data/repositories/` files

**Files to delete:**
- `lib/features/auth/data/repositories/auth_repository_impl.dart`
- `lib/features/courses/data/repositories/courses_repository_impl.dart`
- `lib/features/student/data/repositories/student_repository_impl.dart`
- `lib/features/mentor/data/repositories/mentor_repository_impl.dart`
- `lib/features/avatar/data/repositories/avatar_repository_impl.dart`

### Step 5.3 — Delete `data/mappers/` files

- `lib/features/auth/data/mappers/register_params_mapper.dart`
- `lib/features/auth/data/mappers/update_profile_params_mapper.dart`

### Step 5.4 — Verify Phase 5

```bash
flutter analyze
```

---

## Phase 6: Rename `pages/` → `screens/` + Add `name` Constants

### Step 6.1 — Rename directories

For each feature:
- `features/{feature}/presentation/pages/` → `features/{feature}/presentation/screens/`
- Rename each file from `*_page.dart` → `*_screen.dart`

### Step 6.2 — Add `static const String name`

Every screen gets:
```dart
class LoginScreen extends StatefulWidget {
  static const String name = '/login';
  ...
}
```

### Step 6.3 — Update all imports

Every file that imports `*_page.dart` must now import `*_screen.dart`.

### Step 6.4 — Verify Phase 6

```bash
flutter analyze
```

---

## Phase 7: Simplify `main.dart` + Routing

### Step 7.1 — Create `app/app.dart`

The root widget with `MultiProvider`:
```dart
class AppName extends StatefulWidget {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<AppName> createState() => _AppNameState();
}

class _AppNameState extends State<AppName> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadInitialThemeMode()),
        // Register all new providers here
        ChangeNotifierProvider(create: (_) => SignInProvider()),
        ChangeNotifierProvider(create: (_) => SignUpProvider()),
        // ...
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: AppName.navigatorKey,
            initialRoute: SplashScreen.name,
            onGenerateRoute: AppRoutes.routes,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.currentThemeMode,
          );
        },
      ),
    );
  }
}
```

### Step 7.2 — Update `main.dart`

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppName());
}
```

### Step 7.3 — Update `app/app_routes.dart`

Use `onGenerateRoute` with screen `name` constants:
```dart
class AppRoutes {
  static Route<dynamic> routes(RouteSettings setting) {
    Widget widget = const SizedBox();
    if (setting.name == SplashScreen.name) {
      widget = const SplashScreen();
    } else if (setting.name == SignInScreen.name) {
      widget = const SignInScreen();
    } else if (setting.name == SignUpScreen.name) {
      widget = const SignUpScreen();
    }
    // ... all routes
    return MaterialPageRoute(builder: (context) => widget);
  }
}
```

### Step 7.4 — Clean up `provider_setup.dart`

Remove all old ProxyProviders. The file can be **deleted** since all providers are now registered in `app.dart`.

**Files to delete:**
- `lib/global/core/di/provider_setup.dart`

### Step 7.5 — Remove unused global/core files

**Files to check and potentially delete:**
- `lib/global/core/data/base_remote_data_source.dart` — replaced by `network_caller.dart`
- `lib/global/core/data/base_repository.dart` — no longer needed
- `lib/global/core/error/failures.dart` — no longer needed
- `lib/global/core/services/auth_http_client.dart` — replaced by `NetworkCaller`
- `lib/global/core/services/token_service.dart` — replaced by `AuthController`
- `lib/global/core/services/secure_storage.dart` — replaced by `AuthController`
- `lib/global/core/services/app_preferences.dart` — migrated to `AuthController` or `SharedPreferences` directly
- `lib/global/core/usecase/usecase.dart` — no longer needed

### Step 7.6 — Update tests

Update `test/` files to work with the new architecture.

### Step 7.7 — Verify Phase 7

```bash
flutter analyze
flutter test
flutter run
```

---

## Phase 8: Cleanup and Final Verification

### Step 8.1 — Delete unused directories

- `lib/global/` — Entirely replaced by `app/` + `core/`
- `lib/features/` — All old `domain/` and `data/datasources/` folders should be empty now

### Step 8.2 — Final `pubspec.yaml` cleanup

Remove unused dependencies:
- `dartz` (Either type no longer used)
- `flutter_secure_storage` (replaced by `shared_preferences` in AuthController)
- `google_fonts` (if only used by old theme — check)

```bash
flutter pub remove dartz flutter_secure_storage
```

### Step 8.3 — Run full test suite

```bash
flutter analyze
flutter test
flutter run --debug
```

### Step 8.4 — Final directory tree should be:

```
lib/
  main.dart
  app/
    app.dart
    app_colors.dart
    app_routes.dart
    app_theme.dart
    asset_paths.dart
    constants.dart
    urls.dart
    setup_network_caller.dart
    providers/
      theme_provider.dart
  core/
    models/
      network_response.dart
    services/
      network_caller.dart
  features/
    auth/
      data/models/
        auth_controller.dart    <-- NEW (static token manager)
        user_model.dart
        sign_in_params.dart
        sign_up_params.dart
        verify_otp_param.dart
      providers/
        sign_in_provider.dart   <-- NEW (simplified)
        sign_up_provider.dart   <-- NEW
        verify_otp_provider.dart <-- NEW
      presentation/
        screens/
          splash_screen.dart    <-- renamed from splash_page.dart (moved here)
          sign_in_screen.dart   <-- renamed from login_page.dart
          sign_up_screen.dart   <-- renamed from register_page.dart
          verify_otp_screen.dart
          forgot_password_screen.dart
          reset_verification_screen.dart
          set_new_password_screen.dart
          password_success_screen.dart
        widgets/
          custom_text_field.dart
          app_logo.dart
    student/
      data/models/
        user_profile_model.dart
      providers/
        student_profile_provider.dart  <-- NEW (simplified)
        edit_profile_provider.dart     <-- NEW
      presentation/
        screens/
          student_profile_screen.dart  <-- renamed from student_profile_page.dart
        widgets/
          completed_courses_list.dart
          profile_app_bar.dart
          profile_header_card.dart
          section_header.dart
          skill_badges_row.dart
          social_links_row.dart
          video_list_section.dart
          video_player_screen.dart
    mentor/
      data/models/
        (same as student - share UserProfileModel)
      providers/
        mentor_profile_provider.dart   <-- NEW (simplified)
      presentation/
        screens/
          mentor_profile_screen.dart   <-- renamed
        widgets/
          mentor_hero_banner.dart
          mentor_identity_header.dart
          mentor_metrics_bar.dart
    avatar/
      data/models/
        avatar_upload_url_model.dart
      providers/
        avatar_upload_provider.dart    <-- NEW (simplified)
        cover_upload_provider.dart     <-- NEW
      presentation/
        screens/
          full_screen_image_viewer.dart
        widgets/
          avatar_options_bottom_sheet.dart
          cover_reposition_screen.dart
          custom_crop_screen.dart
    courses/
      data/models/
        course_model.dart
        (presentation/manage_module_models.dart → move to data/models/)
      providers/
        course_list_provider.dart      <-- NEW
        course_detail_provider.dart    <-- NEW (simplified)
        enrolled_course_provider.dart  <-- NEW
      presentation/
        screens/
          courses_screen.dart          <-- renamed
          course_details_screen.dart
          enrolled_course_screen.dart
          payment_success_screen.dart
          upload_course_screen.dart
          upload_video_screen.dart
          manage_module_screen.dart
        widgets/
          course_expandable_container.dart
          course_reviews_tab_view.dart
          course_stats_row.dart
          instructor_profile_card.dart
          lesson_row_tile.dart
          module_card.dart
          upload_zone.dart
    hub/
      providers/
        change_password_provider.dart  <-- NEW (simplified)
      presentation/
        screens/
          hub_screen.dart              <-- renamed
          mentor_dashboard_screen.dart
          payments_and_revenue_screen.dart
          password_and_security_screen.dart
          ads_manager_screen.dart
          ads_create_screen.dart
        widgets/
          mentor_balance_banner.dart
          mentor_course_accordion.dart
          mentor_greeting_section.dart
          mentor_metrics_grid.dart
    home/
      presentation/
        screens/
          main_nav_shell.dart
        widgets/
          post_options_overlay.dart
    social/
      presentation/
        screens/
          social_screen.dart
    notifications/
      presentation/
        screens/
          notifications_screen.dart
    common/
      presentation/
        providers/
          main_nav_container_provider.dart
        widgets/
          centered_circular_progress.dart
          app_back_button.dart
          auth_button.dart
          dashed_border.dart
          shimmer_widget.dart
          language_selector.dart       <-- NEW (from app layer)
          theme_selector.dart          <-- NEW (from app layer)
          category_card.dart           <-- if needed
          product_card.dart            <-- if needed
          rating_view.dart
          favourite_button.dart
```

---

## Order Dependency Map

```
Phase 1 (Foundation)
  ↓
Phase 2 (AuthController)
  ↓
Phase 3 (Feature providers — one at a time)
  ↓
Phase 4 (Remove domain/) — only after ALL providers are migrated
  ↓
Phase 5 (Simplify data/) — only after all providers are migrated
  ↓
Phase 6 (Rename pages/ → screens/) — can overlap with Phase 4-5
  ↓
Phase 7 (Simplify main.dart) — only after all features migrated
  ↓
Phase 8 (Cleanup)
```

---

## How to Execute

1. Each step is a separate PR/commit
2. After each step, run `flutter analyze` and verify the app still works
3. Never modify a working file and a file that depends on it in the same step
4. When in doubt, create the new file first, keep the old one, then swap imports
5. The `domain/` layer is the LAST thing to delete — it keeps the app compiling while new providers are being built

---

## Files That Stay the Same

These files need NO changes (they follow the simpler pattern already or are pure UI):

- `lib/features/home/presentation/pages/main_nav_shell.dart`
- `lib/features/home/presentation/widgets/post_options_overlay.dart`
- `lib/features/social/presentation/pages/social_page.dart`
- `lib/features/notifications/presentation/pages/notifications_page.dart`
- All `presentation/widgets/` files (pure UI components)
- `lib/global/core/services/logger_service.dart`
- `lib/global/core/services/toast_service.dart`
- `lib/global/core/services/notification_service.dart`
- `lib/global/core/constants/images/images.dart` (migrate to `app/asset_paths.dart`)
- `lib/global/core/constants/text/text_color.dart` (migrate to `app/app_colors.dart`)
- `lib/global/core/config/app_config.dart` (migrate to `app/urls.dart`)
- `lib/global/core/theme/` (migrate to `app/app_theme.dart`)

---

*Created: 2026-06-12*
*Last updated: 2026-06-12*

## Status

| Phase | Status |
|-------|--------|
| Phase 1: Foundation — Create `app/` + `core/` layers | ✅ Done |
| Phase 2: AuthController — Simplify token management | ✅ Done |
| Phase 3: Feature-by-feature migration | ✅ Done |
| Phase 4: Remove `domain/` layer | ✅ Done |
| Phase 5: Simplify `data/` layer | ✅ Done |
| Phase 6: Rename `pages/` → `screens/` | ✅ Done |
| Phase 7: Simplify `main.dart` + routing | ✅ Done |
| Phase 8: Cleanup and final test | ✅ Done |
