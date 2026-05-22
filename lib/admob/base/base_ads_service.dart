import 'dart:math';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:log_utils/log_utils_lib.dart';

abstract class BaseAdsService<T extends Ad> implements AdmobAdsServiceAbs<T> {
  final AdUnit _unit;
  BaseAdsService(this._unit);
  final _random = Random();

  // 当一个广告位配置了多个 id 时，每次请求随机挑一个，
  // 调用方只需要维护一份 AdUnit 定义。
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
  final defaultRequest = const AdRequest(httpTimeoutMillis: 10000);

  @protected
  // 不支持的调用统一视为接入错误：
  // 既打印日志，也直接抛异常，避免静默失败。
  Never unsupportedOperation(String operation) {
    final message = '$adsType: Unsupported operation "$operation" for ${T.toString()} service';
    LogUtils.e(message);
    throw UnsupportedError(message);
  }

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
  Future<void> preloadAds(int targetCount, {AdRequest? request}) async {
    unsupportedOperation('preloadAds');
  }

  @override
  Future<void> showFullScreenAds({AdOptions? options, AdRequest? request, AdCallBack? adCallBack}) async {
    unsupportedOperation('showFullScreenAds');
  }

  @override
  Future<void> showAdIfAvailable({AdOptions? options, AdCallBack? adCallBack}) async {
    unsupportedOperation('showAdIfAvailable');
  }

  @override
  Future<BannerAd?> loadBannerAd({required BuildContext? context, AdOptions? options, AdRequest? request}) {
    unsupportedOperation('loadBannerAd');
  }

  @override
  Future<NativeAd?> loadNativeAd({AdOptions? options, AdRequest? request}) {
    unsupportedOperation('loadNativeAd');
  }

  @override
  void shouldShowOpenAppAd(bool shouldShow, {Object? blocker}) {
    unsupportedOperation('shouldShowOpenAppAd');
  }

  @override
  void setOpenAppAdVisibility(bool shouldShow, {required Object owner}) {
    unsupportedOperation('setOpenAppAdVisibility');
  }

  @override
  void clearOpenAppAdVisibility(Object owner) {
    unsupportedOperation('clearOpenAppAdVisibility');
  }

  @override
  void appOpenAdEnabled(bool enabled, {int? fixedInterval, bool enableAutoCache = true}) {
    unsupportedOperation('appOpenAdEnabled');
  }
}
