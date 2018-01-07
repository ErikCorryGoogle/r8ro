import 'dart:typed_data';

import 'memory_map.dart';
import 'memory.dart';

// 1k Screen vector layout:
// For each line:
// data addr:16
// sprite addr: 16
// 64 memory mapped 2-bit registers control the mode for each bunch of
// 4 lines. 128 bits.
// low 2 bits ctrl   // 0 = 1 bit, 320 columns, 40 bytes  10k screen
//                   // 1 = 2 bit, 320 columns, 80 bytes  20k screen
//                   // 2 = 1 bit, 160 columns, 20 bytes  5k screen
//                   // 3 = 2 bit, 160 columns, 40 bytes  10k screen

// Sprite memory:
// Each word is: len4 pix3 pix3 pix3 pix3
// len4 is the number of times to repeat the last 4 pixels - allows up to 60
// pixels of gap between sections.  4 pixels are 0000 at start of line.
// Each pix3 indexes into global color map

// Global color map:
// ttrrggbb       2 bits of transparency, red, green, blue.  T not used on background.
// Entries: 0-7   Sprite color map and 3-bit modes
//          8-11  2-bit modes
//          12-13 1-bit modes
// In all 112 bits of palate.

class R8roScreen {
  R8roScreen(this.mem) {
    mem.register(screenPalateStart, screenPalateEnd, updatePalate);
    mem.register(screenModeStart, screenModeEnd, updateModes);
  }

  Memory mem;
  int rendered = -1;

  void updatePalate(int index, int color) {
    index &= 0xf;
    if (index >= 14) return;
    palate[index] = color & 0x3f;
  }

  void updateModes(int index, int mode) {
    index &= 0x3f;
    modes[index] = mode & 3;
  }

  Uint8List palate = new Uint8List(14);
  Uint8List modes = new Uint8List(64);  // Actually only 2 bits.
}
