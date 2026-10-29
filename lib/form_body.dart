import 'package:flutter/material.dart';

/// Bounded, scrollable content for the app's finite forms and instructions.
class FormBody extends StatelessWidget {
  const FormBody({super.key, required this.children, this.centered = false});

  final List<Widget> children;
  final bool centered;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: centered ? Alignment.center : Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
