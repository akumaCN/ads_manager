import 'dart:async';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:log_utils/log_utils_lib.dart';

import '../base/base_ads_service.dart';

final class NativeAdServiceImpl extends BaseAdsService<NativeAd> {
  NativeAdServiceImpl(super._unit);
  @override
  Future<NativeAd?> loadNativeAd({AdOptions? options, AdRequest? request}) {
    if (!AdsManager.isMobileAdsInitializeCalled) {
      LogUtils.w('$adsType: Mobile Ads not initialized, ad loading canceled');
      return Future.value(null);
    }
    final completer = Completer<NativeAd?>();
    NativeAd? nativeAd;

    void safeComplete([NativeAd? ad]) {
      if (!completer.isCompleted) {
        completer.complete(ad);
      }
    }

    void disposeAd() {
      nativeAd?.dispose();
      nativeAd = null;
    }

    nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: request ?? defaultRequest,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          LogUtils.d('$adsType: Ad loaded successfully');
          safeComplete(ad as NativeAd);
        },
        onAdFailedToLoad: (ad, error) {
          LogUtils.e(
            '$adsType: Load failed | Code: ${error.code}, '
            'Message: ${error.message}',
          );
          disposeAd();
          safeComplete();
        },
        // Called when a click is recorded for a NativeAd.
        onAdClicked: (ad) {},
        // Called when an impression occurs on the ad.
        onAdImpression: (ad) {},
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (ad) {},
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (ad) {},
        // For iOS only. Called before dismissing a full screen view
        onAdWillDismissScreen: (ad) {},
        // Called when an ad receives revenue value.
        onPaidEvent: notifyAdRevenue,
      ),
      nativeTemplateStyle: options?.nativeStyle ?? NativeTemplateStyle(templateType: TemplateType.medium),
    )..load();
    return completer.future.timeout(kLoadTimeout, onTimeout: () {
      LogUtils.w('$adsType: Load timed out after $kLoadTimeout');
      disposeAd();
      safeComplete();
      return null;
    }).catchError((error, stackTrace) {
      LogUtils.e(
        '$adsType: Unexpected loading error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    });
  }

  @override
  Future<void> dispose() async {}
}
