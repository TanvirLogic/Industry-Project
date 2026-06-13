# Common UI Design System — Eduverse

> **Purpose**: A single source of truth for all UI decisions. Before building any new page or widget, read this file to match the project's visual language. Also read [`AI_CODING_GUIDE.md`](AI_CODING_GUIDE.md) for architecture patterns.

---

## 1. Design Tokens

### 1.1 Color Palette

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `scaffoldBackgroundColor` | `#FCFCFD` | `#111827` | Page backgrounds. **Never override per-page.** |
| `cs.primary` | `#134BBF` | `#134BBF` | Buttons, active pills, accent icons, links |
| `cs.onSurface` | `#1F2937` | `Colors.white` | Primary text |
| `cs.onSurface` (alpha 0.6) | `#6B7280` equivalent | white 60% | Secondary/subtitle text |
| `cs.onSurface` (alpha 0.5) | `#9CA3AF` equivalent | white 50% | Tertiary/metadata text (dates, status) |
| `cs.onSurface` (alpha 0.4) | — | — | Arrow icons, disabled hints |
| Card background | `Colors.white` | `cs.surfaceContainerLow` | All card/container surfaces |
| Card border | `#EFEFF0` | `#EFEFF0` | Card outlines (enabled borders everywhere) |
| Input fill | `Colors.white` | `#1F2937` | TextField backgrounds |
| Input border | `#EFEFF0` | `#EFEFF0` | TextField enabled border |
| Back button bg | `#F5F5F5` | `cs.surfaceContainerHighest` | `AppBackButton` |
| Tile/hover bg | `#F9F9F9` | `#F9F9F9` | Menu row tiles (hub general items), filter pills |
| Hub icon circle bg | `#EFEFF0` | `#EFEFF0` | 40×40 circle behind item icons in hub sections |
| **AuthButton background** | `TextColor.appColor` (`#134BBF`) | Same | Primary CTA buttons (solid color) |
| Positive amount | `#10B981` | `#10B981` | Revenue/green indicators |
| Negative amount | `#EF4444` | `#EF4444` | Expense/red indicators |
| Pending status | `#F59E0B` | `#F59E0B` | Amber/warning indicators |
| Logout text | `#DC2626` | `#DC2626` | Logout button |
| Logout bg | `#FEF2F2` | — | Logout button background |
| Logout border | `#FEE2E2` | — | Logout button border |
| Star rating | `#FBBF24` | `#FBBF24` | Star icons |
| Star empty | `#E5E7EB` | `#E5E7EB` | Empty star icons |

### 1.2 Semantic Colors (Hardcoded — Not Theme-Dependent)

These are status/semantic colors that do NOT change between light/dark:

```
Positive green   → #10B981    (amounts, success badges)
Negative red     → #EF4444    (expenses, errors)
                  → #DC2626    (logout text)
Pending amber    → #F59E0B    (pending status)
Warning orange   → #EA580C    (ad-related icons)
Star gold        → #FBBF24    (filled star)
Star gray        → #E5E7EB    (empty star)
```

### 1.3 Typography

| Style | Size | Weight | Color |
|-------|------|--------|-------|
| Page title | 24px | w700 | `cs.onSurface` |
| Section title | 16px | w700 | `isDark ? Colors.white : Color(0xFF1F2937)` |
| Body / menu labels | 14px | w500 | `isDark ? Colors.white : TextColor.primaryTextColor` |
| Small label | 12px | w600 | `cs.onSurface.withValues(alpha: 0.6)` |
| Metadata | 12px | w500 | `cs.onSurface.withValues(alpha: 0.5)` |
| Card amount | 20px | w800 | `isDark ? Colors.white : Color(0xFF1F2937)` |
| Transaction amount | 15px | w800 | positive: `#10B981` / negative: `#EF4444` |
| Heading (h1) | 24px | w700 | `cs.onSurface` |
| Subheading | 14px | w500 | `cs.onSurface.withValues(alpha: 0.6)` |
| Hint | 14px | w500 | light: `#9CA3AF`, dark: `#6B7280` |
| Button text | 16px | w600 | `Colors.white` |
| Pill filter text | 13px | w700 | selected: white, unselected: `cs.onSurface.withValues(alpha: 0.7)` |

