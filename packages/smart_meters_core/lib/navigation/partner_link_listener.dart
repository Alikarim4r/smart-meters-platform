import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'partner_link_parser.dart';
import 'partner_link_intent.dart';
import 'partner_web_links.dart';

/// Listens for incoming `smartmeters-*://` links and dispatches parsed intents.
class PartnerLinkListener extends StatefulWidget {
  const PartnerLinkListener({
    super.key,
    required this.child,
    required this.onLink,
    this.expectedScheme,
  });

  final Widget child;
  final ValueChanged<PartnerLinkIntent> onLink;

  /// When set, ignores links that do not use this scheme.
  final String? expectedScheme;

  @override
  State<PartnerLinkListener> createState() => _PartnerLinkListenerState();
}

class _PartnerLinkListenerState extends State<PartnerLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _handleWebQueryLink();
    _handleInitialLink();
    _subscription = _appLinks.uriLinkStream.listen(_dispatch);
  }

  void _handleWebQueryLink() {
    if (!kIsWeb || widget.expectedScheme == null) return;
    final intent = parsePartnerWebQuery(
      Uri.base.queryParameters,
      expectedScheme: widget.expectedScheme!,
    );
    if (intent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onLink(intent);
      });
    }
  }

  Future<void> _handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _dispatch(uri);
  }

  void _dispatch(Uri uri) {
    if (widget.expectedScheme != null && uri.scheme != widget.expectedScheme) {
      final flexible = parsePartnerLinkFlexible(uri);
      if (flexible == null) return;
      widget.onLink(flexible);
      return;
    }
    final intent = parsePartnerLink(uri) ?? parsePartnerLinkFlexible(uri);
    if (intent == null) return;
    widget.onLink(intent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
