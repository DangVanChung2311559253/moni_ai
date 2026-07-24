import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/category_model.dart';
import '../../models/budget_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';

class AddEditBudgetScreen extends StatefulWidget {
  final BudgetModel? existing;
  const AddEditBudgetScreen({super.key, this.existing});

  @override
  State<AddEditBudgetScreen> createState() => _AddEditBudgetScreenState();
}

class _AddEditBudgetScreenState extends State<AddEditBudgetScreen> {
  final _db = DatabaseService();
  final _amountCtrl = TextEditingController();
  CategoryModel _selectedCategory = CategoryModel.expenseCategories.first;
  late int _month;
  late int _year;
  bool _loading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    if (isEditing) {
      _selectedCategory = CategoryModel.getById(widget.existing!.categoryId);
      _amountCtrl.text = formatVndInput(widget.existing!.limitAmount);
      _month = widget.existing!.month;
      _year = widget.existing!.year;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  static const _months = [
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            AppIcons.arrowBackIosNewRounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Chỉnh sửa ngân sách' : 'Thêm ngân sách',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Tháng / Năm'),
            const SizedBox(height: 12),
            _buildMonthYearPicker(),
            const SizedBox(height: 24),
            _buildLabel('Danh mục chi tiêu'),
            const SizedBox(height: 12),
            _buildCategoryGrid(),
            const SizedBox(height: 24),
            _buildLabel('Hạn mức ngân sách'),
            const SizedBox(height: 8),
            _buildAmountField(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: GoogleFonts.outfit(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildMonthYearPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          // Month
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _month,
                dropdownColor: AppColors.navyCard,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                items: List.generate(
                  12,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text(_months[i])),
                ),
                onChanged: (v) => setState(() => _month = v!),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.navyBorder),
          const SizedBox(width: 16),
          // Year
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _year,
              dropdownColor: AppColors.navyCard,
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              items: List.generate(5, (i) {
                final y = DateTime.now().year - 2 + i;
                return DropdownMenuItem(value: y, child: Text(y.toString()));
              }),
              onChanged: (v) => setState(() => _year = v!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final cats = CategoryModel.expenseCategories;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat = cats[i];
        final selected = _selectedCategory.id == cat.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? cat.color.withAlpha(38) : AppColors.navyCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? cat.color : AppColors.navyBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat.icon, color: cat.color, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    cat.name,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: selected ? cat.color : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: TextField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: const [VndInputFormatter()],
        style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 18),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: GoogleFonts.outfit(
            color: AppColors.textMuted,
            fontSize: 18,
          ),
          prefixIcon: const Icon(
            AppIcons.savingsRounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffix: Text(
            'VND',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _loading
              ? const LinearGradient(
                  colors: [AppColors.navyBorder, AppColors.navyBorder],
                )
              : AppColors.tealGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.tealPrimary.withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isEditing ? 'Cập nhật' : 'Thêm ngân sách',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final limit = parseVndInput(_amountCtrl.text);
    if (limit == null || limit <= 0) {
      _showError('Vui lòng nhập hạn mức ngân sách');
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (isEditing) {
        await _db.updateBudget(
          widget.existing!.copyWith(
            categoryId: _selectedCategory.id,
            limitAmount: limit,
            month: _month,
            year: _year,
          ),
        );
      } else {
        await _db.insertBudget(
          BudgetModel(
            userId: uid,
            categoryId: _selectedCategory.id,
            limitAmount: limit,
            month: _month,
            year: _year,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navyCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(AppIcons.errorOutlineRounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(msg, style: GoogleFonts.outfit(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
