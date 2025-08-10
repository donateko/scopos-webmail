
import 'dart:async';

import 'package:core/presentation/extensions/uri_extension.dart';
import 'package:core/utils/app_logger.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/extensions/session_extension.dart';
import 'package:tmail_ui_user/features/push_notification/data/datasource/web_socket_datasource.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/web_socket_api.dart';
import 'package:tmail_ui_user/main/error/capability_validator.dart';
import 'package:tmail_ui_user/main/exceptions/exception_thrower.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/html.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/login/data/local/account_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/local/token_oidc_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:model/oidc/token_oidc.dart';

class WebSocketDatasourceImpl implements WebSocketDatasource {
  final WebSocketApi _webSocketApi;
  final ExceptionThrower _exceptionThrower;
  
  const WebSocketDatasourceImpl(this._webSocketApi, this._exceptionThrower);

  @override
  Future<WebSocketChannel> getWebSocketChannel(Session session, AccountId accountId) {
    return Future.sync(() async {
      _verifyWebSocketCapabilities(session, accountId);

      final bool ticketSupported = CapabilityIdentifier.jmapWebSocketTicket.isSupported(session, accountId);

      // Determine target WebSocket URI
      // Prefer capability URL; for Stalwart (no ticket) strip explicit :443 if present
      final wsCapUrl = session
          .getCapabilityProperties<WebSocketCapability>(accountId, CapabilityIdentifier.jmapWebSocket)
          ?.url;
      Uri targetWsUri;
      if (wsCapUrl != null) {
        targetWsUri = wsCapUrl.ensureWebSocketUri();
        if (!ticketSupported && targetWsUri.scheme == 'wss' && targetWsUri.hasPort && targetWsUri.port == 443) {
          targetWsUri = _stripDefaultPort443(targetWsUri);
        }
      } else {
        targetWsUri = Uri(scheme: 'wss', host: session.apiUrl.host);
      }
      log('WebSocketDatasourceImpl::getWebSocketChannel: targetWsUri = $targetWsUri | ticketSupported = $ticketSupported');

      // Append ticket (James/TMail) or access_token (Stalwart) as needed
      Uri uriToConnect;
      if (ticketSupported) {
        uriToConnect = targetWsUri.replace(queryParameters: {
          ...targetWsUri.queryParameters,
          'ticket': await _webSocketApi.getWebSocketTicket(session, accountId),
        });
      } else {
        // Attempt to include access_token for Stalwart
        try {
          final accountCacheManager = Get.find<AccountCacheManager>();
          final tokenCacheManager = Get.find<TokenOidcCacheManager>();
          final currentAccount = await accountCacheManager.getCurrentAccount();
          var token = await tokenCacheManager.getTokenOidc(currentAccount.id);
          // Refresh if expired
          if (token.isExpired) {
            final auth = Get.find<AuthorizationInterceptors>();
            if (auth.oidcConfig != null && token.refreshToken.isNotEmpty) {
              // Reuse interceptor's refresh flow via its public error path would be heavy; call internal safely
              // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
              final refreshed = await auth.invokeRefreshTokenForWebSocket();
              if (refreshed != null) {
                token = refreshed;
                await tokenCacheManager.persistOneTokenOidc(refreshed);
              }
            }
          }
          // On web, pass access_token in query. On native, we'll also pass in query for compatibility
          uriToConnect = targetWsUri.replace(queryParameters: {
            ...targetWsUri.queryParameters,
            'access_token': token.token,
          });
        } catch (_) {
          uriToConnect = targetWsUri;
        }
      }

      log('WebSocketDatasourceImpl::getWebSocketChannel: uriToConnect = $uriToConnect');
      // Use concrete channels for platform-specific header/query auth handling
      late final WebSocketChannel webSocketChannel;
      if (ticketSupported) {
        if (kIsWeb) {
          webSocketChannel = HtmlWebSocketChannel.connect(uriToConnect, protocols: const ['jmap']);
        } else {
          webSocketChannel = IOWebSocketChannel.connect(uriToConnect, protocols: const ['jmap']);
        }
      } else {
        if (kIsWeb) {
          // Stalwart expects access_token in query on web
          webSocketChannel = HtmlWebSocketChannel.connect(uriToConnect, protocols: const ['jmap']);
        } else {
          // Native can use Authorization header
          final authToken = await _getAuthorizationToken(session);
          if (authToken != null && authToken.isNotEmpty) {
            webSocketChannel = IOWebSocketChannel.connect(
              uriToConnect,
              headers: {'Authorization': 'Bearer $authToken'},
              protocols: const ['jmap'],
            );
          } else {
            webSocketChannel = IOWebSocketChannel.connect(uriToConnect, protocols: const ['jmap']);
          }
        }
      }

      await webSocketChannel.ready;

      return webSocketChannel;
    }).catchError(_exceptionThrower.throwException);
  }

  void _verifyWebSocketCapabilities(Session session, AccountId accountId) {
    // For Stalwart we allow fallback even if ticket capability is missing.
    // Do not throw here; just log and continue with best-effort connection.
    final wsCap = session.getCapabilityProperties<WebSocketCapability>(
      accountId,
      CapabilityIdentifier.jmapWebSocket,
    );
    log('WebSocketDatasourceImpl::_verifyWebSocketCapabilities: ws capability = ${wsCap?.toJson()}');
  }

  // Note: method removed; URL is derived inline for simplicity.
  Uri _stripDefaultPort443(Uri url) {
    // Manually rebuild without port
    return Uri.parse('wss://${url.host}${url.path.isNotEmpty ? url.path : ''}');
  }
  Future<String?> _getAuthorizationToken(Session session) async {
    try {
      final accountCacheManager = Get.find<AccountCacheManager>();
      final tokenCacheManager = Get.find<TokenOidcCacheManager>();
      final currentAccount = await accountCacheManager.getCurrentAccount();
      var token = await tokenCacheManager.getTokenOidc(currentAccount.id);
      if (token.isExpired) {
        final auth = Get.find<AuthorizationInterceptors>();
        final refreshed = await auth.invokeRefreshTokenForWebSocket();
        if (refreshed != null) {
          await tokenCacheManager.persistOneTokenOidc(refreshed);
          token = refreshed;
        }
      }
      return token.token;
    } catch (e) {
      logError('WebSocketDatasourceImpl::_getAuthorizationToken: $e');
      return null;
    }
  }
}