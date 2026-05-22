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
  void appOpenAdEnabled(bool enabled, {int? fixedInterval, bool enableAutoCache = true});

  ///是否应该显示开屏广告
  ///
  ///[blocker] 用于标识当前这次“禁止展示”来源。
  ///嵌套页面场景建议传入页面私有 blocker，避免不同页面互相覆盖状态。
  void shouldShowOpenAppAd(bool shouldShow, {Object? blocker});

  ///设置当前页面作用域下的开屏广告展示策略。
  ///
  ///当存在多个 [owner] 时，以最后一次设置的 owner 为当前生效页面；
  ///clear 后会自动恢复到上一个页面的策略。
  void setOpenAppAdVisibility(bool shouldShow, {required Object owner});

  ///清除某个页面作用域下的开屏广告展示策略。
  void clearOpenAppAdVisibility(Object owner);

  ///释放广告
  Future<void> dispose();
}
