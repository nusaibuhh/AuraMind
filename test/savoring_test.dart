import 'dart:async';
import 'dart:convert';

import 'package:auramind/models/savoring_log.dart';
import 'package:auramind/providers/savoring_provider.dart';
import 'package:auramind/screens/savoring/savoring_history_screen.dart';
import 'package:auramind/screens/savoring/savoring_log_screen.dart';
import 'package:auramind/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _logPayload({
  String status = 'draft',
  List<Map<String, dynamic>>? entries,
}) {
  return {
    'id': 'log_123',
    'user_id': 'user_123',
    'log_date': '2026-08-28',
    'status': status,
    'completed_at': status == 'completed' ? '2026-08-28T20:00:00Z' : null,
    'created_at': '2026-08-28T18:00:00Z',
    'updated_at': '2026-08-28T20:00:00Z',
    'entries': entries ??
        List.generate(
          3,
          (index) => {
            'position': index + 1,
            'positive_event': '',
            'why_happened': '',
          },
        ),
  };
}

List<Map<String, dynamic>> _completedEntries() => List.generate(
      3,
      (index) => {
        'position': index + 1,
        'positive_event': 'Good moment ${index + 1}',
        'why_happened': 'Helpful reason ${index + 1}',
      },
    );

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );

Widget _testApp(ApiService api, Widget home) {
  return ChangeNotifierProvider(
    create: (_) => SavoringProvider(api),
    child: MaterialApp(home: home),
  );
}

void main() {
  group('Savoring models and provider', () {
    test('parses three ordered entries and completion state', () {
      final reversed = _completedEntries().reversed.toList();
      final log = SavoringLog.fromJson(
        _logPayload(status: 'completed', entries: reversed),
      );

      expect(log.isCompleted, isTrue);
      expect(log.canComplete, isTrue);
      expect(log.entries.map((entry) => entry.position), [1, 2, 3]);
      expect(log.entries.first.positiveEvent, 'Good moment 1');
    });

    test('partial draft is serialized and saved without completing', () async {
      late http.Request savedRequest;
      final api = ApiService(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            savedRequest = request;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(_logPayload(
              entries: (body['entries'] as List)
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList(),
            ));
          }
          return _jsonResponse(_logPayload());
        }),
      );
      final provider = SavoringProvider(api);

      await provider.loadToday();
      provider.updateEntry(
        1,
        positiveEvent: 'A peaceful breakfast',
        whyHappened: 'I gave myself enough time',
      );
      final saved = await provider.saveDraft();
      final sent = jsonDecode(savedRequest.body) as Map<String, dynamic>;

      expect(saved, isTrue);
      expect(savedRequest.method, 'PUT');
      expect(sent['entries'], hasLength(3));
      expect(provider.todayLog?.status, SavoringLogStatus.draft);
      expect(
        provider.todayLog?.entries.first.positiveEvent,
        'A peaceful breakfast',
      );
    });

    test('completion is blocked locally until every pair is filled', () async {
      var requestCount = 0;
      final api = ApiService(
        client: MockClient((_) async {
          requestCount++;
          return _jsonResponse(_logPayload());
        }),
      );
      final provider = SavoringProvider(api);
      await provider.loadToday();

      final completed = await provider.complete();

      expect(completed, isFalse);
      expect(requestCount, 1);
      expect(provider.error, contains('all three cards'));
    });

    test('discards an in-flight response after account state resets', () async {
      final response = Completer<http.Response>();
      final provider = SavoringProvider(
        ApiService(client: MockClient((_) => response.future)),
      );

      final load = provider.loadToday();
      provider.reset();
      response.complete(_jsonResponse(_logPayload()));
      await load;

      expect(provider.todayLog, isNull);
      expect(provider.isTodayLoading, isFalse);
    });
  });

  group('Savoring UI', () {
    testWidgets('shows three swipe cards and moves to the next prompt',
        (tester) async {
      final api = ApiService(
        client: MockClient((_) async => _jsonResponse(_logPayload())),
      );
      await tester.pumpWidget(_testApp(api, const SavoringLogScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Three Good Things'), findsOneWidget);
      expect(find.text('Small moments count'), findsOneWidget);
      expect(find.text('Good thing 1'), findsOneWidget);
      expect(find.byKey(const Key('savoring-event-1')), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await tester.pumpAndSettle();

      expect(find.text('Good thing 2'), findsOneWidget);
      expect(find.byKey(const Key('savoring-why-2')), findsOneWidget);
    });

    testWidgets('completed log is read-only and links to history',
        (tester) async {
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/history')) {
            return _jsonResponse([]);
          }
          return _jsonResponse(
            _logPayload(status: 'completed', entries: _completedEntries()),
          );
        }),
      );
      await tester.pumpWidget(_testApp(api, const SavoringLogScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Today’s reflection is complete'), findsOneWidget);
      expect(find.text('View past reflections'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('savoring-event-1')),
      );
      expect(field.readOnly, isTrue);
    });

    testWidgets('history displays completed entries', (tester) async {
      final api = ApiService(
        client: MockClient((_) async => _jsonResponse([
              _logPayload(status: 'completed', entries: _completedEntries()),
            ])),
      );
      await tester.pumpWidget(_testApp(api, const SavoringHistoryScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Past reflections'), findsOneWidget);
      expect(find.text('Good moment 1'), findsOneWidget);
      expect(find.text('What helped: Helpful reason 1'), findsOneWidget);
    });
  });
}
