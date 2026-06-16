import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/journal_note.dart';

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.note});
  final JournalNote note;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Ambient Glow
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [context.colors.cyan.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: topPadding + AppSpacing.md,
              left: AppSpacing.pagePaddingH,
              right: AppSpacing.pagePaddingH,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 16, color: context.colors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Journal', style: AppTypography.labelMedium.copyWith(color: context.colors.textSecondary)),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: AppSpacing.xl),

                // Note Type & Privacy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        note.noteType.toUpperCase(),
                        style: AppTypography.caption.copyWith(color: context.colors.brand, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (note.isPrivate)
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: context.colors.textTertiary),
                          const SizedBox(width: 4),
                          Text('Private', style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.public_rounded, size: 14, color: context.colors.textTertiary),
                          const SizedBox(width: 4),
                          Text('Shared', style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                        ],
                      ),
                  ],
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: AppSpacing.md),

                // Title
                Text(note.title, style: AppTypography.displaySmall)
                    .animate(delay: 150.ms).fadeIn().slideX(begin: -0.02),
                
                const SizedBox(height: AppSpacing.sm),

                // Author & Date
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: context.colors.surfaceOverlay,
                      child: Text(
                        note.authorName?[0] ?? 'U',
                        style: TextStyle(fontSize: 10, color: context.colors.brandLight),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${note.authorName ?? 'Unknown'} • ${DateFormat('MMMM d, yyyy • h:mm a').format(note.createdAt)}',
                      style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: AppSpacing.xxxl),

                // Content
                Text(
                  note.content,
                  style: AppTypography.bodyLarge.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                ).animate(delay: 300.ms).fadeIn(),

                // Attachments
                if (note.attachments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxxl),
                  Text('Attachments', style: AppTypography.titleMedium).animate(delay: 400.ms).fadeIn(),
                  const SizedBox(height: AppSpacing.md),
                  ...note.attachments.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.colors.glassHighlight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.attach_file_rounded, size: 18, color: context.colors.textSecondary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(a.fileName, style: AppTypography.labelMedium),
                            ),
                            Icon(Icons.download_rounded, size: 20, color: context.colors.brand),
                          ],
                        ),
                      ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.05),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
