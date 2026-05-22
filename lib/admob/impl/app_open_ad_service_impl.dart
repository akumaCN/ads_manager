import 'dart:async';
import 'dart:collection';

import 'package:ads_manager/ad_manager_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:log_utils_plus/log_utils_lib.dart';

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
  // 兼容旧版 bool 开关的阻止计数。适用于单页面成对调用 false/true。
  int _legacyBlockCount = 0;
  // 页面级阻止集合。嵌套页面场景建议传入 blocker，避免互相覆盖。
  final Set<Object> _blockers = <Object>{};
  // 页面级展示策略。最后一个进入的页面优先生效，退出后恢复上一层页面策略。
  final LinkedHashMap<Object, bool> _visibilityOwners = LinkedHashMap<Object, bool>();
  // 真正总开关：控制前后台监听、加载、缓存、失败重试整条链路是否启用
  bool _isAppOpenAdEnabled = false;
  //上一次广告显示时间
  DateTime _lastAdShownTime = DateTime.now();
  //开屏固定间隔
  int _fixedInterval = 10;
  // 开启自动缓存
  bool _enableAutoCache = true;
  AppOpenAdServiceImpl(super._unit);

  @override
  void shouldShowOpenAppAd(bool shouldShow, {Object? blocker}) {
    final previousState = _shouldShowAppOpenAd;

    if (blocker != null) {
      if (shouldShow) {
        _blockers.remove(blocker);
      } else {
        _blockers.add(blocker);
      }
      LogUtils.d('$adsType blocker updated: ${shouldShow ? "remove" : "add"}, total:${_blockers.length}');
    } else if (shouldShow) {
      if (_legacyBlockCount > 0) {
        _legacyBlockCount -= 1;
      }
      LogUtils.d('$adsType legacy blocker released, remaining:$_legacyBlockCount');
    } else {
      _legacyBlockCount += 1;
      LogUtils.d('$adsType legacy blocker added, total:$_legacyBlockCount');
    }

    if (previousState != _shouldShowAppOpenAd) {
      // 这里只改变展示意图，不主动清理当前缓存，也不停止后台补缓存
      LogUtils.d('$adsType should show changed: $_shouldShowAppOpenAd');
    }
  }

  @override
  void setOpenAppAdVisibility(bool shouldShow, {required Object owner}) {
    final previousState = _shouldShowAppOpenAd;
    _visibilityOwners.remove(owner);
    _visibilityOwners[owner] = shouldShow;
    LogUtils.d('$adsType visibility owner updated: shouldShow:$shouldShow, total:${_visibilityOwners.length}');
    if (previousState != _shouldShowAppOpenAd) {
      LogUtils.d('$adsType should show changed: $_shouldShowAppOpenAd');
    }
  }

  @override
  void clearOpenAppAdVisibility(Object owner) {
    final previousState = _shouldShowAppOpenAd;
    final removed = _visibilityOwners.remove(owner) != null;
    if (!removed) return;
    LogUtils.d('$adsType visibility owner cleared, total:${_visibilityOwners.length}');
    if (previousState != _shouldShowAppOpenAd) {
      LogUtils.d('$adsType should show changed: $_shouldShowAppOpenAd');
    }
  }

  @override
  void appOpenAdEnabled(bool enabled, {int? fixedInterval, bool enableAutoCache = true}) {
    if (fixedInterval != null) {
      _fixedInterval = fixedInterval;
    }
    _enableAutoCache = enableAutoCache;
    if (_isAppOpenAdEnabled == enabled) return;
    _isAppOpenAdEnabled = enabled;
    if (_isAppOpenAdEnabled) {
      unawaited(_startListeningSafely());
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

  Future<void> _startListeningSafely() async {
    try {
      await AppStateEventNotifier.startListening();
    } on MissingPluginException catch (error) {
      LogUtils.w('$adsType startListening skipped: $error');
    } on PlatformException catch (error) {
      LogUtils.w('$adsType startListening failed: ${error.message ?? error.code}');
    }
  }

  bool get _shouldShowAppOpenAd {
    if (_visibilityOwners.isNotEmpty) {
      return _visibilityOwners.values.last;
    }
    return _legacyBlockCount == 0 && _blockers.isEmpty;
  }

  @visibleForTesting
  bool get debugShouldShowOpenAppAd => _shouldShowAppOpenAd;

  @visibleForTesting
  int get debugLegacyBlockCount => _legacyBlockCount;

  @visibleForTesting
  int get debugScopedBlockCount => _blockers.length;

  @visibleForTesting
  int get debugVisibilityOwnerCount => _visibilityOwners.length;

  // 禁用逻辑
  void _disableAppOpenAd() {
    _resetRetryState();
    unawaited(_stopListeningSafely());
    //取消订阅
    _appStateSubscription?.cancel();
    _appStateSubscription = null;
    _isShowingAd = false;
    _isAdAvailable = false;
    _appOpenLoadTime = null;
    _visibilityOwners.clear();
    clearPreloadedAds();
  }

  Future<void> _stopListeningSafely() async {
    try {
      await AppStateEventNotifier.stopListening();
    } on MissingPluginException catch (error) {
      LogUtils.w('$adsType stopListening skipped: $error');
    } on PlatformException catch (error) {
      LogUtils.w('$adsType stopListening failed: ${error.message ?? error.code}');
    }
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
      _scheduleRetry();
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
      if (_enableAutoCache) {
        preloadAds(1);
      }
    }

    if (!_shouldShowAppOpenAd) {
      LogUtils.w('$adsType: Should not show App Open Ad, skipping');
      restorePreloadedAd(ad, toFront: true);
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
