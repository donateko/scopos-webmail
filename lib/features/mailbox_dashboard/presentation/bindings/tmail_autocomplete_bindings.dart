
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/base/interactors_bindings.dart';
import 'package:tmail_ui_user/features/composer/data/repository/auto_complete_repository_impl.dart';
import 'package:tmail_ui_user/features/composer/domain/repository/auto_complete_repository.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_autocomplete_interactor.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_all_autocomplete_interactor.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_device_contact_suggestions_interactor.dart';
import 'package:tmail_ui_user/features/contact/data/datasource_impl/tmail_contact_datasource_impl.dart';
import 'package:tmail_ui_user/features/contact/data/network/contact_api.dart';
import 'package:tmail_ui_user/main/exceptions/remote_exception_thrower.dart';
import 'package:tmail_ui_user/features/contact/data/datasource/carddav_autocomplete_datasource.dart';
import 'package:tmail_ui_user/features/contact/data/network/carddav_api.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/features/contact/data/datasource/auto_complete_datasource.dart';

class TMailAutoCompleteBindings extends InteractorsBindings {

  @override
  void bindingsDataSourceImpl() {
    Get.put(TMailContactDataSourceImpl(
      Get.find<ContactAPI>(),
      Get.find<RemoteExceptionThrower>(),
    ));
  }

  @override
  void bindingsInteractor() {
    Get.put(GetAutoCompleteInteractor(Get.find<AutoCompleteRepository>()));
    Get.put(GetAllAutoCompleteInteractor(
      Get.find<GetAutoCompleteInteractor>(),
      Get.find<GetDeviceContactSuggestionsInteractor>()
    ));
  }

  @override
  void bindingsRepository() {
    Get.put<AutoCompleteRepository>(Get.find<AutoCompleteRepositoryImpl>());
  }

  @override
  void bindingsRepositoryImpl() {
    final Session? session = Get.isRegistered<Session>() ? Get.find<Session>() : null;
    final sources = <AutoCompleteDataSource>{Get.find<TMailContactDataSourceImpl>()};
    if (session != null) {
      sources.add(CardDavAutoCompleteDataSource(Get.find<CardDavApi>(), session));
    }
    Get.put(AutoCompleteRepositoryImpl(sources));
  }

  @override
  void bindingsDataSource() {}
}