import 'cpu.dart';
import 'linker.dart';
import 'memory_map.dart';
import 'memory.dart';
import 'util.dart';

import '../rom/rom.dart';

import 'assembler_test.dart';

class Tests {
  static runTests(Memory memory) {
    new AssemblerTest().test();
    new Test1(memory).test();
    new Test2(memory).test();
    new TestLoadImm1(memory).test();
    new TestLoadImm2(memory).test();
    new TestShr(memory).test();
    new TestShl(memory).test();
    new TestDivModN(memory, 1).test();
    new TestDivModN(memory, 2).test();
    new TestDivModN(memory, 3).test();
    new TestDivModN(memory, 4).test();
    new TestDivModN(memory, 5).test();
    new TestDivModN(memory, 6).test();
    new TestDivModN(memory, 7).test();
    new TestDivModN(memory, 8).test();
    new TestDivModN(memory, 9).test();
    new TestDivModN(memory, 10).test();
    new CLZ(memory).test();
    new PushPopTest(memory).test();
    new TestMemMoveDown(memory).test();
    new TestMemSet(memory).test();
    new TestMul(memory).test();
    new TestDivMod(memory).test();
    // This is run last since it leaves the right data in the display memory.
    new TestPrintChar(memory).test();
  }
}

abstract class Test {
  String get source => null;
  String get name;

  static const ANYTHING = 0xffff;

  Test(this.memory);

  void setup(Memory memory, CPU cpu) {}

  CPU cpu;
  Memory memory;
  Linker linker;

  void compile() {
    print("Compiling $name");
    if (source != null) sources[name] = source;
    linker = new Linker(memory);
    linker.link(name);
    memory.store8(0, 0xa5); // A brk instruction to return to.
  }

  void run(String fn, bool disassemble) {
    cpu.sp -= 2;
    memory.store16(cpu.sp, 0); // Return address 0 on stack.
    cpu.pc = linker.assembler.lookupSymbol(fn);
    while (!cpu.step(disassemble)) {
      if (!(cpu.pc == 0 || (cpu.pc > 0x8000 && cpu.pc <= 0xff00))) throw "Unexpected pc: ${hex(cpu.pc)}";
    }
  }

  void test() {
    compile();
    run(name, /* disassemble = */ false);
  }
}

typedef void Checker(Memory, CPU);

class StackCase {
  StackCase(this.name, this.arguments, this.check);

  void disassemble() { shouldDisassemble = true; }

  String name;
  List<int> arguments;
  Checker check;
  bool shouldDisassemble = false;
}

// Takes args on stack and returns result in register(s).
abstract class StackTest extends Test {
  StackTest(Memory memory) : super(memory);

  Iterable<StackCase> get cases => [];

  void test() {
    compile();
    print("Testing $name");

    cpu = new CPU(memory);
    cpu.sp = stackEnd;
    setup(memory, cpu);

    for (StackCase c in cases) {
      print("Testing $name:${c.name}, args ${c.arguments.join(', ')}");
      cpu.sp = stackEnd;
      for (int i = c.arguments.length - 1; i >= 0; i--) cpu.push(c.arguments[i]);
      run(name, c.shouldDisassemble);
      for (int i = c.arguments.length - 1; i >= 0; i--) cpu.pop();
      c.check(memory, cpu);
    }
  }
}

class RegCase {
  RegCase(this.name, this.a, this.b, this.c, this.check);

  void disassemble() { shouldDisassemble = true; }

  String name;
  int a, b, c;
  Checker check;
  bool shouldDisassemble = false;
}

// Takes args in a, b, c and returns result in register(s).
abstract class RegTest extends Test {
  RegTest(Memory memory) : super(memory);
  Iterable<RegCase> get cases => [];

  void test() {
    compile();
    print("Testing $name");

    cpu = new CPU(memory);
    cpu.sp = stackEnd;
    setup(memory, cpu);

    for (RegCase c in cases) {
      print("Testing $name:${c.name}");
      cpu.rA = c.a & 0xffff;
      cpu.rB = c.b & 0xffff;
      cpu.rC = c.c & 0xffff;
      run(name, c.shouldDisassemble);
      c.check(memory, cpu);
    }
  }
}

// Test the divmod1, divmod2 etc functions.  They all take an arg in A and
// return A%N in A and A/N in B.
class TestDivModN extends RegTest {
  TestDivModN(Memory memory, this.N) : super(memory);
  int N;
  String get name => "divmod$N";
  RegCase generate(int index) {
    if (index == 299) {
      index = 0xffff;
    } else if (index == 298) {
      index = 0xfffe;
    } else if (index > 257) {
      index = (index - 256) * 97;
    }
    RegCase c = new RegCase(index.toString(), index, Test.ANYTHING, Test.ANYTHING,
	(Memory mem, CPU cpu) => divmod_check(cpu, index));
    return c;
  }

