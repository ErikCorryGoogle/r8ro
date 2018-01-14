import 'cpu.dart';
import 'memory.dart';
import 'mnemonics.dart';
import 'util.dart';

class Disassembler {
  static List<String> cond_name_list = create_cond_name_list();

  static void disassemble(Memory memory, int pc, CPU cpu) {
    int bytecode = memory.load8(pc);
    int reg1 = (bytecode >> 2) & 3;
    int reg2 = bytecode & 3;
    int memop_code = (bytecode >> 4) & 3;
    int imm = memory.load8(pc + 1);
    if (imm > 0x7f) imm -= 0x100;
    const mnem = const <String>[
      "sub",
      "and",
      "or",
      "xor",
      "shift",
      "movhi",
      "rsb",
      "add",
      "cmp",
      "mul",
      "mov",
      "div"
    ];
    const mnemsame = const <String>[
      "neg",
      "not",
      "adc",
      "zer",
      "sbc",
      "inc",
      "dec",
      "shl",
      "cmp#0",
      "square",
      "nop",
      "popcount"
    ];
    const memop_names = const <String>["ld8", "ld", "st8", "st16"];
    const pushpop_names = const <String>["pop8", "pop", "push8", "push"];
    const special = const <String>[
      "mov c pc",
      "mov pc c",
      "mov c sp",
      "mov sp c",
      "mov c status",
      "mov status c",
      "mov status status8",
      "??"
    ];

    const reg_names = const <String>["a", "b", "c", "sp"];

    int len = 1;
    if ((bytecode & 3) == 3 || (bytecode & 0xc) == 0xc) len = 2;
    if ((bytecode & 0xef) == 0xef) len = 3;

    String prefix = "${hex(pc)}: ${hex(bytecode)} ";
    if (len >= 2) prefix += "${hex(memory.load8(pc + 1))} ";
    if (len >= 3) prefix += "${hex(memory.load8(pc + 2))} ";
    prefix = prefix.padRight(20);

    String regs = "";
    if (cpu != null) {
      regs = "a=${hex(cpu.rA)} b=${hex(cpu.rB)} c=${hex(cpu.rC)} sp=${hex(cpu.sp)}".padRight(40);
    }
    prefix = regs + prefix;

    int opcode = bytecode >> 4;
    if (opcode < 12 && reg1 < 3) {
      if (reg1 == reg2) {
        if (opcode == MOV) {
          print("$prefix ${['nop', 'brk', 'hlt'][reg1]}");
        } else {
          print("$prefix ${mnemsame[opcode]} ${reg_names[reg1]}");
        }
      } else {
	if (opcode == SUB && reg2 == 3 && imm < 0) {
	  // For negative immediate sub, print add instead.
	  print("$prefix add ${reg_names[reg1]} ${hex(-imm)}");
	} else {
	  String r1;
	  if (opcode == ADD && reg2 == 3) {
	    // Immediate adds use alternative registers (use immediate sub
	    // instead).
	    r1 = <String>["pc", "sp", "status"][reg1];
	  } else {
	    r1 = reg_names[reg1];
	  }
	  String r2 = reg2 == 3 ? hex(imm) : reg_names[reg2];
	  print("$prefix ${mnem[opcode]} $r1 $r2");
	}
      }
    } else if ((bytecode & 0xcc) == 0xcc) {
      if (reg2 != 3) {
        // Conditional branch.
        int cond = ((bytecode & 3) << 2) + ((bytecode >> 4) & 3);
        print("$prefix b ${cond_name_list[cond]} ${hex(imm)}");
      } else {
        int op = (bytecode >> 4) & 3;
        String name = ["ret", "rti", "jmp", "call"][op];
        if (op >= 2) imm = memory.load16(pc + 1);
        print("$prefix $name ${hex(imm)}");
      }
    } else if ((bytecode & 0xce) == 0xc8) {
      int op = ((bytecode >> 3) & 6) + (bytecode & 1);
      print("$prefix ${special[op]}");
    } else if ((bytecode & 0xc3) == 0xc2) {
      print("$prefix ${pushpop_names[memop_code]} ${reg_names[reg1]}");
    } else if ((bytecode & 0xc3) == 0xc3) {
      if (memop_code < 2) {
        // load zero page.
        print("$prefix ${memop_names[memop_code]} ${reg_names[reg1]} [#${hex(
            imm)}]");
      } else {
        // store zero page.
        print("$prefix ${memop_names[memop_code]} [#${hex(
            imm)}] ${reg_names[reg1]}");
      }
    } else if ((bytecode & 0xc0) != 0xc0) {
      int data_reg = bytecode >> 6;
      int address_reg = reg2;
      String addr = "[${reg_names[address_reg]} #${hex(imm)}]";
      if (memop_code < 2) {
        // load.
        print(
            "$prefix ${memop_names[memop_code]} ${reg_names[data_reg]} $addr");
      } else {
        print(
            "$prefix ${memop_names[memop_code]} $addr ${reg_names[data_reg]}");
      }
    } else
      print("$prefix ??");
  }

  
  static List<String> create_cond_name_list() {
    List<String> l = new List<String>(12);
    for (String name in COND_NAMES.keys) {
      l[COND_NAMES[name]] = name;
    }
    return l;
  }
}
