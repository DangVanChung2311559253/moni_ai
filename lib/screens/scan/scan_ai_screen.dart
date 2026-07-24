import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/category_model.dart';
import '../../models/scan_result_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../services/database_service.dart';
import '../../services/scan_ai_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';

class ScanAiScreen extends StatefulWidget {
  const ScanAiScreen({super.key});

  @override
  State<ScanAiScreen> createState() => _ScanAiScreenState();
}

class _ScanAiScreenState extends State<ScanAiScreen> {
  final _picker = ImagePicker();
  final _service = ScanAiService();
  bool _processing = false;
  File? _selectedImage;

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 76,
        maxWidth: 1600,
        maxHeight: 2000,
      );
      if (picked == null) return;

      setState(() {
        _selectedImage = File(picked.path);
        _processing = true;
      });
      final result = await _service.scan(_selectedImage!);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ScanConfirmationScreen(result: result, image: _selectedImage!),
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu giao dịch từ Scan AI.')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(message.replaceFirst('Exception: ', '')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Scan AI',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.balanceCardGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Icon(
                      AppIcons.documentScannerRounded,
                      color: Colors.white,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Biến ảnh thành giao dịch',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'OCR đọc nội dung, AI phân loại và bạn xác nhận trước khi lưu.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _sourceCard(
                icon: AppIcons.photoCameraRounded,
                title: 'Chụp hóa đơn giấy',
                subtitle: 'Mở camera và chụp rõ toàn bộ hóa đơn',
                onTap: () => _pickAndScan(ImageSource.camera),
              ),
              const SizedBox(height: 14),
              _sourceCard(
                icon: AppIcons.imageSearchRounded,
                title: 'Chọn ảnh giao dịch',
                subtitle: 'Ảnh chụp màn hình hoặc ảnh có sẵn trong máy',
                onTap: () => _pickAndScan(ImageSource.gallery),
              ),
              const SizedBox(height: 24),
              Text(
                'Hỗ trợ nhận diện',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _SupportChip('MoMo'),
                  _SupportChip('ZaloPay'),
                  _SupportChip('VietQR'),
                  _SupportChip('VNPay'),
                  _SupportChip('Ngân hàng'),
                ],
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImage!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
          if (_processing)
            Container(
              color: AppColors.navyDeep.withAlpha(220),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.tealPrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Đang đọc ảnh bằng OCR trên máy chủ...',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _processing ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tealPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.tealPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                AppIcons.chevronRightRounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportChip extends StatelessWidget {
  final String label;
  const _SupportChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class ScanConfirmationScreen extends StatefulWidget {
  final ScanResultModel result;
  final File image;

  const ScanConfirmationScreen({
    super.key,
    required this.result,
    required this.image,
  });

  @override
  State<ScanConfirmationScreen> createState() => _ScanConfirmationScreenState();
}

class _ScanConfirmationScreenState extends State<ScanConfirmationScreen> {
  final _db = DatabaseService();
  final _notificationService = NotificationService();
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  late CategoryModel _category;
  List<WalletModel> _wallets = [];
  WalletModel? _wallet;
  bool _loadingWallets = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _merchantCtrl = TextEditingController(text: widget.result.merchant);
    _amountCtrl = TextEditingController(
      text: formatVndInput(widget.result.amount),
    );
    _noteCtrl = TextEditingController(text: widget.result.rawText);
    _date = widget.result.date;
    _category = _matchCategory(widget.result.category);
    _loadWallets();
  }

  CategoryModel _matchCategory(String value) {
    final normalized = value.toLowerCase().trim();
    for (final category in CategoryModel.expenseCategories) {
      final name = category.name.toLowerCase();
      if (name == normalized ||
          name.contains(normalized) ||
          normalized.contains(name)) {
        return category;
      }
    }
    return CategoryModel.expenseCategories.last;
  }

  Future<void> _loadWallets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final wallets = await _db.getWallets(uid);
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _wallet = WalletModel.preferred(wallets);
      _loadingWallets = false;
    });
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = parseVndInput(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _error('Số tiền không hợp lệ.');
      return;
    }
    if (_wallet == null) {
      _error('Bạn cần tạo ít nhất một ví trước khi lưu.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.insertTransaction(
        TransactionModel(
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          title: _merchantCtrl.text.trim().isEmpty
              ? _category.name
              : _merchantCtrl.text.trim(),
          amount: amount,
          categoryId: _category.id,
          walletId: _wallet!.id!,
          date: _date,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          type: 'expense',
        ),
      );
      unawaited(
        _notificationService
            .evaluate(FirebaseAuth.instance.currentUser?.uid ?? '')
            .catchError((_) {}),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _error('Không thể lưu giao dịch: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final confidence = (widget.result.confidence * 100).clamp(0, 100);
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Xác nhận giao dịch',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(widget.image, height: 170, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                AppIcons.autoAwesomeRounded,
                color: AppColors.tealPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Độ tin cậy ${confidence.toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(
                  color: AppColors.tealPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _field('Đơn vị nhận tiền', _merchantCtrl),
          _field(
            'Số tiền',
            _amountCtrl,
            keyboardType: TextInputType.number,
            formatters: const [VndInputFormatter()],
            suffixText: 'VND',
          ),
          _selector(
            'Ngày giao dịch',
            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
            _pickDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CategoryModel>(
            initialValue: _category,
            dropdownColor: AppColors.navyCard,
            decoration: _decoration('Danh mục'),
            items: CategoryModel.expenseCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WalletModel>(
            initialValue: _wallet,
            dropdownColor: AppColors.navyCard,
            decoration: _decoration(
              _loadingWallets ? 'Đang tải ví...' : 'Ví thanh toán',
            ),
            items: _wallets
                .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                .toList(),
            onChanged: (value) => setState(() => _wallet = value),
          ),
          _field('Nội dung OCR', _noteCtrl, maxLines: 4),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(AppIcons.checkRounded),
              label: Text(_saving ? 'Đang lưu...' : 'Xác nhận và lưu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: AppColors.tealPrimary,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: AppColors.navyCard,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.navyBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.tealPrimary),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    int maxLines = 1,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: _decoration(label, suffixText: suffixText),
      ),
    );
  }

  Widget _selector(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _decoration(label),
        child: Text(
          value,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
