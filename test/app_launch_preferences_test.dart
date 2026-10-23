import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/app_launch_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'limited notification choice is persisted without pretending it is enabled',
    () async {
      SharedPreferences.setMockInitialValues({});

      await AppLaunchPreferences.markPermissionSetupCompleted(
        notificationAccessEnabled: false,
      );
      final state = await AppLaunchPreferences.load();

      expect(state.permissionSetupCompleted, isTrue);
      expect(state.requiredNotificationAccessWasEnabled, isFalse);
    },
  );

  test(
    'existing completed setup migrates as previously notification-enabled',
    () async {
      SharedPreferences.setMockInitialValues({
        'esugid_permission_setup_completed_v1': true,
      });

      final state = await AppLaunchPreferences.load();

      expect(state.permissionSetupCompleted, isTrue);
      expect(state.requiredNotificationAccessWasEnabled, isTrue);
    },
  );
}
