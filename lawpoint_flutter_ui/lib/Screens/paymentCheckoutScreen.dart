import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.actionUrl,
    required this.fields,
  });

  final String actionUrl;
  final Map<String, dynamic> fields;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  String _buildHtml() {
    final inputs = widget.fields.entries.map((e) {
      final key = e.key;
      final value = '${e.value}'.replaceAll('"', '&quot;');
      return '<input type="hidden" name="$key" value="$value" />';
    }).join();

    return '''
<!DOCTYPE html>
<html>
  <body onload="document.forms[0].submit();">
    <p style="font-family:sans-serif;padding:16px;">Redirecting to payment gateway...</p>
    <form method="POST" action="${widget.actionUrl}">
      $inputs
    </form>
  </body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.contains('/payhere/return')) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            if (url.contains('/payhere/cancel')) {
              Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete payment')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
