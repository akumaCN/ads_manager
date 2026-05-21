# ad_manager

`ad_manager` 是一个基于 `google_mobile_ads` 的内部广告管理库，用来统一管理 AdMob 广告的初始化、实例缓存、展示流程、收入回传和开屏广告控制。

它不是一个 UI 组件库，而是一层广告服务封装。调用方通过 `AdsManager` 和 `AdmobAdsServiceAbs` 获取不同广告类型的服务，再按需加载、预加载、展示和释放广告实例。

## 目标

- 统一管理 AdMob SDK 初始化。
- 统一封装 Banner、插屏、激励、激励插屏、原生、开屏广告。
- 支持全屏广告预加载和缓存复用。
- 支持广告收入回传监听。
- 支持开屏广告开关、展示时机控制、失败重试和指数退避。
- 为错误调用提供明确日志和异常，而不是静默失败。

## 依赖

当前库依赖：

- `google_mobile_ads`
- `log_utils`

其中 `log_utils` 来自内部 Git 仓库：

```yaml
log_utils:
  git:
    url: https://gitlab.dt.dramatalk.live/vahaflix/flutter/log_utils.git
    ref: main
```

这意味着该库默认用于内部工程，不适合直接脱离当前环境单独发布。

## 支持的广告类型

通过 `AdsType` 区分广告类型：

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

## 核心概念

### 1. AdsManager

`AdsManager` 是整个库的统一入口，负责：

- 初始化 AdMob SDK
- 获取不同广告类型的 service
- 释放指定广告 service 或全部 service
- 广告收入事件分发
- 打开 Ad Inspector
- 控制日志级别

### 2. AdUnit

`AdUnit` 用来描述一个广告位：

```dart
const adUnit = AdUnit(
  AdsType.interstitial,
  'ca-app-pub-xxx/yyy',
);
```

字段说明：

- `type`: 广告类型
- `id`: 主广告位 id
- `extIdList`: 扩展广告位 id 列表，可用于多 id 轮询

当提供 `extIdList` 时，实际请求广告时会从 `id + extIdList` 中随机选择一个 id。

### 3. AdOptions

`AdOptions` 用来补充广告加载或展示时的可选参数：

```dart
const options = AdOptions(
  userId: 'user_1001',
  customData: 'order_2002',
);
```

字段说明：

- `userId`: 激励广告服务端校验使用
- `customData`: 激励广告服务端校验扩展字段
- `bannerCustomSize`: Banner 自定义尺寸
- `nativeStyle`: 原生广告模板样式

### 4. AdCallBack

`AdCallBack` 用来接收广告生命周期回调：

- `onAdLoading`
- `onAdLoaded`
- `onAdLoadFailed`
- `onAdShown`
- `onAdShowFailed`
- `onAdDismissed`
- `onAdClicked`
- `onRewardEarned`
- `onAdImpression`

## 快速开始

### 1. 初始化 AdMob

建议在应用启动后尽早初始化：

```dart
final success = await AdsManager.initAdmob(
  testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
);

if (!success) {
  // 初始化失败时自行兜底
}
```

说明：

- 如果已经初始化过，`initAdmob()` 会直接返回 `true`
- `testDeviceIds` 仅在初始化成功时生效
- `AdsManager.isMobileAdsInitializeCalled` 表示 AdMob SDK 是否已初始化成功

### 2. 开启日志

```dart
AdsManager.setLogEnable(true);
```

关闭后会只保留较高等级日志：

```dart
AdsManager.setLogEnable(false);
```

### 3. 获取广告服务

```dart
const rewardedUnit = AdUnit(
  AdsType.rewarded,
  'ca-app-pub-xxx/rewarded',
);

final service = AdsManager.getAdmobService(rewardedUnit);
```

同一个 `type + id` 会复用同一个 service 实例。

## 各广告类型使用方式

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

说明：

- `context` 不能为空
- 如果不传 `bannerCustomSize`，会自动尝试获取当前屏幕方向下的自适应 Banner 尺寸
- `loadBannerAd()` 返回的是 `BannerAd?`
- 不再需要时，请由调用方对返回的 `BannerAd` 调用 `dispose()`

自定义 Banner 尺寸示例：

```dart
final bannerAd = await bannerService.loadBannerAd(
  context: context,
  options: const AdOptions(
    bannerCustomSize: AdSize.banner,
  ),
);
```

### Native 原生广告

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

if (nativeAd != null) {
  final widget = AdWidget(ad: nativeAd);
}
```

说明：

- `loadNativeAd()` 返回的是 `NativeAd?`
- 默认使用 `TemplateType.medium`
- 不再需要时，请由调用方对返回的 `NativeAd` 调用 `dispose()`

### 插屏广告

```dart
const interstitialUnit = AdUnit(
  AdsType.interstitial,
  'ca-app-pub-xxx/interstitial',
);

final interstitialService = AdsManager.getAdmobService(interstitialUnit);

await interstitialService.preloadAds(1);

