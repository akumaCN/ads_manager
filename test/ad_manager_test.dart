import 'package:ad_manager/ad_manager_lib.dart';
import 'package:ad_manager/admob/impl/app_open_ad_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('app open ad blockers remain effective when nested pages restore out of order', () {
    const appOpenUnit = AdUnit(AdsType.appOpenAd, 'app-open-id');
    final service = AdsManager.getAdmobService(appOpenUnit) as AppOpenAdServiceImpl;
    final pageABlocker = Object();
    final pageBBlocker = Object();

    expect(service.debugShouldShowOpenAppAd, isTrue);

    service.shouldShowOpenAppAd(false, blocker: pageABlocker);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugScopedBlockCount, 1);

    service.shouldShowOpenAppAd(false, blocker: pageBBlocker);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugScopedBlockCount, 2);

    service.shouldShowOpenAppAd(true, blocker: pageBBlocker);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugScopedBlockCount, 1);

    service.shouldShowOpenAppAd(true, blocker: pageABlocker);
    expect(service.debugShouldShowOpenAppAd, isTrue);
    expect(service.debugScopedBlockCount, 0);
  });

  test('legacy app open ad toggle remains backward compatible', () {
    const appOpenUnit = AdUnit(AdsType.appOpenAd, 'app-open-id');
    final service = AdsManager.getAdmobService(appOpenUnit) as AppOpenAdServiceImpl;

    service.shouldShowOpenAppAd(false);
    service.shouldShowOpenAppAd(false);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugLegacyBlockCount, 2);

    service.shouldShowOpenAppAd(true);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugLegacyBlockCount, 1);

    service.shouldShowOpenAppAd(true);
    expect(service.debugShouldShowOpenAppAd, isTrue);
    expect(service.debugLegacyBlockCount, 0);

    service.shouldShowOpenAppAd(true);
    expect(service.debugShouldShowOpenAppAd, isTrue);
    expect(service.debugLegacyBlockCount, 0);
  });

  test('app open ad visibility restores correctly for A hide -> B show -> C hide', () {
    const appOpenUnit = AdUnit(AdsType.appOpenAd, 'app-open-id');
    final service = AdsManager.getAdmobService(appOpenUnit) as AppOpenAdServiceImpl;
    final pageAOwner = Object();
    final pageBOwner = Object();
    final pageCOwner = Object();

    expect(service.debugShouldShowOpenAppAd, isTrue);

    service.setOpenAppAdVisibility(false, owner: pageAOwner);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugVisibilityOwnerCount, 1);

    service.setOpenAppAdVisibility(true, owner: pageBOwner);
    expect(service.debugShouldShowOpenAppAd, isTrue);
    expect(service.debugVisibilityOwnerCount, 2);

    service.setOpenAppAdVisibility(false, owner: pageCOwner);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugVisibilityOwnerCount, 3);

    service.clearOpenAppAdVisibility(pageCOwner);
    expect(service.debugShouldShowOpenAppAd, isTrue);
    expect(service.debugVisibilityOwnerCount, 2);

    service.clearOpenAppAdVisibility(pageBOwner);
    expect(service.debugShouldShowOpenAppAd, isFalse);
    expect(service.debugVisibilityOwnerCount, 1);

    service.clearOpenAppAdVisibility(pageAOwner);
    expect(service.debugShouldShowOpenAppAd, isTrue);
    expect(service.debugVisibilityOwnerCount, 0);
  });
}
