import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import for SharedPreferences
import 'dashboard_page.dart';
import 'login_page.dart';
import 'app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: BaglaApp()));
}

class BaglaApp extends StatefulWidget {
  const BaglaApp({super.key});

  @override
  State<BaglaApp> createState() => _BaglaAppState();
}

class _BaglaAppState extends State<BaglaApp> {
  Locale? _locale;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _locale = WidgetsBinding.instance.platformDispatcher.locale;
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bearer_token') ?? prefs.getString('authToken');
    if (token != null && token.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
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
          ? const DashboardPage()
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
            Image.asset(
              'assets/logo.png',
              height: 100,
              fit: BoxFit.contain,
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
    final loc = AppLocalizations.of(context)!;

    final pages = <_OnboardPage>[
      _OnboardPage(
        title: loc.onboardTitle1,
        desc: loc.onboardDesc1,
        image: 'assets/onboarding_biolink.png',
        gradient: const [Color(0xFF0F172A), Color(0xFF312E81)],
        accent: const Color(0xFF7C3AED),
      ),
      _OnboardPage(
        title: loc.onboardTitle2,
        desc: loc.onboardDesc2,
        image: 'assets/onboarding_sms.png',
        gradient: const [Color(0xFF0B1224), Color(0xFF0EA5E9)],
        accent: const Color(0xFF22D3EE),
      ),
      _OnboardPage(
        title: loc.onboardTitle3,
        desc: loc.onboardDesc3,
        image: 'assets/onboarding_free.png',
        gradient: const [Color(0xFF0F172A), Color(0xFF14B8A6)],
        accent: const Color(0xFF34D399),
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
                  children: [
                    Chip(
                      backgroundColor:
                          pages[_currentPage].accent.withOpacity(0.15),
                      label: const Text(
                        'Bagla.app',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text(
                        'Atla',
                        style: TextStyle(
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
                          horizontal: 24, vertical: 28),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
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
                            Column(
                              children: [
                                Text(
                                  page.title,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  page.desc,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                pages.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  height: 10,
                                  width: _currentPage == i ? 32 : 12,
                                  decoration: BoxDecoration(
                                    color: _currentPage == i
                                        ? page.accent
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      _currentPage == pages.length - 1 ? 'Başla' : 'İleri',
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
  final List<Color> gradient;
  final Color accent;

  _OnboardPage({
    required this.title,
    required this.desc,
    required this.image,
    required this.gradient,
    required this.accent,
  });
}
