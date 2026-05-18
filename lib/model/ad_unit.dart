part of "../ad_manager_lib.dart";

class AdUnit {
  final AdsType type;
  final String id; //主要id
  // 可选扩展 id，实际请求时会和主 id 一起参与随机选择
  final List<String>? extIdList; //拓展的id
  const AdUnit(this.type, this.id, {this.extIdList});

  // serviceKey 用于 AdsManager 内部缓存同一个广告位对应的 service 实例
  String get serviceKey => '${type.name}-$id';

  @override
  String toString() {
    return 'AdUnit(type: ${type.name}, id: $id, idList: ${extIdList ?? []})';
  }
}
