import 'dart:async';

import 'package:ad_manager/ad_manager_lib.dart';
import 'package:log_utils/log_utils_lib.dart';

import '../base/full_screen_ads_service.dart';

final class AppOpenAdServiceImpl extends FullScreenAdsService<AppOpenAd> {
  //加载失败重试间隔
  static const _initialRetryDelay = Duration(minutes: 1);
  static const _maxRetryDelay = Duration(minutes: 8);
  //广告最大缓存时长
  final Duration _maxCacheDuration = const Duration(hours: 3);
  //广告加载的时间
  DateTime? _appOpenLoadTime;
  //App状态管理
  StreamSubscription<AppState>? _appStateSubscription;
  //是否正在显示广告
  bool _isShowingAd = false;
  //广告是否可用
  bool _isAdAvailable = false;
  //是否正在加载广告
  bool _isLoadingAd = false;
  //失败后的延迟重试
  Timer? _retryTimer;
  // 连续失败次数，用来计算指数退避时长
  int _retryAttempt = 0;
  // 是否应该显示开屏广告
  bool _shouldShowAppOpenAd = true;
  // 开屏广告动态开关控制
  bool _isAppOpenAdEnabled = false;
  //上一次广告显示时间
  DateTime _lastAdShownTime = DateTime.now();
  AppOpenAdServiceImpl(super._unit);

  @override
  void shouldShowOpenAppAd(bool shouldShow) {
    if (_shouldShowAppOpenAd != shouldShow) {
      _shouldShowAppOpenAd = shouldShow;
    }
  }

  int _fixedInterval = 10;

  @override
  void appOpenAdEnabled(bool enabled, {int? fixedInterval}) {
    if (fixedInterval != null) {
      _fixedInterval = fixedInterval;
    }
    if (_isAppOpenAdEnabled == enabled) return;
    _isAppOpenAdEnabled = enabled;
    if (_isAppOpenAdEnabled) {
      AppStateEventNotifier.startListening();
      //取消旧订阅
      _appStateSubscription?.cancel();
      //开启订阅
      _appStateSubscription = AppStateEventNotifier.appStateStream.listen((state) {
        LogUtils.d("$adsType app state changed: ${state.name}");
        if (!_isAppOpenAdEnabled || !_shouldShowAppOpenAd) return;
        if (state == AppState.foreground) {
          final secondsSinceLastAd = DateTime.now().difference(_lastAdShownTime).inSeconds;
          if (secondsSinceLastAd >= _fixedInterval) {
            showFullScreenAds();
          } else {
            LogUtils.d("Ad countdown: ${_fixedInterval - secondsSinceLastAd}s remaining");
          }
        }
      });
    } else {
      _disableAppOpenAd();
    }
  }

  void _setLastAdShownTime() {
    _lastAdShownTime = DateTime.now();
  }

