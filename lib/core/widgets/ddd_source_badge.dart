import 'package:flutter/material.dart';

import '../models/tachograph_type.dart';

/// "STC 8255" or "ATC 8256": the tachograph a .ddd file was downloaded from,
/// next to it in the file lists. The two kinds go to the same list, so this
/// is how they are told apart. The code reads the same in every language.
class DddSourceBadge extends StatelessWidget {
  const DddSourceBadge(this.source, {super.key});

  final TachographType source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (source) {
      TachographType.stc8255 => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      TachographType.atc8256 => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        source.code,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
