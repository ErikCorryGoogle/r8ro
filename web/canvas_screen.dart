import 'dart:html';
import 'dart:typed_data';

import 'r8ro/screen.dart';
import 'r8ro/memory.dart';
import 'r8ro/memory_map.dart';
import 'r8ro/util.dart';

class CanvasScreen extends R8roScreen {
  CanvasScreen(Memory mem) : super(mem) {
    CanvasElement screen = querySelector("#screen");
    ctx = screen.context2D;
    window.requestAnimationFrame(render);
  }

  void render(num hirestime) {
    if (rendered == mem.generation) {
      window.requestAnimationFrame(render);
      return;
    }
    rendered = mem.generation;
    for (int row = 0; row < 256; row++) {
      int background = mem.load16(screenVectorStart + 4 * row);
      int sprite = mem.load16(screenVectorStart + 4 * row + 2);
      int mode = modes[row >> 2];
      print("row $row bg ${hex(background)} sprt ${hex(sprite)} mode $mode");
      for (int x = 0; x < 320; ) {
	int pixels = mem.load16(background);
	background += 2;
	if ((mode & 1) == 0) {
	  for (int i = 0; i < 16; i++) {
	    int color = 12 + (pixels & 1);
	    line[x++] = color;
	    if (mode == 2) line[x++] = color;
	    pixels >>= 1;
	  }
	} else {
	  for (int i = 0; i < 8; i++) {
	    int color = 8 + (pixels & 3);
	    line[x++] = color;
	    if (mode == 3) line[x++] = color;
	    pixels >>= 1;
	  }
	}
      }
      int repeats = 0;
      int pixels = 0;
      int shift_reg = 0;
      for (int x = 0; x < 320; x++) {
	if (repeats == 0) {
	  pixels = mem.load16(sprite);
	  print("pixels ${hex(pixels)}");
	  sprite += 2;
	  repeats = (1 + (pixels & 0xf)) << 2;
	}
	if ((repeats & 3) == 0) {
	  shift_reg = pixels >> 4;
	}
	int sprite_pix = shift_reg & 7;
	shift_reg >>= 3;
	int idx = sprite_pix == 0 ? line[x] : sprite_pix;
	int r = 85 * ((palate[idx] >> 4) & 3);
	int g = 85 * ((palate[idx] >> 2) & 3);
	int b = 85 * ((palate[idx] >> 0) & 3);
	ctx.setFillColorRgb(r, g, b);
	ctx.fillRect(x * 2, row * 2, 2, 2);
	repeats--;
      }
    }
    window.requestAnimationFrame(render);
  }

  Uint8List line = new Uint8List(320);  // Actually only 4 bits per pixel.
  CanvasRenderingContext2D ctx;
}
