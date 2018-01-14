import 'r8ro/tests.dart';
import 'r8ro/memory.dart';
import 'canvas_screen.dart';

// Web r8ro top level that creates a machine and runs the
// tests.  Runs in the browser via dart2js.  Build with
// pub build.


void main() {
  Memory memory = new Memory();
  new CanvasScreen(memory);
  for (int i = 0; i < 10000; i++) {
    memory.store8(22 * 1024 + i, i & 255);
  }
  Tests.runTests(memory);
}
