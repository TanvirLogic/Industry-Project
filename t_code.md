# Project Structure Reference: Crafty Bay (Flutter E-Commerce)

## Architecture Pattern

**Feature-First Architecture** + **Provider** for state management.

Each feature (auth, home, category, product, cart, wishlist) has its own folder with:
```
features/<feature_name>/
  data/
    models/     # Data classes (fromJson/toJson)
  providers/    # OR presentation/provider/ - ChangeNotifier classes for API + state
  presentation/
    screens/    # UI pages (StatefulWidget)
    widgets/    # Reusable UI components
```

**Global app config** lives in `app/`. **Core utilities** (network) live in `core/`.

---

## 1. Project Setup Flow

### 1.1 pubspec.yaml Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  provider: ^6.1.5+1
  shared_preferences: ^2.5.4
  http: ^1.5.0
  logger: ^2.6.1
  flutter_svg: ^2.2.3
  pin_code_fields: ^8.0.1
  carousel_slider: ^5.1.1
  firebase_core: ^4.3.0
  firebase_crashlytics: ^5.0.6
  firebase_analytics: ^12.1.0
  intl: ^0.20.2
  cupertino_icons: ^1.0.8
```

### 1.2 Folder Structure (to create first)
```
lib/
  main.dart
  firebase_options.dart
  app/
    app.dart
    app_colors.dart
    app_routes.dart
    app_theme.dart
    asset_paths.dart
    constants.dart
    urls.dart
    setup_network_caller.dart
    extensions/
      localization_extension.dart
    providers/
      language_provider.dart
      theme_provider.dart
  core/
    models/
      network_response.dart
    services/
      network_caller.dart
  l10n/
    app_en.arb
    app_bn.arb
    app_localizations.dart
    app_localizations_en.dart
    app_localizations_bn.dart
  features/
    auth/
      data/models/
        sign_in_params.dart
        sign_up_params.dart
        user_model.dart
        verify_otp_param.dart
      providers/  (or presentation/provider/)
        auth_controller.dart
        sign_in_provider.dart
        sign_up_provider.dart
        verify_otp_provider.dart
      presentation/
        screens/
          splash_screen.dart
          sign_in_screen.dart
          sign_up_screen.dart
          verify_otp_screen.dart
        widgets/
          app_logo.dart
    home/
      data/model/
        slider_model.dart
      providers/ (or presentation/provider/)
        slider_provider.dart
      presentation/
        screens/
          home_screen.dart
        widgets/
          circle_icon_button.dart
          home_carousel_slider.dart
          product_search_field.dart
          section_header.dart
    category/
      data/models/
        category_model.dart
      providers/ (or presentation/provider/)
        category_list_provider.dart
      presentation/
        screens/
          category_list_screen.dart
    product/
      data/models/
        product_model.dart
        product_details_model.dart
      providers/ (or presentation/provider/)
        product_list_by_category_provider.dart
        product_details_provider.dart
      presentation/
        screens/
          product_list_by_category_screen.dart
          product_details_screen.dart
        widgets/
          color_picker.dart
          size_picker.dart
          product_image_slider.dart
    cart/
      presentaton/    (note: typo in original - "presentaton")
        provider/
          add_to_cart_provider.dart
        screens/
          cart_screen.dart
        widgets/
          cart_item.dart
          inc_dec_button.dart
    wish_list/
      presentation/
        screens/
          wish_list_screen.dart
    common/
      presentation/
        providers/
          main_nav_container_provider.dart
        screens/
          main_nav_holder_screen.dart
        widgets/
          category_card.dart
          centered_circular_progress.dart
          favourite_button.dart
          language_selector.dart
          product_card.dart
          rating_view.dart
          theme_selector.dart
```

### 1.3 main.dart Entry Point
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  runApp(AppName());
}
```

---

## 2. App Layer (Global Config)

