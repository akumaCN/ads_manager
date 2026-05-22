# ads_manager

`ads_manager` is a Flutter ad service wrapper built on top of `google_mobile_ads`.
It helps centralize SDK initialization, ad instance reuse, preload flows, app open ad control, and revenue callbacks.

[中文文档](README.zh.md) | [CHANGELOG](CHANGELOG.md)

## Features

- Unified access to Banner, Interstitial, Rewarded, Rewarded Interstitial, Native, and App Open ads
- Shared ad service cache keyed by ad unit
- Preload support for full-screen ads
- Revenue event stream for analytics reporting
- App open ad enable/disable control
- App open ad page-level visibility control for nested routes
- Clear logs and explicit unsupported-operation errors

## Installation

Add the dependency:

```yaml
dependencies:
  ads_manager: ^1.2.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize Mobile Ads

```dart
final success = await AdsManager.initAdmob(
  testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
);

if (!success) {
  // Handle initialization failure.
}
```

### 2. Get an ad service

```dart
const rewardedUnit = AdUnit(
  AdsType.rewarded,
  'ca-app-pub-xxx/rewarded',
);

final rewardedService = AdsManager.getAdmobService(rewardedUnit);
```

### 3. Preload and show an ad

```dart
await rewardedService.preloadAds(1);

await rewardedService.showAdIfAvailable(
  options: const AdOptions(
    userId: 'user_1001',
    customData: 'room_2002',
  ),
  adCallBack: AdCallBack(
    onRewardEarned: (type) {
      // Reward earned.
    },
    onAdDismissed: (type, {isEarnedReward}) {
      // Ad closed.
    },
  ),
);
```

## Supported Ad Types

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

## Core APIs

### AdsManager

`AdsManager` is the main entry point. It is responsible for:

- Initializing the Google Mobile Ads SDK
- Creating and caching ad services
- Disposing one ad service or all ad services
- Dispatching ad revenue events
- Opening Ad Inspector
- Toggling logs

### AdUnit

`AdUnit` describes an ad slot:

```dart
const adUnit = AdUnit(
  AdsType.interstitial,
  'ca-app-pub-xxx/yyy',
);
```

You can also provide `extIdList` to randomly rotate among multiple ad unit IDs.

### AdOptions

`AdOptions` carries extra configuration for loading or showing ads:

- `userId`
- `customData`
- `bannerCustomSize`
- `nativeStyle`

### AdCallBack

`AdCallBack` exposes ad lifecycle hooks such as:

- `onAdLoading`
- `onAdLoaded`
- `onAdLoadFailed`
- `onAdShown`
- `onAdShowFailed`
- `onAdDismissed`
- `onAdClicked`
- `onRewardEarned`
- `onAdImpression`

## Usage

### Banner Ads

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

### Native Ads

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

### Interstitial Ads

```dart
const interstitialUnit = AdUnit(
  AdsType.interstitial,
  'ca-app-pub-xxx/interstitial',
);

final interstitialService = AdsManager.getAdmobService(interstitialUnit);

await interstitialService.preloadAds(1);
await interstitialService.showAdIfAvailable();
```

### Rewarded Ads

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

### Rewarded Interstitial Ads

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

### App Open Ads

```dart
const appOpenUnit = AdUnit(
  AdsType.appOpenAd,
  'ca-app-pub-xxx/app-open',
);

final appOpenService = AdsManager.getAdmobService(appOpenUnit);
appOpenService.appOpenAdEnabled(true, fixedInterval: 10);
```

Temporary hide/show:

```dart
appOpenService.shouldShowOpenAppAd(false);
appOpenService.shouldShowOpenAppAd(true);
```

For nested pages that all want to hide app open ads, use independent blockers:

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

For page-stack-aware visibility, use owner-based visibility:

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

This lets routes behave like:

- Page A hides app open ads
- Page B allows app open ads
- Page C hides app open ads
- Returning from C restores B's rule
- Returning from B restores A's rule

## Revenue Events

Listen for ad revenue updates through `AdsManager.onAdRevenueChange`:

```dart
final subscription = AdsManager.onAdRevenueChange.listen((event) {
  print('type: ${event.type}');
  print('unit: ${event.adUnitId}');
  print('valueMicros: ${event.valueMicros}');
  print('currencyCode: ${event.currencyCode}');
});
```

## Notes

- Call `dispose()` on returned `BannerAd` and `NativeAd` instances when no longer needed
- Rewarded and rewarded interstitial preload count is capped at 6
- App open ad retries use exponential backoff after load failures
- `preloadAds(targetCount)` fills by gap and does not guarantee that every request succeeds

## Example

See the minimal example in [example/lib/main.dart](example/lib/main.dart).

## License

This package is available under the MIT License. See [LICENSE](LICENSE).
