import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:home_widget/home_widget.dart';

InAppLocalhostServer localhostServer = InAppLocalhostServer(
  documentRoot: 'assets/www',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  // Start the local web server to serve the React assets
  await localhostServer.start();

  runApp(const AdnoraApp());
}

class AdnoraApp extends StatelessWidget {
  const AdnoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adnora',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1e293b)),
        useMaterial3: true,
      ),
      home: const AdnoraWebView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdnoraWebView extends StatefulWidget {
  const AdnoraWebView({super.key});

  @override
  State<AdnoraWebView> createState() => _AdnoraWebViewState();
}

class _AdnoraWebViewState extends State<AdnoraWebView> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true,
      geolocationEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
  );

  String? pendingWidgetAction;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    HomeWidget.widgetClicked.listen(_handleWidgetDeepLink);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetDeepLink);
  }

  void _handleWidgetDeepLink(Uri? uri) {
    if (uri != null && uri.scheme == 'adnora') {
       if (webViewController != null) {
           _executeWidgetAction(uri.host);
       } else {
           pendingWidgetAction = uri.host;
       }
    }
  }

  void _executeWidgetAction(String action) {
    if (['start_office', 'start_wfh', 'start_field_work', 'break_toggle', 'end'].contains(action)) {
      webViewController?.evaluateJavascript(source: "if (window.triggerWidgetPunch) window.triggerWidgetPunch('$action');");
    }
  }

  Future<void> requestPermissions() async {
    await Permission.locationWhenInUse.request();
  }

  @override
  void dispose() {
    localhostServer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e293b), 
      body: SafeArea(
        child: InAppWebView(
          key: webViewKey,
          // Load the local React app bundle served by InAppLocalhostServer
          initialUrlRequest: URLRequest(url: WebUri("http://localhost:8080/index.html")),
          initialSettings: settings,
          onWebViewCreated: (controller) {
            webViewController = controller;
            
            controller.addJavaScriptHandler(
              handlerName: 'updateWidgetState',
              callback: (args) async {
                if (args.isNotEmpty) {
                  final data = args[0] as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'offline';
                  final workedSeconds = data['workedSeconds'] as int? ?? 0;
                  final targetMessage = data['targetMessage'] as String? ?? '';
                  final firstIn = data['firstIn'] as String? ?? '-';
                  final lastOut = data['lastOut'] as String? ?? '-';
                  
                  await HomeWidget.saveWidgetData<String>('status', status);
                  await HomeWidget.saveWidgetData<int>('workedSeconds', workedSeconds);
                  await HomeWidget.saveWidgetData<String>('targetMessage', targetMessage);
                  await HomeWidget.saveWidgetData<String>('firstIn', firstIn);
                  await HomeWidget.saveWidgetData<String>('lastOut', lastOut);
                  
                  await HomeWidget.updateWidget(name: 'AdnoraWidgetProvider');
                }
              }
            );

            if (pendingWidgetAction != null) {
              Future.delayed(const Duration(milliseconds: 1500), () {
                _executeWidgetAction(pendingWidgetAction!);
                pendingWidgetAction = null;
              });
            }
          },
          onGeolocationPermissionsShowPrompt:
              (controller, origin) async {
            var status = await Permission.locationWhenInUse.status;
            if (status.isDenied) {
              status = await Permission.locationWhenInUse.request();
            }
            
            if (status.isGranted) {
              return GeolocationPermissionShowPromptResponse(
                  origin: origin, allow: true, retain: true);
            } else {
              return GeolocationPermissionShowPromptResponse(
                  origin: origin, allow: false, retain: true);
            }
          },
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT);
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint("WEBVIEW CONSOLE: ${consoleMessage.message}");
          },
          onReceivedError: (controller, request, error) {
            debugPrint("WEBVIEW LOAD ERROR: ${error.description} (code ${error.type}) for ${request.url}");
          },
          onReceivedHttpError: (controller, request, errorResponse) {
            debugPrint("WEBVIEW HTTP ERROR: ${errorResponse.statusCode} for ${request.url}");
          },
        ),
      ),
    );
  }
}
