import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const hCaptchaSiteKey = String.fromEnvironment('HCAPTCHA_SITE_KEY');

class HCaptchaWidget extends StatefulWidget {
  const HCaptchaWidget({
    super.key,
    required this.onToken,
    required this.onError,
  });

  final ValueChanged<String> onToken;
  final ValueChanged<String> onError;

  @override
  State<HCaptchaWidget> createState() => _HCaptchaWidgetState();
}

class _HCaptchaWidgetState extends State<HCaptchaWidget> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (hCaptchaSiteKey.isEmpty || hCaptchaSiteKey.startsWith('YOUR_')) return;
    final siteKey = jsonEncode(hCaptchaSiteKey);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CaptchaToken',
        onMessageReceived: (message) => widget.onToken(message.message),
      )
      ..addJavaScriptChannel(
        'CaptchaError',
        onMessageReceived: (message) => widget.onError(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url.startsWith('https://')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(
        '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script>
    function onCaptchaLoaded() {
      hcaptcha.render('captcha', {
        sitekey: $siteKey,
        callback: function(token) { CaptchaToken.postMessage(token); },
        'error-callback': function() { CaptchaError.postMessage('CAPTCHA could not load. Try again.'); },
        'expired-callback': function() { CaptchaError.postMessage('CAPTCHA expired. Complete it again.'); }
      });
    }
  </script>
  <script src="https://js.hcaptcha.com/1/api.js?onload=onCaptchaLoaded&render=explicit" async defer></script>
</head>
<body style="margin:0;padding:8px;font-family:sans-serif">
  <div id="captcha"></div>
</body>
</html>
        ''',
        baseUrl: 'https://hcaptcha.com/',
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Text('CAPTCHA is not configured for this build.');
    }
    return SizedBox(
      height: 190,
      child: WebViewWidget(controller: controller),
    );
  }
}
