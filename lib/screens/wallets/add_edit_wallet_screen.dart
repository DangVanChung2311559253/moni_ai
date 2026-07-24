import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/wallet_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';
import '../../widgets/financial_brand_mark.dart';

class AddEditWalletScreen extends StatefulWidget {
  final WalletModel? existing;

  const AddEditWalletScreen({super.key, this.existing});

  @override
  State<AddEditWalletScreen> createState() => _AddEditWalletScreenState();
}

class _AddEditWalletScreenState extends State<AddEditWalletScreen> {
  final _database = DatabaseService();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _noteController = TextEditingController();

  WalletType _selectedType = WalletType.all.first;
  String _iconKey = WalletType.all.first.iconKey;
  int _colorValue = WalletType.colorOptions.first;
  bool _isDefault = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  Color get _selectedColor => Color(_colorValue);
  IconData get _selectedIcon =>
      WalletType.iconFor(_iconKey, _selectedType.icon);

  @override
  void initState() {
    super.initState();
    final wallet = widget.existing;
    if (wallet == null) {
      _nameController.text = _suggestionsFor('cash').first;
      _colorValue = _selectedType.color.toARGB32();
    } else {
      _selectedType = WalletType.getByKey(wallet.type);
      _iconKey = wallet.iconKey ?? _selectedType.iconKey;
      _colorValue = wallet.colorValue ?? _selectedType.color.toARGB32();
      _nameController.text = wallet.name;
      _balanceController.text = formatVndInput(wallet.balance);
      _noteController.text = wallet.note ?? '';
      _isDefault = wallet.isDefault;
    }
    _nameController.addListener(_refreshPreview);
    _balanceController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _balanceController.removeListener(_refreshPreview);
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Trở lại',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.arrowBackRounded),
        ),
        title: Text(
          _isEditing ? 'Chỉnh sửa ví' : 'Thêm ví',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _walletPreview(),
              const SizedBox(height: 24),
              _label('Tên ví'),
              const SizedBox(height: 8),
              _textField(
                controller: _nameController,
                hint: _suggestionsFor(_selectedType.key).first,
                icon: AppIcons.driveFileRenameOutlineRounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              _nameSuggestions(),
              const SizedBox(height: 22),
              _label('Loại ví'),
              const SizedBox(height: 10),
              _typeGrid(),
              const SizedBox(height: 22),
              _label(_isEditing ? 'Số dư hiện tại' : 'Số dư ban đầu'),
              const SizedBox(height: 8),
              _textField(
                controller: _balanceController,
                hint: '0',
                icon: AppIcons.paymentsOutlined,
                keyboardType: TextInputType.number,
                inputFormatters: const [VndInputFormatter()],
                suffix: 'đ',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 22),
              _label('Đơn vị tiền'),
              const SizedBox(height: 8),
              _currencyTile(),
              const SizedBox(height: 22),
              _label('Ghi chú'),
              const SizedBox(height: 8),
              _textField(
                controller: _noteController,
                hint: 'Ví dùng cho chi tiêu hằng ngày',
                icon: AppIcons.notesRounded,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),
              _defaultWalletTile(),
              const SizedBox(height: 26),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _walletPreview() {
    final name = _nameController.text.trim().isEmpty
        ? _suggestionsFor(_selectedType.key).first
        : _nameController.text.trim();
    final balance = parseVndInput(_balanceController.text) ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _selectedColor.withAlpha(215),
            _selectedColor.withAlpha(105),
            AppColors.navyCard,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _selectedColor.withAlpha(130)),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: _showAppearanceSheet,
                  borderRadius: BorderRadius.circular(18),
                  child: FinancialBrandMark(
                    name: name,
                    fallbackIcon: _selectedIcon,
                    fallbackColor: _selectedColor,
                    size: 68,
                    inverted: true,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _showAppearanceSheet,
                icon: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70),
                  ),
                ),
                label: const Text('Icon & màu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha(75)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Số dư',
            style: GoogleFonts.outfit(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${formatVndInput(balance)}đ',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameSuggestions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _suggestionsFor(_selectedType.key)
            .map(
              (name) => Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ActionChip(
                  avatar: const Icon(
                    AppIcons.autoAwesomeRounded,
                    size: 14,
                    color: AppColors.tealPrimary,
                  ),
                  label: Text(name),
                  onPressed: () {
                    _nameController.value = TextEditingValue(
                      text: name,
                      selection: TextSelection.collapsed(offset: name.length),
                    );
                  },
                  backgroundColor: AppColors.navyCard,
                  side: const BorderSide(color: AppColors.navyBorder),
                  labelStyle: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _typeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: WalletType.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.25,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
      ),
      itemBuilder: (_, index) {
        final type = WalletType.all[index];
        final selected = type.key == _selectedType.key;
        return Material(
          color: selected ? _selectedColor.withAlpha(25) : AppColors.navyCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _selectType(type),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _selectedColor : AppColors.navyBorder,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.icon,
                    color: selected ? _selectedColor : type.color,
                    size: 25,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    type.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: GoogleFonts.outfit(
                      color: selected
                          ? _selectedColor
                          : AppColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectType(WalletType type) {
    final currentName = _nameController.text.trim();
    final shouldSuggest =
        currentName.isEmpty ||
        _suggestionsFor(_selectedType.key).contains(currentName);
    setState(() {
      _selectedType = type;
      _iconKey = type.iconKey;
      _colorValue = type.color.toARGB32();
      if (shouldSuggest) {
        final name = _suggestionsFor(type.key).first;
        _nameController.value = TextEditingValue(
          text: name,
          selection: TextSelection.collapsed(offset: name.length),
        );
      }
    });
  }

  Widget _currencyTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '₫',
              style: GoogleFonts.outfit(
                color: AppColors.tealPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Việt Nam đồng – VND',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            AppIcons.lockOutlineRounded,
            color: AppColors.textMuted,
            size: 17,
          ),
        ],
      ),
    );
  }

  Widget _defaultWalletTile() {
    return Material(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => setState(() => _isDefault = !_isDefault),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _isDefault
                  ? AppColors.tealPrimary.withAlpha(130)
                  : AppColors.navyBorder,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _isDefault,
                onChanged: (value) =>
                    setState(() => _isDefault = value ?? false),
                activeColor: AppColors.tealPrimary,
                checkColor: AppColors.navyDeep,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đặt làm ví mặc định',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Ví này sẽ được ưu tiên khi tạo giao dịch mới.',
                      style: GoogleFonts.outfit(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffix,
    int minLines = 1,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixText: suffix,
        suffixStyle: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.navyCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.navyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.tealPrimary,
            width: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.outfit(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _saving
              ? const LinearGradient(
                  colors: [AppColors.navyBorder, AppColors.navyBorder],
                )
              : AppColors.tealGradient,
          borderRadius: BorderRadius.circular(17),
          boxShadow: _saving
              ? null
              : [
                  BoxShadow(
                    color: AppColors.tealPrimary.withAlpha(65),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditing ? 'Cập nhật ví' : 'Tạo ví',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showAppearanceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, sheetSetState) {
          void update(VoidCallback callback) {
            setState(callback);
            sheetSetState(() {});
          }

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              decoration: const BoxDecoration(
                color: AppColors.navyMid,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.navyBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Chọn icon và màu ví',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: WalletType.iconOptions.entries.map((entry) {
                      final selected = entry.key == _iconKey;
                      return InkWell(
                        onTap: () => update(() => _iconKey = entry.key),
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: selected
                                ? _selectedColor.withAlpha(30)
                                : AppColors.navyCard,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected
                                  ? _selectedColor
                                  : AppColors.navyBorder,
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            color: selected
                                ? _selectedColor
                                : AppColors.textSecondary,
                            size: 26,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Màu ví',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: WalletType.colorOptions.map((value) {
                      final selected = value == _colorValue;
                      return InkWell(
                        onTap: () => update(() => _colorValue = value),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: Color(value).withAlpha(90),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  AppIcons.checkRounded,
                                  color: Colors.white,
                                  size: 19,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tealPrimary,
                        foregroundColor: AppColors.navyDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text('Xong'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final name = _nameController.text.trim();
    final balance = parseVndInput(_balanceController.text) ?? 0;
    if (userId.isEmpty) {
      _showError('Bạn cần đăng nhập trước khi tạo ví.');
      return;
    }
    if (name.isEmpty) {
      _showError('Vui lòng nhập tên ví.');
      return;
    }
    if (balance < 0) {
      _showError('Số dư ví không được âm.');
      return;
    }

    setState(() => _saving = true);
    try {
      final note = _noteController.text.trim();
      final current = widget.existing;
      if (current == null) {
        await _database.insertWallet(
          WalletModel(
            userId: userId,
            name: name,
            type: _selectedType.key,
            balance: balance,
            iconKey: _iconKey,
            colorValue: _colorValue,
            currency: 'VND',
            note: note.isEmpty ? null : note,
            isDefault: _isDefault,
          ),
        );
      } else {
        await _database.updateWallet(
          current.copyWith(
            name: name,
            type: _selectedType.key,
            balance: balance,
            iconKey: _iconKey,
            colorValue: _colorValue,
            currency: 'VND',
            note: note,
            isDefault: _isDefault,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError('Không thể lưu ví: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navyCard,
      ),
    );
  }

  List<String> _suggestionsFor(String type) {
    switch (type) {
      case 'cash':
        return const ['Ví tiền mặt', 'Tiền mặt'];
      case 'bank':
        return const ['MB Bank', 'Vietcombank', 'BIDV', 'Agribank'];
      case 'ewallet':
        return const ['MoMo', 'ZaloPay', 'VNPay'];
      case 'credit':
        return const ['Thẻ tín dụng', 'Visa', 'Mastercard'];
      case 'savings':
        return const ['Ví tiết kiệm', 'Quỹ khẩn cấp'];
      default:
        return const ['Ví cá nhân', 'Ví khác'];
    }
  }
}
