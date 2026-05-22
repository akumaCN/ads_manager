import 'dart:async';

import 'package:ads_manager/ad_manager_lib.dart';
import 'package:log_utils_plus/log_utils_lib.dart';

import '../base/full_screen_ads_service.dart';

final class RewardedInterstitialAdServiceImpl extends FullScreenAdsService<RewardedInterstitialAd> {
  RewardedInterstitialAdServiceImpl(super.adUnitId);

  @override
  Future<RewardedInterstitialAd?> performLoadAd({AdRequest? request}) async {
    if (!AdsManager.isMobileAdsInitializeCalled) {
      LogUtils.w('$adsType: Mobile Ads not initialized, ad loading canceled');
      return Future.value(null);
    }
    final completer = Completer<RewardedInterstitialAd?>();
    RewardedInterstitialAd? loadedAd;
    bool isTimedOut = false;
    void completeCompleter([RewardedInterstitialAd? ad]) {
      if (!completer.isCompleted) {
        completer.complete(ad);
      }
    }

    void disposeAd() {
      loadedAd?.dispose();
      loadedAd = null;
    }

    RewardedInterstitialAd.load(
        adUnitId: adUnitId,
        request: request ?? defaultRequest,
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
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
  Future<void> performShow(RewardedInterstitialAd ad, {AdOptions? options, AdCallBack? adCallBack}) async {
    if (options != null) {
      await ad.setServerSideOptions(options.serverSideVerificationOptions);
    }
    bool isEarnedReward = false;
    ad.onPaidEvent = notifyAdRevenue;
    ad.fullScreenContentCallback = getCallback(
      adCallBack,
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        adCallBack?.onAdDismissed?.call(adsType, isEarnedReward: isEarnedReward);
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) {
      adCallBack?.onRewardEarned?.call(adsType);
      isEarnedReward = true;
      LogUtils.i('$adsType: User earned reward: ${reward.amount} ${reward.type}');
    });
  }
}
