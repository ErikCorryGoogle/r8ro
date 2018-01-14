import "assembler.dart";
import "memory.dart";
import "../rom/rom.dart";

class Linker {
  Linker(this.memory) {
    assembler = new Assembler(memory, 0x8000, 0xff00);
  }

  void link(String name) {
    assembler.addUnboundLabel(name);
    bool work = true;
    while (work) {
      Iterable outstanding = assembler.unboundLabels().toList();
      work = false;
      for (String n in outstanding) {
	work = true;
	if (!assembler.hasSymbol(n) || !assembler.getLabel(n).bound) {
	  if (!sources.containsKey(n)) throw "Unknown symbol: '$n'";
	  print("Assemble $n");
	  assembler.parse(":::$n\n");
	  assembler.parse(sources[n]);
	  assembler.finish();
	}
      }
    }
  }

  Memory memory;
  Assembler assembler;
}
