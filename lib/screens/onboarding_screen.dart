import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  bool isLastPage = false;
  int _currentPage = 0;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      icon: AppIcons.accountBalanceWalletRounded,
      gradient: [Color(0xFF00D4AA), Color(0xFF0099D6)],
      title: 'Quản lý thu nhập\n& chi tiêu',
      subtitle:
          'Theo dõi mọi giao dịch của bạn một cách dễ dàng, minh bạch và thông minh.',
      badge: 'Tài chính thông minh',
    ),
    _OnboardingData(
      icon: AppIcons.psychologyRounded,
      gradient: [Color(0xFF7C6FCD), Color(0xFF5B63B7)],
      title: 'Phân tích\nbằng AI',
      subtitle:
          'AI của chúng tôi giúp bạn hiểu rõ thói quen chi tiêu và đưa ra gợi ý thông minh.',
      badge: '🤖 AI Power',
    ),
    _OnboardingData(
      icon: AppIcons.trendingUpRounded,
      gradient: [Color(0xFF00D4AA), Color(0xFF7C6FCD)],
      title: 'Dự báo &\ngợi ý tiết kiệm',
      subtitle:
          'Nhận các dự báo tài chính cá nhân hoá và lời khuyên tiết kiệm thông minh.',
      badge: '📈 Tiết kiệm',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      isLastPage = index == _pages.length - 1;
    });
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Stack(
        children: [
          // Animated background gradient that shifts per page
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.navyDeep,
                  _pages[_currentPage].gradient.last.withAlpha(25),
                ],
              ),
            ),
          ),
          // Background decorative blob
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _pages[_currentPage].gradient.first.withAlpha(64),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Page content
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),
              _buildBottomBar(),
            ],
          ),
          // Skip button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: GestureDetector(
              onTap: () {
                _controller.animateToPage(
                  _pages.length - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navyCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.navyBorder),
                ),
                child: Text(
                  'Bỏ qua',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Icon with gradient background
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: data.gradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: data.gradient.first.withAlpha(102),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Icon(data.icon, size: 64, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    data.gradient.first.withAlpha(38),
                    data.gradient.last.withAlpha(38),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: data.gradient.first.withAlpha(77)),
              ),
              child: Text(
                data.badge,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: data.gradient.first,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        28,
        20,
        28,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        children: [
          // Page indicator
          SmoothPageIndicator(
            controller: _controller,
            count: _pages.length,
            effect: ExpandingDotsEffect(
              spacing: 8,
              radius: 4,
              dotWidth: 8,
              dotHeight: 8,
              expansionFactor: 3.5,
              dotColor: AppColors.navyBorder,
              activeDotColor: _pages[_currentPage].gradient.first,
            ),
            onDotClicked: (index) => _controller.animateToPage(
              index,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: 28),
          // CTA button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLastPage ? _buildGetStartedButton() : _buildNextButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _pages[_currentPage].gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _pages[_currentPage].gradient.first.withAlpha(77),
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
          onPressed: () => _controller.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tiếp theo',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                AppIcons.arrowForwardRounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.tealGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealPrimary.withAlpha(102),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
          onPressed: () {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LoginScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                AppIcons.rocketLaunchRounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Bắt đầu ngay',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String badge;

  const _OnboardingData({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}
