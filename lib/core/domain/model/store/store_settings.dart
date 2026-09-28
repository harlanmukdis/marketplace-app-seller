import '../../../utils/json_parse.dart';

/// `GET /stores/{id}/settings`.
///
/// Vacation mode is the feature the previous backend never had: a way to stop
/// taking orders without deleting the catalogue, which is what a store
/// actually needs when the owner travels.
///
/// **The row is optional.** A store only gets one when something writes it, so
/// every store created by the seed answers `data: null` here. [StoreSettings]
/// therefore has a working default for every field and a [StoreSettings.empty]
/// constructor that keeps the store id the caller already knows — a settings
/// form renders from that rather than from an error state.
///
/// There is no `vacation_message` column; the field the previous backend had
/// does not exist here, and sending it is silently dropped by the whitelist in
/// `Store_model::update_settings`.
class StoreSettings {
  const StoreSettings({
    required this.storeId,
    this.autoAcceptOrder = false,
    this.vacationMode = false,
    this.defaultCurrency = 'IDR',
    this.operationalHours,
    this.returnPolicy,
    this.shippingOrigin,
    this.contactPhone,
    this.contactWhatsapp,
  });

  /// The defaults a store runs on before anyone has saved settings for it.
  const StoreSettings.empty(this.storeId)
      : autoAcceptOrder = false,
        vacationMode = false,
        defaultCurrency = 'IDR',
        operationalHours = null,
        returnPolicy = null,
        shippingOrigin = null,
        contactPhone = null,
        contactWhatsapp = null;

  final int storeId;

  /// When set, paid orders skip the manual accept step.
  final bool autoAcceptOrder;

  final bool vacationMode;

  /// Not writable through `PATCH` — the whitelist ignores it.
  final String defaultCurrency;

  /// Free-form JSON on the server; kept raw because no screen reads them yet
  /// and inventing a shape would be guessing. All three are `JSON` columns and
  /// have to be sent as structures, not strings.
  final Map<String, dynamic>? operationalHours;
  final Map<String, dynamic>? returnPolicy;
  final Map<String, dynamic>? shippingOrigin;

  /// Seller-private contact details. Deliberately absent from the public
  /// `GET /stores/{id}` and from product detail, pending a privacy decision, so
  /// they are the seller app's to show and nobody else's.
  final String? contactPhone;
  final String? contactWhatsapp;

  factory StoreSettings.fromJson(Map<String, dynamic> json) => StoreSettings(
        storeId: asInt(json['store_id']),
        autoAcceptOrder: asBool(json['auto_accept_order']),
        vacationMode: asBool(json['vacation_mode']),
        defaultCurrency: asString(json['default_currency'], fallback: 'IDR'),
        operationalHours: asMapOrNull(asDecodedJson(json['operational_hours'])),
        returnPolicy: asMapOrNull(asDecodedJson(json['return_policy'])),
        shippingOrigin: asMapOrNull(asDecodedJson(json['shipping_origin'])),
        contactPhone: asStringOrNull(json['contact_phone']),
        contactWhatsapp: asStringOrNull(json['contact_whatsapp']),
      );
}

/// The shape this app writes into `store_settings.operational_hours`.
///
/// The server stores whatever JSON it is sent and defines no format, and the
/// Partners Performance payload echoes it back as-is — so the app fixes one:
/// `{"open": "08:00", "close": "22:00", "days": ["mon", ...]}`.
class OperationalHours {
  const OperationalHours({
    this.open = '08:00',
    this.close = '21:00',
    this.days = const <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
  });

  static const List<String> week = <String>[
    'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
  ];

  static String dayLabel(String d) => switch (d) {
        'mon' => 'Sen',
        'tue' => 'Sel',
        'wed' => 'Rab',
        'thu' => 'Kam',
        'fri' => 'Jum',
        'sat' => 'Sab',
        'sun' => 'Min',
        _ => d,
      };

  final String open;
  final String close;
  final List<String> days;

  /// Null when nothing is set or the stored value is some other shape.
  static OperationalHours? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final open = json['open'];
    final close = json['close'];
    if (open is! String || close is! String) return null;
    final days = json['days'];
    return OperationalHours(
      open: open,
      close: close,
      days: days is List
          ? days.whereType<String>().where(week.contains).toList()
          : week,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'open': open,
        'close': close,
        'days': <String>[for (final d in week) if (days.contains(d)) d],
      };

  OperationalHours copyWith({String? open, String? close, List<String>? days}) =>
      OperationalHours(
        open: open ?? this.open,
        close: close ?? this.close,
        days: days ?? this.days,
      );
}