**Font family**: `GoogleFonts.urbanist` (set globally via theme's `textTheme`).  
**Do NOT call `GoogleFonts.urbanist(...)` inline** — use plain `TextStyle` which inherits Urbanist from the theme. (Legacy pages have been migrated.)

### 1.4 Border Radii

| Element | Radius | Notes |
|---------|--------|-------|
| Cards / containers | `16` | Standard card radius (project convention) |
| Section group cards (hub) | `24` | Hub page `_SettingsGroupCard` style |
| Menu row tiles | `16` | Hub sub-tiles (non-general) |
| Hub general menu items | `24` | `isGeneral: true` items in hub settings cards |
| AuthButton | `30` | Matches theme `elevatedButtonTheme` |
| AppBackButton | `circle` | Circular avatar shape |
| TextField border | `15` | From theme's `InputDecorationTheme` |
| OTP boxes | `12` | Verification page code boxes |
| Filter pills | `20` | Horizontal pill selectors |
| Logout button | `28` | Hub page logout |
| Crop guide (circular) | circle | Avatar crop guide cutout |
| Crop guide (rect) | `6` | Cover crop dotted border |

### 1.5 Spacing

| Token | Value | Usage |
|-------|-------|-------|
| Page horizontal padding | `24` | All pages with SafeArea |
| Between form fields | `20` | Between CustomTextFields |
| Section gap | `24` | Between major sections |
| Between cards | `16` | Between sibling cards |
| Card inner padding | `16` or `20` | Inside containers |
| Hub settings card padding | `h:12, v:15` | `_SettingsGroupCard` padding |
| Tile inner padding | `h:14, v:12` | Menu/Toggle row tiles (non-general) |
| Hub general item padding | `all(8)` | `isGeneral: true` items padding |
| Tile gap | `12` | Between tiles in a group |

### 1.6 Shadows & Elevation

- **No shadows** used anywhere. Cards use `Border` instead of `BoxShadow`.
- AuthButton uses `elevation: 0`.

---

## 2. Page Structure Patterns

### 2.1 Auth Sub-Pages (Login, Register, Forgot, Verification, Reset, Set Password, Password Success)

```
Scaffold
  body: SafeArea
    child: GestureDetector(onTap: → unfocus)    ← keyboard dismiss
      child: SingleChildScrollView
        padding: EdgeInsets.symmetric(horizontal: 24.0)
        child: Column(crossAxisAlignment: stretch)
          SizedBox(height: 20)
          AppBackButton (align left)             ← not an AppBar
          SizedBox(height: 24)
          Title text (24px, w700, cs.onSurface)
          SizedBox(height: 8)
          Subtitle text (14px, w500, cs.onSurface alpha 0.6)
          SizedBox(height: 24)
          ... form fields ...
          Consumer<XxxProvider>(builder: → AuthButton)
```

**Key rules**: No AppBar. Back button is `AppBackButton` inside body. Keyboard dismiss wrap.

### 2.2 Hub Sub-Pages (Password & Security, Payments & Revenue)

Same as auth sub-pages but:
- Title + content structure follows section needs
- `AppBackButton` is the first element in the Column
- Padding: `EdgeInsets.symmetric(horizontal: 24.0)`
- No AppBar, no Scaffold background override

### 2.3 Hub Page (Settings Tab, Inside Nav Shell)

```
SafeArea (no Scaffold at page level)
  SingleChildScrollView
    padding: l:16, r:16, t:8, b:24
    physics: BouncingScrollPhysics
    Column
      _HubHeader
      SizedBox(16)
      _SettingsGroupCard[...]
      SizedBox(16)
      _SettingsGroupCard[...]
      ...
      SizedBox(32)
      LogoutButton
      SizedBox(16)
```

**Key rules**: No Scaffold (rendered inside `MainNavShell`'s IndexedStack). Cards use `_SettingsGroupCard` pattern.

### 2.4 Course Pages (Details, Enrolled, Upload)

```
Scaffold
  AppBar (with AppBackButton as leading)
  body: SingleChildScrollView / content
```

**Key rules**: These USE AppBar. Back button via `AppBackButton` as leading widget.

### 2.5 Profile Pages (Student, Mentor, Edit)

```
Scaffold
  (custom AppBar or hero-based back button)
  body: content
```

Student profile uses `ProfileAppBar`. Mentor profile uses hero banner's built-in back button. Edit profile uses `EditAppBarModule`.

---

## 3. Card & Container Patterns

### 3.1 Standard Content Card

```dart
Container(
  padding: const EdgeInsets.all(16),    // or 20 for activity cards
  decoration: BoxDecoration(
    color: isDark ? cs.surfaceContainerLow : Colors.white,
    borderRadius: BorderRadius.circular(24),    // hub section cards
    // OR BorderRadius.circular(16),            // standard content cards
    border: Border.all(
      color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
    ),
  ),
  child: ...
)
```

### 3.2 Settings Group Card (Hub Page)

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
  decoration: BoxDecoration(
    color: Colors.white,                // all hub cards use white
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFEFEFF0),   // consistent stroke
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 12),
        child: Text(title, style: groupTitleStyle),
      ),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => children[index],
      ),
    ],
  ),
)
```

### 3.3 Menu Row Tile (Hub Page)

**Default variant** (`isGeneral: false`):
```dart
InkWell(
  onTap: onTap ?? () {},
  borderRadius: BorderRadius.circular(16),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: isDark ? cs.surfaceContainerHighest : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(                         // icon circle
          width: 40, height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEFEFF0),
            shape: BoxShape.circle,
          ),
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: menuLabelStyle)),
        trailing arrow / text,
      ],
    ),
  ),
)
```

**General variant** (`isGeneral: true` — used in hub settings cards):
```dart
InkWell(
  onTap: onTap ?? () {},
  borderRadius: BorderRadius.circular(24),
  child: Container(
    width: 313,
    height: 56,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFF9F9F9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Color(0xFFEFEFF0)),
    ),
    child: Row(
      children: [
        Container(                         // icon circle 40×40
          width: 40, height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEFEFF0),
            shape: BoxShape.circle,
          ),
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: menuLabelStyle)),
        Icon(Icons.arrow_forward_ios_rounded, size: 14,
              color: cs.onSurface.withValues(alpha: 0.4)),
      ],
    ),
  ),
)
```

**Toggle variant** (`_ToggleRowTile` — used in Personalise section):
- Same general styling (313×56, `#F9F9F9` fill, `#EFEFF0` border, radius 24)
- Trailing widget is `Switch.adaptive` instead of arrow
- Supports both `iconAsset` (SVG) and `icon` (IconData) parameters
  - Email Notification uses `Icons.email_outlined` (not SVG)

