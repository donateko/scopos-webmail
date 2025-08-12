import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:server_settings/server_settings/converter/boolean_nullable_converter.dart';
import 'package:server_settings/server_settings/converter/server_settings_id_nullable_converter.dart';
import 'package:server_settings/server_settings/server_settings.dart';
import 'package:server_settings/server_settings/server_settings_id.dart';

part 'tmail_server_settings.g.dart';

@JsonSerializable(
  explicitToJson: true, 
  includeIfNull: false, 
  converters: [ServerSettingsIdNullableConverter()])
class TMailServerSettings extends ServerSettings {
  final ServerSettingsId? id;
  final TMailServerSettingOptions? settings;
  TMailServerSettings({this.id, this.settings});

  factory TMailServerSettings.fromJson(Map<String, dynamic> json) =>
    _$TMailServerSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$TMailServerSettingsToJson(this);

  @override
  List<Object?> get props => [id, settings];
}

@JsonSerializable(
  explicitToJson: true, 
  includeIfNull: false,
  converters: [BooleanNullableConverter()]
)
class TMailServerSettingOptions with EquatableMixin {
  @JsonKey(name: 'read.receipts.always')
  final bool? alwaysReadReceipts;

  @JsonKey(name: 'display.sender.priority')
  final bool? displaySenderPriority;

  @JsonKey(name: 'language')
  final String? language;

  // Map of mailboxId -> hex color string (e.g., #FF0000) to sync label colors across devices
  @JsonKey(name: 'labels.colors')
  final Map<String, String>? labelColors;

  TMailServerSettingOptions({
    this.alwaysReadReceipts,
    this.displaySenderPriority,
    this.language,
    this.labelColors,
  });

  factory TMailServerSettingOptions.fromJson(Map<String, dynamic> json) =>
    _$TMailServerSettingOptionsFromJson(json);

  Map<String, dynamic> toJson() => _$TMailServerSettingOptionsToJson(this);

  TMailServerSettingOptions copyWith({
    bool? alwaysReadReceipts,
    bool? displaySenderPriority,
    String? language,
    Map<String, String>? labelColors,
  }) {
    return TMailServerSettingOptions(
      alwaysReadReceipts: alwaysReadReceipts ?? this.alwaysReadReceipts,
      displaySenderPriority: displaySenderPriority ?? this.displaySenderPriority,
      language: language ?? this.language,
      labelColors: labelColors ?? this.labelColors,
    );
  }

  @override
  List<Object?> get props => [
    alwaysReadReceipts,
    displaySenderPriority,
    language,
    labelColors,
  ];
}