  get cases => new Iterable.generate(900, generate);

  void divmod_check(CPU cpu, int index) {
    assert(cpu.rA == index % N);
    assert(cpu.rB == index ~/ N);
  }
}

// Test the divmod function.  Takes args in A and B,
// returns A%B in A and A/B in B.
class TestDivMod extends RegTest {
  TestDivMod(Memory memory) : super(memory);
  String get name => "divmod";
  RegCase generate(int i) {
    int index = i % 900;
    int divisor = i ~/ 900;
    if (divisor == 0) {
      divisor = 0xffff;
    } else if (divisor > 12) {
      divisor *= 237;
    }
    if (index == 299) {
      index = 0xffff;
    } else if (index == 298) {
      index = 0xfffe;
    } else if (index > 257) {
      index = (index - 256) * 97;
    }
    return new RegCase("$index/$divisor", index, divisor, Test.ANYTHING,
	(Memory mem, CPU cpu) => divmod_check(cpu, index, divisor));
  }

  get cases => new Iterable.generate(18000, generate);

  void divmod_check(CPU cpu, int index, int divisor) {
    assert(cpu.rA == ((index % divisor) & 0xffff));
    assert(cpu.rB == ((index ~/ divisor) & 0xffff));
  }
}

// Input: i: unsigned integer in c
// Output: in c: number of leading (high) zeros.
class CLZ extends RegTest {
  CLZ(Memory memory) : super(memory);
  String get name => "count_leading_zeros";
  RegCase generate(int index) {
    if (index == 299) {
      index = 0xffff;
    } else if (index == 298) {
      index = 0xfffe;
    } else if (index > 257) {
      index = (index - 256) * 97;
    }
    return new RegCase(index.toString(), index, Test.ANYTHING, index,
	(Memory mem, CPU cpu) => clz_check(cpu, index));
  }

  get cases => new Iterable.generate(900, generate);

  void clz_check(CPU cpu, int index) {
    assert(cpu.rA == index);  // Untouched.
    int leading_zeros = 0;
    if (index == 0) {
      leading_zeros = 16;
    } else {
      while ((index & 0x8000) == 0) {
	leading_zeros++;
	index <<= 1;
      }
    }
    assert(cpu.rC == leading_zeros);
  }
}

// Takes no args.
abstract class NoArgsTest extends Test {
  bool get shouldDisassemble => false;
  NoArgsTest(Memory memory) : super(memory);
  void test() {
    compile();
    print("Testing $name");

    cpu = new CPU(memory);
    cpu.sp = stackEnd;
    setup(memory, cpu);

    cpu.rA = 0;
    cpu.rB = 0;
    cpu.rC = 0;
    run(name, shouldDisassemble);
    check(memory, cpu);
  }
  void check(Memory memory, CPU cpu);
}

class Test1 extends NoArgsTest {
  Test1(Memory memory) : super(memory);
  String get name => "test1";
  String source = """
    mov a #0
    inc a
    mov b #0
    dec b
    mov c #122
    inc c
    ret
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 0xffff);
    assert(cpu.rC == 123);
  }
}

class Test2 extends NoArgsTest {
  Test2(Memory memory) : super(memory);
  String get name => "Test2";
  String source = """
    mov a #0
    inc a
    mov b #0
    dec b
    mov c #122
    add c a
    add c b
    ret
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 0xffff);
    assert(cpu.rC == 122);
  }
}

class TestLoadImm1 extends NoArgsTest {
  TestLoadImm1(Memory memory) : super(memory);
  String get name => "LoadImm1";
  String source = """
    mov a #1234
    ret
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1234);
  }
}

class TestLoadImm2 extends NoArgsTest {
  TestLoadImm2(Memory memory) : super(memory);
  String get name => "LoadImm2";
  String source = """
    mov a #-2
    ret
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0xfffe);
  }
}

class TestShr extends NoArgsTest {
  TestShr(Memory memory) : super(memory);
  String get name => "Shiftright";
  String source = """
    mov a #0x1234
    shr a #4
    mov b #0x8834
    sar b #15
    add a b
    ret
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0x122);
  }
}

class TestShl extends NoArgsTest {
  TestShl(Memory memory) : super(memory);
  String get name => "Shiftleft";
  String source = """
    mov a #0x1234
    shl a
    mov b #0x8834
    shl b #4
    ret
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0x2468);
    assert(cpu.rB == 0x8340);
  }
}

