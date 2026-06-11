import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import for SharedPreferences
import 'auth.dart';
import 'login_page.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'main_tabs_page.dart';

void main() {
  runApp(const ProviderScope(child: BaglaApp()));
}

class BaglaApp extends StatefulWidget {
  const BaglaApp({super.key});

  @override
  State<BaglaApp> createState() => BaglaAppState();
}

class BaglaAppState extends State<BaglaApp> {
  Locale? _locale;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initLocale();
    _checkLoginStatus();
  }

  Future<void> _initLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('preferred_locale');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _locale = Locale(saved);
      });
    } else {
      _locale = WidgetsBinding.instance.platformDispatcher.locale;
    }
  }

  void _checkLoginStatus() async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  void setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_locale', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bagla.app',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _locale ?? const Locale('tr'),
      home: _isLoggedIn
          ? const MainTabsPage()
          : SplashScreen(onLocaleChange: setLocale),
    );
  }
}

// --- SplashScreen Widget ---
class SplashScreen extends StatelessWidget {
  final void Function(Locale) onLocaleChange;
  const SplashScreen({super.key, required this.onLocaleChange});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OnboardingScreen(onLocaleChange: onLocaleChange),
        ),
      );
    });
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/mobile_logo.png',
                  height: 86,
                  width: 86,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Bagla.app',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// --- OnboardingScreen Widget ---
class OnboardingScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChange;
  const OnboardingScreen({super.key, required this.onLocaleChange});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(onLocaleChange: widget.onLocaleChange),
      ),
    );
  }

  void _switchLocale(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    final next = current == 'tr' ? const Locale('en') : const Locale('tr');
    widget.onLocaleChange(next);
  }

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final skipLabel = isTr ? 'Atla' : 'Skip';
    final nextLabel = isTr ? 'İleri' : 'Next';
    final startLabel = isTr ? 'Başlayalım' : "Let's start";

    final pages = <_OnboardPage>[
      _OnboardPage(
        badge: isTr ? 'Büyüme Platformu' : 'Growth Platform',
        title: isTr
            ? 'Sosyal medyadan\ngelen ziyaretçiyi\nrandevuya dönüştür'
            : 'Turn social media\nvisitors into\nbookings',
        desc: isTr
            ? 'Bagla, uzmanların dijital ortamda daha profesyonel görünmesini, daha az zaman harcamasını ve sosyal medyadan gelen kişileri daha kolay danışana dönüştürmesini sağlayan bir büyüme platformudur.'
            : 'Bagla is a growth platform that helps professionals look more polished online, spend less time on admin, and convert social media visitors into real clients.',
        icon: Icons.trending_up_rounded,
        highlights: isTr
            ? const ['Profesyonel dijital varlık', 'Daha az zaman kaybı', 'Daha fazla randevu']
            : const ['Professional presence', 'Less admin work', 'More bookings'],
        gradient: const [Color(0xFF0A0E1A), Color(0xFF0D2137), Color(0xFF0B3D5E)],
        accent: const Color(0xFF38BDF8),
        iconBgGradient: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      ),
      _OnboardPage(
        badge: isTr ? 'Yapay Zeka' : 'AI-Powered',
        title: isTr
            ? 'Yapay zeka ile\nprofesyonel\nprofilini oluştur'
            : 'Build your\nprofessional profile\nwith AI',
        desc: isTr
            ? 'AI destekli profil oluşturucu ile Google\'da öne çık. Mesleğine özel açıklama, hizmet listesi ve SEO uyumlu bio linkini saniyeler içinde oluştur.'
            : 'Stand out on Google with AI-powered profile creation. Generate profession-specific descriptions, service lists and an SEO-ready bio link in seconds.',
        icon: Icons.auto_awesome_rounded,
        highlights: isTr
            ? const ['Google\'da öne çık', 'SEO uyumlu profil', 'Anında yayın']
            : const ['Rank on Google', 'SEO-ready profile', 'Instant publish'],
        gradient: const [Color(0xFF0D0B1E), Color(0xFF1A1050), Color(0xFF2D1060)],
        accent: const Color(0xFFA78BFA),
        iconBgGradient: const [Color(0xFF6366F1), Color(0xFF9333EA)],
      ),
      _OnboardPage(
        badge: isTr ? 'Randevu & SMS' : 'Appointments & SMS',
        title: isTr
            ? 'Randevularını\nyönet, SMS ile\nmüşterini koru'
            : 'Manage bookings\nand retain clients\nwith SMS',
        desc: isTr
            ? 'Takvim, otomatik SMS hatırlatma ve müşteri takibi ile gününü düzenle. Daha az no-show, daha dolu randevu defteri.'
            : 'Calendar, automatic SMS reminders and client tracking. Fewer no-shows, a fuller schedule every day.',
        icon: Icons.calendar_month_rounded,
        highlights: isTr
            ? const ['Otomatik hatırlatma', 'Müşteri takibi', 'No-show önleme']
            : const ['Auto reminders', 'Client tracking', 'No-show prevention'],
        gradient: const [Color(0xFF051510), Color(0xFF073D2A), Color(0xFF0A5C3E)],
        accent: const Color(0xFF34D399),
        iconBgGradient: const [Color(0xFF059669), Color(0xFF0D9488)],
      ),
    ];

    final page = pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: page.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: page.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: page.accent.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        'bagla.app',
                        style: TextStyle(
                          color: page.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dil değiştirici
                        GestureDetector(
                          onTap: () => _switchLocale(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isTr ? '🇹🇷' : '🇬🇧',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isTr ? 'TR' : 'EN',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _goToLogin,
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            skipLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final p = pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon hero
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: p.iconBgGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: p.accent.withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(p.icon, color: Colors.white, size: 48),
                          ),
                          const SizedBox(height: 32),

                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: p.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              p.badge,
                              style: TextStyle(
                                color: p.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Title
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          Text(
                            p.desc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Highlights
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: p.highlights.map((item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.13),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: p.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dots
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pages.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 8,
                    width: _currentPage == i ? 28 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? page.accent
                          : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  )),
                ),
              ),

              // CTA button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == pages.length - 1) {
                        _goToLogin();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: page.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == pages.length - 1 ? startLabel : nextLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardPage {
  final String title;
  final String desc;
  final String badge;
  final IconData icon;
  final List<String> highlights;
  final List<Color> gradient;
  final Color accent;
  final List<Color> iconBgGradient;

  _OnboardPage({
    required this.title,
    required this.desc,
    required this.badge,
    required this.icon,
    required this.highlights,
    required this.gradient,
    required this.accent,
    required this.iconBgGradient,
  });
}

