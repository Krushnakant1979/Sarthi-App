import 'package:sarthi_app/app/app_config.dart';
import 'bootstrap.dart';

void main() {
  // Entry point for PRODUCTION
  bootstrap(env: 'prod', appType: AppType.user);
}