---

## 4. Global Widgets Reference

### 4.1 `AppBackButton` (`lib/global/core/widgets/app_back_button.dart`)

- Circular back button, `Icons.keyboard_arrow_left`
- Light bg: `#F5F5F5`, Dark bg: `cs.surfaceContainerHighest`
- `Border.all(color: cs.outlineVariant)`
- Default `onPressed`: `Navigator.pop(context)`
- **Where used**: All auth sub-pages, hub sub-pages, course pages
- **Where MISSING**: Some pages that still have custom back buttons (e.g., `set_new_password_page.dart` uses inline CircleAvatar)

### 4.2 `AuthButton` (`lib/global/core/widgets/auth_button.dart`)

- Full-width solid button: `TextColor.appColor` (`#134BBF`)
- Default height: `56`, default radius: `30`
- Loading state: shows `CircularProgressIndicator`, disables tap
- Disabled state: opacity 0.5
- Params: `text`, `onPressed`, `isLoading`, `height`, `borderRadius`
- **Where used**: Most auth pages, hub sub-pages, course enrollment
- **Where MISSING**: ~~`profile_editing_page.dart` had duplicate `ActionButtonsModule`~~ ✅ Replaced with `AuthButton`

### 4.3 `CustomTextField` (`lib/features/auth/presentation/widgets/custom_text_field.dart`)

