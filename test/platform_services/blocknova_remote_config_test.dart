import 'package:blocknova_app/platform_services/ads/ads_config.dart';
import 'package:blocknova_app/platform_services/remote_config/blocknova_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adsConfig without Firebase init returns defaults', () {
    expect(BlocknovaRemoteConfig.adsConfig, AdsConfig.defaults());
    expect(BlocknovaRemoteConfig.experimentAdPacingVariant, 'baseline');
  });
}
