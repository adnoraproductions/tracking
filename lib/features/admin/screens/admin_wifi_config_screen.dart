import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wifi_config.dart';
import '../repositories/admin_repository.dart';

/// Provider for WiFi configs
final wifiConfigListProvider = FutureProvider<List<WifiConfig>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getWifiConfigs();
});

class AdminWifiConfigScreen extends ConsumerWidget {
  const AdminWifiConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(wifiConfigListProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding + AppSpacing.lg,
            left: AppSpacing.pagePaddingH,
            right: AppSpacing.pagePaddingH,
            bottom: 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text('NETWORK SETTINGS', style: AppTypography.caption.copyWith(
                color: context.colors.amber, letterSpacing: 2, fontWeight: FontWeight.w700,
              )).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 4),
              Text('WiFi Configuration', style: AppTypography.displaySmall)
                  .animate(delay: 100.ms).fadeIn().slideX(begin: -0.03),

              const SizedBox(height: AppSpacing.md),
              Text(
                'Configure which WiFi networks count as "office" for automatic attendance tracking.',
                style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary, height: 1.5),
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: AppSpacing.xxl),

              // Current WiFi Info Card
              _CurrentWifiCard().animate(delay: 300.ms).fadeIn().slideY(begin: 0.05),

              const SizedBox(height: AppSpacing.xxl),

              // Configured Networks
              Text('Configured Networks', style: AppTypography.titleMedium)
                  .animate(delay: 400.ms).fadeIn(),
              const SizedBox(height: AppSpacing.md),

              configsAsync.when(
                data: (configs) {
                  if (configs.isEmpty) {
                    return _EmptyConfigState().animate(delay: 450.ms).fadeIn();
                  }
                  return Column(
                    children: configs.asMap().entries.map((e) {
                      final i = e.key;
                      final config = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _WifiConfigCard(
                          config: config,
                          onToggle: (active) async {
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.toggleWifiConfig(config.id, active);
                            ref.invalidate(wifiConfigListProvider);
                          },
                          onDelete: () async {
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.deleteWifiConfig(config.id);
                            ref.invalidate(wifiConfigListProvider);
                          },
                        ).animate(delay: Duration(milliseconds: 450 + i * 60))
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: 0.03),
                      );
                    }).toList(),
                  );
                },
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: context.colors.brand),
                  ),
                ),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),

        // FAB
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 90,
          right: AppSpacing.pagePaddingH,
          child: _AddWifiFAB(
            onTap: () => _showAddWifiSheet(context, ref),
          ).animate(delay: 500.ms).fadeIn().scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  void _showAddWifiSheet(BuildContext context, WidgetRef ref) {
    final ssidCtrl = TextEditingController();
    final bssidCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Office');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: context.colors.glassBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    )
                  ]
                ),
                child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: context.colors.textDisabled,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Add Office WiFi', style: AppTypography.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Employees connected to this network will auto-clock in',
                        style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
                    const SizedBox(height: AppSpacing.xxl),

                    // Scan current WiFi button
                    GestureDetector(
                      onTap: () async {
                        try {
                          final info = NetworkInfo();
                          final ssid = await info.getWifiName();
                          final bssid = await info.getWifiBSSID();
                          ssidCtrl.text = ssid?.replaceAll('"', '') ?? '';
                          bssidCtrl.text = bssid ?? '';
                        } catch (_) {}
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: context.colors.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.cyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_find_rounded, color: context.colors.cyan, size: 18),
                            const SizedBox(width: 8),
                            Text('Scan Current WiFi', style: AppTypography.labelMedium.copyWith(
                              color: context.colors.cyan, fontWeight: FontWeight.w600,
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    GlassTextField(
                      controller: ssidCtrl,
                      label: 'WiFi Name (SSID)',
                      hint: 'e.g. Adnora-Office',
                      prefixIcon: Icons.wifi_rounded,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    GlassTextField(
                      controller: bssidCtrl,
                      label: 'Router MAC (BSSID) — REQUIRED',
                      hint: 'e.g. AA:BB:CC:DD:EE:FF',
                      prefixIcon: Icons.router_outlined,
                      validator: (v) => v?.isEmpty == true ? 'Required for security check' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    GlassTextField(
                      controller: labelCtrl,
                      label: 'Label',
                      hint: 'Office, Studio, etc.',
                      prefixIcon: Icons.label_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    GestureDetector(
                      onTap: () async {
                        if (!formKey.currentState!.validate()) return;
                        final repo = ref.read(adminRepositoryProvider);
                        final currentUser = ref.read(authRepositoryProvider).currentUser;
                        await repo.addWifiConfig(
                          ssid: ssidCtrl.text.trim(),
                          bssid: bssidCtrl.text.isNotEmpty ? bssidCtrl.text.trim() : null,
                          label: labelCtrl.text.isNotEmpty ? labelCtrl.text.trim() : 'Office',
                          createdBy: currentUser?.id ?? '',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(wifiConfigListProvider);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [context.colors.amber, const Color(0xFFE6A817)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: context.colors.amber.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('Add Network', style: AppTypography.labelLarge.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w700,
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ), // Form
              ), // SingleChildScrollView
            ), // Container
          ), // BackdropFilter
        ), // ClipRRect
        ), // Padding
        ),
      ), // SafeArea
    ); // showModalBottomSheet
  }
}

