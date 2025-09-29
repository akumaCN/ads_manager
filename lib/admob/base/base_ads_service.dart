import 'dart:math';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:log_utils/log_utils_lib.dart';

abstract class BaseAdsService<T extends Ad> implements AdmobAdsServiceAbs<T> {
  final AdUnit _unit;
  BaseAdsService(this._unit);
  final _random = Random();
  @protected
  String get adUnitId {
    var extIdList = _unit.extIdList;
    if (extIdList == null || extIdList.isEmpty) {
      return _unit.id;
    }
    final allIds = [_unit.id, ...(_unit.extIdList ?? [])];
    return allIds[_random.nextInt(allIds.length)];
  }

  @protected
  AdsType get adsType => _unit.type;
  // 统一超时处理
  @protected
  final kLoadTimeout = const Duration(seconds: 10);

  @protected
  final request = const AdRequest(httpTimeoutMillis: 1000);

  @protected
  void notifyAdRevenue(Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
    LogUtils.d(
        "notifyAdRevenue => ad:${ad.runtimeType} valueMicros:$valueMicros currencyCode:$currencyCode precision:$precision");
    AdsManager.notifyAdRevenue(AdRevenueEvent(
      adsType,
      ad.adUnitId,
      precision,
      currencyCode,
      valueMicros,
      loadedAdapterResponseInfo: ad.responseInfo?.loadedAdapterResponseInfo,
    ));
  }

  @override
  Future<void> preloadAds(int targetCount) async {}

  @override
  Future<void> showFullScreenAds({AdOptions? options, AdCallBack? adCallBack}) async {}

  @override
  Future<void> showAdIfAvailable({AdOptions? options, AdCallBack? adCallBack}) async {}

  @override
  Future<BannerAd?> loadBannerAd({required BuildContext? context, AdOptions? options}) {
    return Future.value(null);
  }

  @override
  Future<NativeAd?> loadNativeAd({AdOptions? options}) {
    return Future.value(null);
  }

  @override
  void shouldShowOpenAppAd(bool shouldShow) {}

  @override
  void appOpenAdEnabled(bool enabled) {}
}
