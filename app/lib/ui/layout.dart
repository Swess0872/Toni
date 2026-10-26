import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Phone first, TV second, desktop third. The TV layout is chosen by device
/// (smart-TV browser or setting), the others by available width.
enum FormFactor { phone, tablet, desktop, tv }

FormFactor formFactorOf(BuildContext context) {
  if (context.t.tv) return FormFactor.tv;
  final w = MediaQuery.sizeOf(context).width;
  if (w < 560) return FormFactor.phone;
  if (w < 980) return FormFactor.tablet;
  return FormFactor.desktop;
}

/// Logical width the TV layout is designed for; the whole UI is scaled up from it.
const tvDesignWidth = 1280.0;

const maxContentWidth = 1080.0;
