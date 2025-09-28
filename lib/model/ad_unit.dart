part of "../ad_manager_lib.dart";

class AdUnit {
  final AdsType type;
  final String id; //主要id
  final List<String>? extIdList; //拓展的id
  const AdUnit(this.type, this.id, {this.extIdList});

  String get serviceKey => '${type.name}-$id';

  @override
  String toString() {
    return 'AdUnit(type: ${type.name}, id: $id, idList: ${extIdList ?? []})';
  }
}