### 2.1 app/app.dart — Root Widget with MultiProvider
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
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadInitialLanguage()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadInitialThemeMode()),
        ChangeNotifierProvider(create: (_) => MainNavContainerProvider()),
        ChangeNotifierProvider(create: (_) => CategoryListProvider()),
        ChangeNotifierProvider(create: (_) => HomeSliderProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, _) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                navigatorKey: AppName.navigatorKey,
                debugShowCheckedModeBanner: false,
                initialRoute: SplashScreen.name,
                onGenerateRoute: AppRoutes.routes,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.currentThemeMode,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: [Locale('en'), Locale('bn')],
                locale: langProvider.currentLocale,
              );
            },
          );
        },
      ),
    );
  }
}
```

### 2.2 app/app_colors.dart
```dart
class AppColors {
  static Color themeColor = Color(0XFF07ADAE); // teal
}
```

### 2.3 app/app_theme.dart
```dart
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.themeColor,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        fixedSize: Size.fromWidth(double.maxFinite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.teal,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.grey),
      contentPadding: EdgeInsets.all(16),
      border: OutlineInputBorder(borderSide: BorderSide()),
      errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
    ),
  );
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.themeColor,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        fixedSize: Size.fromWidth(double.maxFinite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.teal,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: EdgeInsets.all(16),
      border: OutlineInputBorder(borderSide: BorderSide()),
      errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
    ),
  );
}
```

### 2.4 app/app_routes.dart — Named Route Generator
```dart
class AppRoutes {
  static Route<dynamic> routes(RouteSettings setting) {
    Widget widget = SizedBox();
    if (setting.name == SplashScreen.name) {
      widget = SplashScreen();
    } else if (setting.name == SignUpScreen.name) {
      widget = SignUpScreen();
    } else if (setting.name == SignInScreen.name) {
      widget = SignInScreen();
    } else if (setting.name == MainNavHolderScreen.name) {
      widget = MainNavHolderScreen();
    } else if (setting.name == CategoryListScreen.name) {
      widget = CategoryListScreen();
    } else if (setting.name == ProductListByCategoryScreen.name) {
      final categoryModel = setting.arguments as CategoryModel;
      widget = ProductListByCategoryScreen(categoryModel: categoryModel);
    } else if (setting.name == ProductDetailsScreen.name) {
      final productId = setting.arguments as String;
      widget = ProductDetailsScreen(productId: productId);
    } else if (setting.name == HomeScreen.name) {
      widget = HomeScreen();
    } else if (setting.name == VerifyOTPScreen.name) {
      final email = setting.arguments as String;
      widget = VerifyOTPScreen(email: email);
    }
    return MaterialPageRoute(builder: (context) => widget);
  }
}
```

**Pattern for routes:**
- Each screen has `static const String name = '/route-name';`
- Pass arguments via `setting.arguments`
- Extract and cast arguments in the route handler

### 2.5 app/urls.dart — API Endpoints
```dart
class Urls {
  static const String _baseUrl = 'https://your-api.com/api';
  static const String signUpUrl = '$_baseUrl/auth/signup';
  static const String verifyOtpUrl = '$_baseUrl/auth/verify-otp';
  static const String signInUrl = '$_baseUrl/auth/login';
  static const String homeSlidersUrl = '$_baseUrl/slides';
  static String categoryListUrl(int count, int page) =>
      '$_baseUrl/categories?count=$count&page=$page';
  static String productsByCategoryUrl(int size, int page, String categoryId) =>
      '$_baseUrl/products?count=$size&page=$page&category=$categoryId';
  static String productDetailsUrl(String id) =>
      '$_baseUrl/products/id/$id';
  static const String addToCartUrl = '$_baseUrl/cart';
}
```

### 2.6 app/constants.dart
```dart
class Constants {
  static const String takaSign = '৳';
}
```

### 2.7 app/asset_paths.dart
```dart
class AssetPaths {
  static const String _baseImagePath = 'assets/images/';
  static const String logoSvg = '${_baseImagePath}logo.svg';
  static const String logoNavSvg = '${_baseImagePath}logo_nav.svg';
  static const String shoePng = '${_baseImagePath}shoe.png';
}
```

### 2.8 app/setup_network_caller.dart — Factory with Auth Headers
```dart
NetworkCaller getNetworkCaller() {
  return NetworkCaller(
    headers: {
      'Content-type': 'application/json',
      'token': AuthController.accessToken ?? ''
    },
    onUnauthorize: () {
      // Navigate to login
    },
  );
}
```

### 2.9 app/extensions/localization_extension.dart
```dart
extension LocalizationExtension on BuildContext {
  AppLocalizations get localizations => AppLocalizations.of(this)!;
}
```

### 2.10 app/providers/language_provider.dart — Locale Management
```dart
class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = Locale("en");
  Locale get currentLocale => _currentLocale;

  Future<void> loadInitialLanguage() async {
    _currentLocale = await _getLocale();
    notifyListeners();
  }

  void changeLocale(Locale newLocale) {
    if (_currentLocale == newLocale) return;
    _currentLocale = newLocale;
    _saveLocale(currentLocale.languageCode);
    notifyListeners();
  }

  Future<void> _saveLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
  }

  Future<Locale> _getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return Locale(prefs.getString('locale') ?? 'en');
  }
}
```

### 2.11 app/providers/theme_provider.dart — Theme Mode Persistence
```dart
class ThemeProvider extends ChangeNotifier {
  final String _themeKey = 'themeMode';
  ThemeMode _currentThemeMode = ThemeMode.system;
  ThemeMode get currentThemeMode => _currentThemeMode;

