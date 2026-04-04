import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/common/custom_button.dart';

class _OnboardPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardPage(
      title: 'Perfect Fit,\nEvery Time',
      subtitle:
          'Say goodbye to ill-fitting clothes. StitchSmart captures your exact body measurements using your phone camera.',
      icon: Icons.camera_alt_rounded,
      color: AppColors.primary,
      gradient: [Color(0xFF5C35E5), Color(0xFF8B6FF0)],
    ),
    _OnboardPage(
      title: 'Kurti, Blouse,\nSuit & More',
      subtitle:
          'Browse hundreds of dress styles for ladies and gents. From everyday kurtis to grand sherwanis — we cover it all.',
      icon: Icons.checkroom_rounded,
      color: Color(0xFFFF6B6B),
      gradient: [Color(0xFFFF6B6B), Color(0xFFFF9B9B)],
    ),
    _OnboardPage(
      title: 'Connect With\nYour Tailor',
      subtitle:
          'Send measurements directly to your trusted tailor. Track your order status and get notified when it\'s ready.',
      icon: Icons.handshake_rounded,
      color: Color(0xFFF5A623),
      gradient: [Color(0xFFF5A623), Color(0xFFFFC85A)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/profile-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () => context.go('/profile-setup'),
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) => _PageContent(page: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: WormEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: _pages[_currentPage].color,
                      dotColor: AppColors.divider,
                      spacing: 6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    icon: _currentPage == _pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : null,
                    onTap: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: page.color.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(page.icon, color: Colors.white, size: 80),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
