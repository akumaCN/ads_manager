part of "../ad_manager_lib.dart";

abstract class AdmobAdsServiceAbs<T extends Ad> {
  ///预加载广告
  Future<void> preloadAds(int targetCount, {AdRequest? request});

  ///显示全屏广告
  Future<void> showFullScreenAds({AdOptions? options, AdRequest? request, AdCallBack? adCallBack});

  ///显示广告
  ///如果有广告直接显示，如果没有，不做处理
  Future<void> showAdIfAvailable({AdOptions? options, AdCallBack? adCallBack});

  ///获取banner广告
  Future<BannerAd?> loadBannerAd({required BuildContext? context, AdOptions? options, AdRequest? request});

  ///获取原生广告
  Future<NativeAd?> loadNativeAd({AdOptions? options, AdRequest? request});

  ///是否启动开屏广告
  void appOpenAdEnabled(bool enabled, {int? fixedInterval});

  ///是否应该显示开屏广告
  void shouldShowOpenAppAd(bool shouldShow);

  ///释放广告
  Future<void> dispose();
}
