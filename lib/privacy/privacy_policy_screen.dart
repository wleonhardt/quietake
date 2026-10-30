import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keys.dart';

void showPrivacyPolicy(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()));

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final _policy = rootBundle
      .loadString('assets/privacy-policy.json')
      .then((text) => jsonDecode(text) as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Keys.privacyPolicyPage,
    appBar: AppBar(title: const Text('Privacy policy')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _policy,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load the privacy policy.'),
          );
        }
        final policy = snapshot.data;
        if (policy == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          key: Keys.privacyPolicyScroll,
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policy['title'] as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${policy['publisher']}\n${policy['contact']}\n'
                      'Updated ${policy['updated']}',
                    ),
                    for (final section in policy['sections'] as List) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          section['heading'] as String,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final paragraph
                          in section['paragraphs'] as List) ...[
                        const SizedBox(height: 12),
                        Text(
                          paragraph as String,
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
