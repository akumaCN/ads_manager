import 'dart:async';
import 'dart:math';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:log_utils/log_utils_lib.dart';
import 'package:meta/meta.dart';

import 'base_ads_service.dart';

abstract class FullScreenAdsService<T extends Ad> extends BaseAdsService<T> {
  static const _maxRewardedAds = 6;
  static const _defaultBatchSize = 3;
  final List<T> _preloadedAds = [];

  FullScreenAdsService(super._unit);

  @override
  Future<void> preloadAds(int targetCount, {AdRequest? request}) async {
    if (T == RewardedAd || T == RewardedInterstitialAd) {
      //激励广告最多缓存6个
      if (targetCount > _maxRewardedAds) {
        targetCount = _maxRewardedAds;
      }
    }
    final initialLength = _preloadedAds.length;
    final needed = targetCount - initialLength;
    if (needed <= 0) {
      LogUtils.d('$adsType: Preload not needed (current: $initialLength, target: $targetCount)');
      return;
    }
    LogUtils.d('$adsType: Starting preload ($needed needed)');
    int loadedCount = 0;

    while (loadedCount < needed) {
      final currentBatch = min(_defaultBatchSize, needed - loadedCount);
      LogUtils.d('$adsType: Loading batch of $currentBatch ads');

      try {
        final results = await Future.wait(
          List.generate(currentBatch, (_) => performLoadAd(request: request)),
        );
        final successfulAds = results.whereType<T>().toList();
        _preloadedAds.addAll(successfulAds);
        loadedCount += currentBatch;

        LogUtils.d('$adsType: Batch completed '
            '(expected: $currentBatch, actual: ${successfulAds.length}, '
            'total: ${_preloadedAds.length})');
      } catch (e) {
        LogUtils.e('$adsType: Error during batch load', error: e);
      }
    }

    LogUtils.d('$adsType: Preload completed (total: ${_preloadedAds.length})');
  }

  @override
  Future<void> showFullScreenAds({AdOptions? options, AdRequest? request, AdCallBack? adCallBack}) async {
    adCallBack?.onAdLoading?.call(adsType);
    T? ad;
    var usedPreloadedAd = false;
    if (_preloadedAds.isNotEmpty) {
      ad = _preloadedAds.removeAt(0);
      usedPreloadedAd = true;
      LogUtils.d('$adsType: Showing preloaded ad (remaining: ${_preloadedAds.length})');
    } else {
      LogUtils.d('$adsType: No preloaded ads, loading new');
      ad = await performLoadAd(request: request);
    }
    if (ad == null) {
      adCallBack?.onAdLoadFailed?.call(adsType);
      LogUtils.e('$adsType: Failed to get ad for showing');
      return;
    }
    adCallBack?.onAdLoaded?.call(
      adsType,
      cachedCount: usedPreloadedAd ? _preloadedAds.length : null,
    );
    await performShow(ad, options: options, adCallBack: adCallBack);
  }

  @override
  Future<void> showAdIfAvailable({AdOptions? options, AdCallBack? adCallBack}) async {
    if (_preloadedAds.isEmpty) {
      LogUtils.d('$adsType: No preloaded ads');
      return;
    }
    T ad = _preloadedAds.removeAt(0);
    await performShow(ad, options: options, adCallBack: adCallBack);
  }

  @override
  Future<void> dispose() async {
    while (_preloadedAds.isNotEmpty) {
      final ad = _preloadedAds.removeLast();
      ad.dispose();
    }
  }

  FullScreenContentCallback<T> getCallback(
    AdCallBack? adCallBack, {
    GenericAdEventCallback<T>? onAdShowedFullScreenContent,
    GenericAdEventCallback<T>? onAdDismissedFullScreenContent,
    Function(Ad ad, AdError error)? onAdFailedToShowFullScreenContent,
  }) {
    return FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: onAdShowedFullScreenContent ??
          (ad) {
            //显示广告时调用
            adCallBack?.onAdShown?.call(adsType);
          },
      onAdImpression: (ad) {
        //广告记录已生成
        adCallBack?.onAdImpression?.call(adsType);
      },
      onAdFailedToShowFullScreenContent: onAdFailedToShowFullScreenContent ??
          (ad, err) {
            //显示失败时调用
            LogUtils.e("$adsType: onAdFailedToShowFullScreenContent.", error: err);
            //释放广告
            ad.dispose();
            adCallBack?.onAdShowFailed?.call(adsType);
          },
      onAdDismissedFullScreenContent: onAdDismissedFullScreenContent ??
          (ad) {
            //广告被关闭
            ad.dispose();
            adCallBack?.onAdDismissed?.call(adsType);
          },
      onAdClicked: (ad) {
        // 点击广告时调用
        adCallBack?.onAdClicked?.call(adsType);
      },
    );
  }

  //加载广告执行
  @protected
  Future<T?> performLoadAd({AdRequest? request});

  //执行显示广告
  @protected
  Future<void> performShow(T ad, {AdOptions? options, AdCallBack? adCallBack});
}
