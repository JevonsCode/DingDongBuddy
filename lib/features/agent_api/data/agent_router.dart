// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/utils/uuid.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/agent_compatibility_routes.dart';
import 'package:dingdong/features/agent_api/data/agent_state_routes.dart';
import 'package:dingdong/features/agent_api/data/clipboard_collection_routes.dart';
import 'package:dingdong/features/agent_api/data/clipboard_routes.dart';
import 'package:dingdong/features/agent_api/data/clipboard_workflow_routes.dart';
import 'package:dingdong/features/agent_api/data/desktop_control_routes.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/agent_api/data/library_routes.dart';
import 'package:dingdong/features/agent_api/data/resource_query_utils.dart';
import 'package:dingdong/features/agent_api/data/trigger_group_routes.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

part 'agent_router_resource_handlers.dart';

/// Routes DingDong's stable loopback API without depending on socket IO.
final class AgentRouter {
  AgentRouter({
    void Function(DingRequest request)? onDing,
    void Function(DingRequest request)? onSuppressedDing,
    ClipboardCaptureService? clipboardCaptureService,
    ClipboardGateway? clipboardGateway,
    ClipboardStore? clipboardStore,
    ResourceStore? resourceStore,
    TriggerGroupStore? triggerGroupStore,
    SkillPackageInstaller? skillPackageInstaller,
    String Function()? idGenerator,
    DateTime Function()? now,
    void Function(bool value)? onClipboardMonitoring,
    void Function(int index)? onShowUi,
  }) : _onDing = onDing ?? _ignoreDing,
       _onSuppressedDing = onSuppressedDing ?? _ignoreDing,
       _clipboardCaptureService = clipboardCaptureService,
       _clipboardGateway = clipboardGateway,
       _clipboardRoutes = clipboardStore == null
           ? null
           : ClipboardRoutes(clipboardStore, now: now),
       _clipboardWorkflowRoutes = clipboardStore == null
           ? null
           : ClipboardWorkflowRoutes(
               store: clipboardStore,
               gateway: clipboardGateway,
               resourceStore: resourceStore,
               idGenerator: idGenerator,
               now: now,
             ),
       _libraryRoutes = resourceStore == null
           ? null
           : LibraryRoutes(
               resourceStore,
               triggerGroupStore: triggerGroupStore,
               skillPackageInstaller: skillPackageInstaller,
               now: now,
               idGenerator: idGenerator,
             ),
       _triggerGroupRoutes = triggerGroupStore == null
           ? null
           : TriggerGroupRoutes(
               store: triggerGroupStore,
               resourceStore: resourceStore,
               idGenerator: idGenerator ?? generateUuid,
               now: now ?? DateTime.now,
             ),
       _agentCompatibilityRoutes = resourceStore == null
           ? null
           : AgentCompatibilityRoutes(
               resourceStore: resourceStore,
               clipboardStore: clipboardStore,
               triggerGroupStore: triggerGroupStore,
               now: now,
             ),
       _agentStateRoutes = resourceStore == null
           ? null
           : AgentStateRoutes(
               resourceStore: resourceStore,
               idGenerator: idGenerator ?? generateUuid,
               now: now ?? DateTime.now,
             ),
       _clipboardCollectionRoutes =
           clipboardStore == null || resourceStore == null
           ? null
           : ClipboardCollectionRoutes(
               clipboardStore: clipboardStore,
               resourceStore: resourceStore,
               idGenerator: idGenerator ?? generateUuid,
               now: now ?? DateTime.now,
             ),
       _desktopControlRoutes = DesktopControlRoutes(
         onClipboardMonitoring: onClipboardMonitoring,
         onShowUi: onShowUi,
       ),
       _resourceStore = resourceStore,
       _triggerGroupStore = triggerGroupStore,
       _idGenerator = idGenerator ?? generateUuid,
       _now = now ?? DateTime.now;

  final void Function(DingRequest request) _onDing;
  final void Function(DingRequest request) _onSuppressedDing;
  final ClipboardCaptureService? _clipboardCaptureService;
  final ClipboardGateway? _clipboardGateway;
  final ClipboardRoutes? _clipboardRoutes;
  final ClipboardWorkflowRoutes? _clipboardWorkflowRoutes;
  final LibraryRoutes? _libraryRoutes;
  final TriggerGroupRoutes? _triggerGroupRoutes;
  final AgentCompatibilityRoutes? _agentCompatibilityRoutes;
  final AgentStateRoutes? _agentStateRoutes;
  final ClipboardCollectionRoutes? _clipboardCollectionRoutes;
  final DesktopControlRoutes _desktopControlRoutes;
  final ResourceStore? _resourceStore;
  final TriggerGroupStore? _triggerGroupStore;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  DateTime? _lastDingAt;
  String? _lastDingSource;

  static const Duration _completionHookDeduplicationWindow = Duration(
    seconds: 5,
  );

  void updateBaseUri(Uri value) {
    _agentCompatibilityRoutes?.updateBaseUri(value);
  }