  Future<void> loadInitialThemeMode() async {
    _currentThemeMode = await _getThemeMode();
    notifyListeners();
  }

  Future<void> changeTheme(ThemeMode mode) async {
    if (currentThemeMode == ThemeMode.system && _currentThemeMode == mode) {
      (await SharedPreferences.getInstance()).remove(_themeKey);
      return;
    }
    _currentThemeMode = mode;
    _saveThemeMode(mode.name);
    notifyListeners();
  }

  Future<void> _saveThemeMode(String mode) async {
    (await SharedPreferences.getInstance()).setString(_themeKey, mode);
  }

  Future<ThemeMode> _getThemeMode() async {
    final saved = (await SharedPreferences.getInstance()).getString(_themeKey) ?? '';
    switch (saved) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }
}
```

---

## 3. Core Layer (Network)

### 3.1 core/models/network_response.dart (part of network_caller.dart)
```dart
part of '../services/network_caller.dart';

class NetworkResponse {
  final bool isSuccess;
  final int responseCode;
  final dynamic responseData;
  final String? errorMessage;

  NetworkResponse({
    required this.isSuccess,
    required this.responseCode,
    required this.responseData,
    this.errorMessage = 'Something went wrong',
  });
}
```

### 3.2 core/services/network_caller.dart — HTTP Client
```dart
class NetworkCaller {
  final VoidCallback onUnauthorize;
  final Map<String, String>? headers;
  final String? decodedErrorMSGKey;

  NetworkCaller({required this.onUnauthorize, this.headers, this.decodedErrorMSGKey});

  Future<NetworkResponse> getRequest({required String url}) async {
    try {
      Uri uri = Uri.parse(url);
      Response response = await get(uri, headers: headers);
      final int statusCode = response.statusCode;

      if (statusCode == 200) {
        return NetworkResponse(
          isSuccess: true,
          responseCode: statusCode,
          responseData: jsonDecode(response.body),
        );
      } else if (statusCode == 401) {
        onUnauthorize();
        return NetworkResponse(isSuccess: false, responseCode: statusCode, errorMessage: 'Unauthorized');
      } else {
        final decodedData = jsonDecode(response.body);
        return NetworkResponse(
          isSuccess: false,
          responseCode: statusCode,
          responseData: decodedData,
          errorMessage: decodedData[decodedErrorMSGKey ?? 'msg'],
        );
      }
    } on Exception catch (e) {
      return NetworkResponse(isSuccess: false, responseCode: -1, errorMessage: e.toString());
    }
  }

