import 'package:ads_manager/ad_manager_lib.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ads_manager example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  static const _bannerUnit = AdUnit(
    AdsType.banner,
    'ca-app-pub-3940256099942544/6300978111',
  );

  static const _rewardedUnit = AdUnit(
    AdsType.rewarded,
    'ca-app-pub-3940256099942544/5224354917',
  );

  late final AdmobAdsServiceAbs _bannerService;
  late final AdmobAdsServiceAbs _rewardedService;
  BannerAd? _bannerAd;
  String _status = 'Idle';

  @override
  void initState() {
    super.initState();
    _bannerService = AdsManager.getAdmobService(_bannerUnit);
    _rewardedService = AdsManager.getAdmobService(_rewardedUnit);
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    final initialized = await AdsManager.initAdmob(
      testDeviceIds: const ['YOUR_TEST_DEVICE_ID'],
    );
    if (!mounted) return;
    setState(() {
      _status = initialized ? 'SDK initialized' : 'SDK initialization failed';
    });
  }

  Future<void> _loadBanner() async {
    final bannerAd = await _bannerService.loadBannerAd(
      context: context,
      options: const AdOptions(),
    );
    if (!mounted) {
      bannerAd?.dispose();
      return;
    }
    setState(() {
      _bannerAd?.dispose();
      _bannerAd = bannerAd;
      _status = bannerAd == null ? 'Banner load failed' : 'Banner loaded';
    });
  }

  Future<void> _showRewarded() async {
    setState(() {
      _status = 'Loading rewarded ad';
    });

    await _rewardedService.showFullScreenAds(
      options: const AdOptions(
        userId: 'example_user',
        customData: 'example_reward',
      ),
      adCallBack: AdCallBack(
        onAdLoaded: (type, {cachedCount}) {
          if (!mounted) return;
          setState(() {
            _status = 'Rewarded ad loaded';
          });
        },
        onAdLoadFailed: (type) {
          if (!mounted) return;
          setState(() {
            _status = 'Rewarded ad load failed';
          });
        },
        onAdShown: (type) {
          if (!mounted) return;
          setState(() {
            _status = 'Rewarded ad shown';
          });
        },
        onRewardEarned: (type) {
          if (!mounted) return;
          setState(() {
            _status = 'Reward earned';
          });
        },
        onAdDismissed: (type, {isEarnedReward}) {
          if (!mounted) return;
          setState(() {
            _status = isEarnedReward == true ? 'Rewarded ad dismissed after reward' : 'Rewarded ad dismissed';
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ads_manager example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _loadBanner,
                  child: const Text('Load banner'),
                ),
                ElevatedButton(
                  onPressed: _showRewarded,
                  child: const Text('Show rewarded'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_bannerAd != null)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}