- Themed wrapper around `TextFormField`
- Uses theme's `InputDecorationTheme` (fill, border, hint)
- `AutovalidateMode.onUserInteraction` for format errors
- "Required" errors shown as toasts (not inline) via `isRequired: true` + validator returning null for empty
- Supports `isObscure` + `suffixIcon` for password visibility
- **Where used**: Login, Register, ForgotPassword, SetNewPassword, PasswordAndSecurity
- **Where MISSING**: `upload_course_page.dart`, `upload_video_page.dart` use raw `TextFormField`

### 4.4 `CachedNetworkImage` / `CachedNetworkImageProvider`

- From `cached_network_image` package
- **Replaces all raw `Image.network` / `NetworkImage`** across the app
- Provides disk caching, placeholders, error widgets, retry
- Avatar/banner placeholders use `Image.asset('assets/images/profile_icons/user.png')` in both `placeholder` and `errorWidget`
- Use `key: ValueKey(imageUrl)` to force re-fetch when URL changes (avatar upload)

### 4.5 `CustomCropScreen` (Avatar/Banner Crop)

- Full-screen manual crop using `dart:ui` `PictureRecorder` + `drawImageRect`
- Replaces native `ImageCropper.cropImage()` which crashes on Android 16 (API 36)
- Circular guide for avatar (1:1), rectangular for cover (16:9)
- Dotted border color: `TextColor.appColor` (`#134BBF`)
- Dim overlay: `Colors.black.withValues(alpha: 0.65)`
- Output: PNG at max 1024×1024 (avatar) or 1920×1080 (cover)
- Body height computed without `padding.bottom` (matches `LayoutBuilder` for exact crop)
- Crop output preserves exact aspect ratio after image-bound clamping

### 4.5 `ToastService` (global service)

- Static methods: `showSuccess()`, `showError()`, `showInfo()`
- Uses `scaffoldMessengerKey` (set in `main.dart`)
- Error sanitizer: `_getFriendlyMessage()` maps technical errors to user-friendly text
- Called from **providers** (not pages)

---

## 5. Per-File Design Audit

### 5.1 Auth Feature

#### `login_page.dart` ✅ Good
- Uses `CustomTextField`, `AuthButton`, `Consumer<AuthProvider>`
- No AppBar, follows SafeArea pattern
- ✅ Verbose comments cleaned

#### `register_page.dart` ⚠️ Too Large (710 lines)
- Follows correct structure but `_InputLabel` is inline — could be extracted (cross-file duplication with `set_new_password_page.dart` ✅ removed)
- DOB picker bottom sheet duplicated in `profile_editing_page.dart`
- `_RoleCard` is inline — could be extracted

#### `verification_page.dart` / `reset_verification_page.dart` ⛔ Near-Duplicate
- ~80% identical (OTP UI, resend timer, 6 `_OtpBox` widgets)
- Different providers (`EmailVerificationProvider` vs `PasswordResetProvider`)
- **Should be unified** into a shared `VerificationPageBase` or `OtpVerificationScreen`

#### `set_new_password_page.dart` ✅ Fixed
- Now uses `CustomTextField`; duplicate `_InputLabel` removed

#### `forgot_password_page.dart` ✅ Good
- Clean, minimal, uses global widgets

#### `password_success_page.dart` ✅ Good
- Clean, dynamic content via route args

### 5.2 Hub Feature

#### `hub_page.dart` ⚠️ Too Many Private Classes
- `GoogleFonts.urbanist` inline ✅ removed
- Hardcoded colors ✅ removed
- Dark mode border ✅ updated to `#EFEFF0`
- Now uses `isGeneral: true` styling for all settings items (313×56, `#F9F9F9` bg, `#EFEFF0` border)
- Cards use `Colors.white` background, `horizontal: 12, vertical: 15` padding
- Email Notification uses `Icons.email_outlined` instead of SVG
- 7 private inline classes still make file ~625 lines — could be extracted
- Refactoring priority: **Low** (functional, no block to further work)

