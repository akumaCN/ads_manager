import 'dart:async';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:log_utils/log_utils_lib.dart';

import '../base/full_screen_ads_service.dart';

final class InterstitialAdServiceImpl extends FullScreenAdsService<InterstitialAd> {
  InterstitialAdServiceImpl(super._unit);

  @override
  Future<InterstitialAd?> performLoadAd() {
    if (!AdsManager.isMobileAdsInitializeCalled) {
      LogUtils.w('$adsType: Mobile Ads not initialized, ad loading canceled');
      return Future.value(null);
    }
    final completer = Completer<InterstitialAd?>();
    InterstitialAd? loadedAd;
    bool isTimedOut = false;
    void completeCompleter([InterstitialAd? ad]) {
      if (!completer.isCompleted) {
        completer.complete(ad);
      }
    }

    void disposeAd() {
      loadedAd?.dispose();
      loadedAd = null;
    }

    InterstitialAd.load(
        adUnitId: adUnitId,
        request: request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            loadedAd = ad;
            if (isTimedOut) {
              disposeAd();
              return;
            }
            LogUtils.d('$adsType: Ad loaded successfully');
            completeCompleter(ad);
          },
          onAdFailedToLoad: (error) {
            LogUtils.e('$adsType: Failed to load ad', error: error);
            completeCompleter();
          },
        ));
    return completer.future.timeout(kLoadTimeout, onTimeout: () {
      isTimedOut = true;
      LogUtils.d('$adsType: Ad load timed out');
      disposeAd();
      completeCompleter();
      return null;
    }).catchError((e) => null);
  }

  @override
  Future<void> performShow(InterstitialAd ad, {AdOptions? options, AdCallBack? adCallBack}) async {
    ad.onPaidEvent = notifyAdRevenue;
    ad.fullScreenContentCallback = getCallback(
      adCallBack,
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        adCallBack?.onAdDismissed?.call(adsType, isEarnedReward: true);
      },
    );
    ad.show();
  }
}
