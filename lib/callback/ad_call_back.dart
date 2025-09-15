part of "../ad_manager_lib.dart";

class AdCallBack {
  /// 广告开始加载时触发
  final Function(AdsType type)? onAdLoading;

  /// 广告加载成功时触发
  final Function(AdsType type, {int? cachedCount})? onAdLoaded;

  /// 广告加载失败时触发
  final Function(AdsType type)? onAdLoadFailed;

  /// 广告开始展示时触发
  final Function(AdsType type)? onAdShown;

  /// 广告展示失败时触发
  final Function(AdsType type)? onAdShowFailed;

  /// 广告关闭时触发
  final Function(AdsType type, {bool? isEarnedReward})? onAdDismissed;

  /// 广告被点击时触发
  final Function(AdsType type)? onAdClicked;

  /// 激励广告奖励达成时触发
  final Function(AdsType type)? onRewardEarned;

  /// 原生广告印象记录时触发
  final Function(AdsType type)? onAdImpression;
  const AdCallBack({
    this.onAdLoading,
    this.onAdLoaded,
    this.onAdLoadFailed,
    this.onAdShown,
    this.onAdShowFailed,
    this.onAdDismissed,
    this.onAdClicked,
    this.onRewardEarned,
    this.onAdImpression,
  });
}
