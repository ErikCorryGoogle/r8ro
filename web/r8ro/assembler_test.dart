import 'assembler.dart';
import 'memory.dart';

class AssemblerTest {
  void testError(String src, String msg) {
    Memory memory = new Memory();
    Assembler ass = new Assembler(memory, 0x8000, 0xc000);
    try {
      ass.parse(src);
      ass.finish();
      if (msg != null) throw "Parsing:\n$src\nNo error, expected:\n$msg";
    } catch (message) {
      if (msg != message) {
	if (msg == null) {
	  throw("Parsing:\n$src\nExpected no error, found:\n$message");
	} else {
	  throw("Parsing:\n$src\nExpected message:\n$msg\nFound:\n$message");
	}
      }
    }
  }

  void test() {
    testError("mov a b", null);
    testError("mov a b c", """
Parse error on line 1
mov a b c
        ^ Expected newline, found c""");
    testError("st a [sp]", """
Parse error on line 1
st a [sp]
   ^ Expected [, found a""");
  }
}
