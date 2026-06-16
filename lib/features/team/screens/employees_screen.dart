import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/status_pill.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    final employees = [
      {'name': 'Aarav Kumar', 'role': 'Lead Designer', 'status': 'Active'},
      {'name': 'Priya Singh', 'role': 'Frontend Developer', 'status': 'On Leave'},
      {'name': 'Rahul Verma', 'role': 'Backend Engineer', 'status': 'Active'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              Expanded(child: Text('Employees', style: AppTypography.displaySmall)),
              LiquidButton(label: 'Add Employee', icon: Icons.add, onPressed: () {}, size: LiquidButtonSize.small),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(left: hPad, right: hPad, bottom: 120),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final emp = employees[i];
              return Animate(
                delay: Duration(milliseconds: i * 50),
                effects: [const FadeEffect(), const SlideEffect(begin: Offset(0.05, 0))],
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: context.colors.brandDark, child: Text(emp['name']![0])),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(emp['name']!, style: AppTypography.titleMedium),
                            Text(emp['role']!, style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: emp['status']!,
                        preset: emp['status'] == 'Active' ? StatusPreset.active : StatusPreset.pending,
                        small: true,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
