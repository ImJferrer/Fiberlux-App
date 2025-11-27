import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/remote_config_service.dart';

class EncuestaScreen extends StatefulWidget {
  const EncuestaScreen({Key? key}) : super(key: key);

  @override
  State<EncuestaScreen> createState() => _EncuestaScreenState();
}

class _EncuestaScreenState extends State<EncuestaScreen> {
  late final WebViewController _controller;
  bool _loaded = false;

  String _buildHtml(String agentId) =>
      '''
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Encuesta</title>
    <script src="https://unpkg.com/@elevenlabs/convai-widget-embed" async type="text/javascript"></script>
    <style>
      html, body { margin:0; padding:0; height:100%; }
      .host { height:100%; display:flex; align-items:center; justify-content:center; }
    </style>
  </head>
  <body>
    <div class="host">
      <!-- El widget aparece flotante, este tag lo inicializa -->
      <elevenlabs-convai agent-id="$agentId"></elevenlabs-convai>
    </div>
  </body>
</html>
''';

  @override
  void initState() {
    super.initState();
    // Web: el widget se recomienda inyectarlo en index.html; aquí damos feedback
    if (!kIsWeb) {
      final agent = RemoteConfigService.i.convaiAgentId;
      final html = _buildHtml(agent);

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => setState(() => _loaded = true),
          ),
        )
        ..loadHtmlString(html);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = RemoteConfigService.i.aiMenuTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF8B4A9C),
        foregroundColor: Colors.white,
      ),
      body: Builder(
        builder: (_) {
          // Si deshabilitan desde RC, muestra aviso
          if (!RemoteConfigService.i.convaiEnabled) {
            return _DisabledInfo();
          }

          if (kIsWeb) {
            return const _WebInfo();
          }

          return Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (!_loaded) const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }
}

class _DisabledInfo extends StatelessWidget {
  const _DisabledInfo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.psychology_alt_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'La encuesta por IA está deshabilitada por configuración.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WebInfo extends StatelessWidget {
  const _WebInfo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        'Web: para mostrar el widget en TODA la app, pega el snippet dentro de web/index.html '
        'y usa el agent-id de Remote Config.',
      ),
    );
  }
}
