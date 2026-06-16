import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/models/user_profile.dart';
import '../repositories/admin_repository.dart';

// ─── Providers ──────────────────────────────────────────────

/// Provider for employee list
final employeeListProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getEmployees();
});

/// Search query provider
final _employeeSearchProvider = StateProvider<String>((ref) => '');

/// Filter provider: null = all, true = active, false = inactive
final _employeeFilterProvider = StateProvider<bool?>((ref) => null);

/// Filtered employee list
final _filteredEmployeesProvider = Provider<AsyncValue<List<UserProfile>>>((ref) {
  final asyncEmployees = ref.watch(employeeListProvider);
  final search = ref.watch(_employeeSearchProvider).toLowerCase();
  final filter = ref.watch(_employeeFilterProvider);

  return asyncEmployees.whenData((employees) {
    var filtered = employees;
    if (filter != null) {
      filtered = filtered.where((e) => e.isActive == filter).toList();
    }
    if (search.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.fullName.toLowerCase().contains(search) ||
        e.email.toLowerCase().contains(search) ||
        (e.department?.toLowerCase().contains(search) ?? false)
      ).toList();
    }
    return filtered;
  });
});

// ─── Main Screen ────────────────────────────────────────────

class AdminEmployeeMgmtScreen extends ConsumerWidget {
  const AdminEmployeeMgmtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);
    final filteredAsync = ref.watch(_filteredEmployeesProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        RefreshIndicator(
          color: context.colors.brand,
          backgroundColor: context.colors.surfaceElevated,
          onRefresh: () async {
            ref.invalidate(employeeListProvider);
            await ref.read(employeeListProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top safe-area spacing
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding + AppSpacing.lg),
              ),

              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TEAM MANAGEMENT', style: AppTypography.caption.copyWith(
                        color: context.colors.cyan, letterSpacing: 2, fontWeight: FontWeight.w700,
                      )).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 4),
                      Text('Employees', style: AppTypography.displaySmall)
                          .animate(delay: 100.ms).fadeIn().slideX(begin: -0.03),
                    ],
                  ),
                ),
              ),

              // Summary Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH, AppSpacing.xl,
                    AppSpacing.pagePaddingH, 0,
                  ),
                  child: employeesAsync.when(
                    data: (employees) => _SummaryRow(employees: employees)
                        .animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Search + Filter Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH, AppSpacing.lg,
                    AppSpacing.pagePaddingH, AppSpacing.md,
                  ),
                  child: _SearchFilterBar()
                      .animate(delay: 300.ms).fadeIn().slideY(begin: 0.03),
                ),
              ),

              // Employee List
              filteredAsync.when(
                data: (employees) {
                  if (employees.isEmpty) {
                    return SliverToBoxAdapter(child: _EmptyState());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
                    sliver: SliverList.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, i) {
                        final emp = employees[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _EmployeeCard(
                            employee: emp,
                            onTap: () => _showEmployeeDetail(context, ref, emp),
                          ).animate(delay: Duration(milliseconds: 350 + i * 50))
                              .fadeIn(duration: 400.ms)
                              .slideX(begin: 0.03),
                        );
                      },
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: context.colors.brand),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: context.colors.error),
                          const SizedBox(height: 12),
                          Text('Failed to load employees',
                            style: AppTypography.titleSmall.copyWith(color: context.colors.error)),
                          const SizedBox(height: 4),
                          Text('Pull down to retry',
                            style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom spacer for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),

        // FAB
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 90,
          right: AppSpacing.pagePaddingH,
          child: _AddEmployeeFAB(
            onTap: () => _showAddEmployeeSheet(context, ref),
          ).animate(delay: 500.ms).fadeIn().scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  // ─── Add Employee Sheet ─────────────────────────────────

  void _showAddEmployeeSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final designCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
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
                        // Handle
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
                        Text('Add Employee', style: AppTypography.headlineMedium),
                        const SizedBox(height: 4),
                        Text('Create a new employee account',
                            style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
                        const SizedBox(height: AppSpacing.xxl),

                        GlassTextField(
                          controller: nameCtrl,
                          label: 'Full Name',
                          hint: 'John Doe',
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassTextField(
                          controller: emailCtrl,
                          label: 'Email',
                          hint: 'john@adnora.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Required';
                            if (!v!.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassTextField(
                          controller: passCtrl,
                          label: 'Password',
                          hint: 'Min 6 characters',
                          prefixIcon: Icons.lock_outline,
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Required';
                            if (v!.length < 6) return 'Min 6 chars';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassTextField(
                          controller: deptCtrl,
                          label: 'Department (optional)',
                          hint: 'e.g. Design, Engineering',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassTextField(
                          controller: designCtrl,
                          label: 'Designation (optional)',
                          hint: 'e.g. Senior Developer',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassTextField(
                          controller: phoneCtrl,
                          label: 'Phone (optional)',
                          hint: '+91 98765 43210',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        _ActionButton(
                          label: 'Create Employee',
                          icon: Icons.person_add_rounded,
                          color: context.colors.success,
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final repo = ref.read(adminRepositoryProvider);
                            final result = await repo.createEmployee(
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text,
                              fullName: nameCtrl.text.trim(),
                              department: deptCtrl.text.isNotEmpty ? deptCtrl.text.trim() : null,
                              designation: designCtrl.text.isNotEmpty ? designCtrl.text.trim() : null,
                              phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text.trim() : null,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            ref.invalidate(employeeListProvider);
                            if (result != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${result.fullName} added!'),
                                  backgroundColor: context.colors.success.withValues(alpha: 0.9),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Employee Detail Sheet ──────────────────────────────

  void _showEmployeeDetail(BuildContext context, WidgetRef ref, UserProfile emp) {
    HapticFeedback.lightImpact();
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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: context.colors.textDisabled,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Avatar
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.brand.withValues(alpha: 0.4),
                            context.colors.cyan.withValues(alpha: 0.2),
                          ],
                        ),
                        border: Border.all(color: context.colors.brand.withValues(alpha: 0.4), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                          style: AppTypography.displaySmall.copyWith(
                            color: context.colors.brand,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Name & Status
                    Text(emp.fullName, style: AppTypography.headlineMedium),
                    const SizedBox(height: 4),
                    Text(emp.email,
                      style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
                    const SizedBox(height: AppSpacing.md),
                    StatusPill(
                      label: emp.isActive ? 'Active' : 'Inactive',
                      preset: emp.isActive ? StatusPreset.active : StatusPreset.inactive,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Info Grid
                    _DetailRow(icon: Icons.business_outlined, label: 'Department', value: emp.department ?? 'Not set'),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(icon: Icons.badge_outlined, label: 'Designation', value: emp.designation ?? 'Not set'),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: emp.phone ?? 'Not set'),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Joined',
                      value: DateFormat('d MMM yyyy').format(emp.createdAt),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Edit',
                            icon: Icons.edit_rounded,
                            color: context.colors.brand,
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditEmployeeSheet(context, ref, emp);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ActionButton(
                            label: emp.isActive ? 'Deactivate' : 'Activate',
                            icon: emp.isActive ? Icons.block_rounded : Icons.check_circle_outline,
                            color: emp.isActive ? context.colors.error : context.colors.success,
                            onPressed: () async {
                              final repo = ref.read(adminRepositoryProvider);
                              if (emp.isActive) {
                                await repo.deactivateEmployee(emp.id);
                              } else {
                                await repo.updateEmployee(
                                  userId: emp.id,
                                  updates: {'is_active': true},
                                );
                              }
                              ref.invalidate(employeeListProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  // ─── Edit Employee Sheet ────────────────────────────────

  void _showEditEmployeeSheet(BuildContext context, WidgetRef ref, UserProfile emp) {
    final nameCtrl = TextEditingController(text: emp.fullName);
    final deptCtrl = TextEditingController(text: emp.department ?? '');
    final designCtrl = TextEditingController(text: emp.designation ?? '');
    final phoneCtrl = TextEditingController(text: emp.phone ?? '');
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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
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
                        // Handle
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
                        Text('Edit Employee', style: AppTypography.headlineMedium),
                        const SizedBox(height: AppSpacing.xxl),

                        GlassTextField(
                          controller: nameCtrl,
                          label: 'Full Name',
                          hint: 'e.g. Sarah Connor',
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GlassTextField(
                          controller: deptCtrl,
                          label: 'Department (Optional)',
                          hint: 'e.g. Engineering',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GlassTextField(
                          controller: designCtrl,
                          label: 'Designation (Optional)',
                          hint: 'e.g. Mobile Developer',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GlassTextField(
                          controller: phoneCtrl,
                          label: 'Phone (Optional)',
                          hint: '+1 234 567 8900',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        _ActionButton(
                          label: 'Save Changes',
                          icon: Icons.save_rounded,
                          color: context.colors.brand,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final repo = ref.read(adminRepositoryProvider);
                              await repo.updateEmployee(
                                userId: emp.id,
                                updates: {
                                  'full_name': nameCtrl.text.trim(),
                                  'department': deptCtrl.text.trim(),
                                  'designation': designCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                },
                              );

                              ref.invalidate(employeeListProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${nameCtrl.text} updated!'),
                                    backgroundColor: context.colors.success.withValues(alpha: 0.9),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary Stats Row ──────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.employees});
  final List<UserProfile> employees;

  @override
  Widget build(BuildContext context) {
    final total = employees.length;
    final active = employees.where((e) => e.isActive).length;
    final inactive = total - active;

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Total', value: '$total', color: context.colors.brand)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _StatCard(label: 'Active', value: '$active', color: context.colors.success)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _StatCard(label: 'Inactive', value: '$inactive', color: context.colors.error)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      borderRadius: 14,
      child: Column(
        children: [
          Text(value, style: AppTypography.headlineMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption.copyWith(
            color: context.colors.textTertiary,
            fontSize: 11,
          )),
        ],
      ),
    );
  }
}

// ─── Search & Filter Bar ────────────────────────────────────

class _SearchFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(_employeeFilterProvider);

    return Column(
      children: [
        // Search field
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.glassBorder),
          ),
          child: TextField(
            onChanged: (v) => ref.read(_employeeSearchProvider.notifier).state = v,
            style: AppTypography.bodySmall.copyWith(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name, email or department…',
              hintStyle: AppTypography.bodySmall.copyWith(color: context.colors.textDisabled),
              prefixIcon: Icon(Icons.search_rounded, color: context.colors.textTertiary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Filter chips
        Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: activeFilter == null,
              onTap: () => ref.read(_employeeFilterProvider.notifier).state = null,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Active',
              selected: activeFilter == true,
              color: context.colors.success,
              onTap: () => ref.read(_employeeFilterProvider.notifier).state = true,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Inactive',
              selected: activeFilter == false,
              color: context.colors.error,
              onTap: () => ref.read(_employeeFilterProvider.notifier).state = false,
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.colors.brand;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor.withValues(alpha: 0.5) : context.colors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? chipColor : context.colors.textTertiary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Enhanced Employee Card ─────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, this.onTap});
  final UserProfile employee;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: 18,
      onTap: onTap,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.brand.withValues(alpha: 0.3),
                  context.colors.cyan.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: context.colors.brand.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : '?',
                style: AppTypography.titleMedium.copyWith(color: context.colors.brand),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.fullName,
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (employee.designation != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          employee.designation!,
                          style: AppTypography.caption.copyWith(
                            color: context.colors.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (employee.department != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business_outlined, size: 12, color: context.colors.textDisabled),
                      const SizedBox(width: 4),
                      Text(
                        employee.department!,
                        style: AppTypography.caption.copyWith(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Status + Chevron
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: employee.isActive ? 'Active' : 'Inactive',
                preset: employee.isActive ? StatusPreset.active : StatusPreset.inactive,
                small: true,
              ),
              const SizedBox(height: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textDisabled),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Detail Row (for detail sheet) ──────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.brand),
          const SizedBox(width: 12),
          Text(label, style: AppTypography.caption.copyWith(
            color: context.colors.textTertiary,
            fontWeight: FontWeight.w600,
          )),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: value == 'Not set'
                    ? context.colors.textDisabled
                    : context.colors.textPrimary,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.brand.withValues(alpha: 0.08),
                border: Border.all(color: context.colors.brand.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.people_outline_rounded, size: 40, color: context.colors.brand.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('No employees yet', style: AppTypography.titleMedium.copyWith(color: context.colors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              'Tap the + button to add your first team member and start building your workforce.',
              style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAB ────────────────────────────────────────────────────

class _AddEmployeeFAB extends StatelessWidget {
  const _AddEmployeeFAB({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [context.colors.brand, context.colors.brandLight],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brand.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

// ─── Action Button ──────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
