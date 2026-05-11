import 'package:blocknova_app/platform_services/analytics/analytics_param_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeAnalyticsParameters coerces types and truncates', () {
    final longKey = 'k' * 50;
    final out = sanitizeAnalyticsParameters(<String, Object?>{
      'a': 'x' * 120,
      'bool_param': true,
      'n': 42,
      'd': 3.5,
      'null_drop': null,
      'object': Object(),
      longKey: 1,
    });
    expect(out['a'], hasLength(100));
    expect(out['bool_param'], 1);
    expect(out['n'], 42);
    expect(out['d'], 3.5);
    expect(out.containsKey('null_drop'), isFalse);
    expect(out.containsKey('kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk'), isTrue);
    expect(out['kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk'], 1);
  });

  test('firebaseTransportEventName maps reserved session_start', () {
    expect(firebaseTransportEventName('session_start'), 'bn_session_start');
    expect(firebaseTransportEventName('run_start'), 'run_start');
  });
}
