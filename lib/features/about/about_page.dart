import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _stats = [
    ('300+', 'Müşteri'),
    ('100.000+', 'Takograf'),
    ('20+', 'Yıl Deneyim'),
  ];

  static const _services = [
    (
      Icons.local_shipping_outlined,
      'Filo Yönetimi',
      'Sektöre özel ihtiyaçları karşılamak üzere uyarlanmış akıllı takip çözümleri.',
    ),
    (
      Icons.gavel_outlined,
      'Düzenleyici Uyumluluk',
      'En son küresel standartlara ve yasal mevzuatlara tam uygunluk.',
    ),
    (
      Icons.health_and_safety_outlined,
      'Yol Güvenliği',
      'Sürücü ve yük güvenliğini artıran yenilikçi güvenlik teknolojileri.',
    ),
    (
      Icons.eco_outlined,
      'Sürdürülebilirlik',
      'Verimliliği artıran ve çevresel etkiyi azaltan uygulamalar.',
    ),
  ];

  static const _steps = [
    (
      '1',
      'Değerlendirme',
      'Filo yönetimi ihtiyaçlarınızı analiz ederek iyileştirme alanlarını belirliyoruz.',
    ),
    (
      '2',
      'Stratejik Planlama',
      'Operasyonel verimliliği ve uyumluluğu artırmak için özel stratejiler geliştiriyoruz.',
    ),
    (
      '3',
      'Uygulama',
      'Gelişmiş takograf sistemlerini operasyonlarınıza entegre ediyoruz.',
    ),
    (
      '4',
      'Sürekli Destek',
      'Sorunsuz performans için sürekli bakım, güncelleme ve uzman desteği sağlıyoruz.',
    ),
  ];

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Hakkımızda'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset('logo.png', height: 28),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 48 : 16,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ASELSAN\'IN TEK KÜRESEL DİSTRİBÜTÖRÜ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filo Yönetimi Teknolojisinde Yenilikler Geliştiriyoruz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 32 : 24,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SmartTrack, onlarca yıldır yol güvenliğini artırmak, filo operasyonlarını optimize etmek '
                  've mevzuata uygunluğu sağlamak için tasarlanmış son teknoloji takograf çözümleri sunmaktadır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (final stat in _stats)
                        Expanded(
                          child: _StatTile(
                            value: stat.$1,
                            label: stat.$2,
                            scheme: scheme,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                Text(
                  'Uzmanlığımız',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: isDesktop ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 0.95 : 0.85,
                  children: [
                    for (final s in _services)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                s.$1,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.$2,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.$3,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Çalışma Süreci',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nasıl Daha Akıllı Filo Çözümleri Sunuyoruz',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      isDesktop
                          ? Stack(
                              children: [
                                Positioned(
                                  top: 24,
                                  left: 24,
                                  right: 24,
                                  child: CustomPaint(
                                    size: const Size(double.infinity, 2),
                                    painter: _DashedLinePainter(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (final step in _steps)
                                      Expanded(child: _StepTile(step: step)),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                for (final step in _steps) ...[
                                  _StepTile(step: step),
                                  const SizedBox(height: 20),
                                ],
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 24),
                Center(child: Image.asset('logo.png', height: 36)),
                const SizedBox(height: 16),
                Text(
                  'SmartTrack, güvenilir ve sürdürülebilir filo yönetimi çözümleri sunmak için '
                  'yenilikçi teknolojiyi uzmanlıkla birleştiriyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                _ContactRow(
                  icon: Icons.location_on_outlined,
                  text:
                      'Ankara Teknopark TGB Yerleşkesi İvedik OSB Mahallesi 2224. Cad No:1 İç Kapı No: 9 Kat:1 Ankara - TÜRKİYE',
                  scheme: scheme,
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.call_outlined,
                  text: '+90 312 544 28 68',
                  scheme: scheme,
                  onTap: () =>
                      _launch(Uri(scheme: 'tel', path: '+903125442868')),
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.mail_outline,
                  text: 'info@smarttrack.com.tr',
                  scheme: scheme,
                  onTap: () => _launch(
                    Uri(scheme: 'mailto', path: 'info@smarttrack.com.tr'),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} SmartTrack. Tüm Hakları Saklıdır.',
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final ColorScheme scheme;

  const _StatTile({
    required this.value,
    required this.label,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: scheme.primaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StepTile extends StatelessWidget {
  final (String, String, String) step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step.$1,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.$2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.$3,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.text,
    required this.scheme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: onTap != null ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: onTap != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
    return Center(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(padding: const EdgeInsets.all(4), child: content),
            )
          : content,
    );
  }
}
