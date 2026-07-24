import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/saving_goal_model.dart';
import '../../models/wallet_model.dart';
import '../../services/database_service.dart';
import '../../services/saving_goal_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/vnd_input_formatter.dart';

class SavingGoalsScreen extends StatefulWidget {
  const SavingGoalsScreen({super.key});

  @override
  State<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends State<SavingGoalsScreen> {
  final _service = SavingGoalService();
  List<SavingGoal> _goals = [];
  double _averageSaving = 0;
  bool _loading = true;
  String _filter = 'all';

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _service.getGoals(_userId),
        _service.averageMonthlySaving(_userId),
      ]);
      if (!mounted) return;
      setState(() {
        _goals = results[0] as List<SavingGoal>;
        _averageSaving = results[1] as double;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  List<SavingGoal> get _visibleGoals => _filter == 'all'
      ? _goals
      : _goals.where((goal) => goal.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Mục tiêu tiết kiệm',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tealPrimary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.tealPrimary,
              backgroundColor: AppColors.navyCard,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _summary()),
                  SliverToBoxAdapter(child: _filters()),
                  if (_visibleGoals.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                      sliver: SliverList.separated(
                        itemCount: _visibleGoals.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) =>
                            _goalCard(_visibleGoals[index]),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.tealPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(AppIcons.addRounded),
        label: Text(
          'Tạo mục tiêu',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _summary() {
    final saved = _goals.fold<double>(0, (sum, goal) => sum + goal.savedAmount);
    final target = _goals.fold<double>(
      0,
      (sum, goal) => sum + goal.targetAmount,
    );
    final completed = _goals.where((goal) => goal.status == 'completed').length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.balanceCardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealPrimary.withAlpha(45),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(AppIcons.savingsRounded, color: Colors.white),
              ),
              const Spacer(),
              Text(
                '$completed/${_goals.length} hoàn thành',
                style: GoogleFonts.outfit(
                  color: Colors.white.withAlpha(210),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Tổng tiền đã tiết kiệm',
            style: GoogleFonts.outfit(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(saved),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Mục tiêu ${_money(target)}',
            style: GoogleFonts.outfit(
              color: Colors.white.withAlpha(190),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    const filters = {
      'all': 'Tất cả',
      'active': 'Đang thực hiện',
      'completed': 'Hoàn thành',
      'paused': 'Tạm dừng',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: filters.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _filter = entry.key),
              label: Text(entry.value),
              labelStyle: GoogleFonts.outfit(
                color: selected ? AppColors.navyDeep : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: AppColors.tealPrimary,
              backgroundColor: AppColors.navyCard,
              side: BorderSide(
                color: selected ? AppColors.tealPrimary : AppColors.navyBorder,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _goalCard(SavingGoal goal) {
    final warning =
        goal.isOverdue ||
        (_averageSaving > 0 && goal.requiredPerMonth > _averageSaving);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SavingGoalDetailScreen(goalId: goal.id),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: warning
                ? AppColors.warning.withAlpha(120)
                : goal.displayColor.withAlpha(80),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: goal.displayColor.withAlpha(31),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    goal.iconData,
                    color: goal.displayColor,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_money(goal.savedAmount)} / ${_money(goal.targetAmount)}',
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${goal.progressPercent.round()}%',
                  style: GoogleFonts.outfit(
                    color: goal.displayColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: goal.progressPercent / 100,
                backgroundColor: AppColors.navyDeep,
                valueColor: AlwaysStoppedAnimation(goal.displayColor),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _meta(
                  AppIcons.eventRounded,
                  goal.isOverdue
                      ? 'Đã quá hạn'
                      : 'Còn ${goal.monthsRemaining} tháng',
                  goal.isOverdue ? AppColors.error : AppColors.textSecondary,
                ),
                const Spacer(),
                _meta(
                  AppIcons.calendarViewMonthRounded,
                  '${_money(goal.requiredPerMonth)}/tháng',
                  warning ? AppColors.warning : AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String value, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 5),
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 11)),
    ],
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            AppIcons.savingsOutlined,
            color: AppColors.textMuted,
            size: 70,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có mục tiêu tiết kiệm',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Tạo mục tiêu đầu tiên để biến kế hoạch thành tiến độ rõ ràng.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  Future<void> _create() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditSavingGoalScreen()),
    );
    if (changed == true) _load();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }
}

class AddEditSavingGoalScreen extends StatefulWidget {
  final SavingGoal? goal;
  const AddEditSavingGoalScreen({super.key, this.goal});

  @override
  State<AddEditSavingGoalScreen> createState() =>
      _AddEditSavingGoalScreenState();
}

class _AddEditSavingGoalScreenState extends State<AddEditSavingGoalScreen> {
  final _service = SavingGoalService();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController(text: '0');
  final _note = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 365));
  String _icon = 'savings';
  int _color = 0xFF00D4AA;
  bool _saving = false;

  bool get _editing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _name.text = goal.name;
      _target.text = formatVndInput(goal.targetAmount);
      _saved.text = formatVndInput(goal.savedAmount);
      _note.text = goal.note ?? '';
      _deadline = goal.deadline;
      _icon = goal.icon;
      _color = goal.color;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          _editing ? 'Chỉnh sửa mục tiêu' : 'Tạo mục tiêu',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preview(),
            const SizedBox(height: 22),
            _label('Tên mục tiêu'),
            _field(
              controller: _name,
              hint: 'Ví dụ: Mua laptop',
              icon: AppIcons.flagRounded,
            ),
            const SizedBox(height: 16),
            _label('Số tiền'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _target,
                    hint: 'Mục tiêu',
                    icon: AppIcons.trackChangesRounded,
                    number: true,
                    suffix: '₫',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    controller: _saved,
                    hint: 'Đã có',
                    icon: AppIcons.savingsRounded,
                    number: true,
                    suffix: '₫',
                    readOnly: _editing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              _editing
                  ? 'Số tiền đã tiết kiệm chỉ thay đổi qua Thêm tiền/Rút tiền.'
                  : '“Đã có” là khoản bạn đã tiết kiệm trước khi dùng Moni AI.',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            _label('Hạn hoàn thành'),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(16),
              child: _box(
                Row(
                  children: [
                    const Icon(
                      AppIcons.eventAvailableRounded,
                      color: AppColors.tealPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_deadline),
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      AppIcons.chevronRightRounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _label('Biểu tượng'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: savingGoalIcons.entries
                  .map(
                    (entry) =>
                        _choiceIcon(entry.key, entry.value, _icon == entry.key),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            _label('Màu sắc'),
            Wrap(
              spacing: 12,
              children:
                  [
                        0xFF00D4AA,
                        0xFF60A5FA,
                        0xFFA78BFA,
                        0xFFFF6B9D,
                        0xFFFBBF24,
                        0xFF4ADE80,
                      ]
                      .map(
                        (value) => InkWell(
                          onTap: () => setState(() => _color = value),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == value
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: _color == value
                                ? const Icon(
                                    AppIcons.checkRounded,
                                    color: Colors.white,
                                    size: 19,
                                  )
                                : null,
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 18),
            _label('Ghi chú'),
            _field(
              controller: _note,
              hint: 'Kế hoạch hoặc động lực của bạn...',
              icon: AppIcons.notesRounded,
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(AppIcons.checkCircleRounded),
                label: Text(
                  _editing ? 'Lưu thay đổi' : 'Tạo mục tiêu',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Color(_color).withAlpha(22),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Color(_color).withAlpha(110)),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Color(_color).withAlpha(36),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(savingGoalIcons[_icon], color: Color(_color), size: 29),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _name.text.trim().isEmpty ? 'Mục tiêu của bạn' : _name.text,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      value,
      style: GoogleFonts.outfit(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool number = false,
    String? suffix,
    int maxLines = 1,
    bool readOnly = false,
  }) => TextField(
    controller: controller,
    readOnly: readOnly,
    maxLines: maxLines,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    inputFormatters: number ? const [VndInputFormatter()] : null,
    onChanged: (_) => setState(() {}),
    style: GoogleFonts.outfit(color: AppColors.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixText: suffix,
    ),
  );

  Widget _box(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    decoration: BoxDecoration(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.navyBorder),
    ),
    child: child,
  );

  Widget _choiceIcon(String key, IconData icon, bool selected) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => setState(() => _icon = key),
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: selected ? Color(_color).withAlpha(35) : AppColors.navyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? Color(_color) : AppColors.navyBorder,
        ),
      ),
      child: Icon(icon, color: selected ? Color(_color) : AppColors.textMuted),
    ),
  );

  Future<void> _pickDeadline() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: _editing
          ? DateTime(2020)
          : DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => _deadline = value);
  }

  Future<void> _save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return _error('Người dùng chưa đăng nhập.');
    if (_name.text.trim().isEmpty) return _error('Vui lòng nhập tên mục tiêu.');
    final target = parseVndInput(_target.text) ?? 0;
    final saved = parseVndInput(_saved.text) ?? 0;
    setState(() => _saving = true);
    try {
      if (_editing) {
        await _service.updateGoal(
          widget.goal!.copyWith(
            name: _name.text.trim(),
            targetAmount: target,
            savedAmount: saved,
            deadline: _deadline,
            icon: _icon,
            color: _color,
            note: _note.text.trim(),
          ),
        );
      } else {
        await _service.createGoal(
          userId: userId,
          name: _name.text,
          targetAmount: target,
          savedAmount: saved,
          deadline: _deadline,
          icon: _icon,
          color: _color,
          note: _note.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _error(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.error, content: Text(message)),
    );
  }
}

class SavingGoalDetailScreen extends StatefulWidget {
  final String goalId;
  const SavingGoalDetailScreen({super.key, required this.goalId});

  @override
  State<SavingGoalDetailScreen> createState() => _SavingGoalDetailScreenState();
}

class _SavingGoalDetailScreenState extends State<SavingGoalDetailScreen> {
  final _service = SavingGoalService();
  final _database = DatabaseService();
  SavingGoal? _goal;
  List<SavingGoalContribution> _history = [];
  List<WalletModel> _wallets = [];
  double _averageSaving = 0;
  bool _loading = true;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getGoal(_userId, widget.goalId),
        _service.getContributions(_userId, widget.goalId),
        _database.getWallets(_userId),
        _service.averageMonthlySaving(_userId),
      ]);
      if (!mounted) return;
      setState(() {
        _goal = results[0] as SavingGoal?;
        _history = results[1] as List<SavingGoalContribution>;
        _wallets = results[2] as List<WalletModel>;
        _averageSaving = results[3] as double;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyMid,
        title: Text(
          'Chi tiết mục tiêu',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tealPrimary),
            )
          : goal == null
          ? const Center(child: Text('Mục tiêu không tồn tại.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                children: [
                  _hero(goal),
                  const SizedBox(height: 14),
                  _metrics(goal),
                  const SizedBox(height: 12),
                  _managementActions(goal),
                  if (goal.isOverdue ||
                      (_averageSaving > 0 &&
                          goal.requiredPerMonth > _averageSaving)) ...[
                    const SizedBox(height: 14),
                    _warning(goal),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Lịch sử đóng góp',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    _emptyHistory()
                  else
                    ..._history.map(_historyTile),
                ],
              ),
            ),
      bottomNavigationBar: goal == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                color: AppColors.navyMid,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            goal.status == 'paused' ||
                                goal.status == 'cancelled'
                            ? null
                            : () => _contribution('withdraw'),
                        icon: const Icon(AppIcons.removeRounded),
                        label: const Text('Rút tiền'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            goal.status == 'paused' ||
                                goal.status == 'cancelled'
                            ? null
                            : () => _contribution('deposit'),
                        icon: const Icon(AppIcons.addRounded),
                        label: const Text('Thêm tiền'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _hero(SavingGoal goal) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: goal.displayColor.withAlpha(22),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: goal.displayColor.withAlpha(100)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: goal.displayColor.withAlpha(35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(goal.iconData, color: goal.displayColor, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _statusName(goal.status),
                    style: GoogleFonts.outfit(
                      color: goal.displayColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${goal.progressPercent.round()}%',
              style: GoogleFonts.outfit(
                color: goal.displayColor,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: goal.progressPercent / 100,
            minHeight: 12,
            backgroundColor: AppColors.navyDeep,
            valueColor: AlwaysStoppedAnimation(goal.displayColor),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _money(goal.savedAmount),
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              _money(goal.targetAmount),
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _metrics(SavingGoal goal) => Row(
    children: [
      Expanded(
        child: _metric(
          AppIcons.accountBalanceWalletRounded,
          'Còn thiếu',
          _money(goal.remainingAmount),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _metric(
          AppIcons.eventRounded,
          'Hạn hoàn thành',
          DateFormat('dd/MM/yyyy').format(goal.deadline),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _metric(
          AppIcons.calendarViewMonthRounded,
          'Mỗi tháng',
          _money(goal.requiredPerMonth),
        ),
      ),
    ],
  );

  Widget _managementActions(SavingGoal goal) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _managementButton(
        AppIcons.editRounded,
        'Chỉnh sửa',
        () => _menuAction('edit'),
      ),
      _managementButton(
        goal.status == 'paused'
            ? AppIcons.playArrowRounded
            : AppIcons.pauseRounded,
        goal.status == 'paused' ? 'Tiếp tục' : 'Tạm dừng',
        () => _menuAction('pause'),
      ),
      _managementButton(
        AppIcons.checkCircleOutlineRounded,
        'Hoàn thành',
        () => _menuAction('complete'),
      ),
      _managementButton(
        AppIcons.deleteOutlineRounded,
        'Xóa',
        () => _menuAction('delete'),
        color: AppColors.error,
      ),
    ],
  );

  Widget _managementButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color color = AppColors.textSecondary,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withAlpha(100)),
      visualDensity: VisualDensity.compact,
    ),
  );

  Widget _metric(IconData icon, String label, String value) => Container(
    height: 112,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.navyBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.tealPrimary, size: 19),
        const Spacer(),
        Text(
          label,
          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _warning(SavingGoal goal) {
    final message = goal.isOverdue
        ? 'Bạn đã quá hạn mục tiêu này.'
        : 'Mục tiêu này có thể khó hoàn thành đúng hạn.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.warningAmberRounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(SavingGoalContribution item) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.navyBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                (item.type == 'deposit' ? AppColors.income : AppColors.warning)
                    .withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.type == 'deposit'
                ? AppIcons.addRounded
                : AppIcons.removeRounded,
            color: item.type == 'deposit'
                ? AppColors.income
                : AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.type == 'deposit' ? 'Thêm tiền' : 'Rút tiền',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${DateFormat('dd/MM/yyyy').format(item.createdAt)}'
                '${item.note?.isNotEmpty == true ? ' • ${item.note}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${item.type == 'deposit' ? '+' : '-'}${_money(item.amount)}',
          style: GoogleFonts.outfit(
            color: item.type == 'deposit'
                ? AppColors.income
                : AppColors.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _emptyHistory() => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: AppColors.navyCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.navyBorder),
    ),
    child: Center(
      child: Text(
        'Chưa có khoản đóng góp nào.',
        style: GoogleFonts.outfit(color: AppColors.textMuted),
      ),
    ),
  );

  Future<void> _contribution(String type) async {
    if (_wallets.isEmpty) return _error('Bạn cần tạo ví trước.');
    WalletModel wallet = WalletModel.preferred(_wallets)!;
    final amount = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.navyCard,
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
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  type == 'deposit'
                      ? 'Thêm tiền vào mục tiêu'
                      : 'Rút tiền khỏi mục tiêu',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [VndInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Số tiền',
                    prefixIcon: Icon(AppIcons.paymentsRounded),
                    suffixText: '₫',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WalletModel>(
                  initialValue: wallet,
                  dropdownColor: AppColors.navyCard,
                  decoration: const InputDecoration(
                    labelText: 'Chọn ví',
                    prefixIcon: Icon(AppIcons.accountBalanceWalletRounded),
                  ),
                  items: _wallets
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            '${value.name} • ${_money(value.balance)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) wallet = value;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.navyBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.eventRounded,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Text(DateFormat('dd/MM/yyyy').format(date)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    prefixIcon: Icon(AppIcons.notesRounded),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'deposit'
                          ? AppColors.tealPrimary
                          : AppColors.warning,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      type == 'deposit'
                          ? 'Xác nhận thêm tiền'
                          : 'Xác nhận rút tiền',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.contribute(
        userId: _userId,
        goalId: widget.goalId,
        walletId: wallet.id!,
        amount: parseVndInput(amount.text) ?? 0,
        type: type,
        date: date,
        note: note.text,
      );
      await _load();
    } catch (error) {
      _error(error);
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Future<void> _menuAction(String action) async {
    final goal = _goal!;
    try {
      if (action == 'edit') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditSavingGoalScreen(goal: goal),
          ),
        );
        return _load();
      }
      if (action == 'pause') {
        await _service.setStatus(
          _userId,
          goal.id,
          goal.status == 'paused' ? 'active' : 'paused',
        );
      } else if (action == 'complete') {
        await _service.setStatus(_userId, goal.id, 'completed');
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.navyCard,
            title: const Text('Xóa mục tiêu?'),
            content: const Text(
              'Lịch sử đóng góp của mục tiêu cũng sẽ bị xóa. '
              'Các giao dịch đã xác nhận vẫn được giữ lại.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _service.deleteGoal(_userId, goal.id);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      await _load();
    } catch (error) {
      _error(error);
    }
  }

  void _error(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text(error.toString().replaceFirst('Bad state: ', '')),
      ),
    );
  }
}

String _money(double amount) =>
    '${NumberFormat.decimalPattern('vi_VN').format(amount.round())}₫';

String _statusName(String status) => switch (status) {
  'completed' => 'Đã hoàn thành',
  'paused' => 'Đang tạm dừng',
  'cancelled' => 'Đã hủy',
  _ => 'Đang thực hiện',
};
