import 'package:flutter/widgets.dart';

/// Root navigator used by [GoRouter]. Lets auth flows navigate when the
/// login [State] was recreated (e.g. Firebase reCAPTCHA custom URL handling).
final stitchSmartRootNavigatorKey = GlobalKey<NavigatorState>();
