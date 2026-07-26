import 'dart:io';

import 'package:admin_app/screens/network_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('state machine prioritizes site and loading', () {
    expect(
      networkV2StateFor(hasSite: false, loading: false, hasNetwork: false),
      NetworkV2ScreenState.noSiteSelected,
    );
    expect(
      networkV2StateFor(hasSite: true, loading: true, hasNetwork: true),
      NetworkV2ScreenState.loading,
    );
  });

  test('state machine maps version and permission errors', () {
    expect(
      networkV2StateFor(
        hasSite: true,
        loading: false,
        hasNetwork: true,
        error: const NetworkVersionConflict(expectedLockVersion: 1),
      ),
      NetworkV2ScreenState.versionConflict,
    );
    expect(
      networkV2StateFor(
        hasSite: true,
        loading: false,
        hasNetwork: true,
        error: const NetworkPermissionError(),
      ),
      NetworkV2ScreenState.permissionDenied,
    );
  });

  test('no network and no draft states', () {
    expect(
      networkV2StateFor(hasSite: true, loading: false, hasNetwork: false),
      NetworkV2ScreenState.noNetwork,
    );
    expect(
      networkV2StateFor(
        hasSite: true,
        loading: false,
        hasNetwork: true,
        error: const NetworkNoDraftError(),
      ),
      NetworkV2ScreenState.networkWithoutDraft,
    );
  });

  test('empty draft vs import available', () {
    final empty = UtilityNetworkSnapshot.fromJson({
      'network': {
        'id': 'n',
        'category_id': 'c',
        'code': 'w',
        'name_en': 'W',
        'name_ar': 'و',
      },
      'revision': {
        'id': 'r',
        'network_id': 'n',
        'status': 'draft',
        'lock_version': 1,
      },
      'nodes': [],
    });
    expect(
      networkV2StateFor(
        hasSite: true,
        loading: false,
        hasNetwork: true,
        snapshot: empty,
      ),
      NetworkV2ScreenState.emptyDraft,
    );
    expect(
      networkV2StateFor(
        hasSite: true,
        loading: false,
        hasNetwork: true,
        snapshot: empty,
        hasLegacyGraph: true,
      ),
      NetworkV2ScreenState.importAvailable,
    );
  });

  test('mode switching view vs edit', () {
    expect(networkEditorModeFor(editDraft: false), NetworkEditorMode.view);
    expect(networkEditorModeFor(editDraft: true), NetworkEditorMode.edit);
  });

  test('undo entry types cover move connect disconnect remove-from-view', () {
    const move = NetworkUndoMove(viewId: 'v', previous: []);
    const connect = NetworkUndoConnect(connectionId: 'c');
    const disconnect = NetworkUndoDisconnect(
      fromNodeId: 'a',
      fromPortId: 'p1',
      toNodeId: 'b',
      toPortId: 'p2',
      connectionKind: 'supply',
    );
    final remove = NetworkUndoRemoveFromView(
      viewId: 'v',
      placement: const UtilityViewNode(
        revisionId: 'r',
        viewId: 'v',
        nodeId: 'n',
        posX: 1,
        posY: 2,
      ),
    );
    expect(move, isA<NetworkUndoEntry>());
    expect(connect, isA<NetworkUndoEntry>());
    expect(disconnect, isA<NetworkUndoEntry>());
    expect(remove, isA<NetworkUndoEntry>());
  });

  test('v2 screen source uses primary network resolution and publish', () {
    final source = File('lib/screens/network_tab.dart').readAsStringSync();
    // Typed repository getter is required (avoids dynamic casts / TypeError).
    expect(source.contains('UtilityNetworkRepository'), isTrue);
    expect(source.contains('utilityNetworkRepositoryProvider'), isTrue);
    expect(source.contains('resolvePrimaryNetworkForSite'), isTrue);
    expect(source.contains('SiteNetworkNode'), isFalse);
    expect(source.contains('SiteNetworkEdge'), isFalse);
    expect(source.contains('siteNetworkRepositoryProvider'), isFalse);
    expect(source.contains('getGraph'), isFalse);
    expect(source.contains('finalizeLegacyCutover'), isFalse);
    expect(networkEditorAvoidsLegacyWrites(source), isTrue);
    expect(source.contains('NetworkEditorMode'), isTrue);
    expect(source.contains('editMode'), isTrue);
    expect(source.contains('publishDraft'), isTrue);
    expect(
      source.contains('networkApproveChanges') || source.contains('اعتماد'),
      isTrue,
    );
    expect(source.contains('batchMoveViewNodes'), isTrue);
  });

  test('editor never dual-writes 031 tables', () {
    final source = File('lib/screens/network_tab.dart').readAsStringSync();
    expect(networkEditorAvoidsLegacyWrites(source), isTrue);
    expect(source.contains('siteNetworkRepositoryProvider'), isFalse);
    expect(source.contains('SiteNetworkCanvas'), isFalse);
    expect(source.contains('importFromMeters'), isFalse);
    expect(source.contains('upsertNode'), isFalse);
    expect(source.contains('updateNodePosition'), isFalse);
    expect(source.contains('createEdge'), isFalse);
    expect(source.contains('deleteNode'), isFalse);
  });
}