  // 禁用逻辑
  void _disableAppOpenAd() {
    _resetRetryState();
    AppStateEventNotifier.stopListening();
    //取消订阅
    _appStateSubscription?.cancel();
    _appStateSubscription = null;
    _isShowingAd = false;
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _resetRetryState() {
    _cancelRetryTimer();
    _retryAttempt = 0;
  }

  // 失败后的重试间隔按 1m -> 2m -> 4m -> 8m 递增，并在 8 分钟封顶。
  Duration _computeRetryDelay() {
    final factor = 1 << _retryAttempt;
    final delay = _initialRetryDelay * factor;
    if (delay > _maxRetryDelay) {
      return _maxRetryDelay;
    }
    return delay;
  }

  void _scheduleRetry() {
    _cancelRetryTimer();
    final delay = _computeRetryDelay();
    _retryAttempt += 1;
    LogUtils.w('$adsType retry scheduled in ${delay.inSeconds}s (attempt: $_retryAttempt)');
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      preloadAds(1);
    });
  }

  AdRequest? _lastRequest;

  @override
  Future<AppOpenAd?> performLoadAd({AdRequest? request}) {
    if (request != null) {
      _lastRequest = request;
    }
    if (!_isAppOpenAdEnabled) {
      LogUtils.w('$adsType: AppOpenAd enable:$_isAppOpenAdEnabled');
      return Future.value(null);
    }
    if (!AdsManager.isMobileAdsInitializeCalled) {
      LogUtils.w('$adsType: Mobile Ads not initialized, ad loading canceled');
      return Future.value(null);
    }
    if (_isLoadingAd || _isAdAvailable) {
      // 开屏广告同一时刻只允许一个加载流程，避免重复请求和状态覆盖。
      LogUtils.d("$adsType load already in progress or ad available");
      return Future.value(null);
    }
    _isLoadingAd = true;
    bool isTimedOut = false;
    AppOpenAd? loadedAd;
    final completer = Completer<AppOpenAd?>();

    void completeCompleter([AppOpenAd? ad]) {
      _isLoadingAd = false;
      _isAdAvailable = ad != null;
      if (ad != null) {
        _appOpenLoadTime = DateTime.now();
      }
      if (!completer.isCompleted) {
        completer.complete(ad);
      }
    }

    void disposeAd() {
      loadedAd?.dispose();
      loadedAd = null;
    }

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: _lastRequest ?? defaultRequest,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _resetRetryState();
          loadedAd = ad;
          if (isTimedOut) {
            disposeAd();
            return;
          }
          LogUtils.d("$adsType loaded successfully");
          completeCompleter(ad);
        },
        onAdFailedToLoad: (error) {
          LogUtils.e("$adsType load failed.", error: error);
          completeCompleter();
          _scheduleRetry();
        },
      ),
    );
    return completer.future.timeout(kLoadTimeout, onTimeout: () {
      isTimedOut = true;
      LogUtils.d('$adsType: Ad load timed out');
      disposeAd();
      completeCompleter();
      return null;
    }).catchError((e) => null);
  }

  @override
  Future<void> performShow(AppOpenAd ad, {AdOptions? options, AdCallBack? adCallBack}) async {
    if (!_isAppOpenAdEnabled) {
      LogUtils.w('$adsType: App Open Ad is disabled, skipping show');
      ad.dispose();
      _isShowingAd = false;
      return;
    }

    void disposeAd() {
      ad.dispose();
      _isShowingAd = false;
      _isAdAvailable = false;
      // 当前广告消费完成后，异步补一个新的缓存，供下次前台展示使用。
      preloadAds(1);
    }

    if (!_shouldShowAppOpenAd) {
      LogUtils.w('$adsType: Should not show App Open Ad, skipping');
      disposeAd();
      return;
    }

    if (_isShowingAd) {
      LogUtils.d("$adsType already showing");
      // 当前已经有开屏广告在展示，新的广告先放回缓存头部，避免白白丢掉。
      restorePreloadedAd(ad, toFront: true);
      return;
    }

    if (_isAdExpired) {
      LogUtils.d("$adsType expired (loaded at $_appOpenLoadTime)");
      disposeAd();
      return;
    }
    ad.fullScreenContentCallback = getCallback(
      adCallBack,
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        _setLastAdShownTime();
        LogUtils.d("$adsType ad showed");
        adCallBack?.onAdShown?.call(adsType);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        LogUtils.e("$adsType ad failed to show", error: error);
        adCallBack?.onAdShowFailed?.call(adsType);
        disposeAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        LogUtils.d("$adsType ad dismissed");
        adCallBack?.onAdDismissed?.call(adsType);
        disposeAd();
      },
    );
    ad.onPaidEvent = notifyAdRevenue;
    ad.show();
  }

  //判断广告是否过期
  bool get _isAdExpired {
    return _appOpenLoadTime == null || DateTime.now().subtract(_maxCacheDuration).isAfter(_appOpenLoadTime!);
  }

  @override
  Future<void> dispose() async {
    _disableAppOpenAd();
    await super.dispose();
    LogUtils.d("$adsType service disposed");
  }
}
