import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../models/app_settings.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static final ValueNotifier<String?> avatarPathNotifier =
      ValueNotifier<String?>(null);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _settingsService = SettingsService();
  final _nameCtrl = TextEditingController();

  String? _avatarPath; // Local file path
  bool _loadingAvatar = false;
  bool _savingName = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  static const _avatarKey = 'user_avatar_path';

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _user?.displayName ?? '';
    _loadAvatar();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarKey);
    if (path != null && File(path).existsSync()) {
      setState(() => _avatarPath = path);
      ProfileScreen.avatarPathNotifier.value = path;
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      setState(() => _loadingAvatar = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy image to app documents directory for persistence
      final dir = await getApplicationDocumentsDirectory();
      final uid = _user?.uid ?? 'default';
      final dest = p.join(dir.path, 'avatar_$uid.jpg');
      await File(picked.path).copy(dest);

      // Save path to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarKey, dest);

      setState(() => _avatarPath = dest);
      ProfileScreen.avatarPathNotifier.value = dest;
    } catch (e) {
      _showSnack('Không thể chọn ảnh: $e');
    } finally {
      if (mounted) setState(() => _loadingAvatar = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.navyBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn ảnh đại diện',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tealPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  AppIcons.photoLibraryRounded,
                  color: AppColors.tealPrimary,
                ),
              ),
              title: Text(
                'Thư viện ảnh',
                style: GoogleFonts.outfit(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.purpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  AppIcons.cameraAltRounded,
                  color: AppColors.purpleAccent,
                ),
              ),
              title: Text(
                'Chụp ảnh',
                style: GoogleFonts.outfit(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (_avatarPath != null)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    AppIcons.deleteRounded,
                    color: AppColors.error,
                  ),
                ),
                title: Text(
                  'Xóa ảnh đại diện',
                  style: GoogleFonts.outfit(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove(_avatarKey);
                  setState(() => _avatarPath = null);
                  ProfileScreen.avatarPathNotifier.value = null;
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Tên không được để trống');
      return;
    }
    setState(() => _savingName = true);
    try {
      await _user?.updateDisplayName(name);
      await _user?.reload();
      _showSnack('Đã cập nhật tên thành công ✓');
    } catch (e) {
      _showSnack('Không thể cập nhật tên: $e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.navyCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Đổi mật khẩu',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pwField(
                'Mật khẩu hiện tại',
                currentCtrl,
                obscureCurrent,
                () => setS(() => obscureCurrent = !obscureCurrent),
              ),
              const SizedBox(height: 12),
              _pwField(
                'Mật khẩu mới',
                newCtrl,
                obscureNew,
                () => setS(() => obscureNew = !obscureNew),
              ),
              const SizedBox(height: 12),
              _pwField(
                'Xác nhận mật khẩu mới',
                confirmCtrl,
                obscureConfirm,
                () => setS(() => obscureConfirm = !obscureConfirm),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Hủy',
                style: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
            ),
            loading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.tealPrimary,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: () async {
                      if (newCtrl.text != confirmCtrl.text) {
                        _showSnack('Mật khẩu xác nhận không khớp');
                        return;
                      }
                      if (newCtrl.text.length < 6) {
                        _showSnack('Mật khẩu mới cần ít nhất 6 ký tự');
                        return;
                      }
                      setS(() => loading = true);
                      try {
                        // Re-authenticate first
                        final cred = EmailAuthProvider.credential(
                          email: _user!.email!,
                          password: currentCtrl.text,
                        );
                        await _user!.reauthenticateWithCredential(cred);
                        await _user!.updatePassword(newCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack('Đổi mật khẩu thành công ✓');
                      } on FirebaseAuthException catch (e) {
                        _showSnack(e.message ?? 'Đổi mật khẩu thất bại');
                      } finally {
                        setS(() => loading = false);
                      }
                    },
                    child: Text(
                      'Lưu',
                      style: GoogleFonts.outfit(
                        color: AppColors.tealPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _pwField(
    String hint,
    TextEditingController ctrl,
    bool obscure,
    VoidCallback toggle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? AppIcons.visibilityRounded
                  : AppIcons.visibilityOffRounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Đăng xuất',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn đăng xuất không?',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Đăng xuất',
              style: GoogleFonts.outfit(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _auth.signOut();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.navyCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _saveSettings(String userId, AppSettings settings) async {
    try {
      await _settingsService.save(userId, settings);
    } catch (error) {
      _showSnack('Không thể lưu cài đặt: $error');
    }
  }

  Future<void> _chooseLowBalanceThreshold(
    String userId,
    AppSettings settings,
  ) async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cảnh báo khi số dư dưới',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final value in const [50000.0, 100000.0, 200000.0, 500000.0])
                ListTile(
                  title: Text(
                    _formatMoney(value),
                    style: GoogleFonts.outfit(color: AppColors.textPrimary),
                  ),
                  trailing: Icon(
                    value == settings.lowBalanceThreshold
                        ? AppIcons.checkCircleRounded
                        : AppIcons.circleOutlined,
                    color: value == settings.lowBalanceThreshold
                        ? AppColors.tealPrimary
                        : AppColors.textMuted,
                  ),
                  onTap: () => Navigator.pop(sheetContext, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await _saveSettings(
        userId,
        settings.copyWith(lowBalanceThreshold: selected),
      );
    }
  }

  String _formatMoney(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '$buffer VND';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Người dùng';
    final email = user?.email ?? '';
    final isGoogleUser =
        user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Trở lại',
          icon: const Icon(
            AppIcons.arrowBackRounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Hồ sơ cá nhân',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar section ──
            _buildAvatarSection(name),
            const SizedBox(height: 28),

            // ── Info section ──
            _buildSection(
              title: 'Thông tin cá nhân',
              children: [
                _buildNameField(name),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: AppIcons.emailRounded,
                  label: 'Email',
                  value: email,
                  color: AppColors.tealPrimary,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Security section ──
            _buildSection(
              title: 'Bảo mật',
              children: [
                if (isGoogleUser)
                  _buildInfoTile(
                    icon: AppIcons.lockOutlineRounded,
                    label: 'Mật khẩu',
                    value: 'Đăng nhập bằng Google',
                    color: AppColors.textMuted,
                  )
                else
                  _buildActionTile(
                    icon: AppIcons.lockResetRounded,
                    label: 'Đổi mật khẩu',
                    color: AppColors.purpleAccent,
                    onTap: _showChangePasswordDialog,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            _buildNotificationSettings(user?.uid ?? ''),
            const SizedBox(height: 20),

            // ── Account section ──
            _buildSection(
              title: 'Tài khoản',
              children: [
                _buildActionTile(
                  icon: AppIcons.logoutRounded,
                  label: 'Đăng xuất',
                  color: AppColors.error,
                  onTap: _confirmSignOut,
                  isDestructive: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── App version ──
            Text(
              'Moni AI v1.0.0',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── WIDGETS ────────────────

  Widget _buildAvatarSection(String name) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Avatar circle
            GestureDetector(
              onTap: _showAvatarOptions,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.tealGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealPrimary.withAlpha(80),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _loadingAvatar
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : _avatarPath != null
                      ? Image.file(
                          File(_avatarPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(name),
                        )
                      : _defaultAvatar(name),
                ),
              ),
            ),
            // Camera badge
            GestureDetector(
              onTap: _showAvatarOptions,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.navyCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navyDeep, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 8),
                  ],
                ),
                child: const Icon(
                  AppIcons.cameraAltRounded,
                  color: AppColors.tealPrimary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          FirebaseAuth.instance.currentUser?.email ?? '',
          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _defaultAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 40,
        ),
      ),
    );
  }

  Widget _buildNameField(String currentName) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.income.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            AppIcons.personRounded,
            color: AppColors.income,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: _nameCtrl,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: InputDecoration(
              hintText: 'Nhập tên hiển thị',
              hintStyle: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _savingName
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.tealPrimary,
                ),
              )
            : GestureDetector(
                onTap: _saveName,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tealPrimary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.tealPrimary.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    'Lưu',
                    style: GoogleFonts.outfit(
                      color: AppColors.tealPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings(String userId) {
    if (userId.isEmpty) {
      return _buildSection(
        title: 'Thông báo',
        children: [
          Text(
            'Bạn cần đăng nhập để thay đổi cài đặt.',
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ],
      );
    }
    return StreamBuilder<AppSettings>(
      stream: _settingsService.watch(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSection(
            title: 'Thông báo',
            children: [
              Text(
                'Không tải được cài đặt thông báo.',
                style: GoogleFonts.outfit(color: AppColors.error),
              ),
            ],
          );
        }
        final settings = snapshot.data ?? AppSettings.defaults;
        return _buildSection(
          title: 'Thông báo',
          children: [
            _buildSwitchTile(
              icon: AppIcons.notificationsActiveRounded,
              label: 'Thông báo tài chính',
              subtitle: 'Ngân sách, số dư và giao dịch bất thường',
              value: settings.notificationsEnabled,
              onChanged: (value) => _saveSettings(
                userId,
                settings.copyWith(notificationsEnabled: value),
              ),
            ),
            _buildSwitchTile(
              icon: AppIcons.editCalendarRounded,
              label: 'Nhắc ghi giao dịch',
              subtitle: 'Nhắc khi hôm nay chưa có giao dịch',
              value:
                  settings.notificationsEnabled &&
                  settings.dailyReminderEnabled,
              enabled: settings.notificationsEnabled,
              onChanged: (value) => _saveSettings(
                userId,
                settings.copyWith(dailyReminderEnabled: value),
              ),
            ),
            _buildSwitchTile(
              icon: AppIcons.trendingUpRounded,
              label: 'Cảnh báo dự báo AI',
              subtitle: 'Báo khi dự kiến vượt tổng ngân sách',
              value:
                  settings.notificationsEnabled &&
                  settings.forecastWarningsEnabled,
              enabled: settings.notificationsEnabled,
              onChanged: (value) => _saveSettings(
                userId,
                settings.copyWith(forecastWarningsEnabled: value),
              ),
            ),
            _buildActionTile(
              icon: AppIcons.accountBalanceWalletOutlined,
              label:
                  'Số dư thấp: dưới ${_formatMoney(settings.lowBalanceThreshold)}',
              color: AppColors.warning,
              onTap: settings.notificationsEnabled
                  ? () => _chooseLowBalanceThreshold(userId, settings)
                  : () {},
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final color = enabled ? AppColors.tealPrimary : AppColors.textMuted;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: AppColors.tealPrimary,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: isDestructive ? color : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            AppIcons.chevronRightRounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.navyBorder),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
