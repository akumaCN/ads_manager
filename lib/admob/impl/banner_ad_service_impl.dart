import 'dart:async';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:log_utils/log_utils_lib.dart';

import '../base/base_ads_service.dart';

final class BannerAdServiceImpl extends BaseAdsService<BannerAd> {
  BannerAdServiceImpl(super._unit);

  @override
  Future<BannerAd?> loadBannerAd({required BuildContext? context, AdOptions? options}) async {
    if (!AdsManager.isMobileAdsInitializeCalled) {
      LogUtils.w('$adsType: Mobile Ads not initialized, ad loading canceled');
      return null;
    }
    if (context == null) {
      LogUtils.w('$adsType: Context is null, ad loading canceled');
      return null;
    }
    final AdSize? adSize = options?.bannerCustomSize ?? await _getAdaptiveAdSize(context);
    if (adSize == null) {
      LogUtils.w('$adsType: Failed to determine adaptive ad size');
      return null;
    }

    final completer = Completer<BannerAd?>();
    BannerAd? bannerAd;

    void safeComplete([BannerAd? ad]) {
      if (!completer.isCompleted) {
        completer.complete(ad);
      }
    }

    void disposeAd() {
      bannerAd?.dispose();
      bannerAd = null;
    }

    bannerAd = BannerAd(
      size: adSize,
      adUnitId: adUnitId,
      request: request,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          LogUtils.d('$adsType: Ad loaded | Size: ${adSize.width}x${adSize.height}');
          safeComplete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          LogUtils.e('$adsType: Failed to load ad', error: error);
          disposeAd();
          safeComplete();
        },
        onPaidEvent: notifyAdRevenue,
      ),
    )..load();
    completer.future.whenComplete(() {
      if (!completer.isCompleted) {
        bannerAd?.dispose();
      }
    });
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

  ///获取广告
  Future<AdSize?> _getAdaptiveAdSize(BuildContext context) async {
    try {
      final width = MediaQuery.sizeOf(context).width.truncate();
      return await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    } catch (error, stackTrace) {
      LogUtils.e(
        '$adsType: Error getting adaptive ad size',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
