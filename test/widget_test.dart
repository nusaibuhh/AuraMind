import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:auramind/app.dart';
import 'package:auramind/models/behavioral_activation.dart';
import 'package:auramind/models/sleep_log.dart';
import 'package:auramind/providers/auth_provider.dart';
import 'package:auramind/providers/behavioral_activation_provider.dart';
import 'package:auramind/providers/theme_provider.dart';
import 'package:auramind/screens/behavioral_activation/behavioral_activation_screen.dart';
import 'package:auramind/screens/behavioral_activation/behavioral_activation_history_screen.dart';
import 'package:auramind/services/api_service.dart';

Map<String, dynamic> _taskPayload({String status = 'pending'}) => {
      'id': 'task_123',
      'user_id': 'user_123',
      'activity_id': 'act_walk_5min',
      'task_date': '2026-08-28',
      'status': status,
      'completed_at': status == 'completed' ? '2026-08-28T10:00:00Z' : null,
      'mood_before': null,
      'mood_after': null,
      'created_at': '2026-08-28T08:00:00Z',
      'activity': {
        'id': 'act_walk_5min',
        'title': 'Walk for 5 minutes',
        'description': 'Take a gentle five-minute stroll.',
        'category': 'Physical',
        'difficulty': 'tiny',
        'duration_minutes': 5,
      },
    };

Map<String, dynamic> _statsPayload() => {
      'period_days': 7,
      'completed_count': 0,
      'skipped_count': 0,
      'pending_count': 1,
      'total_tasks': 1,
      'completion_rate': 0,
      'number_of_active_days': 0,
      'days_in_period': 7,
    };

Widget _behavioralTestApp(ApiService apiService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppThemeProvider()),
      ChangeNotifierProvider(
        create: (_) => BehavioralActivationProvider(apiService),
      ),
    ],
    child: const MaterialApp(home: BehavioralActivationScreen()),
  );
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(jsonEncode(body), statusCode, headers: const {
      'content-type': 'application/json',
    });