  Future<NetworkResponse> postRequest({required String url, Map<String, dynamic>? body}) async {
    try {
      Uri uri = Uri.parse(url);
      Response response = await post(
        uri,
        headers: headers ?? {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
      final int statusCode = response.statusCode;

      if (statusCode == 200 || statusCode == 201) {
        return NetworkResponse(
          isSuccess: true,
          responseCode: statusCode,
          responseData: jsonDecode(response.body),
        );
      } else if (statusCode == 401) {
        onUnauthorize();
        return NetworkResponse(isSuccess: false, responseCode: statusCode, errorMessage: 'Unauthorized');
      } else {
        final decodedData = jsonDecode(response.body);
        return NetworkResponse(isSuccess: false, responseCode: statusCode, errorMessage: decodedData['msg']);
      }
    } on Exception catch (e) {
      return NetworkResponse(isSuccess: false, responseCode: -1, errorMessage: e.toString());
    }
  }
}
```

---

## 4. Data Models Pattern

### 4.1 Request Params (toJson only)
```dart
class SomeParam {
  final String field1;
  final String field2;

  SomeParam({required this.field1, required this.field2});

  Map<String, dynamic> toJson() {
    return {
      "field1": field1,
      "field2": field2,
    };
  }
}
```

### 4.2 Response Models (fromJson + toJson)
```dart
class SomeModel {
  final String id;
  final String title;
  final String icon;

  SomeModel({required this.id, required this.title, required this.icon});

  factory SomeModel.fromJson(Map<String, dynamic> json) {
    return SomeModel(
      id: json['_id'],
      title: json['title'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'title': title, 'icon': icon};
  }
}
```

### 4.3 All Models in This Project

| File | Fields | fromJson | toJson |
|------|--------|----------|--------|
| `sign_in_params.dart` | email, password | - | yes |
| `sign_up_params.dart` | firstName, lastName, email, password, phone, city | - | yes |
| `verify_otp_param.dart` | email, otp | - | yes |
| `user_model.dart` | firstName, lastName, email, phone, avatarUrl, city | yes | yes |
| `slider_model.dart` | id, photoUrl, description, brand, productId | yes | - |
| `category_model.dart` | id, title, icon | yes | - |
| `product_model.dart` | id, title, photo, currentPrice | yes | - |
| `product_details_model.dart` | id, title, description, photos[], colors[], sizes[], price, quantity | yes | - |

---

## 5. Provider Pattern (ChangeNotifier)

### 5.1 Basic Provider Template (Single API Call)
```dart
class MyProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SomeModel> _items = [];
  List<SomeModel> get items => _items;

  Future<bool> fetchItems() async {
    bool isSuccess = false;
    _isLoading = true;
    notifyListeners();

    final NetworkResponse response = await getNetworkCaller().getRequest(url: Urls.someUrl);

    if (response.isSuccess) {
      List<SomeModel> list = [];
      for (Map<String, dynamic> json in response.responseData['data']['results']) {
        list.add(SomeModel.fromJson(json));
      }
      _items = list;
      isSuccess = true;
      _errorMessage = null;
    } else {
      _errorMessage = response.errorMessage;
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }
}
```

### 5.2 Paginated Provider Template
```dart
class PaginatedProvider extends ChangeNotifier {
  final int _pageSize = 30;
  int _currentPageNo = 0;
  int? _lastPageNo;

  bool _initialLoading = false;
  bool _moreLoading = false;
  final List<SomeModel> _items = [];
  String? _errorMessage;

  bool get initialLoading => _initialLoading;
  bool get moreLoading => _moreLoading;
  List<SomeModel> get items => _items;

  Future<bool> fetchItems(String? param) async {
    bool isSuccess = false;

    if (_currentPageNo == 0) {
      _items.clear();
      _initialLoading = true;
    } else if (_currentPageNo < _lastPageNo!) {
      _moreLoading = true;
    } else {
      return false;
    }
    notifyListeners();

    _currentPageNo++;
    final response = await getNetworkCaller().getRequest(url: Urls.listUrl(_pageSize, _currentPageNo));

    if (response.isSuccess) {
      _lastPageNo ??= response.responseData['data']['last_page'];
      List<SomeModel> list = [];
      for (Map<String, dynamic> json in response.responseData['data']['results']) {
        list.add(SomeModel.fromJson(json));
      }
      _items.addAll(list);
      isSuccess = true;
    } else {
      _errorMessage = response.errorMessage;
    }

    if (_initialLoading) _initialLoading = false;
    else _moreLoading = false;

    notifyListeners();
    return isSuccess;
  }

  Future<void> loadInitial(String? param) async {
    _currentPageNo = 0;
    _lastPageNo = null;
    await fetchItems(param);
  }
}
```

### 5.3 Auth Controller (Static SharedPreferences Manager)
```dart
class AuthController {
  static const _tokenKey = 'access-token';
  static const _userKey = 'user-data';
  static UserModel? userModel;
  static String? accessToken;

  static Future<void> saveUserData(String token, UserModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(model.toJson()));
    accessToken = token;
    userModel = model;
  }

  static Future<void> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_tokenKey);
    if (accessToken != null) {
      final userData = prefs.getString(_userKey);
      if (userData != null) userModel = UserModel.fromJson(jsonDecode(userData));
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  static Future<void> clearUserData() async {
    (await SharedPreferences.getInstance()).clear();
  }
}
```

### 5.4 POST Provider Template (Create/Submit)
```dart
class SubmitProvider extends ChangeNotifier {
  bool _inProgress = false;
  bool get inProgress => _inProgress;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> submit(Map<String, dynamic> body) async {
    bool isSuccess = false;
    _inProgress = true;
    notifyListeners();

    final response = await getNetworkCaller().postRequest(url: Urls.somePostUrl, body: body);

    if (response.isSuccess) {
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

---

## 6. Screen Pattern (UI + Provider Integration)

### 6.1 Complete Screen Template
```dart
class MyScreen extends StatefulWidget {
  const MyScreen({super.key, required this.someParam});
  final String someParam;
  static const String name = '/my-screen';

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final MyProvider _provider = MyProvider();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _provider,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(title: Text(context.localizations.someTitle)),
          body: Consumer<MyProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) return CenterCircularProgress();
              return ListView.builder(
                itemCount: provider.items.length,
                itemBuilder: (context, index) => Text(provider.items[index].title),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 6.2 Form Submission Screen (Sign In / Sign Up)
```dart
// In the State class:
void _onTapButton() {
  if (_formKey.currentState!.validate()) {
    _submit();
  }
}

Future<void> _submit() async {
  final bool isSuccess = await _provider.someMethod(SomeParam(
    field1: _controller1.text.trim(),
    field2: _controller2.text,
  ));
  if (isSuccess) {
    Navigator.pushNamed(context, NextScreen.name);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_provider.errorMessage!)),
    );
  }
}
```

### 6.3 Consumer + Loading Pattern (Button with Progress)
```dart
Consumer<MyProvider>(
  builder: (context, provider, _) {
    return Visibility(
      visible: provider.isLoading == false,
      replacement: CircularProgressIndicator(),
      child: FilledButton(
        onPressed: _onTapButton,
        child: Text(context.localizations.submit),
      ),
    );
  },
),
```

### 6.4 Scroll Pagination Pattern
```dart
final ScrollController _scrollController = ScrollController();

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _provider.loadInitial(param);
    _scrollController.addListener(_loadMore);
  });
}

