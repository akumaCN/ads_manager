# ads_manager

`ads_manager` 是一个基于 `google_mobile_ads` 的 Flutter 广告服务封装库。
它用于统一管理广告 SDK 初始化、广告实例复用、预加载流程、开屏广告展示控制和广告收益回传。

[English README](README.md) | [更新说明](CHANGELOG.md)

## 特性

- 统一接入 Banner、插屏、激励、激励插屏、原生、开屏广告
- 基于广告位缓存并复用 service 实例
- 支持全屏广告预加载
- 支持广告收益事件统一监听
- 支持开屏广告启停控制
- 支持嵌套路由场景下的开屏广告页面级展示控制
- 对错误调用提供明确日志和异常

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  ads_manager: ^1.2.2
```

然后执行：

```bash
flutter pub get
```

## 快速开始

### 1. 初始化 Mobile Ads

```dart
final success = await AdsManager.initAdmob(
  testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
);

if (!success) {
  // 初始化失败时自行兜底
}
```

### 2. 获取广告服务

```dart
const rewardedUnit = AdUnit(
  AdsType.rewarded,
  'ca-app-pub-xxx/rewarded',
);

final rewardedService = AdsManager.getAdmobService(rewardedUnit);
```

### 3. 预加载并展示广告

```dart
await rewardedService.preloadAds(1);

await rewardedService.showAdIfAvailable(
  options: const AdOptions(
    userId: 'user_1001',
    customData: 'room_2002',
  ),
  adCallBack: AdCallBack(
    onRewardEarned: (type) {
      // 用户获得奖励
    },
    onAdDismissed: (type, {isEarnedReward}) {
      // 广告关闭
    },
  ),
);
```

## 支持的广告类型

```dart
enum AdsType {
  banner,
  interstitial,
  native,
  rewarded,
  rewardedInterstitial,
  appOpenAd,
}
```

## 核心 API

### AdsManager

`AdsManager` 是统一入口，负责：

- 初始化 Google Mobile Ads SDK
- 创建并缓存广告 service
- 释放单个或全部广告 service
- 分发广告收益事件
- 打开 Ad Inspector
- 控制日志开关

### AdUnit

`AdUnit` 用于描述一个广告位：

```dart
const adUnit = AdUnit(
  AdsType.interstitial,
  'ca-app-pub-xxx/yyy',
);
```

也可以通过 `extIdList` 传入多个广告位 ID，运行时会随机轮换。

### AdOptions

`AdOptions` 用于补充加载或展示时的附加配置：

- `userId`
- `customData`
- `bannerCustomSize`
- `nativeStyle`

### AdCallBack

`AdCallBack` 提供广告生命周期回调，包括：

- `onAdLoading`
- `onAdLoaded`
- `onAdLoadFailed`
- `onAdShown`
- `onAdShowFailed`
- `onAdDismissed`
- `onAdClicked`
- `onRewardEarned`
- `onAdImpression`

## 使用方式

### Banner 广告

```dart
const bannerUnit = AdUnit(
  AdsType.banner,
  'ca-app-pub-xxx/banner',
);

final bannerService = AdsManager.getAdmobService(bannerUnit);

final bannerAd = await bannerService.loadBannerAd(
  context: context,
  options: const AdOptions(),
);

if (bannerAd != null) {
  final widget = AdWidget(ad: bannerAd);
}
```

### 原生广告

```dart
const nativeUnit = AdUnit(
  AdsType.native,
  'ca-app-pub-xxx/native',
);

final nativeService = AdsManager.getAdmobService(nativeUnit);

final nativeAd = await nativeService.loadNativeAd(
  options: AdOptions(
    nativeStyle: NativeTemplateStyle(
      templateType: TemplateType.medium,
    ),
  ),
);
```

### 插屏广告

```dart
const interstitialUnit = AdUnit(
  AdsType.interstitial,
  'ca-app-pub-xxx/interstitial',
);

final interstitialService = AdsManager.getAdmobService(interstitialUnit);

await interstitialService.preloadAds(1);
await interstitialService.showAdIfAvailable();
```

### 激励广告

```dart
const rewardedUnit = AdUnit(
  AdsType.rewarded,
  'ca-app-pub-xxx/rewarded',
);

final rewardedService = AdsManager.getAdmobService(rewardedUnit);

await rewardedService.preloadAds(3);
await rewardedService.showAdIfAvailable(
  options: const AdOptions(
    userId: 'user_1001',
    customData: 'order_2002',
  ),
);
```

### 激励插屏广告

```dart
const rewardedInterstitialUnit = AdUnit(
  AdsType.rewardedInterstitial,
  'ca-app-pub-xxx/rewarded-interstitial',
);

final rewardedInterstitialService =
    AdsManager.getAdmobService(rewardedInterstitialUnit);

await rewardedInterstitialService.preloadAds(2);
await rewardedInterstitialService.showFullScreenAds();
```

### 开屏广告

```dart
const appOpenUnit = AdUnit(
  AdsType.appOpenAd,
  'ca-app-pub-xxx/app-open',
);

final appOpenService = AdsManager.getAdmobService(appOpenUnit);
appOpenService.appOpenAdEnabled(true, fixedInterval: 10);
```

临时关闭/恢复展示：

```dart
appOpenService.shouldShowOpenAppAd(false);
appOpenService.shouldShowOpenAppAd(true);
```

如果存在多个嵌套页面都需要关闭开屏广告，建议使用独立 blocker：

```dart
final blocker = Object();

@override
void initState() {
  super.initState();
  appOpenService.shouldShowOpenAppAd(false, blocker: blocker);
}

@override
void dispose() {
  appOpenService.shouldShowOpenAppAd(true, blocker: blocker);
  super.dispose();
}
```

如果你希望“当前页面自己的策略优先生效，并在返回时自动恢复上一页策略”，可以使用 owner 作用域接口：

```dart
final pageOwner = Object();

@override
void initState() {
  super.initState();
  appOpenService.setOpenAppAdVisibility(false, owner: pageOwner);
}

@override
void dispose() {
  appOpenService.clearOpenAppAdVisibility(pageOwner);
  super.dispose();
}
```

例如：

- A 页面关闭开屏广告
- B 页面允许开屏广告
- C 页面关闭开屏广告
- 从 C 返回 B 后恢复为允许展示
- 从 B 返回 A 后恢复为关闭展示

## 广告收益监听

可以通过 `AdsManager.onAdRevenueChange` 监听广告收益事件：

```dart
final subscription = AdsManager.onAdRevenueChange.listen((event) {
  print('type: ${event.type}');
  print('unit: ${event.adUnitId}');
  print('valueMicros: ${event.valueMicros}');
  print('currencyCode: ${event.currencyCode}');
});
```

## 说明

- `BannerAd` 和 `NativeAd` 由调用方负责在不再使用时执行 `dispose()`
- 激励广告和激励插屏广告的预加载上限为 6
- 开屏广告加载失败后会走指数退避重试
- `preloadAds(targetCount)` 按缺口补充，不保证每一次请求都成功

## 示例

可参考最小示例工程 [example/lib/main.dart](example/lib/main.dart)。

## License

本项目采用 MIT License，详见 [LICENSE](LICENSE)。