void main() {
  testWidgets('AuraMindApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(AuraMindApp());
    expect(find.byType(AuraMindApp), findsOneWidget);
  });

  group('Behavioral Activation Models', () {
    test('BehavioralActivity deserialization', () {
      final json = {
        'id': 'act_water_plant',
        'title': 'Water a plant',
        'description': 'Give a plant some water.',
        'category': 'Self-care',
        'difficulty': 'tiny',
        'duration_minutes': 2,
      };

      final activity = BehavioralActivity.fromJson(json);
      expect(activity.id, 'act_water_plant');
      expect(activity.title, 'Water a plant');
      expect(activity.difficulty, BehavioralDifficulty.tiny);
      expect(activity.durationMinutes, 2);
    });

    test('BehavioralDailyTask states and deserialization', () {
      final json = {
        'id': 'task_123',
        'user_id': 'u1',
        'activity_id': 'act_walk_5min',
        'task_date': '2026-08-28',
        'status': 'completed',
        'completed_at': '2026-08-28T10:00:00.000Z',
        'mood_before': 2,
        'mood_after': 4,
        'created_at': '2026-08-28T08:00:00.000Z',
        'activity': {
          'id': 'act_walk_5min',
          'title': 'Walk for 5 minutes',
          'description': 'Take a gentle 5 minute stroll.',
          'category': 'Physical',
          'difficulty': 'tiny',
          'duration_minutes': 5,
        },
      };

      final task = BehavioralDailyTask.fromJson(json);
      expect(task.id, 'task_123');
      expect(task.isCompleted, true);
      expect(task.isSkipped, false);
      expect(task.isPending, false);
      expect(task.moodAfter, 4);
      expect(task.activity.title, 'Walk for 5 minutes');
    });

    test('BehavioralStats deserialization', () {
      final json = {
        'period_days': 7,
        'completed_count': 5,
        'skipped_count': 1,
        'pending_count': 1,
        'total_tasks': 7,
        'completion_rate': 83.3,
        'number_of_active_days': 5,
        'days_in_period': 7,
      };

      final stats = BehavioralStats.fromJson(json);
      expect(stats.completedCount, 5);
      expect(stats.skippedCount, 1);
      expect(stats.completionRate, 83.3);
      expect(stats.numberOfActiveDays, 5);
    });

    test('Sleep correlation keeps optional tiny-step context', () {
      final point = SleepMoodCorrelation.fromJson({
        'date': '2026-08-28',
        'sleep_hours': 7.5,
        'mood_score': 4.2,
        'behavioral_status': 'completed',
        'behavioral_activity_title': 'Walk for 5 minutes',
      });

      expect(point.hasBehavioralActivity, isTrue);
      expect(point.behavioralActivityCompleted, isTrue);
      expect(point.behavioralActivityTitle, 'Walk for 5 minutes');
    });
  });

  group('Behavioral Activation UI Rendering', () {
    testWidgets('BehavioralActivationScreen renders header and title',
        (WidgetTester tester) async {
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/today')) {
            return _jsonResponse(_taskPayload());
          }
          return _jsonResponse(_statsPayload());
        }),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppThemeProvider()),
            ChangeNotifierProvider(
                create: (_) => AuthProvider(api: apiService)),
            ChangeNotifierProvider(
                create: (_) => BehavioralActivationProvider(apiService)),
          ],
          child: const MaterialApp(
            home: BehavioralActivationScreen(),
          ),
        ),
      );

      expect(find.text('Behavioral Activation'), findsOneWidget);
      expect(find.text("Today's Tiny Step"), findsOneWidget);
      expect(
          find.text('One small action is enough for today.'), findsOneWidget);
    });

    testWidgets(
        'BehavioralActivationHistoryScreen renders empty state gracefully',
        (WidgetTester tester) async {
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/history')) {
            return _jsonResponse([]);
          }
          return _jsonResponse(_statsPayload());
        }),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppThemeProvider()),
            ChangeNotifierProvider(
                create: (_) => BehavioralActivationProvider(apiService)),
          ],
          child: const MaterialApp(
            home: BehavioralActivationHistoryScreen(),
          ),
        ),
      );

      expect(find.text('Activity History'), findsOneWidget);
    });

    testWidgets('shows a specific empty state when no activities are active',
        (WidgetTester tester) async {
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/today')) {
            return _jsonResponse(
              {'detail': 'No behavioral activities found.'},
              statusCode: 404,
            );
          }
          return _jsonResponse(_statsPayload());
        }),
      );

      await tester.pumpWidget(_behavioralTestApp(apiService));
      await tester.pump();
      await tester.pump();

      expect(find.text('No tiny steps available'), findsOneWidget);
      expect(
        find.text(
          'No tiny steps are available right now. Please check again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Unable to connect to planner'), findsNothing);
    });

    testWidgets('shows a loading state, then the assigned activity',
        (WidgetTester tester) async {
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/today')) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            return _jsonResponse(_taskPayload());
          }
          return _jsonResponse({});
        }),
      );

      await tester.pumpWidget(_behavioralTestApp(apiService));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Walk for 5 minutes'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('shows a gentle API error state', (WidgetTester tester) async {
      final apiService = ApiService(
        client: MockClient((_) async => _jsonResponse(
              {'detail': 'The planner is temporarily unavailable.'},
              statusCode: 503,
            )),
      );

      await tester.pumpWidget(_behavioralTestApp(apiService));
      await tester.pump();
      await tester.pump();

      expect(find.text('Unable to connect to planner'), findsOneWidget);
      expect(
          find.text('The planner is temporarily unavailable.'), findsOneWidget);
    });

    testWidgets('completing an activity shows confirmation and a mood prompt',
        (WidgetTester tester) async {
      var currentTask = _taskPayload();
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/today')) {
            return _jsonResponse(currentTask);
          }
          if (request.url.path.endsWith('/complete')) {
            currentTask = _taskPayload(status: 'completed');
            return _jsonResponse(currentTask);
          }
          return _jsonResponse({});
        }),
      );

      await tester.pumpWidget(_behavioralTestApp(apiService));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Complete'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Completed for today'), findsOneWidget);
      expect(
        find.text('Nice work. You showed up for yourself today.'),
        findsOneWidget,
      );
    });

    testWidgets('skipping an activity remains supportive',
        (WidgetTester tester) async {
      var currentTask = _taskPayload();
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/today')) {
            return _jsonResponse(currentTask);
          }
          if (request.url.path.endsWith('/skip')) {
            currentTask = _taskPayload(status: 'skipped');
            return _jsonResponse(currentTask);
          }
          return _jsonResponse({});
        }),
      );

      await tester.pumpWidget(_behavioralTestApp(apiService));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Skip for today'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Resting today — that is completely okay.'),
          findsOneWidget);
    });

    testWidgets('history renders the requested empty state',
        (WidgetTester tester) async {
      final apiService = ApiService(
        client: MockClient((_) async => _jsonResponse([])),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => BehavioralActivationProvider(apiService),
            ),
          ],
          child: const MaterialApp(home: BehavioralActivationHistoryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No activity history yet'), findsOneWidget);
      expect(
          find.text('Your first tiny step will appear here.'), findsOneWidget);
    });

    testWidgets('history renders activity details and weekly progress',
        (WidgetTester tester) async {
      final completed = _taskPayload(status: 'completed');
      final stats = _statsPayload()
        ..['completed_count'] = 1
        ..['pending_count'] = 0
        ..['completion_rate'] = 100
        ..['number_of_active_days'] = 1;
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/history')) {
            return _jsonResponse([completed]);
          }
          return _jsonResponse(stats);
        }),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => BehavioralActivationProvider(apiService),
            ),
          ],
          child: const MaterialApp(home: BehavioralActivationHistoryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Walk for 5 minutes'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('This week: 1 of 7 days completed'), findsOneWidget);
    });

    test('completed state persists when the provider refreshes', () async {
      final apiService = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/complete')) {
            return _jsonResponse(_taskPayload(status: 'completed'));
          }
          return _jsonResponse(_taskPayload(status: 'completed'));
        }),
      );
      final provider = BehavioralActivationProvider(apiService);

      await provider.loadToday();
      expect(provider.todayTask?.isCompleted, isTrue);
      await provider.refresh();
      expect(provider.todayTask?.isCompleted, isTrue);
    });

    test('provider discards an in-flight response after user state resets',
        () async {
      final response = Completer<http.Response>();
      final apiService = ApiService(
        client: MockClient((_) => response.future),
      );
      final provider = BehavioralActivationProvider(apiService);

      final load = provider.loadToday();
      provider.reset();
      response.complete(_jsonResponse(_taskPayload()));
      await load;

      expect(provider.todayTask, isNull);
      expect(provider.isTodayLoading, isFalse);
    });

    test('API sends the device timezone offset on planner requests', () async {
      late http.Request captured;
      final apiService = ApiService(
        client: MockClient((request) async {
          captured = request;
          return _jsonResponse(_taskPayload());
        }),
      );

      await apiService.getTodayBehavioralTask();
      final timezoneHeader = captured.headers.entries.firstWhere(
        (entry) => entry.key.toLowerCase() == 'x-timezone-offset-minutes',
      );
      expect(
        timezoneHeader.value,
        DateTime.now().timeZoneOffset.inMinutes.toString(),
      );
    });
  });
}