void _loadMore() {
  if (_provider.moreLoading) return;
  if (_scrollController.position.extentBefore < 300) {
    _provider.fetchItems(param);
  }
}

// In GridView/ListView:
GridView.builder(
  controller: _scrollController,
  itemCount: _provider.items.length,
  ...
),
if (_provider.moreLoading) CenterCircularProgress()
```

---

## 7. Navigation Flow

```
SplashScreen (3s delay)
  └→ MainNavHolderScreen (Bottom Nav)
       ├─ Tab 0: HomeScreen
       │    ├─ CategoryCard → ProductListByCategoryScreen
       │    │    └─ ProductCard → ProductDetailsScreen
       │    └─ Carousel / Popular / Special / New sections
       ├─ Tab 1: CategoryListScreen (paginated grid)
       │    └─ CategoryCard → ProductListByCategoryScreen
       ├─ Tab 2: CartScreen (auth-gated)
       └─ Tab 3: WishListScreen (auth-gated)

Auth Flow:
  SignUpScreen → (success) → VerifyOTPScreen → (success) → SignInScreen
  SignInScreen → (success) → HomeScreen (replace)
```

**Auth gating in bottom nav:**
```dart
onTap: (int index) async {
  if (index == 2 || index == 3) {
    if (await AuthController.isLoggedIn() == false) {
      Navigator.pushNamed(context, SignUpScreen.name);
      return;
    }
  }
  provider.changeIndex(index);
},
```

---

## 8. Common Reusable Widgets

### 8.1 CenteredCircularProgress
```dart
class CenterCircularProgress extends StatelessWidget {
  Widget build(BuildContext context) => Center(child: CircularProgressIndicator());
}
```

### 8.2 SectionHeader (Title + "See All" button)
```dart
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTapSeeAll;

  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Spacer(),
        TextButton(
          onPressed: onTapSeeAll,
          child: Text(context.localizations.seeAll, style: TextStyle(color: AppColors.themeColor)),
        ),
      ],
    );
  }
}
```

### 8.3 LanguageSelector / ThemeSelector
```dart
// LanguageSelector - uses DropdownMenu
DropdownMenu<String>(
  initialSelection: context.read<LanguageProvider>().currentLocale.languageCode,
  label: const Text('Language'),
  onSelected: (String? lang) => context.read<LanguageProvider>().changeLocale(Locale(lang!)),
  dropdownMenuEntries: [
    DropdownMenuEntry(value: 'en', label: 'English'),
    DropdownMenuEntry(value: 'bn', label: 'Bangla'),
  ],
);

