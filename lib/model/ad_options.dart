part of "../ad_manager_lib.dart";

class AdOptions {
  final String? userId;
  final String? customData;
  final AdSize? bannerCustomSize;
  final NativeTemplateStyle? nativeStyle;

  const AdOptions({this.userId, this.customData, this.bannerCustomSize, this.nativeStyle});

  ServerSideVerificationOptions get serverSideVerificationOptions =>
      ServerSideVerificationOptions(userId: userId, customData: customData);
}
