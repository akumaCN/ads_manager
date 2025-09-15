import 'package:ad_manager/ad_manager_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:log_utils/log_utils_lib.dart';

abstract class BaseAdsService<T extends Ad> implements AdmobAdsServiceAbs<T> {
  final AdUnit _unit;
  BaseAdsService(this._unit);
  @protected
  String get adUnitId => _unit.id;
  @protected
  AdsType get adsType => _unit.type;
  // 统一超时处理
  @protected
  final kLoadTimeout = const Duration(seconds: 10);

  @protected
  final request = const AdRequest(httpTimeoutMillis: 1000);

  @protected
  void notifyAdRevenue(Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
    LogUtils.d("notifyAdRevenue => ad:$ad valueMicros:$valueMicros currencyCode:$currencyCode precision:$precision");
    AdsManager.notifyAdRevenue(_unit, currencyCode, valueMicros);
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
