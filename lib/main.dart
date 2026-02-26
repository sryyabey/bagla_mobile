import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import for SharedPreferences
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
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('bearer_token') ?? prefs.getString('authToken');
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final skipLabel = isTr ? 'Atla' : 'Skip';
    final nextLabel = isTr ? 'İleri' : 'Next';
    final startLabel = isTr ? 'Başlayalım' : "Let's start";
    final headerTitle = isTr
        ? 'Bio link ve randevu yönetimi'
        : 'Bio link and appointment management';
    final headerSubtitle = isTr
        ? 'Bireysel çalışan profesyoneller için tek uygulama'
        : 'One app for independent professionals';

    final pages = <_OnboardPage>[
      _OnboardPage(
        title: loc.onboardTitle1,
        desc: loc.onboardDesc1,
        image: 'assets/onboarding_biolink.png',
        badge: isTr ? 'Bio Link' : 'Bio Link',
        highlights: isTr
            ? const ['Tek link', 'Kişisel sayfa', 'Hızlı paylaşım']
            : const ['Single link', 'Personal page', 'Fast sharing'],
        gradient: const [Color(0xFF0B1020), Color(0xFF1F3B73)],
        accent: const Color(0xFF4F9CF9),
      ),
      _OnboardPage(
        title: loc.onboardTitle2,
        desc: loc.onboardDesc2,
        image: 'assets/onboarding_sms.png',
        badge: isTr ? 'Randevu' : 'Appointments',
        highlights: isTr
            ? const ['Takvim kontrolü', 'SMS hatırlatma', 'Müşteri takibi']
            : const ['Calendar control', 'SMS reminders', 'Client tracking'],
        gradient: const [Color(0xFF101927), Color(0xFF0C6A7A)],
        accent: const Color(0xFF1FC7B6),
      ),
      _OnboardPage(
        title: loc.onboardTitle3,
        desc: loc.onboardDesc3,
        image: 'assets/onboarding_free.png',
        badge: isTr ? 'Hızlı Başlangıç' : 'Quick Start',
        highlights: isTr
            ? const [
                'Dakikalar içinde yayında',
                'Büyüdükçe yükselt',
                'İşine odaklan'
              ]
            : const [
                'Go live in minutes',
                'Upgrade as you grow',
                'Focus on your work'
              ],
        gradient: const [Color(0xFF151326), Color(0xFF15514F)],
        accent: const Color(0xFF45D483),
      ),
    ];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: pages[_currentPage].gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: pages[_currentPage]
                                  .accent
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'bagla.app',
                              style: TextStyle(
                                color: pages[_currentPage].accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            headerTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            headerSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _goToLogin,
                      child: Text(
                        skipLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight),
                                child: IntrinsicHeight(
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            height: 184,
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.1),
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: page.image != null
                                                ? Image.asset(
                                                    page.image!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                page.badge,
                                                style: TextStyle(
                                                  color: page.accent,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        page.title,
                                        style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        page.desc,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          color: Colors.white70,
                                          height: 1.45,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: page.highlights
                                            .map(
                                              (item) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.15),
                                                  ),
                                                ),
                                                child: Text(
                                                  item,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const Spacer(),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          pages.length,
                                          (i) => AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 5),
                                            height: 9,
                                            width: _currentPage == i ? 30 : 11,
                                            decoration: BoxDecoration(
                                              color: _currentPage == i
                                                  ? page.accent
                                                  : Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == pages.length - 1) {
                        _goToLogin();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pages[_currentPage].accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == pages.length - 1 ? startLabel : nextLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
  final String? image;
  final String badge;
  final List<String> highlights;
  final List<Color> gradient;
  final Color accent;

  _OnboardPage({
    required this.title,
    required this.desc,
    required this.image,
    required this.badge,
    required this.highlights,
    required this.gradient,
    required this.accent,
  });
}