await interstitialService.showAdIfAvailable(
  adCallBack: AdCallBack(
    onAdShown: (type) {
      // 已开始展示
    },
    onAdDismissed: (type, {isEarnedReward}) {
      // 广告关闭
    },
  ),
);
```

也可以直接边加载边展示：

```dart
await interstitialService.showFullScreenAds(
  adCallBack: AdCallBack(
    onAdLoading: (type) {},
    onAdLoaded: (type, {cachedCount}) {},
    onAdLoadFailed: (type) {},
    onAdShowFailed: (type) {},
  ),
);
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
    customData: 'room_2002',
  ),
  adCallBack: AdCallBack(
    onRewardEarned: (type) {
      // 用户已达成奖励条件
    },
    onAdDismissed: (type, {isEarnedReward}) {
      // 广告关闭
      // isEarnedReward 表示业务定义下是否达成奖励
    },
  ),
);
```

说明：

- 激励广告支持服务端校验参数
- `onRewardEarned` 在用户达成奖励时回调
- `onAdDismissed` 中的 `isEarnedReward` 会反映奖励状态
- 激励广告和激励插屏广告预加载上限为 6

### 激励插屏广告

```dart
const rewardedInterstitialUnit = AdUnit(
  AdsType.rewardedInterstitial,
  'ca-app-pub-xxx/rewarded-interstitial',
);

final rewardedInterstitialService =
    AdsManager.getAdmobService(rewardedInterstitialUnit);

await rewardedInterstitialService.preloadAds(2);

await rewardedInterstitialService.showFullScreenAds(
  options: const AdOptions(
    userId: 'user_1001',
    customData: 'task_3003',
  ),
  adCallBack: AdCallBack(
    onRewardEarned: (type) {},
    onAdDismissed: (type, {isEarnedReward}) {},
  ),
);
```

### 开屏广告

```dart
const appOpenUnit = AdUnit(
  AdsType.appOpenAd,
  'ca-app-pub-xxx/app-open',
);