// ThemeSelector
DropdownMenu<ThemeMode>(
  initialSelection: context.read<ThemeProvider>().currentThemeMode,
  label: const Text('Theme'),
  onSelected: (ThemeMode? mode) => context.read<ThemeProvider>().changeTheme(mode!),
  dropdownMenuEntries: [
    DropdownMenuEntry(value: ThemeMode.light, label: 'Light'),
    DropdownMenuEntry(value: ThemeMode.dark, label: 'Dark'),
    DropdownMenuEntry(value: ThemeMode.system, label: 'System'),
  ],
);
```

### 8.4 CategoryCard (Icon + Title → navigates to ProductListByCategory)
```dart
GestureDetector(
  onTap: () => Navigator.pushNamed(context, ProductListByCategoryScreen.name, arguments: categoryModel),
  child: Column(
    children: [
      Card(color: AppColors.themeColor.withAlpha(30), child: Padding(
        padding: EdgeInsets.all(12),
        child: Image.network(categoryModel.icon, width: 30, height: 30),
      )),
      Text(categoryModel.title, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.themeColor)),
    ],
  ),
);
```

### 8.5 ProductCard (Image + Title + Price + Rating + Favourite)
```dart
GestureDetector(
  onTap: () => Navigator.pushNamed(context, ProductDetailsScreen.name, arguments: productModel.id),
  child: Card(
    child: Column(children: [
      Container(height: 90, decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(productModel.photo)))),
      Padding(
        padding: EdgeInsets.all(8),
        child: Column(children: [
          Text(productModel.title, maxLines: 1),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${Constants.takaSign}${productModel.currentPrice}'),
            RatingView(),
            FavouriteButton(),
          ]),
        ]),
      ),
    ]),
  ),
);
```

### 8.6 IncDecButton (+/- quantity stepper)
```dart
class IncDecButton extends StatefulWidget {
  final Function(int) onChange;
  final int maxValue;
}

class _IncDecButtonState extends State<IncDecButton> {
  int _currentValue = 1;

