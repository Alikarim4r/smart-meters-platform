import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../billing/billing_logic.dart';
import '../billing/billing_repository.dart';
import '../billing/play_billing_store.dart';
import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';

/// Organization subscription & Google Play billing.
///
/// Everything shown as "current plan" comes from the server. Store purchase
/// updates only trigger server verification; the entitlement card changes
/// only after the server confirms and the entitlement is re-read.
class SubscriptionBillingScreen extends ConsumerStatefulWidget {
  const SubscriptionBillingScreen({super.key});

  @override
  ConsumerState<SubscriptionBillingScreen> createState() =>
      _SubscriptionBillingScreenState();
}

enum _MessageKind { info, success, error }

class _SubscriptionBillingScreenState
    extends ConsumerState<SubscriptionBillingScreen> {
  final PlayBillingStore _store = PlayBillingStore();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  String? _orgId;
  bool _loading = true;
  bool _loadFailed = false;
  OrgBillingState? _state;
  BillingCatalogResult? _catalog;
  List<BillingOption> _options = const [];
  bool _storeAvailable = false;
  bool _busy = false;
  String? _message;
  _MessageKind _messageKind = _MessageKind.info;

  AdminStrings get _s => AdminStrings(ref.read(adminLocaleProvider));

  @override
  void initState() {
    super.initState();
    if (PlayBillingStore.isSupportedPlatform) {
      // Subscribe early: Play redelivers unfinished purchases on startup.
      _purchaseSub = _store.purchaseUpdates.listen(
        _onPurchaseUpdates,
        onError: (Object _) =>
            _setMessage(_s.purchaseStoreError, _MessageKind.error),
      );
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _load(String orgId) async {
    setState(() {
      _orgId = orgId;
      _loading = true;
      _loadFailed = false;
    });
    final repo = ref.read(googlePlayBillingRepositoryProvider);
    try {
      final results = await Future.wait<Object>([
        repo.loadState(orgId),
        repo.loadCatalog(orgId),
        _store.isAvailable(),
      ]);
      final state = results[0] as OrgBillingState;
      final catalog = results[1] as BillingCatalogResult;
      final available = results[2] as bool;
      var options = const <BillingOption>[];
      if (available && !catalog.forbidden && catalog.entries.isNotEmpty) {
        final offers = await _store.queryOffers(
          catalog.entries.map((e) => e.productId).toSet(),
        );
        options = matchBillingOptions(catalog.entries, offers);
      }
      if (!mounted || _orgId != orgId) return;
      setState(() {
        _state = state;
        _catalog = catalog;
        _storeAvailable = available;
        _options = options;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _orgId != orgId) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Re-reads the server entitlement only (after a verification).
  Future<void> _refreshEntitlement() async {
    final orgId = _orgId;
    if (orgId == null) return;
    try {
      final state = await ref
          .read(googlePlayBillingRepositoryProvider)
          .loadState(orgId);
      if (mounted && _orgId == orgId) setState(() => _state = state);
    } catch (_) {
      // Keep the last server state; a manual refresh retries.
    }
  }

  void _setMessage(String message, _MessageKind kind) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageKind = kind;
    });
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    final binding = _catalog?.entries.firstOrNull?.accountBinding;
    for (final purchase in purchases) {
      final action = actionForStoreUpdate(
        PlayBillingStore.statusOf(purchase),
        purchaseAccountId: PlayBillingStore.accountIdOf(purchase),
        expectedAccountBinding: binding,
      );
      switch (action) {
        case StoreUpdateAction.showPending:
          _setMessage(_s.purchasePending, _MessageKind.info);
        case StoreUpdateAction.ignore:
          if (mounted) setState(() => _busy = false);
        case StoreUpdateAction.showStoreError:
          if (mounted) setState(() => _busy = false);
          _setMessage(_s.purchaseStoreError, _MessageKind.error);
        case StoreUpdateAction.verifyWithServer:
          await _verify(purchase);
      }
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final orgId = _orgId;
    if (orgId == null) return;
    setState(() => _busy = true);
    _setMessage(_s.verifyingPurchase, _MessageKind.info);

    BillingVerificationResult result;
    try {
      result = await ref
          .read(googlePlayBillingRepositoryProvider)
          .verify(
            organizationId: orgId,
            purchaseToken: PlayBillingStore.purchaseTokenOf(purchase),
            productId: purchase.productID,
          );
    } catch (_) {
      // Unverified: never complete/acknowledge; restore retries later.
      if (mounted) setState(() => _busy = false);
      _setMessage(_s.purchaseVerifyFailedRetry, _MessageKind.error);
      return;
    }

    if (shouldCompletePurchase(
      pendingCompletePurchase: purchase.pendingCompletePurchase,
      server: result,
    )) {
      try {
        await _store.complete(purchase);
      } catch (_) {
        // Play redelivers the purchase; the next verify retries.
      }
    }

    await _refreshEntitlement();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.applied && result.hasAccess) {
      _setMessage(_s.purchaseVerified, _MessageKind.success);
    } else if (result.outcome == 'recorded' || result.applied) {
      _setMessage(_s.purchaseRecordedNoAccess, _MessageKind.info);
    } else if (result.outcome == 'conflict') {
      _setMessage(_s.purchaseConflict, _MessageKind.error);
    } else {
      _setMessage(
        '${_s.purchaseNotVerified}${result.reason == null ? '' : ' (${result.reason})'}',
        _MessageKind.error,
      );
    }
  }

  Future<void> _buy(BillingOption option) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final launched = await _store.buy(option);
      if (!launched && mounted) {
        setState(() => _busy = false);
        _setMessage(_s.purchaseStoreError, _MessageKind.error);
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _setMessage(_s.purchaseStoreError, _MessageKind.error);
    }
  }

  Future<void> _restore() async {
    setState(() => _message = null);
    try {
      await _store.restore();
    } catch (_) {
      _setMessage(_s.purchaseStoreError, _MessageKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final orgsAsync = ref.watch(adminOrganizationsProvider);

    return orgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(s.billingLoadFailed)),
      data: (organizations) {
        if (organizations.isEmpty) {
          return Center(child: Text(s.noOrganizationAvailable));
        }
        final orgId = _orgId ?? organizations.first.id;
        if (_orgId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _orgId == null) _load(orgId);
          });
        }
        return RefreshIndicator(
          onRefresh: () => _load(orgId),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              DropdownButtonFormField<String>(
                initialValue: orgId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: s.organization,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final org in organizations)
                    DropdownMenuItem(
                      value: org.id,
                      child: Text(
                        org.nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null || value == _orgId) return;
                        setState(() {
                          _message = null;
                          _options = const [];
                        });
                        _load(value);
                      },
              ),
              const SizedBox(height: 16),
              if (_message != null) ...[
                _MessageBanner(message: _message!, kind: _messageKind),
                const SizedBox(height: 12),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadFailed)
                _InfoCard(
                  icon: Icons.error_outline,
                  text: s.billingLoadFailed,
                  action: TextButton(
                    onPressed: () => _load(orgId),
                    child: Text(s.retry),
                  ),
                )
              else ...[
                _EntitlementCard(state: _state, strings: s),
                const SizedBox(height: 20),
                ..._planSection(s),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _planSection(AdminStrings s) {
    final theme = Theme.of(context);
    final catalog = _catalog;
    final subscription = _state?.subscription;
    final canBuy = canStartPurchase(
      storeAvailable: _storeAvailable,
      canManageBilling: catalog != null && !catalog.forbidden,
      optionCount: _options.length,
      provider: _state?.provider,
      hasAccess: subscription?.hasAccess ?? false,
    );

    final header = Text(
      s.availablePlans,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    if (!PlayBillingStore.isSupportedPlatform) {
      return [
        header,
        const SizedBox(height: 8),
        _InfoCard(icon: Icons.android, text: s.billingAndroidOnly),
      ];
    }
    if (catalog == null || catalog.forbidden) {
      return [
        header,
        const SizedBox(height: 8),
        _InfoCard(icon: Icons.lock_outline, text: s.billingForbidden),
      ];
    }
    if (!_storeAvailable) {
      return [
        header,
        const SizedBox(height: 8),
        _InfoCard(icon: Icons.store_outlined, text: s.billingStoreUnavailable),
      ];
    }

    final restore = Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: _busy ? null : _restore,
        icon: const Icon(Icons.restore),
        label: Text(s.restorePurchases),
      ),
    );

    if (_options.isEmpty) {
      return [
        header,
        const SizedBox(height: 8),
        _InfoCard(
          icon: Icons.inventory_2_outlined,
          text: s.billingNotConfigured,
        ),
        restore,
      ];
    }

    final locked = !canBuy;
    return [
      header,
      const SizedBox(height: 8),
      if (locked && (subscription?.hasAccess ?? false))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InfoCard(
            icon: Icons.info_outline,
            text: s.billingActiveSubscriptionLocked,
          ),
        ),
      for (final option in _options)
        _OptionCard(
          option: option,
          strings: s,
          enabled: canBuy && !_busy,
          onSubscribe: () => _buy(option),
        ),
      restore,
    ];
  }
}

