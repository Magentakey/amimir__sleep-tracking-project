import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/disease_history.dart';
import '../../data/repositories/disease_history_repository.dart';
import 'disease_history_providers.dart';

class DiseaseHistoryScreen extends ConsumerWidget {
  const DiseaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DiseaseHistory>> historyAsync = ref.watch(
      diseaseHistoryProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainer,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Riwayat Penyakit', style: AppTextStyles.cardTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Tambah riwayat penyakit',
            onPressed: () => _showEntrySheet(context, ref, null),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat data: $err',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return _buildList(context, ref, list);
        },
      ),
    );
  }

  // ─── List view ────────────────────────────────────────────────────────────

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<DiseaseHistory> list,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildEntryCard(context, ref, list[index]);
      },
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    WidgetRef ref,
    DiseaseHistory entry,
  ) {
    final String? diagnosedYear = entry.diagnosedAt != null
        ? entry.diagnosedAt!.year.toString()
        : null;

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ikon ──────────────────────────────────────────────────────────
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHighest,
            ),
            child: const Icon(
              Icons.medical_information_rounded,
              color: AppColors.primaryFixedDim,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // ── Konten ────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (diagnosedYear != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          diagnosedYear,
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.primaryFixedDim,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    entry.note,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Action menu ───────────────────────────────────────────────────
          PopupMenuButton<_EntryAction>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.onSurfaceMuted,
              size: 20,
            ),
            color: AppColors.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (action) async {
              switch (action) {
                case _EntryAction.edit:
                  await _showEntrySheet(context, ref, entry);
                case _EntryAction.delete:
                  await _confirmDelete(context, ref, entry);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _EntryAction.edit,
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded,
                        color: AppColors.primaryFixedDim, size: 18),
                    const SizedBox(width: 10),
                    Text('Edit', style: AppTextStyles.body),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.delete,
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Text('Hapus',
                        style:
                            AppTextStyles.body.copyWith(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerHigh,
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.primaryFixedDim,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada riwayat penyakit',
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan riwayat penyakit untuk membantu AI memberikan '
              'rekomendasi tidur yang lebih sesuai kondisimu.',
              style: AppTextStyles.small.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showEntrySheet(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Penyakit'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom sheet add/edit ────────────────────────────────────────────────

  Future<void> _showEntrySheet(
    BuildContext context,
    WidgetRef ref,
    DiseaseHistory? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _EntrySheet(
          existing: existing,
          onSave: (entry) async {
            final DiseaseHistoryRepository repo = ref.read(
              diseaseHistoryRepositoryProvider,
            );
            if (existing == null) {
              await repo.add(entry);
            } else {
              await repo.update(entry);
            }
          },
        );
      },
    );
  }

  // ─── Delete confirm ───────────────────────────────────────────────────────

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DiseaseHistory entry,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Hapus riwayat?', style: AppTextStyles.cardTitle),
        content: Text(
          'Hapus "${entry.name}" dari riwayat penyakitmu?',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Hapus',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(diseaseHistoryRepositoryProvider).delete(entry.id);
  }
}

// ─── Enum action ─────────────────────────────────────────────────────────────

enum _EntryAction { edit, delete }

// ─── Bottom sheet widget ──────────────────────────────────────────────────────

class _EntrySheet extends StatefulWidget {
  final DiseaseHistory? existing;
  final Future<void> Function(DiseaseHistory entry) onSave;

  const _EntrySheet({required this.existing, required this.onSave});

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  DateTime? _diagnosedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _noteCtrl.text = widget.existing!.note;
      _diagnosedAt = widget.existing!.diagnosedAt;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickYear() async {
    final int currentYear = DateTime.now().year;
    final int initialYear = _diagnosedAt?.year ?? currentYear;

    // Show scrollable year picker via dialog
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        int selected = initialYear;
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerHigh,
              title: Text('Tahun Diagnosa', style: AppTextStyles.cardTitle),
              content: SizedBox(
                height: 200,
                width: 120,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 48,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: currentYear - initialYear,
                  ),
                  onSelectedItemChanged: (i) {
                    setInner(() => selected = currentYear - i);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: currentYear - 1900 + 1,
                    builder: (_, i) {
                      final int year = currentYear - i;
                      final bool isSelected = year == selected;
                      return Center(
                        child: Text(
                          year.toString(),
                          style: AppTextStyles.cardTitle.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _diagnosedAt = null);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Hapus'),
                ),
                TextButton(
                  onPressed: () {
                    setState(
                      () => _diagnosedAt = DateTime(selected),
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Pilih'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final String id = widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final DiseaseHistory entry = DiseaseHistory(
        id: id,
        name: _nameCtrl.text.trim(),
        diagnosedAt: _diagnosedAt,
        note: _noteCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.onSave(entry);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    final String yearLabel = _diagnosedAt != null
        ? _diagnosedAt!.year.toString()
        : 'Pilih tahun (opsional)';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                isEdit ? 'Edit Penyakit' : 'Tambah Penyakit',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 20),

              // ── Nama penyakit ──────────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                style: AppTextStyles.body.copyWith(color: AppColors.onSurface),
                decoration: _inputDecoration('Nama penyakit *',
                    Icons.medical_services_outlined),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // ── Tahun diagnosa ─────────────────────────────────────────────
              GestureDetector(
                onTap: _pickYear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.onSurfaceMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        yearLabel,
                        style: AppTextStyles.body.copyWith(
                          color: _diagnosedAt != null
                              ? AppColors.onSurface
                              : AppColors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Catatan ────────────────────────────────────────────────────
              TextFormField(
                controller: _noteCtrl,
                style: AppTextStyles.body.copyWith(color: AppColors.onSurface),
                decoration: _inputDecoration(
                  'Catatan (opsional)',
                  Icons.notes_rounded,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // ── Tombol simpan ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(isEdit ? 'Simpan Perubahan' : 'Tambah'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.onSurfaceMuted, size: 20),
      filled: true,
      fillColor: AppColors.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
