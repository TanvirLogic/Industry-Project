// app understanding questions -> 

main.dart -> initailize


WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await UploadNotificationService.init();
  BackgroundUploadService.registerBackgroundHandler();
  final prefs = await SharedPreferences.getInstance();
  runApp(App(prefs: prefs)); -> ! Q -> why prefs ? 

app.dart -> register providers , routes , toasts ,

<!-- builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final overlay = App.navigatorKey.currentState?.overlay;
              if (overlay != null) {
                ToastService.initOverlay(overlay);
              }
            });
            return child!;
          }, --> Why this 

Now -> Staring revicing from -> Splash -> 

Understand -> Auth Controller -> Then Understand Secure Storage -> 