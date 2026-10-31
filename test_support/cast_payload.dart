import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/google_cast_backend.dart';

/// Check the actual app-to-plugin request without contacting a receiver.
Future<void> checkCastLoadPayload(String contentType, int metadataType) async {
  final channel = MethodChannel(
    Platform.isAndroid
        ? 'com.felnanuke.google_cast.remote_media_client'
        : 'google_cast.remote_media_client',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final request = Completer<MethodCall>();
  messenger.setMockMethodCallHandler(channel, (call) async {
    request.complete(call);
    return null;
  });
  try {
    final url = Uri.parse('http://127.0.0.1:12345/synthetic-token');
    await GoogleCastBackend().load(
      url,
      contentType,
      title: 'Synthetic capture',
    );
    final call = await request.future.timeout(const Duration(seconds: 5));
    expect(call.method, 'loadMedia');
    final arguments = Map<Object?, Object?>.from(call.arguments as Map);
    final media = Platform.isAndroid
        ? Map<Object?, Object?>.from(arguments['mediaInfo'] as Map)
        : arguments;
    final metadata = Map<Object?, Object?>.from(media['metadata'] as Map)
      ..removeWhere((key, value) => value == null);
    expect(metadata, {
      'metadataType': metadataType,
      'title': 'Synthetic capture',
    }, reason: 'Only the chosen title may accompany photo/movie metadata');
    expect(media['contentURL'], url.toString());
    expect(media['contentID'], 'synthetic-token');
    expect(media['contentType'], contentType);
    expect(media['customData'], isNull);
    expect(arguments['credentials'], isNull);
    expect(arguments['credentialsType'], isNull);
    expect(arguments['customData'], isNull);
  } finally {
    messenger.setMockMethodCallHandler(channel, null);
  }
}
