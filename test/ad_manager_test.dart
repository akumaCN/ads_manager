import 'package:ad_manager/ad_manager_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async {
    await AdsManager.removeAll();
  });

  test('removeAdmobService creates a new instance for the same ad unit', () async {
    const adUnit = AdUnit(AdsType.banner, 'banner-id');

    final firstService = AdsManager.getAdmobService(adUnit);
    await AdsManager.removeAdmobService(adUnit);
    final secondService = AdsManager.getAdmobService(adUnit);

    expect(identical(firstService, secondService), isFalse);
  });

  test('removeAllByType only clears matching ad services', () async {
    const bannerUnit = AdUnit(AdsType.banner, 'banner-id');
    const nativeUnit = AdUnit(AdsType.native, 'native-id');

    final firstBannerService = AdsManager.getAdmobService(bannerUnit);
    final firstNativeService = AdsManager.getAdmobService(nativeUnit);

    await AdsManager.removeAllByType(AdsType.banner);

    final secondBannerService = AdsManager.getAdmobService(bannerUnit);
    final secondNativeService = AdsManager.getAdmobService(nativeUnit);

    expect(identical(firstBannerService, secondBannerService), isFalse);
    expect(identical(firstNativeService, secondNativeService), isTrue);
  });

  test('removeAll clears all cached services', () async {
    const bannerUnit = AdUnit(AdsType.banner, 'banner-id');
    const nativeUnit = AdUnit(AdsType.native, 'native-id');

    final firstBannerService = AdsManager.getAdmobService(bannerUnit);
    final firstNativeService = AdsManager.getAdmobService(nativeUnit);

    await AdsManager.removeAll();

    final secondBannerService = AdsManager.getAdmobService(bannerUnit);
    final secondNativeService = AdsManager.getAdmobService(nativeUnit);

    expect(identical(firstBannerService, secondBannerService), isFalse);
    expect(identical(firstNativeService, secondNativeService), isFalse);
  });

  test('banner service throws when requesting unsupported fullscreen show', () async {
    const bannerUnit = AdUnit(AdsType.banner, 'banner-id');
    final bannerService = AdsManager.getAdmobService(bannerUnit);

    expect(
      () => bannerService.showFullScreenAds(),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('native service throws when requesting unsupported app open toggle', () {
    const nativeUnit = AdUnit(AdsType.native, 'native-id');
    final nativeService = AdsManager.getAdmobService(nativeUnit);

    expect(
      () => nativeService.appOpenAdEnabled(true),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('interstitial service throws when requesting unsupported native ad load', () async {
    const interstitialUnit = AdUnit(AdsType.interstitial, 'interstitial-id');
    final interstitialService = AdsManager.getAdmobService(interstitialUnit);

    expect(
      () => interstitialService.loadNativeAd(),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
