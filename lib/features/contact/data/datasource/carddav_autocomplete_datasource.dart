import 'package:core/utils/app_logger.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/autocomplete/auto_complete_pattern.dart';
import 'package:tmail_ui_user/features/contact/data/datasource/auto_complete_datasource.dart';
import 'package:tmail_ui_user/features/contact/data/network/carddav_api.dart';

class CardDavAutoCompleteDataSource implements AutoCompleteDataSource {
  final CardDavApi _cardDavApi;
  final Session _session;

  CardDavAutoCompleteDataSource(this._cardDavApi, this._session);

  @override
  Future<List<EmailAddress>> getAutoComplete(AutoCompletePattern autoCompletePattern) async {
    if (autoCompletePattern.word.trim().isEmpty) return [];
    final list = await _cardDavApi.listContacts(_session);
    final q = autoCompletePattern.word.toLowerCase();
    final results = list
      .where((c) =>
        (c.fullName?.toLowerCase().contains(q) == true) ||
        c.emails.any((e) => e.toLowerCase().contains(q)))
      .expand((c) {
        final display = c.fullName?.isNotEmpty == true ? c.fullName! : (c.emails.isNotEmpty ? c.emails.first : '');
        return c.emails.map((email) => EmailAddress(display, email));
      })
      .toList();
    log('CardDavAutoCompleteDataSource::listContacts: total=${list.length} | matched=${results.length} | query="$q"');
    return results;
  }
}