#### `password_and_security_page.dart` ✅ Good (Reference Pattern)
- Clean SafeArea structure, `AppBackButton`, `CustomTextField`, `AuthButton`
- Uses `cs.onSurface` throughout
- No `GoogleFonts` inline
- Follows auth sub-page pattern

#### `payments_and_revenue_page.dart` ⚠️ Recently Refactored
- Now uses `AppBackButton`, proper card/color patterns
- Still has hardcoded dummy data and semantic colors (acceptable for semantic colors like `#EF4444`)
- Transaction data is mock — will be replaced by API

### 5.3 Courses Feature

#### `courses_page.dart` ⚠️ No `CustomTextField` + Dummy Data
- Search field uses raw `TextFormField` (not `CustomTextField`)
- Hardcoded colors ✅ removed
- Dummy data throughout
- Refactoring priority: **Low** (functional)

#### `course_details_page.dart` / `enrolled_course_page.dart` ⛔ Near-Duplicate
- ~70% identical structure (tabs, thumbnail, overview, reviews)
- `GoogleFonts.urbanist` inline ✅ removed
- Shared logic should be extracted into a `CourseContentBase` or mixin
- Refactoring priority: **Low** (API integration will rewrite anyway)

#### `upload_course_page.dart` / `upload_video_page.dart` ⛔ Not Using `CustomTextField`
- Use raw `TextFormField` with inline `_inputDecoration` helper
- Duplicates input border decoration from theme
- **Should use `CustomTextField`**

#### `payment_success_page.dart` ✅ Clean
- `GoogleFonts.urbanist` inline ✅ removed
- Hardcoded colors ✅ removed

### 5.4 Social Feature

#### `social_page.dart` ⚠️ Styling + Dummy Data
- `#1E1E2E` ✅ removed
- Hardcoded colors ✅ removed
- `GoogleFonts.urbanist` inline ✅ removed
- AuthButton used with tiny custom height (28px) — not designed for this
- Dummy data

### 5.5 Profile Features

#### `student_profile_page.dart` ⚠️ Large File
- Handles loading/error/data states well
- Imports 8+ feature-specific widgets (good separation)
- `_LoadingAppBar` is a near-empty duplicate of regular AppBar
- Avatar upload flow: pick → `CustomCropScreen` (1:1 circular, 1024×1024) → upload via `AvatarUploadProvider`
- Skill badges use high-quality `blue_tick.png` (500×500, from `profile_icons/`)

#### `mentor_profile_page.dart` ⚠️ Large File (374 lines)
- Has a 100+ line "Helper Functions" section that could be extracted
- Reuses student widgets (good pattern)
- Avatar upload: same flow as student (pick → `CustomCropScreen` → upload)
- Cover photo: uses `CoverRepositionScreen` with `bannerHeight: 195`
- Banner upload uses `CoverUploadProvider` (separate from avatar provider)

#### `profile_editing_page.dart` ⛔ Largest File (829 lines)
- `ActionButtonsModule` ~~duplicates `AuthButton` pattern~~ ✅ Replaced with `AuthButton`
- Gender field now sends `int` (1=Male, 0=Female) instead of `String`
- Post-save provider refresh is role-aware: `MENTOR` → `MentorProfileProvider`, else → `StudentProfileProvider`
- `refreshProfile` merges 12 editable fields via `copyWith` (preserves `videos`, `courses`, `socialPlatforms`)
- DOB picker duplicates `register_page.dart` implementation
- Should be split into smaller files
- Refactoring priority: **Medium**

---

## 6. Quick Reference: New Page Checklist

### Structure
- [ ] Correct scaffold pattern: `SafeArea` (no AppBar) for sub-pages, `Scaffold` + `AppBar` for detail/upload pages, no Scaffold for tab pages
- [ ] `GestureDetector(onTap: () => FocusScope.of(context).unfocus())` for keyboard dismiss on form pages
- [ ] `SingleChildScrollView` for scrollable content
- [ ] Horizontal padding: `EdgeInsets.symmetric(horizontal: 24.0)`

