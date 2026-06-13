import '../../features/auth/data/models/auth_controller.dart';
import '../../features/auth/providers/sign_in_provider.dart';

import '../global/core/services/network_caller.dart';
import 'app.dart';

NetworkCaller getNetworkCaller({bool isPublic = false}) {
  return NetworkCaller(
    decodedErrorMSGKey: 'message',
    headers: isPublic
        ? {'content-type': 'application/json'}
        : {
            'content-type': 'application/json',
            'Authorization': 'Bearer ${AuthController.accessToken ?? ''}',
          },
    onRefreshToken: isPublic
        ? null
        : () async {
            final provider = SignInProvider();
            return await provider.tryRefreshToken();
          },
    onUnauthorize: isPublic
        ? () {}
        : () {
            AuthController.clearUserData();
            App.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
          },
  );
}
