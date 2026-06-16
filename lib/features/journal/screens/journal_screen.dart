import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/loading_state.dart';
import '../models/journal_note.dart';
import '../providers/journal_provider.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    final notesAsync = ref.watch(filteredJournalNotesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),

        // ─── Header & Search ──────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Journal', style: AppTypography.displaySmall)
                        .animate()
                        .fadeIn()
                        .slideX(begin: -0.03, end: 0),
                  ),
                  LiquidButton(
                    label: 'New Entry',
                    icon: Icons.edit_note_rounded,
                    size: LiquidButtonSize.small,
                    onPressed: () {},
                  ).animate(delay: 100.ms).fadeIn(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _JournalSearchBar().animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Content ──────────────────────────────────────
        Expanded(
          child: notesAsync.when(
            data: (categorized) {
              final pinned = categorized['pinned']!;
              final timeline = categorized['timeline']!;

              if (pinned.isEmpty && timeline.isEmpty) {
                return const Center(child: Text('No journal entries found.'));
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: hPad,
                      right: hPad,
                      top: AppSpacing.md,
                      bottom: 120,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Pinned Section
                        if (pinned.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.brand),
                              const SizedBox(width: AppSpacing.sm),
                              Text('Pinned', style: AppTypography.titleSmall),
                            ],
                          ).animate().fadeIn(),
                          const SizedBox(height: AppSpacing.md),
                          ...pinned.map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _JournalNoteCard(note: n).animate().fadeIn().slideY(begin: 0.05),
                              )),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        // Timeline Section Header
                        if (timeline.isNotEmpty) ...[
                          Text('Timeline', style: AppTypography.titleSmall)
                              .animate()
                              .fadeIn(),
                          const SizedBox(height: AppSpacing.md),
                          ...timeline.map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _JournalNoteCard(note: n).animate().fadeIn().slideY(begin: 0.05),
                              )),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: LoadingState()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────
class _JournalSearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              onChanged: (val) => ref.read(journalSearchQueryProvider.notifier).state = val,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search notes, meetings, voices...',
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Note Card ────────────────────────────────────────────
class _JournalNoteCard extends StatelessWidget {
  const _JournalNoteCard({required this.note});
  final JournalNote note;

  IconData get _typeIcon => switch (note.noteType) {
    'meeting' => Icons.groups_rounded,
    'voice' => Icons.mic_rounded,
    _ => Icons.notes_rounded,
  };

  Color get _typeColor => switch (note.noteType) {
    'meeting' => AppColors.brand,
    'voice' => AppColors.amber,
    _ => AppColors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Type & Author)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon, size: 16, color: _typeColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${note.authorName ?? 'Unknown'} • ${DateFormat('MMM d, h:mm a').format(note.createdAt)}',
                      style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (note.isPrivate) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textTertiary),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Content
          if (note.noteType == 'voice')
            _VoiceNotePlaceholder(color: _typeColor)
          else
            Text(
              note.content,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

          // Attachments Snippet
          if (note.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: note.attachments.map((a) => _AttachmentPill(attachment: a)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceNotePlaceholder extends StatelessWidget {
  const _VoiceNotePlaceholder({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.play_circle_fill_rounded, color: color, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(20, (i) {
                return Container(
                  width: 4,
                  height: 10.0 + (i % 3) * 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('0:42', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _AttachmentPill extends StatelessWidget {
  const _AttachmentPill({required this.attachment});
  final JournalAttachment attachment;

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.insert_drive_file_outlined;
    if (attachment.fileType == 'image') icon = Icons.image_outlined;
    if (attachment.fileType == 'pdf') icon = Icons.picture_as_pdf_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassHighlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            attachment.fileName,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
