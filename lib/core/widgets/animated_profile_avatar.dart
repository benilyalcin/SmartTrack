import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/driving_time_calculator.dart';

class AnimatedProfileAvatar extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;
  final VoidCallback onLogout;

  const AnimatedProfileAvatar({
    super.key,
    required this.onOpenSettings,
    required this.onOpenAbout,
    required this.onLogout,
  });

  @override
  State<AnimatedProfileAvatar> createState() => _AnimatedProfileAvatarState();
}

class _AnimatedProfileAvatarState extends State<AnimatedProfileAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openMenu() async {
    _controller.forward();
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(
      Offset(0, box.size.height + 6),
      ancestor: overlay,
    );
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset(0, box.size.height + 6)),
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
    final scheme = Theme.of(context).colorScheme;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            'HESAP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: scheme.outline,
            ),
          ),
        ),
        const PopupMenuDivider(height: 8),
        _menuRow(
          'settings',
          Icons.settings_outlined,
          'Ayarlar',
          scheme.onSurface,
          scheme,
        ),
        _menuRow(
          'about',
          Icons.info_outline,
          'Hakkımızda',
          scheme.onSurface,
          scheme,
        ),
        _menuRow(
          'rules',
          Icons.gavel_outlined,
          'Kurallar ve Yönetmelik',
          scheme.onSurface,
          scheme,
        ),
        const PopupMenuDivider(height: 8),
        _menuRow('logout', Icons.logout, 'Çıkış Yap', scheme.error, scheme),
      ],
    );

    if (!mounted) return;
    _controller.reverse();
    switch (selected) {
      case 'settings':
        widget.onOpenSettings();
        break;
      case 'about':
        widget.onOpenAbout();
        break;
      case 'rules':
        _showRulesDialog(context);
        break;
      case 'logout':
        widget.onLogout();
        break;
    }
  }

  PopupMenuItem<String> _menuRow(
    String value,
    IconData icon,
    String label,
    Color textColor,
    ColorScheme scheme,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textColor, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _openMenu,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          final size = 36.0 + t * 10.0;
          return SizedBox(
            width: size,
            height: size,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: t < 0.5
                  ? Container(
                      key: const ValueKey('avatar'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    )
                  : Image.asset(
                      'logo.png',
                      key: const ValueKey('logo'),
                      fit: BoxFit.contain,
                    ),
            ),
          );
        },
      ),
    );
  }
}

void _showRulesDialog(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final rules = [
    (
      'Kesintisiz Sürüş — Art. 7',
      '${DrivingTimeCalculator.continuousDrivingLimit.inHours} saat ${DrivingTimeCalculator.continuousDrivingLimit.inMinutes % 60} dakika sonunda en az 45 dakikalık mola gerekir '
          '(ya da önce en az 15 dakika, sonra en az 30 dakika olacak şekilde bölünmüş mola).',
    ),
    (
      'Günlük Sürüş — Art. 6',
      'Günlük sürüş süresi ${DrivingTimeCalculator.dailyDrivingLimit.inHours} saati geçemez (haftada iki kez ${DrivingTimeCalculator.dailyDrivingLimit.inHours + 1} saate kadar uzatılabilir).',
    ),
    (
      'Haftalık Sürüş — Art. 6',
      'Bir haftalık (Pazartesi-Pazar) toplam sürüş süresi ${DrivingTimeCalculator.weeklyDrivingLimit.inHours} saati geçemez.',
    ),
    (
      'İki Haftalık Sürüş — Art. 6',
      'Ardışık iki hafta içindeki toplam sürüş süresi ${DrivingTimeCalculator.biWeeklyDrivingLimit.inHours} saati geçemez.',
    ),
    (
      'Haftalık Dinlenme Telafisi — Art. 8(6)',
      'Kısaltılmış bir haftalık dinlenme nedeniyle oluşan telafi borcu, oluştuğu haftayı izleyen 3. haftanın sonuna kadar, tek seferde kullanılarak telafi edilmelidir.',
    ),
  ];

  final pdfDocuments = [
    (
      'Kullanım Kılavuzu',
      'STC-8255 Dijital Takograf Kullanım Kılavuzu',
      'assets/pdfs/STC-8255-Operation-Manual.pdf',
      Icons.menu_book_outlined,
    ),
    (
      'Hazırlık Kılavuzu',
      'STC-8255 Dijital Takograf Hazırlık Kılavuzu',
      'assets/pdfs/STC-8255-Preparation-Manual.pdf',
      Icons.build_outlined,
    ),
    (
      'Takograf Dökümanı',
      'STC-8255 Dijital Takograf Teknik Döküman',
      'assets/pdfs/STC-8255-Tachograph.pdf',
      Icons.description_outlined,
    ),
  ];

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kurallar ve Yönetmelik'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uygulamanın uyum hesaplamaları AB 561/2006 Tüzüğü\'nün aşağıdaki maddelerine dayanır:',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final rule in rules) ...[
                Text(
                  rule.$1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Not: Bu, uzatılmış limitler ve feribot/tren istisnaları gibi tüm özel durumları '
                'kapsamayan bir temel uyum kontrolüdür — resmi denetimlerde tüzüğün kendisi esastır.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'Teknik Dökümanlar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aşağıdaki PDF dökümanlarına tıklayarak açabilirsiniz:',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final doc in pdfDocuments) ...[
                _PdfDocumentTile(
                  title: doc.$1,
                  subtitle: doc.$2,
                  assetPath: doc.$3,
                  icon: doc.$4,
                  scheme: scheme,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

class _PdfDocumentTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String assetPath;
  final IconData icon;
  final ColorScheme scheme;

  const _PdfDocumentTile({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.icon,
    required this.scheme,
  });

  @override
  State<_PdfDocumentTile> createState() => _PdfDocumentTileState();
}

class _PdfDocumentTileState extends State<_PdfDocumentTile> {
  bool _loading = false;

  Future<void> _openPdf() async {
    setState(() => _loading = true);
    try {
      final byteData = await rootBundle.load(widget.assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.assetPath.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      final result = await OpenFilex.open(
        file.path,
        type: 'application/pdf',
      );

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF açılamadı: ${result.message}'),
            backgroundColor: widget.scheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF açılırken hata oluştu: $e'),
            backgroundColor: widget.scheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _loading ? null : _openPdf,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.scheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.open_in_new_rounded,
                  color: widget.scheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