class PushPopTest extends NoArgsTest {
  PushPopTest(Memory memory) : super(memory);
  String get name => "PushPop";
  String source = """
    mov a #0x1234
    mov b #0x12
    push a
    pop c
    push b
    pop a
    sub c b
    push8 c
    pop8 a
    ret 
  """;

  void check(Memory memory, CPU cpu) {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0x22);
  }
}

class TestMemSet extends StackTest {
  TestMemSet(Memory memory) : super(memory);
  String get name => "memset";

  get cases => <StackCase>[
    new StackCase("zero length", <int>[screenStart, 0x55, 0], (mem, cpu) {
      assert(mem.load8(screenStart - 1) != 0x55);
      assert(mem.load8(screenStart) != 0x55);
      assert(mem.load8(screenStart + 1) != 0x55);
    }),
    new StackCase("one length", <int>[screenStart, 0x55, 1], (mem, cpu) {
      assert(mem.load8(screenStart - 1) != 0x55);
      assert(mem.load8(screenStart) == 0x55);
      assert(mem.load8(screenStart + 1) != 0x55);
    }),
    new StackCase("two length", <int>[screenStart + 5, 0x55, 2], (mem, cpu) {
      assert(mem.load8(screenStart + 4) != 0x55);
      assert(mem.load8(screenStart + 5) == 0x55);
      assert(mem.load8(screenStart + 6) == 0x55);
      assert(mem.load8(screenStart + 7) != 0x55);
    }),
    new StackCase("three length", <int>[screenStart + 20, -42, 3], (mem, cpu) {
      int minus42 = -42 & 0xff;
      assert(mem.load8(screenStart + 19) != minus42);
      assert(mem.load8(screenStart + 20) == minus42);
      assert(mem.load8(screenStart + 21) == minus42);
      assert(mem.load8(screenStart + 22) == minus42);
      assert(mem.load8(screenStart + 23) != minus42);
    }),
    new StackCase("twentythree length", <int>[screenStart + 100, 42, 23], (mem, cpu) {
      assert(mem.load8(screenStart + 99) != 42);
      assert(mem.load8(screenStart + 100) == 42);
      assert(mem.load8(screenStart + 107) == 42);
      assert(mem.load8(screenStart + 122) == 42);
      assert(mem.load8(screenStart + 123) != 42);
    }),
    new StackCase("cls", <int>[screenStart, 0, screenEnd - screenStart], (mem, cpu) {
      assert(mem.load8(screenStart) == 0);
      assert(mem.load8(screenEnd - 1) == 0);
      assert(mem.load8(screenEnd) != 0);
    }),
  ];
}

class TestMemMoveDown extends StackTest {
  TestMemMoveDown(Memory memory) : super(memory);
  String get name => "memcpy";

  void setup(Memory memory, CPU cpu) {
    for (int i = 0; i < 256; i++) {
      memory.store8(screenStart + i, i);
    }
  }

  get cases => <StackCase>[
    new StackCase("one", <int>[screenStart + 10, screenStart + 30, 70], (mem, cpu) {
      assert(mem.load8(screenStart) == 0);
      assert(mem.load8(screenStart + 1) == 1);
      assert(mem.load8(screenStart + 9) == 9);
      assert(mem.load8(screenStart + 10) == 30);
      assert(mem.load8(screenStart + 11) == 31);
      assert(mem.load8(screenStart + 79) == 99);
      assert(mem.load8(screenStart + 80) == 80);
    }),
  ];

  void check() {}
}

class TestPrintChar extends NoArgsTest {
  TestPrintChar(Memory memory) : super(memory);
  String get name => "print_hello_world";

  String get source => """
    call ..init_cursor
    mov a ..hello_world
    push a

   :loop
    pop a
    ld8 b [a]
    inc a
    push a
    cmp b #0
    b eq .done
    push8 b
    call ..print_char
    pop8 b
    jmp .loop

    :done
    pop a
    ret

  :::hello_world
    "Hello, World!\n"
  """;
  void check(Memory memory, CPU cpu) {}
}

class TestMul extends StackTest {
  TestMul(Memory memory) : super(memory);
  String get name => "mul";

  Iterable<StackCase> get cases {
    List<StackCase> l = <StackCase>[];
    for (int x in <int>[0, 1, -1, 2, -2, 314, -200, 0x7fff, -0x8000]) {
      for (int y in <int>[0, 1, -1, 2, -2, 314, -200, 0x7fff, -0x8000]) {
	l.add(new StackCase("$x * $y", <int>[x, y], (memory, cpu) {
	  assert(cpu.rA == (((x & 0xffff) * (y & 0xffff)) & 0xffff));
	}));
      }
    }
    return l;
  }
}