final appOpenService = AdsManager.getAdmobService(appOpenUnit);
```

#### 开启开屏广告监听

```dart
appOpenService.appOpenAdEnabled(true, fixedInterval: 10);
```

字段说明：

- `enabled`: 是否启用开屏广告监听
- `fixedInterval`: 距离上次成功展示至少间隔多少秒后，回到前台时才允许再次展示

#### 控制某些页面不展示开屏广告

```dart
appOpenService.shouldShowOpenAppAd(false);
```

说明：

- 这是“临时不展示”开关
- 它不会停止后台加载、缓存和失败重试
- 如果需要真正关闭开屏广告能力，请使用 `appOpenAdEnabled(false)`

恢复允许展示：

```dart
appOpenService.shouldShowOpenAppAd(true);
```

#### 主动预加载开屏广告

当前设计下，开屏广告是否预加载由调用端自行控制：

```dart
await appOpenService.preloadAds(1);
```

#### 前后台切换展示逻辑

开屏广告启用后：

- 监听 App 进入前台事件
- 当距离上次成功展示超过 `fixedInterval`
- 且当前允许展示开屏广告
- 且有可展示广告或可即时拉起加载

则尝试展示开屏广告。

#### 开屏广告失败重试

开屏广告加载失败后会自动进行指数退避重试：

- 第 1 次失败后：1 分钟
- 第 2 次失败后：2 分钟
- 第 3 次失败后：4 分钟
- 第 4 次及以后：最大 8 分钟封顶

成功加载、禁用开屏广告、释放 service 时会清理重试定时器并重置重试状态。

## preloadAds 说明

`preloadAds(int targetCount)` 的语义需要特别注意。

对于全屏广告：

- `targetCount` 表示本次希望追加的“目标缓存规模”
- 当前实现内部采用的是“按缺口进行加载尝试”
- 日志里会明确区分 `attempted`、`loaded` 和缓存总量
- 它不是严格意义上的“保证最终缓存到 targetCount 个成功广告”

例如：

```dart
await rewardedService.preloadAds(3);
```

这表示：

- 如果当前缓存是 0，会尝试补到 3
- 如果当前缓存已经是 2，则只会再尝试 1 次

## 回调语义说明

### onAdLoading

开始加载广告时触发。

### onAdLoaded

广告已可用于展示时触发。

如果本次展示直接使用了预加载缓存，`cachedCount` 表示取出当前广告后剩余的缓存数。

### onAdLoadFailed

加载失败，无法拿到可展示广告时触发。

### onAdShown

广告已开始展示时触发。

### onAdShowFailed

广告对象已拿到，但实际展示失败时触发。

### onAdDismissed

广告关闭时触发。

对于激励相关广告，`isEarnedReward` 表示业务定义下的奖励结果。

### onAdClicked

广告点击时触发。

### onRewardEarned

激励广告奖励达成时触发。

### onAdImpression

广告产生曝光时触发。

## 广告收入监听

库内统一通过 `AdsManager.onAdRevenueChange` 分发广告收入事件：

```dart
final subscription = AdsManager.onAdRevenueChange.listen((event) {
  print('type: ${event.type}');
  print('adUnitId: ${event.adUnitId}');
  print('currencyCode: ${event.currencyCode}');
  print('valueMicros: ${event.valueMicros}');
});
```

`AdRevenueEvent` 字段说明：

- `type`: 广告类型
- `adUnitId`: 广告位 id
- `precision`: 收入精度
- `currencyCode`: 币种
- `valueMicros`: 收入微单位
- `loadedAdapterResponseInfo`: 已加载适配器信息

使用完成后请记得取消订阅：

```dart
await subscription.cancel();
```

## 释放资源

### 释放单个 service

```dart
await AdsManager.removeAdmobService(rewardedUnit);
```

### 按类型释放

```dart
await AdsManager.removeAllByType(AdsType.rewarded);
```

### 释放全部 service

```dart
await AdsManager.removeAll();
```

说明：

- 这里只释放 `AdsManager` 管理的广告 service
- Banner / Native 这类直接返回给调用方的广告对象，仍然需要调用方自己负责 `dispose()`

## Ad Inspector

```dart
AdsManager.openAdInspector();
```

适合开发调试阶段定位广告填充、适配器和配置问题。

## 错误调用说明

当前库会对明显错误的调用方式直接打错误日志并抛出 `UnsupportedError`。

例如：

- 用 Banner service 去调用 `showFullScreenAds()`
- 用 Native service 去调用 `appOpenAdEnabled()`
- 用 Interstitial service 去调用 `loadNativeAd()`

这是有意为之，目的是尽早暴露接入错误，而不是静默失败。

## 推荐接入模式

### 1. 为每个广告位维护固定的 AdUnit 常量

```dart
class AdUnits {
  static const homeBanner = AdUnit(AdsType.banner, 'ca-app-pub-xxx/home-banner');
  static const launchOpen = AdUnit(AdsType.appOpenAd, 'ca-app-pub-xxx/launch-open');
  static const rewardVideo = AdUnit(AdsType.rewarded, 'ca-app-pub-xxx/reward-video');
}
```

### 2. 应用启动时初始化 SDK

```dart
await AdsManager.initAdmob();
```

### 3. 页面或模块内部只负责拿 service 和调用

```dart
final rewardService = AdsManager.getAdmobService(AdUnits.rewardVideo);
```

### 4. 页面销毁或场景结束时清理 service

```dart
await AdsManager.removeAdmobService(AdUnits.rewardVideo);
```

### 5. 对 Banner / Native 返回对象自己做 dispose

```dart
@override
void dispose() {
  bannerAd?.dispose();
  nativeAd?.dispose();
  super.dispose();
}
```

## 常见问题

### 1. 为什么 loadBannerAd 返回 null

常见原因：

- AdMob 未初始化
- `context` 为 null
- 自适应尺寸获取失败
- 广告请求超时
- 广告填充失败

### 2. 为什么 showAdIfAvailable 没有展示

因为它的语义是：

- 只有缓存里有广告时才展示
- 如果没有缓存广告，不会主动加载，也不会报错

需要“没有缓存也立即尝试展示”时，请使用：

```dart
await service.showFullScreenAds();
```

### 3. 为什么调用某些方法会抛 UnsupportedError

因为当前 service 类型不支持该操作。

例如：

- Banner 只能 `loadBannerAd`
- Native 只能 `loadNativeAd`
- 开屏广告支持 `appOpenAdEnabled` 和 `shouldShowOpenAppAd`
- 全屏广告支持 `preloadAds`、`showFullScreenAds`、`showAdIfAvailable`

### 4. extIdList 有什么作用

当一个广告位需要在多个 id 间做随机分发时，可以配置：

```dart
const rewardedUnit = AdUnit(
  AdsType.rewarded,
  'ca-app-pub-xxx/main',
  extIdList: [
    'ca-app-pub-xxx/backup1',
    'ca-app-pub-xxx/backup2',
  ],
);
```

请求广告时会随机选一个 id 使用。

## 最小接入示例

```dart
import 'package:ad_manager/ad_manager_lib.dart';

class AdBootstrap {
  static const rewardUnit = AdUnit(
    AdsType.rewarded,
    'ca-app-pub-xxx/rewarded',
  );

  static Future<void> init() async {
    AdsManager.setLogEnable(true);
    await AdsManager.initAdmob();
  }

  static Future<void> showReward() async {
    final service = AdsManager.getAdmobService(rewardUnit);

    await service.preloadAds(1);

    await service.showAdIfAvailable(
      options: const AdOptions(
        userId: 'u_1001',
        customData: 'reward_scene',
      ),
      adCallBack: AdCallBack(
        onAdLoading: (type) {},
        onAdLoaded: (type, {cachedCount}) {},
        onRewardEarned: (type) {},
        onAdDismissed: (type, {isEarnedReward}) {},
        onAdLoadFailed: (type) {},
        onAdShowFailed: (type) {},
      ),
    );
  }
}
```

## 维护建议

- 所有广告位 id 用常量集中管理
- 不要在多个地方临时拼装 `AdUnit`
- 对 Banner / Native 广告对象记得手动释放
- 对激励广告的奖励逻辑，建议统一在 `onRewardEarned` 和 `onAdDismissed` 中收口
- 开屏广告是否预加载、何时调用 `shouldShowOpenAppAd(false)`，建议由宿主工程统一约定
