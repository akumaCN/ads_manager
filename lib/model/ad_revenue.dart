part of "../ad_manager_lib.dart";

final class AdRevenueEvent {
  final AdsType type;
  final String adUnitId;
  final PrecisionType precision;
  final String currencyCode;
  final double valueMicros;

  AdRevenueEvent(this.type, this.adUnitId, this.precision, this.currencyCode, this.valueMicros);

  @override
  String toString() => {
        'type': type.toString(),
        'adUnitId': adUnitId,
        'precision': precision.toString(),
        'currencyCode': currencyCode,
        'valueMicros': valueMicros,
      }.toString();
}