  Future<HttpResponseData> route(HttpRequestData request) async {
    final HttpResponseData? desktopResponse = _desktopControlRoutes.route(
      method: request.method,
      path: request.parsedUri.path,
      query: request.parsedUri.queryParameters,
      body: request.body,
    );
    if (desktopResponse != null) {
      return desktopResponse;
    }
    if (request.method == 'POST' &&
        request.parsedUri.path == '/clipboard/collect') {
      final ClipboardCollectionRoutes? routes = _clipboardCollectionRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.collect(request.body);
    }
    final HttpResponseData? stateResponse = await _agentStateRoutes?.route(
      method: request.method,
      path: request.parsedUri.path,
      query: request.parsedUri.queryParameters,
      body: request.body,
    );
    if (stateResponse != null) {
      return stateResponse;
    }
    if (request.method == 'GET') {
      final HttpResponseData? compatibility = await _agentCompatibilityRoutes
          ?.get(request.parsedUri.path, request.parsedUri.queryParameters);
      if (compatibility != null) {
        return compatibility;
      }
    }
    if (request.method == 'GET' && request.parsedUri.path == '/health') {
      return const HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{'status': 'ok', 'service': 'DingDong'},
      );
    }
    if ((request.method == 'GET' || request.method == 'POST') &&
        request.parsedUri.path == '/ding') {
      try {
        final DingRequest dingRequest = DingRequest.parse(request.body);
        final DateTime now = _now();
        final DateTime? lastDingAt = _lastDingAt;
        if (dingRequest.fallback &&
            lastDingAt != null &&
            dingRequest.source == _lastDingSource &&
            now.difference(lastDingAt) < _completionHookDeduplicationWindow) {
          _onSuppressedDing(dingRequest);
          return HttpResponseData(
            statusCode: 200,
            json: <String, Object?>{
              'status': 'suppressed',
              'message': dingRequest.message,
            },
          );
        }
        _lastDingAt = now;
        _lastDingSource = dingRequest.source;
        _onDing(dingRequest);
        return HttpResponseData(
          statusCode: 200,
          json: <String, Object?>{
            'status': 'triggered',
            'message': dingRequest.message,
          },
        );
      } on Object {
        return const HttpResponseData(
          statusCode: 400,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Invalid JSON body',
          },
        );
      }
    }
    if (request.method == 'POST' && request.parsedUri.path == '/library') {
      return _createResource(request.body);
    }
    if (request.method == 'POST' &&
        request.parsedUri.path == '/library/skills/install') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.installSkill(request.body);
    }
    if (request.method == 'POST' && request.parsedUri.path == '/agent/bridge') {
      final ResourceStore? store = _resourceStore;
      if (store == null) {
        return _resourceUnavailable();
      }
      return AgentBridge(
        store,
        triggerGroupStore: _triggerGroupStore,
        now: _now,
      ).respond(request.body);
    }
    if (request.method == 'GET' && request.parsedUri.path == '/library') {
      return _listResources(request.parsedUri.queryParameters);
    }
    if (request.parsedUri.path == '/library/trigger-groups') {
      final TriggerGroupRoutes? routes = _triggerGroupRoutes;
      if (routes == null) {
        return _resourceUnavailable();
      }
      if (request.method == 'GET') {
        return routes.list();
      }
      if (request.method == 'POST') {
        return routes.create(request.body);
      }
    }
    if (request.method == 'POST' &&
        request.parsedUri.path == '/library/trigger-groups/upsert') {
      final TriggerGroupRoutes? routes = _triggerGroupRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.upsert(request.body);
    }
    if (request.method == 'POST' &&
        request.parsedUri.pathSegments.length == 3 &&
        request.parsedUri.pathSegments[0] == 'library' &&
        request.parsedUri.pathSegments[2] == 'scope') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.bindScope(request.parsedUri.pathSegments[1], request.body);
    }
    if ((request.method == 'PATCH' || request.method == 'DELETE') &&
        request.parsedUri.pathSegments.length == 3 &&
        request.parsedUri.pathSegments[0] == 'library' &&
        request.parsedUri.pathSegments[1] == 'trigger-groups') {
      final TriggerGroupRoutes? routes = _triggerGroupRoutes;
      if (routes == null) {
        return _resourceUnavailable();
      }
      final String id = request.parsedUri.pathSegments[2];
      return request.method == 'PATCH'
          ? routes.update(id, request.body)
          : routes.delete(id);
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/library/groups') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.groups(request.parsedUri.queryParameters);
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/library/export') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.export(request.parsedUri.queryParameters);
    }
    if (request.method == 'POST' &&
        request.parsedUri.path == '/library/import') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.importResources(request.body);
    }
    if (request.method == 'POST' &&
        request.parsedUri.path == '/library/seed-defaults') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null ? _resourceUnavailable() : routes.seedDefaults();
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/knowledge/index') {
      final LibraryRoutes? routes = _libraryRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.knowledgeIndex(request.parsedUri.queryParameters);
    }
    if ((request.method == 'PATCH' || request.method == 'DELETE') &&
        request.parsedUri.pathSegments.length == 2 &&
        request.parsedUri.pathSegments.first == 'library') {
      final LibraryRoutes? routes = _libraryRoutes;
      if (routes == null) {
        return _resourceUnavailable();
      }
      final String id = request.parsedUri.pathSegments.last;
      return request.method == 'PATCH'
          ? routes.update(id, request.body)
          : routes.delete(id);
    }
    if (request.method == 'GET' &&
        request.parsedUri.pathSegments.length == 2 &&
        request.parsedUri.pathSegments.first == 'library') {
      return _getResource(
        request.parsedUri.pathSegments.last,
        request.parsedUri.queryParameters,
      );
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/clipboard/history') {
      final ClipboardRoutes? routes = _clipboardRoutes;
      if (routes == null) {
        return _resourceUnavailable();
      }
      return routes.history(request.parsedUri.queryParameters);
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/clipboard/overview') {
      final ClipboardRoutes? routes = _clipboardRoutes;
      return routes == null ? _resourceUnavailable() : routes.overview();
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/clipboard/groups') {
      final ClipboardRoutes? routes = _clipboardRoutes;
      return routes == null ? _resourceUnavailable() : routes.groups();
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/clipboard/snippets') {
      final ClipboardWorkflowRoutes? routes = _clipboardWorkflowRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.snippets(request.parsedUri.queryParameters);
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/clipboard/digest') {
      final ClipboardWorkflowRoutes? routes = _clipboardWorkflowRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.digest(request.parsedUri.queryParameters);
    }
    if (request.method == 'GET' &&
        request.parsedUri.path == '/clipboard/insights') {
      final ClipboardWorkflowRoutes? routes = _clipboardWorkflowRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.insights(request.parsedUri.queryParameters);
    }
    if (request.method == 'POST' &&
        request.parsedUri.pathSegments.length == 4 &&
        request.parsedUri.pathSegments[0] == 'clipboard' &&
        request.parsedUri.pathSegments[1] == 'snippet' &&
        request.parsedUri.pathSegments[3] == 'restore') {
      final ClipboardWorkflowRoutes? routes = _clipboardWorkflowRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.restoreSnippet(
              request.parsedUri.pathSegments[2],
              request.parsedUri.queryParameters,
            );
    }
    if (request.method == 'POST' &&
        request.parsedUri.pathSegments.length == 3 &&
        request.parsedUri.pathSegments[0] == 'clipboard' &&
        request.parsedUri.pathSegments[1] == 'promote') {
      final ClipboardWorkflowRoutes? routes = _clipboardWorkflowRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.promote(request.parsedUri.pathSegments[2], request.body);
    }
    if (request.method == 'PATCH' &&
        request.parsedUri.pathSegments.length == 2 &&
        request.parsedUri.pathSegments.first == 'clipboard') {
      final ClipboardRoutes? routes = _clipboardRoutes;
      return routes == null
          ? _resourceUnavailable()
          : routes.update(request.parsedUri.pathSegments.last, request.body);
    }
    if (request.method == 'POST' &&
        request.parsedUri.path == '/clipboard/capture') {
      final ClipboardCaptureService? service = _clipboardCaptureService;
      if (service == null) {
        return const HttpResponseData(
          statusCode: 503,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Clipboard capture is not available',
          },
        );
      }
      final ClipboardRecord? captured = await service.capture();
      if (captured == null) {
        return const HttpResponseData(
          statusCode: 204,
          json: <String, Object?>{
            'status': 'empty',
            'message': 'Clipboard has no text',
          },
        );
      }
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{
          'status': 'captured',
          'item': captured.toResourceApiJson(),
        },
      );
    }
    if (request.method == 'POST' &&
        request.parsedUri.path.startsWith('/clipboard/restore/')) {
      final ClipboardRoutes? routes = _clipboardRoutes;
      if (routes == null) {
        return _resourceUnavailable();
      }
      final ClipboardRecord? record = routes.findById(
        request.parsedUri.pathSegments.last,
      );
      if (record == null) {
        return const HttpResponseData(
          statusCode: 404,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Clipboard record not found',
          },
        );
      }
      final ClipboardGateway? gateway = _clipboardGateway;
      if (gateway == null) {
        return const HttpResponseData(
          statusCode: 500,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Could not restore clipboard',
          },
        );
      }
      if (record.tags.contains('file-url')) {
        final List<String> paths = record.content
            .split('\n')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
        if (paths.isNotEmpty) {
          await gateway.writeFiles(paths);
        } else {
          await gateway.writeText(record.content);
        }
      } else {
        await gateway.writeText(record.content);
      }
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'restored',
          'id': record.id,
          'title': record.title,
          'contentCharacterCount': record.content.length,
        },
      );
    }
    return const HttpResponseData(
      statusCode: 404,
      json: <String, Object?>{'status': 'error', 'message': 'Route not found'},
    );
  }
}

void _ignoreDing(DingRequest request) {}

HttpResponseData _resourceUnavailable() {
  return const HttpResponseData(
    statusCode: 503,
    json: <String, Object?>{
      'status': 'error',
      'message': 'Resource library is not available',
    },
  );
}

HttpResponseData _invalidResourceType() {
  return const HttpResponseData(
    statusCode: 400,
    json: <String, Object?>{
      'status': 'error',
      'message': 'Invalid resource type',
    },
  );
}
