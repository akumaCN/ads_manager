part of "../ad_manager_lib.dart";

class AdUnit {
  final AdsType type;
  final String id;
  const AdUnit(this.type, this.id);

  String get serviceKey => '${type.name}-$id';
}
