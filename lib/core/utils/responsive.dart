import 'package:flutter/widgets.dart';

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;
