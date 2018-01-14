import 'web/r8ro/tests.dart';
import 'web/r8ro/memory.dart';

// Standalone r8ro top level that creates a machine and runs the
// tests.  Doesn't run in the browser.  Run with dart r8ro.dart.

void main() {
  Memory memory = new Memory();
  Tests.runTests(memory);
}
