part of "../ad_manager_lib.dart";

class AdOptions {
  final String? userId;
  final String? customData;
  final AdSize? bannerCustomSize;
  final NativeTemplateStyle? nativeStyle;

  const AdOptions({this.userId, this.customData, this.bannerCustomSize, this.nativeStyle});

  // 激励广告展示前按需生成服务端校验参数。
  ServerSideVerificationOptions get serverSideVerificationOptions =>
      ServerSideVerificationOptions(userId: userId, customData: customData);
}
