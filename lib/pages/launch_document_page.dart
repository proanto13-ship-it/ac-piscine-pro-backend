import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LaunchDocumentPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const LaunchDocumentPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LaunchDocumentPage> createState() => _LaunchDocumentPageState();
}

class _LaunchDocumentPageState extends State<LaunchDocumentPage> {
  late final Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Impossible de charger ce document pour le moment.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.data ?? '',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF1D2939),
              ),
            ),
          );
        },
      ),
    );
  }
}
