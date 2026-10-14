import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';

/// True when the web dashboard URL is configured, so web links can be shown.
bool get canOpenWeb => Env.webUrl.isNotEmpty;

/// Opens a page of the web dashboard (sign up, password reset, privacy) in an
/// in-app browser, for things the mobile app does not do itself.
Future<void> openWebPage(String path) async {
  if (!canOpenWeb) return;
  final uri = Uri.parse('${Env.webUrl}${path.startsWith('/') ? path : '/$path'}');
  try {
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    // Nothing useful to show; the link simply does not open.
  }
}
