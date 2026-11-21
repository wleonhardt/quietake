import 'package:flutter/material.dart';

/// Bounded, scrollable content for the app's finite forms and instructions.
class FormBody extends StatelessWidget {
  const FormBody({super.key, required this.children, this.centered = false});

  final List<Widget> children;
  final bool centered;

  @override
  Widget build(BuildContext context) => SafeArea(
    // The content scrolls under the home indicator instead of being cut off
    // above it; the padding below keeps the last item clear of it.
    bottom: false,
    child: Align(
      alignment: centered ? Alignment.center : Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}