class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({required this.state, required this.strings});

  final OrgBillingState? state;
  final AdminStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final sub = state?.subscription;
    if (sub == null) {
      return _InfoCard(
        icon: Icons.info_outline,
        text: s.entitlementUnavailable,
      );
    }
    final usage = state!.usage;
    final loc = MaterialLocalizations.of(context);
    String date(DateTime d) => loc.formatMediumDate(d.toLocal());
    final accessColor = sub.hasAccess
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.currentPlan, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.planLabel(sub.plan.name),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(s.statusLabel(sub.status.name))),
              ],
            ),
            Row(
              children: [
                Icon(
                  sub.hasAccess ? Icons.check_circle : Icons.block,
                  size: 18,
                  color: accessColor,
                ),
                const SizedBox(width: 6),
                Text(
                  sub.hasAccess ? s.accessActive : s.accessInactive,
                  style: TextStyle(color: accessColor),
                ),
              ],
            ),
            if (sub.currentPeriodEnd != null) ...[
              const SizedBox(height: 6),
              Text(
                '${state!.cancelAtPeriodEnd || !sub.hasAccess ? s.endsOn : s.renewsOn}: '
                '${date(sub.currentPeriodEnd!)}',
              ),
            ],
            if (sub.gracePeriodEnd != null)
              Text('${s.graceEndsOn}: ${date(sub.gracePeriodEnd!)}'),
            if (state!.cancelAtPeriodEnd)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s.cancelsAtPeriodEnd,
                  style: TextStyle(color: theme.colorScheme.tertiary),
                ),
              ),
            const Divider(height: 24),
            Text(s.usage, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _UsageRow(
              label: s.planUsers,
              used: usage.activeUsers,
              max: sub.maxUsers,
            ),
            _UsageRow(
              label: s.planSites,
              used: usage.activeSites,
              max: sub.maxSites,
            ),
            _UsageRow(
              label: s.planMeters,
              used: usage.activeMeters,
              max: sub.maxMeters,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.used, required this.max});

  final String label;
  final int used;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = max <= 0 ? 1.0 : (used / max).clamp(0.0, 1.0);
    final over = max > 0 && used >= max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                max >= 1000000 ? '$used / ∞' : '$used / $max',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: over ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max >= 1000000 ? 0 : ratio,
            color: over ? theme.colorScheme.error : null,
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.strings,
    required this.enabled,
    required this.onSubscribe,
  });

  final BillingOption option;
  final AdminStrings strings;
  final bool enabled;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final entry = option.entry;
    final offer = option.offer;
    final monthly = entry.billingPeriod == BillingPeriod.monthly;
    String limit(int v) => v >= 1000000 ? '∞' : '$v';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.planLabel(entry.plan.name),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(monthly ? s.monthly : s.annual)),
              ],
            ),
            Text(
              '${offer.recurringPrice} ${monthly ? s.perMonth : s.perYear}',
              style: theme.textTheme.titleLarge,
            ),
            if (offer.hasIntro)
              Text(
                '${s.introOffer}: ${offer.introPrice}',
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
            const SizedBox(height: 6),
            Text(
              '${s.planUsers}: ${limit(entry.maxUsers)} · '
              '${s.planSites}: ${limit(entry.maxSites)} · '
              '${s.planMeters}: ${limit(entry.maxMeters)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: enabled ? onSubscribe : null,
                child: Text(s.subscribe),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(leading: Icon(icon), title: Text(text), trailing: action),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.kind});

  final String message;
  final _MessageKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (kind) {
      _MessageKind.success => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      _MessageKind.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      _MessageKind.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}