// ─── Current WiFi Info ────────────────────────────────────────
class _CurrentWifiCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CurrentWifiCard> createState() => _CurrentWifiCardState();
}

class _CurrentWifiCardState extends ConsumerState<_CurrentWifiCard> {
  String? _ssid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWifiInfo();
  }

  Future<void> _fetchWifiInfo() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      final name = await NetworkInfo().getWifiName();
      if (mounted) {
        setState(() {
          _ssid = name?.replaceAll('"', '');
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _ssid = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GlassCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        borderRadius: 20,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final ssid = _ssid ?? 'Not connected';
    final isConnected = _ssid != null;

    return GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: 20,
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isConnected ? context.colors.success : context.colors.error).withValues(alpha: 0.1),
                  border: Border.all(color: (isConnected ? context.colors.success : context.colors.error).withValues(alpha: 0.3)),
                ),
                child: Icon(
                  isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: isConnected ? context.colors.success : context.colors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Network', style: AppTypography.caption.copyWith(
                      color: context.colors.textTertiary, letterSpacing: 1, fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 4),
                    Text(ssid, style: AppTypography.titleMedium),
                  ],
                ),
              ),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? context.colors.success : context.colors.error,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? context.colors.success : context.colors.error).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

class _WifiConfigCard extends StatelessWidget {
  const _WifiConfigCard({
    required this.config,
    required this.onToggle,
    required this.onDelete,
  });

  final WifiConfig config;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: (config.isActive ? context.colors.amber : context.colors.textDisabled).withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.wifi_rounded,
              color: config.isActive ? context.colors.amber : context.colors.textDisabled,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.ssid, style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${config.label}${config.bssid != null ? " · ${config.bssid}" : ""}',
                  style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: config.isActive,
            onChanged: (v) => onToggle(v),
            activeTrackColor: context.colors.amber,
          ),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.delete_outline_rounded, color: context.colors.error, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConfigState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: context.colors.textDisabled),
            const SizedBox(height: AppSpacing.lg),
            Text('No WiFi configured', style: AppTypography.titleMedium.copyWith(color: context.colors.textSecondary)),
            const SizedBox(height: 4),
            Text('Tap + to add your office network',
                style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _AddWifiFAB extends StatelessWidget {
  const _AddWifiFAB({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [context.colors.amber, const Color(0xFFE6A817)]),
          boxShadow: [
            BoxShadow(color: context.colors.amber.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
