part of "ad_manager_lib.dart";

final class AdsManager {
  AdsManager._();

  //admob 初始化状态
  static bool _isMobileAdsInitializeCalled = false;

  static bool get isMobileAdsInitializeCalled => _isMobileAdsInitializeCalled;

  //初始化Google Mobile Ads SDK
  ///返回true表示初始化成功，false表示初始化失败
  ///注意：如果已经初始化过，则不会重复初始化
  ///可以通过调用[removeAll]方法释放所有广告服务
  ///在应用启动时调用此方法进行初始化
  static Future<bool> initAdmob({List<String>? testDeviceIds}) async {
    if (_isMobileAdsInitializeCalled) {
      return true;
    }
    InitializationStatus status = await MobileAds.instance.initialize();
    _isMobileAdsInitializeCalled = status.adapterStatuses.values.any(
      (adapter) => adapter.state == AdapterInitializationState.ready,
    );
    if (_isMobileAdsInitializeCalled) {
      final buffer = StringBuffer();
      buffer.writeln("MobileAds initialize successful.");
      status.adapterStatuses.forEach((key, adapter) {
        buffer.writeln(
            "Adapter: $key | State: ${adapter.state} | Latency: ${adapter.latency}ms | Description: ${adapter.description}");
      });
      LogUtils.d(buffer.toString());
    } else {
      LogUtils.d("MobileAds initialize failed.");
    }
    if (_isMobileAdsInitializeCalled && testDeviceIds != null && testDeviceIds.isNotEmpty) {
      MobileAds.instance.updateRequestConfiguration(RequestConfiguration(testDeviceIds: testDeviceIds));
    }
    return _isMobileAdsInitializeCalled;
  }

  //admob广告服务
  static final _admobServices = <String, AdmobAdsServiceAbs>{};

  ///获取相应的广告服务
  static AdmobAdsServiceAbs getAdmobService(AdUnit adUnit) {
    return _admobServices.putIfAbsent(adUnit.serviceKey, () {
      switch (adUnit.type) {
        case AdsType.banner:
          return BannerAdServiceImpl(adUnit);
        case AdsType.interstitial:
          return InterstitialAdServiceImpl(adUnit);
        case AdsType.native:
          return NativeAdServiceImpl(adUnit);
        case AdsType.rewarded:
          return RewardedAdServiceImpl(adUnit);
        case AdsType.rewardedInterstitial:
          return RewardedInterstitialAdServiceImpl(adUnit);
        case AdsType.appOpenAd:
          return AppOpenAdServiceImpl(adUnit);
      }
    });
  }

  /// 清理某个广告实例
  static Future<void> removeAdmobService(AdUnit adUnit) async {
    final service = _admobServices.remove(adUnit.serviceKey);
    if (service != null) {
      await service.dispose();
    }
  }

  /// 清理某个类型下的所有广告实例
  static Future<void> removeAllByType(AdsType type) async {
    final keysToRemove = _admobServices.keys.where((key) => key.startsWith('${type.name}-')).toList();

    for (final key in keysToRemove) {
      final service = _admobServices.remove(key);
      if (service != null) {
        await service.dispose();
      }
    }
  }

  ///释放全部广告
  static Future<void> removeAll() async {
    final services = _admobServices.values.toList();
    _admobServices.clear();
    for (final service in services) {
      await service.dispose();
    }
  }

  static final _revenueController = StreamController<AdRevenueEvent>.broadcast();

  static Stream<AdRevenueEvent> get onAdRevenueChange => _revenueController.stream;

  static void notifyAdRevenue(AdRevenueEvent adRevenue) {
    if (_revenueController.isClosed) return;
    _revenueController.sink.add(adRevenue);
  }

  ///是否开启日志
  static void setLogEnable(bool enable) {
    LogUtils.setLevel(enable ? Level.all : Level.warning);
  }

  static void openAdInspector() {
    MobileAds.instance.openAdInspector((error) {
      LogUtils.e("openAdInspector:${error?.code} ${error?.domain} ${error?.message}");
    });
  }
}
