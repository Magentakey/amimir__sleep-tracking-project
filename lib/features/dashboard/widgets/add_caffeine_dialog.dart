import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/daily_log.dart';

class AddCaffeineDialog extends StatefulWidget {
  const AddCaffeineDialog({super.key});

  @override
  State<AddCaffeineDialog> createState() => _AddCaffeineDialogState();
}

class _AddCaffeineDialogState extends State<AddCaffeineDialog> {
  final TextEditingController _drinkController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();

  @override
  void dispose() {
    _drinkController.dispose();
    super.dispose();
  }

  void _unfocusKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDateTime() async {
    _unfocusKeyboard();

    final DateTime now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isAfter(now) ? now : _selectedDateTime,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (pickedDate == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _selectedDateTime.hour,
        minute: _selectedDateTime.minute,
      ),
    );

    if (pickedTime == null) {
      return;
    }

    final DateTime result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (result.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu caffeine tidak boleh melewati waktu sekarang.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedDateTime = result;
    });
  }

  void _submit() {
    _unfocusKeyboard();

    final String drink = _drinkController.text.trim();

    if (drink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drink name tidak boleh kosong.')),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(CaffeineLog(name: drink, dateTime: _selectedDateTime));
  }

  String _formatDateTime(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocusKeyboard,
      behavior: HitTestBehavior.translucent,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(
                Icons.local_cafe_rounded,
                color: AppColors.onPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Add caffeine', style: AppTextStyles.cardTitle),
            ),
          ],
        ),
        content: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _drinkController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Drink name',
                  hintText: 'Espresso, kopi susu, teh...',
                  prefixIcon: Icon(Icons.coffee_rounded),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date and time',
                    prefixIcon: Icon(Icons.schedule_rounded),
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  child: Text(
                    _formatDateTime(_selectedDateTime),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Catat waktu caffeine supaya AI bisa melihat kemungkinan pengaruhnya ke tidur.',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _unfocusKeyboard();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: _submit, child: const Text('Add')),
        ],
      ),
    );
  }
}
