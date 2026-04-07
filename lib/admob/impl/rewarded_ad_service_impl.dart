import 'dart:async';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:log_utils/log_utils_lib.dart';

import '../base/full_screen_ads_service.dart';

final class RewardedAdServiceImpl extends FullScreenAdsService<RewardedAd> {
  RewardedAdServiceImpl(super._unit);

  @override
  Future<RewardedAd?> performLoadAd({AdRequest? request}) async {
    if (!AdsManager.isMobileAdsInitializeCalled) {
      LogUtils.w('$adsType: Mobile Ads not initialized, ad loading canceled');
      return Future.value(null);
    }
    final completer = Completer<RewardedAd?>();
    RewardedAd? loadedAd;
    bool isTimedOut = false;
    void completeCompleter([RewardedAd? ad]) {
      if (!completer.isCompleted) {
        completer.complete(ad);
      }
    }

    void disposeAd() {
      loadedAd?.dispose();
      loadedAd = null;
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: request ?? defaultRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          loadedAd = ad;
          if (isTimedOut) {
            disposeAd();
            return;
          }
          LogUtils.d('$adsType: Ad loaded successfully');
          completeCompleter(ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          LogUtils.e('$adsType: Failed to load ad', error: error);
          completeCompleter();
        },
      ),
    );
    return completer.future.timeout(kLoadTimeout, onTimeout: () {
      isTimedOut = true;
      LogUtils.d('$adsType: Ad load timed out');
      disposeAd();
      completeCompleter();
      return null;
    }).catchError((e) => null);
  }

  @override
  Future<void> performShow(RewardedAd ad, {AdOptions? options, AdCallBack? adCallBack}) async {
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