### Colors
- [ ] Card bg: `isDark ? cs.surfaceContainerLow : Colors.white`
- [ ] Card border: `Color(0xFFEFEFF0)` (same in light and dark — unified)
- [ ] Primary text: `cs.onSurface`
- [ ] Secondary text: `cs.onSurface.withValues(alpha: 0.6)`
- [ ] Metadata text: `cs.onSurface.withValues(alpha: 0.5)`
- [ ] Hub item fill: `Color(0xFFF9F9F9)`
- [ ] Hub icon circle bg: `Color(0xFFEFEFF0)`
- [ ] No hardcoded colors except semantic tokens (§1.2)
- [ ] No per-page `scaffoldBackgroundColor` override

### Widgets
- [ ] `AppBackButton` for back navigation (not custom CircleAvatar)
- [ ] `AuthButton` for primary CTA buttons (not custom buttons)
- [ ] `CustomTextField` for text inputs (not raw `TextFormField`)
- [ ] `CachedNetworkImage` / `CachedNetworkImageProvider` for all network images
- [ ] `Consumer<XxxProvider>` for state-dependent widgets (not full-page rebuilds)

### Typography
- [ ] Plain `TextStyle` (not `GoogleFonts.urbanist(...)` inline)
- [ ] Font weights match §1.3

---

## 7. Dead Code & Cleanup Items

| Item | File | Severity |
|------|------|----------|
| ~~`SvgImage` global widget~~ ✅ Removed | — | 🔴 Dead code |
| `PostPage` — stub with no functionality (8 lines, `SizedBox.shrink`) | `lib/features/posts/presentation/pages/post_page.dart` | 🟡 Placeholder |
| ~~`SectionHeader.showSeeAll` — missing text~~ ✅ Fixed | — | 🟡 Broken |
| ~~`uploadVidoePage` — typo~~ ✅ Fixed | — | 🟢 Typo |
| ~~`_InputLabel` duplicated~~ ✅ Fixed | — | 🟡 Duplicate |
| ~~AuthButton in `ActionButtonsModule` + `InstructorProfileCard`~~ ✅ Fixed | — | 🟡 Duplicate |
| ~~`SocialLinksFormBlockUi` wrong dir~~ ✅ Moved | — | 🟢 Structure |
| ~~`custom_crop_screen.dart` body height bug~~ ✅ Fixed | — | 🔴 Crop mismatch |
| ~~`pubspec.yaml` missing `profile_icons/` assets~~ ✅ Added | — | 🔴 Runtime crash |
| ~~`Images.blue_tick` path updated to high-res~~ ✅ Fixed | — | 🟢 Quality |

---

## 8. Refactoring Priority Matrix

| Priority | File | Issue | Effort |
|----------|------|-------|--------|
| 🔴 High | `verification_page.dart` + `reset_verification_page.dart` | 80% duplicate — unify | Medium |
| ~~🔴~~ ✅ | `svg_image.dart` | Dead code — removed | Low |
| ~~🟡~~ ✅ | `hub_page.dart` | GoogleFonts inline + hardcoded colors + dark-mode borders — fixed | Medium |
| 🟡 Medium | `profile_editing_page.dart` | 829 lines, duplicate ~~AuthButton~~✅ + DOB picker | High |
| ~~🟡~~ ✅ | `set_new_password_page.dart` | Not using CustomTextField — fixed | Low |
| ~~🟡~~ ✅ | `custom_crop_screen.dart` | Removed `padding.bottom` from body height calc (crop mismatch bug) | Low |
| 🟡 Medium | `upload_course_page.dart` + `upload_video_page.dart` | Not using CustomTextField | Low |
| 🟢 Low | `course_details_page.dart` + `enrolled_course_page.dart` | 70% duplicate — will be addressed during API integration | High |
| 🟢 Low | `courses_page.dart` | raw TextFormField + dummy data — will be addressed during API integration | Medium |
| 🟢 Low | `social_page.dart` | AuthButton tiny height + dummy data | Medium |
| ~~🟢~~ ✅ | `payment_success_page.dart` | GoogleFonts inline — fixed | Low |
| ~~🟢~~ ✅ | Route name typo (`uploadVidoePage`) | Fixed | Low |
| ~~🟢~~ ✅ | SectionHeader missing "See All" text | Fixed | Low |