  Widget build(BuildContext context) {
    return Row(children: [
      GestureDetector(
        onTap: () { if (_currentValue > 1) { _currentValue--; widget.onChange(_currentValue); setState(() {}); }},
        child: Container(padding: EdgeInsets.all(4), color: AppColors.themeColor, child: Icon(Icons.remove, color: Colors.white)),
      ),
      Text('$_currentValue'),
      GestureDetector(
        onTap: () { if (widget.maxValue > _currentValue) { _currentValue++; widget.onChange(_currentValue); setState(() {}); }},
        child: Container(padding: EdgeInsets.all(4), color: AppColors.themeColor, child: Icon(Icons.add, color: Colors.white)),
      ),
    ]);
  }
}
```

### 8.7 ColorPicker / SizePicker (selectable chips)
```dart
// ColorPicker
class ColorPicker extends StatefulWidget {
  final List<String> colors;
  final Function(String) onchange;
}
// State: String? _selectedColor
// Build: Wrap of GestureDetector containers - on tap sets _selectedColor, calls widget.onchange, setState

// SizePicker — identical pattern but for sizes list
```

### 8.8 ProductImageSlider / HomeCarouselSlider
```dart
// Both use CarouselSlider + ValueNotifier<int> for index tracking + Row of dot indicators
ValueNotifier<int> _selectedIndex = ValueNotifier(0);

CarouselSlider(
  options: CarouselOptions(height: 200, viewportFraction: 1, onPageChanged: (i, r) => _selectedIndex.value = i),
  items: items.map((item) => Container(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(item))))).toList(),
),
ValueListenableBuilder(
  valueListenable: _selectedIndex,
  builder: (context, index, _) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(items.length, (i) => Container(
      width: 12, height: 12, margin: EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: i == index ? AppColors.themeColor : null,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(16),
      ),
    )),
  ),
),
```

---

## 9. Data Flow Summary

```
User taps button
  → Screen's _onTap method validates form
    → Calls Provider.method(Params)
      → Provider sets _isLoading = true, notifyListeners()
        → UI shows CircularProgressIndicator (via Consumer + Visibility)
      → Provider calls getNetworkCaller().getRequest/postRequest(url: Urls.someUrl, body: params.toJson())
        → NetworkCaller makes HTTP request
          → Returns NetworkResponse(isSuccess, responseCode, responseData, errorMessage)
      → If success: parse data, create models, save to provider state
      → If failure: save errorMessage
      → Provider sets _isLoading = false, notifyListeners()
        → UI shows results or error SnackBar
```

---

## 10. Key Conventions to Follow

1. **Screen name constant**: Every screen has `static const String name = '/route-name'`
2. **Provider in State**: Create provider instance in State, wrap screen body with `ChangeNotifierProvider(create: (_) => _provider)`
3. **Consumer for reactivity**: Use `Consumer<ProviderType>` to rebuild specific parts
4. **Loading state**: Boolean flag + notifyListeners() before and after async work
5. **Error handling**: Store error message in provider, show via `ScaffoldMessenger.showSnackBar`
6. **Navigation arguments**: Extract from `setting.arguments` in AppRoutes, pass as constructor params
7. **Localization**: Use `context.localizations.someKey` (via extension on BuildContext)
8. **Form validation**: `GlobalKey<FormState>` + `TextEditingController` per field + dispose in `dispose()`
9. **Unfocus**: Wrap Scaffold with `GestureDetector(onTap: () => FocusScope.of(context).unfocus())`
10. **Auth gating**: Check `AuthController.isLoggedIn()` before accessing protected screens
11. **API response structure**: Expect `responseData['data']['results']` for lists, `responseData['data']['last_page']` for pagination
12. **Pagination**: Track `_currentPageNo`, `_lastPageNo`, `_initialLoading`, `_moreLoading` — reset on fresh load
13. **Bottom nav state**: `MainNavContainerProvider` manages `_selectedIndex`, has helper methods `changeToHome()`, `changeToCategory()`