import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/widgets/app_snackbar.dart';
import 'road_scenes.dart';

/// The company page, after smarttrack.com.tr. Each section has a look of its
/// own - colour tiles, a list, a timeline - so the page does not read as one
/// box after another. Every block sizes to its text, so a longer translation
/// or a larger system font grows it instead of overflowing it.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _phone = '+90 312 544 28 68';
  static const _email = 'info@smarttrack.com.tr';
  static const _website = 'smarttrack.com.tr';
  static const _linkedin =
      'https://www.linkedin.com/company/smarttrackteknoloji/';
  static const _slogan = 'Track Smarter, Drive Safer';
  static const _address =
      'Ankara Teknopark TGB Yerleşkesi, İvedik OSB Mah. 2224. Cad. No:1 '
      'İç Kapı No:9 Kat:1, Yenimahalle / Ankara - TÜRKİYE';

  static const _stats = [
    ('300+', 'about.statCustomers', Icons.groups_outlined),
    ('100.000+', 'about.statTachographs', Icons.speed_outlined),
    ('20+', 'about.statYears', Icons.workspace_premium_outlined),
  ];

  static const _expertise = [
    (Icons.local_shipping_outlined, 'about.s1Title', 'about.s1Body'),
    (Icons.gavel_outlined, 'about.s2Title', 'about.s2Body'),
    (Icons.health_and_safety_outlined, 'about.s3Title', 'about.s3Body'),
    (Icons.eco_outlined, 'about.s4Title', 'about.s4Body'),
  ];

  static const _services = [
    (Icons.speed_outlined, 'about.sv1Title', 'about.sv1Body'),
    (Icons.verified_user_outlined, 'about.sv2Title', 'about.sv2Body'),
    (Icons.insights_outlined, 'about.sv3Title', 'about.sv3Body'),
    (Icons.energy_savings_leaf_outlined, 'about.sv4Title', 'about.sv4Body'),
    (Icons.shield_outlined, 'about.sv5Title', 'about.sv5Body'),
    (Icons.public, 'about.sv6Title', 'about.sv6Body'),
  ];

  static const _steps = [
    (Icons.search, 'about.p1Title', 'about.p1Body'),
    (Icons.route_outlined, 'about.p2Title', 'about.p2Body'),
    (Icons.settings_suggest_outlined, 'about.p3Title', 'about.p3Body'),
    (Icons.support_agent, 'about.p4Title', 'about.p4Body'),
  ];

  static const _products = [
    (Icons.speed_outlined, 'Aselsan STC-8255', 'about.prodTacho'),
    (Icons.tune_outlined, 'Aselsan STKC-8250', 'about.prodCalibration'),
  ];

  static final Uri _telUri = Uri(scheme: 'tel', path: '+903125442868');
  static final Uri _mailUri = Uri(scheme: 'mailto', path: _email);

  /// The office on the map: Google Maps opens in its app when it is there,
  /// in the browser otherwise.
  static final Uri _mapUri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': 'SmartTrack Ankara Teknopark İvedik OSB 2224. Cadde No:1 Ankara',
  });

  /// Hands the link to the phone: the dialer for tel:, the mail app for
  /// mailto:, the browser or the app that owns the address for https:. Not
  /// asked about first with canLaunchUrl - on Android 11+ that answers no
  /// for anything the manifest does not list, which is why the links did
  /// nothing before.
  static Future<void> _launch(
    BuildContext context,
    Uri uri,
    String failed,
  ) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      showAppSnackBar(context, failed, type: AppSnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = AppStateProvider.of(context).selectedLanguage;
    String t(String key) => AppLocalizations.getText(lang, key);
    void open(Uri uri) => _launch(context, uri, t('about.linkFailed'));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(t('about.title')),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 768;
          final gutter = wide ? 48.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(t: t, wide: wide),
                    const SizedBox(height: 24),
                    _Reveal(
                      delay: const Duration(milliseconds: 300),
                      child: _StatsBand(t: t),
                    ),
                    const SizedBox(height: 44),
                    _SectionTitle(t('about.expertise')),
                    const SizedBox(height: 18),
                    _CardGrid(
                      columns: wide ? 4 : 2,
                      minCardWidth: 150,
                      children: [
                        for (var i = 0; i < _expertise.length; i++)
                          _Reveal(
                            pop: true,
                            delay: Duration(milliseconds: 90 * i),
                            child: _ColorTile(
                              index: i,
                              icon: _expertise[i].$1,
                              title: t(_expertise[i].$2),
                              body: t(_expertise[i].$3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    _SectionTitle(t('about.servicesTitle')),
                    const SizedBox(height: 10),
                    _ServiceList(t: t, wide: wide),
                    const SizedBox(height: 36),
                    _SloganBanner(wide: wide),
                    const SizedBox(height: 44),
                    _SectionTitle(
                      t('about.process'),
                      subtitle: t('about.processSub'),
                    ),
                    const SizedBox(height: 22),
                    _Timeline(t: t, wide: wide),
                    const SizedBox(height: 44),
                    _SectionTitle(t('about.products')),
                    const SizedBox(height: 18),
                    _CardGrid(
                      columns: 2,
                      minCardWidth: 260,
                      children: [
                        for (var i = 0; i < _products.length; i++)
                          _Reveal(
                            delay: Duration(milliseconds: 120 * i),
                            child: _ProductCard(
                              icon: _products[i].$1,
                              name: _products[i].$2,
                              kind: t(_products[i].$3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    _Reveal(
                      child: _CallToAction(
                        t: t,
                        onCall: () => open(_telUri),
                        onMail: () => open(_mailUri),
                        onMap: () => open(_mapUri),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Reveal(
                      child: _ContactCard(
                        t: t,
                        rows: [
                          _ContactRow(
                            icon: Icons.location_on_outlined,
                            text: _address,
                            actionIcon: Icons.map_outlined,
                            onTap: () => open(_mapUri),
                          ),
                          _ContactRow(
                            icon: Icons.call_outlined,
                            text: _phone,
                            actionIcon: Icons.phone_forwarded_outlined,
                            onTap: () => open(_telUri),
                          ),
                          _ContactRow(
                            icon: Icons.mail_outline,
                            text: _email,
                            onTap: () => open(_mailUri),
                          ),
                          _ContactRow(
                            icon: Icons.language,
                            text: _website,
                            onTap: () => open(Uri.https(_website, '/tr/')),
                          ),
                          _ContactRow(
                            icon: Icons.work_outline,
                            text: 'LinkedIn',
                            onTap: () => open(Uri.parse(_linkedin)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _Reveal(
                      pop: true,
                      child: Center(child: Image.asset('logo.png', height: 36)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('about.closing'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.fill(t('about.rights'), {
                        'year': DateTime.now().year,
                      }),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.t, required this.wide});
  final String Function(String) t;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 8)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _LogoIntro()),
        const SizedBox(height: 8),
        _Reveal(
          pop: true,
          delay: const Duration(milliseconds: 500),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 16, color: scheme.onPrimary),
                  const SizedBox(width: 6),
                  // Flexible: the badge wraps on a narrow phone instead of
                  // running off the screen.
                  Flexible(
                    child: Text(
                      t('about.badge'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // The site's opening picture, drawn: a highway at dusk, the title
        // over it.
        _Reveal(
          delay: const Duration(milliseconds: 600),
          child: SceneBanner(
            scene: RoadScene.highway,
            height: wide ? 340 : 300,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('about.heroTitle'),
                    style: TextStyle(
                      fontSize: wide ? 32 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: Colors.white,
                      shadows: shadow,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('about.intro'),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xEEFFFFFF),
                      shadows: shadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A drawn truck rolling along between the sections, the slogan over it.
class _SloganBanner extends StatelessWidget {
  const _SloganBanner({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) => _Reveal(
    child: SceneBanner(
      scene: RoadScene.sideTruck,
      height: wide ? 240 : 190,
      alignment: Alignment.topCenter,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Text(
          AboutPage._slogan,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
          ),
        ),
      ),
    ),
  );
}

class _StatsBand extends StatelessWidget {
  const _StatsBand({required this.t});
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < AboutPage._stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(AboutPage._stats[i].$3, color: scheme.primary),
                  const SizedBox(height: 6),
                  // A third of a 320 px phone is not wide enough for
                  // "100.000+" at this size; it scales down rather than wrap.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountUp(
                      AboutPage._stats[i].$1,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t(AboutPage._stats[i].$2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The expertise: solid colour tiles, each its own colour, with the icon
/// large and faint in the corner.
class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int index;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (index % 4) {
      0 => (scheme.primary, scheme.onPrimary),
      1 => (scheme.tertiary, scheme.onTertiary),
      2 => (scheme.secondary, scheme.onSecondary),
      _ => (scheme.inverseSurface, scheme.onInverseSurface),
    };
    return _Pressable(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg, Color.lerp(bg, Colors.black, 0.22)!],
          ),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -14,
              child: Icon(icon, size: 96, color: fg.withValues(alpha: 0.12)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: fg, size: 30),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: fg.withValues(alpha: 0.88),
                    ),
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

/// The services: an open list - icon, title, text, a hairline between -
/// that slides in from the side, two columns on a wide screen.
class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.t, required this.wide});
  final String Function(String) t;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      for (var i = 0; i < AboutPage._services.length; i++)
        _Reveal(
          fromSide: true,
          delay: Duration(milliseconds: 70 * (wide ? i ~/ 2 : i % 3)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    AboutPage._services[i].$1,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(AboutPage._services[i].$2),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(AboutPage._services[i].$3),
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
    final divider = Divider(height: 1, color: scheme.outlineVariant);
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) divider,
            items[i],
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) divider,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 28),
              Expanded(
                child: i + 1 < items.length
                    ? items[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The way of working as a timeline: numbered stops joined by a line, down
/// the page on a phone, across it on a wide screen.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.t, required this.wide});
  final String Function(String) t;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = AboutPage._steps;

    Widget stop(int i) => _Reveal(
      pop: true,
      delay: Duration(milliseconds: 160 * i),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '${i + 1}',
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    Widget texts(int i, TextAlign align) => _Reveal(
      delay: Duration(milliseconds: 160 * i + 100),
      child: Column(
        crossAxisAlignment: align == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(steps[i].$1, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  t(steps[i].$2),
                  textAlign: align,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t(steps[i].$3),
            textAlign: align,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (wide) {
      return Stack(
        children: [
          Positioned(
            top: 25,
            left: 60,
            right: 60,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        stop(i),
                        const SizedBox(height: 12),
                        texts(i, TextAlign.center),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      stop(i),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  scheme.primary,
                                  scheme.tertiary.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 12,
                      bottom: i < steps.length - 1 ? 26 : 0,
                    ),
                    child: texts(i, TextAlign.start),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.icon,
    required this.name,
    required this.kind,
  });

  final IconData icon;
  final String name;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pressable(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: scheme.onPrimary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: scheme.onSurfaceVariant,
                    ),
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

/// "Bize ulaşın": a strong colour block with light buttons on it, so
/// nothing sinks into the background.
class _CallToAction extends StatelessWidget {
  const _CallToAction({
    required this.t,
    required this.onCall,
    required this.onMail,
    required this.onMap,
  });

  final String Function(String) t;
  final VoidCallback onCall;
  final VoidCallback onMail;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.7)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Icons.support_agent,
              size: 150,
              color: on.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('about.ctaTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: on,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('about.ctaBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: on.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: on,
                        foregroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onCall,
                      icon: const Icon(Icons.call),
                      label: Text(t('about.call')),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: on,
                        foregroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onMail,
                      icon: const Icon(Icons.mail_outline),
                      label: Text(t('about.sendMail')),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: on,
                        side: BorderSide(color: on, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onMap,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(t('about.openMap')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.t, required this.rows});
  final String Function(String) t;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              t('about.contact'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// A section heading with an accent bar under it that grows in.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.subtitle});
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Reveal(
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              width: 56 * v,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cards in rows of [columns], dropping to fewer columns when a card would
/// be narrower than [minCardWidth]. Each row is as tall as its tallest card,
/// so the text decides the height - nothing is clipped.
class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.columns,
    required this.minCardWidth,
    required this.children,
  });

  final int columns;
  final double minCardWidth;
  final List<Widget> children;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var n = columns;
      while (n > 1 &&
          (constraints.maxWidth - _gap * (n - 1)) / n < minCardWidth) {
        n--;
      }
      return Column(
        children: [
          for (var start = 0; start < children.length; start += n) ...[
            if (start > 0) const SizedBox(height: _gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + n; i++) ...[
                    if (i > start) const SizedBox(width: _gap),
                    Expanded(
                      child: i < children.length
                          ? children[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Lifts a little under the mouse and gives under a finger.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child});
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : (_hover ? 1.03 : 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
    this.onTap,
    this.actionIcon = Icons.open_in_new,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8),
                child: Icon(actionIcon, size: 20, color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

/// The big logo on top: it springs in, with a ring that spreads out and
/// fades once behind it.
class _LogoIntro extends StatefulWidget {
  const _LogoIntro();

  @override
  State<_LogoIntro> createState() => _LogoIntroState();
}

class _LogoIntroState extends State<_LogoIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _logo = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );
  late final Animation<double> _ring = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      height: 130,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - _ring.value) * 0.6,
              child: Transform.scale(
                scale: 0.5 + 1.1 * _ring.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 3),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: _fade.value.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -0.12 * (1 - _logo.value),
                child: Transform.scale(
                  scale: 0.4 + 0.6 * _logo.value,
                  child: Image.asset('logo.png', height: 96),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades its child in the first time it scrolls into view, sliding up - or
/// in from the side with [fromSide] - or, with [pop], scaling up with a
/// little overshoot. Shown at once when the system asks for reduced motion.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.pop = false,
    this.fromSide = false,
  });

  final Widget child;
  final Duration delay;
  final bool pop;
  final bool fromSide;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 650);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + _length,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _length).inMilliseconds,
      1,
      curve: widget.pop ? Curves.easeOutBack : Curves.easeOutCubic,
    ),
  );

  ScrollPosition? _position;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _started = true;
      _controller.value = 1;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_check);
      _position = position?..addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.92) {
      _started = true;
      _position?.removeListener(_check);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) {
      final v = _t.value;
      final Widget moved;
      if (widget.pop) {
        moved = Transform.scale(scale: 0.6 + 0.4 * v, child: child);
      } else if (widget.fromSide) {
        moved = Transform.translate(
          offset: Offset(-36 * (1 - v), 0),
          child: child,
        );
      } else {
        moved = Transform.translate(
          offset: Offset(0, 28 * (1 - v)),
          child: child,
        );
      }
      return Opacity(opacity: v.clamp(0.0, 1.0), child: moved);
    },
  );
}

/// Counts a figure like "100.000+" up from zero, keeping its dot grouping
/// and whatever follows the number.
class _CountUp extends StatelessWidget {
  const _CountUp(this.text, {required this.style});

  final String text;
  final TextStyle style;

  static String _group(int v) {
    final s = v.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
      out.write(s[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^([\d.]+)(.*)$').firstMatch(text);
    if (m == null || MediaQuery.of(context).disableAnimations) {
      return Text(text, maxLines: 1, style: style);
    }
    final target = int.parse(m.group(1)!.replaceAll('.', ''));
    final suffix = m.group(2)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('${_group(v.round())}$suffix', maxLines: 1, style: style),
    );
  }
}
