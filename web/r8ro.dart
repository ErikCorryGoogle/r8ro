import 'r8ro/assembler.dart';
import 'r8ro/memory_map.dart';
import 'r8ro/memory.dart';
import 'r8ro/util.dart';
import 'r8ro/cpu.dart';

import 'r8ro/assembler_test.dart';

import 'canvas_screen.dart';

void main() {
  Memory memory = new Memory();
  new CanvasScreen(memory);
  for (int i = 0; i < 10000; i++) {
    memory.store8(22 * 1024 + i, i & 255);
  }
  Test.memory = memory;
  new AssemblerTest().test();
  new Test1().test();
  new Test2().test();
  new TestLoadImm1().test();
  new TestLoadImm2().test();
  new TestShr().test();
  new TestShl().test();
  new DivMod1().test();
  new DivMod2().test();
  new DivMod3().test();
  new DivMod4().test();
  new DivMod5().test();
  new DivMod6().test();
  new DivMod7().test();
  new DivMod8().test();
  new DivMod9().test();
  new DivMod10().test();
  new CLZ().test();
  new PushPopTest().test();
  new TestMemSet().test();
  new TestMemMoveDown().test();
  new TestInitCursor().test();
  new TestPrintChar().test();
  new TestMul().test();
  new TestMulToWide().test();
  new TestDivModTable().test();
  new TestDiv().test();
}


abstract class Test {
  String get source;

  String get name;

  List<int> get arguments => [];

  int get initial_a => 0;

  int get initial_b => 0;

  int get initial_c => 0;

  bool get disassemble => false;
  CPU cpu;
  static Assembler ass;
  static Memory memory;

  void check();

  void test() {
    print("Testing $name");
    if (memory == null) {
      memory = new Memory();
    }
    if (ass == null) {
      ass = new Assembler(memory, 0x8000, 0xc000);
    }
    ass.parse(":::$name\n");
    ass.parse(source);
    ass.finish();
    //print("Assembled $name to ${ass.pc - 0x8000} bytes");
    cpu = new CPU(memory);
    cpu.sp = 0x200;
    for (int i = arguments.length - 1; i >= 0; i--) {
      int arg = arguments[i];
      cpu.sp -= 2;
      memory.store16(cpu.sp, arg); // Arguments on stack.
    }
    cpu.sp -= 2;
    memory.store16(cpu.sp, 0); // Return address 0 on stack.
    memory.store8(0, 0xa5); // A brk instruction to return to.
    cpu.pc = ass.lookupSymbol(name);
    cpu.rA = initial_a;
    cpu.rB = initial_b;
    cpu.rC = initial_c;
    while (!cpu.step(disassemble)) {
      if (!(cpu.pc == 0 || (cpu.pc > 0x8000 && cpu.pc <= 0x9000))) throw "Unexpected pc: ${hex(cpu.pc)}";
    }
    check();
  }
}

class Test1 extends Test {
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

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 0xffff);
    assert(cpu.rC == 123);
  }
}

class Test2 extends Test {
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

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 0xffff);
    assert(cpu.rC == 122);
  }
}

class TestLoadImm1 extends Test {
  String get name => "LoadImm1";
  String source = """
    mov a #1234
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1234);
  }
}

class TestLoadImm2 extends Test {
  String get name => "LoadImm2";
  String source = """
    mov a #-2
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0xfffe);
  }
}

class TestShr extends Test {
  String get name => "Shiftright";
  String source = """
    mov a #0x1234
    shr a #4
    mov b #0x8834
    sar b #15
    add a b
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0x122);
  }
}

class TestShl extends Test {
  String get name => "Shiftleft";
  String source = """
    mov a #0x1234
    shl a
    mov b #0x8834
    shl b #4
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0x2468);
    assert(cpu.rB == 0x8340);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 1
//         in a: i % 1
class DivMod1 extends Test {
  String get name => "divmod1";

  int get initial_a => 101;
  String source = """
    mov b a
    mov a #0
    ret
    """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0);
    assert(cpu.rB == 101);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 2
//         in a: i % 2
class DivMod2 extends Test {
  String get name => "divmod2";

  int get initial_a => 101;
  String source = """
    mov b a
    shr b #1
    and a #1
    ret
    """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 50);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 5
//         in a: i % 5
class DivMod3 extends Test {
  String get name => "divmod3";

  int get initial_a => 101;

  // Similar algo to DivMod5
  String source = """
    mov b #0
    jmp .loop_test

    :loop1
    mov c a
    shr c #4
    and a #15
    add a c
    add b c
    shl c #2
    add b c

    :loop_test
    cmp a #16
    b ae .loop1

    :loop2
    inc b
    sub a #3
    b ae .loop2

    dec b
    add a #3
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 2);
    assert(cpu.rB == 33);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 4
//         in a: i % 4
class DivMod4 extends Test {
  String get name => "divmod4";

  int get initial_a => 101;
  String source = """
    mov b a
    shr b #2
    and a #3
    ret
    """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 25);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 5
//         in a: i % 5
class DivMod5 extends Test {
  String get name => "divmod5";

  int get initial_a => 101;

  // If we see input as 4 bit nibbles, we can represent it as x * 16 + y where
  // 0 ≤ y ≤ 15.
  // x * 16 + y = x * 15 + (x + y).
  String source = """
    mov b #0
    jmp .loop_test

    :loop1
    mov c a
    shr c #4
    and a #15
    add a c
    add b c
    add b c
    add b c

    :loop_test
    cmp a #16
    b ae .loop1

    :loop2
    inc b
    sub a #5
    b ae .loop2

    dec b
    add a #5
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 20);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 6
//         in a: i % 6
class DivMod6 extends Test {
  String get name => "divmod6";

  int get initial_a => 101;
  String source = """
    mov b a
    and b #1
    push8 b
    shr a #1
    call ..divmod3
    pop8 c
    shl a #1
    add a c
    ret
    """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 5);
    assert(cpu.rB == 16);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 7
//         in a: i % 7
class DivMod7 extends Test {
  String get name => "divmod7";

  int get initial_a => 101;

  // Like DivMod3, but making use of 9*7 == 63
  String source = """
    mov b #0
    jmp .loop_test

    :loop1
    mov c a
    shr c #6
    and a #0x3f
    add a c
    add b c
    shl c #3
    add b c

    :loop_test
    cmp a #63
    b ae .loop1

    :loop2
    inc b
    sub a #7
    b ae .loop2

    dec b
    add a #7
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 3);
    assert(cpu.rB == 14);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 8
//         in a: i % 8
class DivMod8 extends Test {
  String get name => "divmod8";

  int get initial_a => 101;
  String source = """
    mov b a
    shr b #3
    and a #7
    ret
    """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 5);
    assert(cpu.rB == 12);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 9
//         in a: i % 9
class DivMod9 extends Test {
  String get name => "divmod9";

  int get initial_a => 101;

  // Like DivMod3, but making use of 9*7 == 63
  String source = """
    mov b #0
    jmp .loop_test

    :loop1
    mov c a
    shr c #6
    and a #0x3f
    add a c
    sub b c
    shl c #3
    add b c

    :loop_test
    cmp a #63
    b ae .loop1

    :loop2
    inc b
    sub a #9
    b ae .loop2

    dec b
    add a #9
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 2);
    assert(cpu.rB == 11);
  }
}

// Input: i: unsigned integer
// Output: in b: i / 10
//         in a: i % 10
class DivMod10 extends Test {
  String get name => "divmod10";

  int get initial_a => 101;
  String source = """
    mov b a
    and b #1
    push8 b
    shr a #1
    call ..divmod5
    pop8 c
    shl a #1
    add a c
    ret
    """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 1);
    assert(cpu.rB == 10);
  }
}

// Input: i: unsigned integer in c
// Output: in c: number of leading (high) zeros.
// a is untouched
// b is used as scratch
class CLZ extends Test {
  String get name => "count_leading_zeros";

  int get initial_c => 0x18;
  String source = """
    mov b c
    shr b #1
    or c b
    mov b c
    shr b #2
    or c b
    mov b c
    shr b #4
    or c b
    mov b c
    shr b #8
    or c b
    popcnt c
    rsb c #16
    ret
  """;

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rC == 11);
  }
}

// Input: i: unsigned integer
// Output: in a: number of leading (high) zeros.
class PushPopTest extends Test {
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

  void check() {
    assert(cpu.pc == 1);
    assert(cpu.rA == 0x22);
  }
}

class TestMemSet extends Test {
  String get name => "memset";

  bool get disassemble => false;
  String source = """
    ld a [sp #2]  ; Destination
    ld b [sp #4]  ; Value
    ld c [sp #6]  ; Byte count

    ; Write first byte if count is odd.
    cmp c #1          ; Acts as a tst instruction...
    b tz .even_count  ; ... due to tz condition here.
    st [a] b          ; Write the odd byte.
    dec c
    inc a
    :even_count

    ; Terminate early if count is zero.
    cmp c #0
    b ne .non_zero
    ret
    :non_zero

    ; Double up value to two bytes.
    st [sp #6] c   ; Spill byte count.
    shl b #8
    shr b #8
    movhi c b
    add b c
    ld c [sp #6]  ; Unspill byte count

    :loop
    st [a] b
    add a #2
    sub c #2
    b nz .loop

    ret
    """;

  List<int> get arguments => [screenStart, 0, screenEnd - screenStart];

  void check() {
    assert(Test.memory.load8(screenStart) == 0);
    assert(Test.memory.load8(screenEnd - 1) == 0);
    assert(Test.memory.load8(screenEnd) != 0);
  }
}

class TestMemMoveDown extends Test {
  String get name => "memcpy";

  bool get disassemble => false;
  String source = """
  :::memmove_down
    ld a [sp #2]  ; Destination
    ld b [sp #4]  ; Source

    :bytewiseloop
    ld c [sp #6]  ; Byte count
    cmp c #0
    b eq .done
    cmp c #7
    b tz .loop
    dec c
    st [sp #6] c
    ld8 c [b]
    st8 [a] c
    inc a
    inc b
    jmp .bytewiseloop

    ; Copy 8 bytes at a time.
    :loop
    sub c #8
    st [sp #6] c
    ld c [b]
    st [a] c
    ld c [b #2]
    st [a #2] c
    ld c [b #4]
    st [a #4] c
    ld c [b #6]
    st [a #6] c
    add a #8
    add b #8
    ld c [sp #6]

    :loop_test
    cmp c #0
    b ne .loop

    :done
    ret

  :::memmove
    ld a [sp #2]  ; Destination
    ld b [sp #4]  ; Source
    cmp a b
    b le ..memmove_down
    ; Fall through

  :::memmove_up

  """;

  List<int> arguments = [
    screenStart,
    screenStart + 400,
    screenEnd - 400 - screenStart
  ];

  void check() {}
}

class TestInitCursor extends Test {
  String get name => "init_cursor";
  bool get disassemble => true;
  String source = """
    struct globals {
      char break
      ptr cursor_address
      char cursor_x
      char cursor_y
      char graphics_mode
    }

    struct args {
      ptr return_addr;
      char character;
    }

    mov a #0
    st8 [->globals.cursor_x] a
    st8 [->globals.cursor_y] a
    mov a #${screenStart}
    st [->globals.cursor_address] a 

    mov c #0
    push8 c
    call ..set_screen_mode
    pop8 c
    ret

 ::screen_address_table
  int #${0x8000 - 10 * 1024}   ; Mode 0 is a 10k mode.
  char #40
  int #${0x8000 - 20 * 1024}   ; Mode 1 is a 20k mode.
  char #80
  int #${0x8000 - 5 * 1024}    ; Mode 2 is a 5k mode.
  char #20
  int #${0x8000 - 10 * 1024}   ; Mode 3 is a 10k mode.
  char #40

 ::blank_sprite_sequence
  int #0xf     ; 64 pixels of transparency.
  int #0xf     ; 64 pixels of transparency.
  int #0xf     ; 64 pixels of transparency.
  int #0xf     ; 64 pixels of transparency.
  int #0xf     ; 64 pixels of transparency.

 ::set_screen_mode
    ld8 c [sp #2]  ; Mode 0-3
    mov a ..screen_address_table
    add a c
    add a c
    add a c
    ld b [a]     ; Get start address.
    ld8 a [a #2] ; Get bytes per line.
    mov c #${screenVectorStart}

    push c
   :background_loop
    pop c
    st [c] b
    add c #4
    push c
    add b a
    shr c #8
    cmp c #${screenVectorEnd >> 8}
    b ne .background_loop
    pop c

    mov c #${screenVectorStart}
    mov b ..blank_sprite_sequence
    mov a #${screenVectorEnd}

   :sprite_loop
    st [c #2] b
    add c #4
    cmp c a 
    b ne .sprite_loop

    mov a #$screenModeStart
    mov b a
    add b #${screenModeEnd - screenModeStart}
    ld8 c [sp #2]  ; Mode 0-3
    st8 [->globals.graphics_mode] c
   :loop
    st8 [b] c
    dec b
    cmp a b
    b b .loop

    add a #${screenPalateStart - screenModeStart}
    mov c #14
    push c
    mov b .default_palate
    push b
    push a
    call ..memcpy
    ret #6

   :default_palate
    ; Sprite colours.
    char #0     ; Black/Transparent
    char #0x03  ; Blue
    char #0x0c  ; Green
    char #0x0f  ; Cyan
    char #0x30  ; Red
    char #0x33  ; Magenta
    char #0x3c  ; Yellow
    char #0xff  ; White
    ; 2-bit mode colors.
    char #0x00  ; Black
    char #0x30  ; Red
    char #0x2a  ; Grey
    char #0x3f  ; White
    ; 1-bit mode colors.
    char #0x00  ; Black
    char #0x3f  ; White
  """;

  void check() {}
}

class TestPrintChar extends Test {
  String get name => "printHelloWorld";

  bool get disassemble => false;
  String source = """
    mov a ..helloworld
    push a

   :loop
    pop a
    ld8 b [a]
    inc a
    push a
    cmp b #0
    b eq .done
    push8 b
    call ..printchar
    pop8 b
    jmp .loop

    :done
    pop a
    ret
    
    :::helloworld
    "Hello, World!\n"

    :::printchar
    ld8 c [sp->args.character]
    cmp c #0xa    ; newline
    b eq .newline

   :newline_done
    ld8 a [->globals.cursor_x]
    cmp a #40     ; Last column
    b eq .newline

    ld8 c [sp->args.character]

    inc a
    st8 [->globals.cursor_x] a    ; Increment
    shl c
    mov a c
    shl a #2
    add c a    ; c now *10 to index into font array.
    mov a #$fontRomStart
    add c a    ; Points at start of character.
    ld a [->globals.cursor_address]

    mov b #0

   :loop
    push8 b
    ld8 b [c]
    st8 [a] b
    pop8 b
    inc b
    inc c
    add a #$bytesPerLine
    cmp b #10
    b ne .loop
    mov b #0
    st8 [a] b

    ld a [->globals.cursor_address]
    inc a
    st [->globals.cursor_address] a
    ret
   
   :newline
    ld8 a [->globals.cursor_y]
    cmp a #${textLines - 1}
    b ne .no_scroll
    call .scroll

   :no_scroll
    ld8 a [->globals.cursor_y]
    inc a
    st8 [->globals.cursor_y] a
    mov b #0
    st8 [->globals.cursor_x] b
    ; Multiply a by 1b8   110111000
    shl a #3
    mov b a
    shl b
    add a b
    shl b
    add a b
    shl b #2
    add a b
    shl b
    add a b
    mov b #$screenStart
    add a b
    st [->globals.cursor_address] a

    ld8 c [sp->args.character]
    cmp c #0xa    ; newline
    b ne .newline_done
    ret

   :scroll
    mov a #${linesPerCharLine * bytesPerLine * (textLines - 1)}
    push a
    mov a #${screenStart + linesPerCharLine * bytesPerLine}
    push a
    mov a #$screenStart
    push a
    call ..memcpy
    pop a
    pop a
    pop a

    mov a #${linesPerCharLine * bytesPerLine}
    push a
    mov a #0
    push a
    mov a #${screenStart + linesPerCharLine * bytesPerLine * (textLines - 1)}
    st [->globals.cursor_address] a
    push a
    call ..memset
    pop a
    pop a
    pop a

    ld8 a [->globals.cursor_y]
    cmp a #0
    b eq .yalreadyzero

    dec a
    st8 [->globals.cursor_y] a
    ld a [->globals.cursor_address]
    mov b #${bytesPerLine * linesPerCharLine}
    sub a b
    st [->globals.cursor_address] a

   :yalreadyzero
    ret
  """;

  void check() {}
}

class TestMul extends Test {
  String get name => "mul";

  bool get disassemble => false;
  // Input x y.
  // Output: a: low part of x * y
  String source = """
    struct mulargs {
      ptr return_addr
      int x
      int y
    }

    ld a [sp->mulargs.x]
    ld b [sp->mulargs.y]
    cmp a b
    b b .a_smaller
    mov c a
    mov a b
    mov b c

   :a_smaller
    mov c #0

   :loop
    cmp a #1
    b tz .no

    add c b

   :no
    shl b #1
    shr a #1
    b nz .loop

    mov a c
    ret
  """;

  List<int> get arguments => [13, 7];

  void check() {
    if (cpu.rA != 91) throw "${cpu.rA} instead";
  }
}

// Incomplete - sign extends one input, but not the other.
class TestMulToWide extends Test {
  String get name => "mul2w";

  bool get disassemble => false;
  // Input x y.
  // Output: a: low part of x * y
  //         b: high part of x * y
  String source = """
    struct mul2wargs {
      int hi
      int lo
      ptr return_addr
      int x
      int y
    }

    mov a #0
    push a
    push a
    ld a [sp->mul2wargs.x]
    ld b [sp->mul2wargs.y]
    cmp a b
    b b .a_smaller
    mov c a
    mov a b
    mov b c

   :a_smaller
    mov c #0
    cmp b #0
    b ge .positive
    dec c
   :positive

   :loop
    ; a = x
    ; b = low part of y
    ; c = high part of y
    cmp a #1
    b tz .no_bit

    ; Found a bit in x, we need to add y to accumulator.
    ; Spill a.
    st [sp->mul2wargs.x] a
    ld a [sp->mul2wargs.lo]
    add a b
    st [sp->mul2wargs.lo] a
    ld a [sp->mul2wargs.hi]
    adc a
    add a c
    st [sp->mul2wargs.hi] a
    ; Reload a
    ld a [sp->mul2wargs.x]

   :no_bit
    shl b #1
    b cc .no_y_carry
    shl c #1
    or c #1
    jmp .y_carry_done
   :no_y_carry
    shl c #1
   :y_carry_done

    shr a #1
    b nz .loop

    ld a [sp->mul2wargs.lo]
    ld b [sp->mul2wargs.hi]
    ret #4
  """;

  List<int> get arguments => [13, 7];

  void check() {
    if (cpu.rA != 91) throw "${cpu.rA} instead";
    if (cpu.rB != 0) throw "${cpu.rB} instead";
  }
}

class TestDivModTable extends Test {
  String get name => "divmod_table";

  bool get disassemble => false;
  String source = """
    brk
    brk
    brk
    jmp ..divmod1
    jmp ..divmod2
    jmp ..divmod3
    jmp ..divmod4
    jmp ..divmod5
    jmp ..divmod6
    jmp ..divmod7
    jmp ..divmod8
    jmp ..divmod9
    jmp ..divmod10
""";
  void check() {}
}

// Input: i: unsigned integer in a
//        d: unsinged integer in b
// Output: in b: i / d
//         in a: i % d
class TestDiv extends Test {
  String get name => "divmod";
  String source = """
    cmp b #10
    b a .big_dividend
    mov c ..divmod_table
    add c b
    add c b
    add c b
    mov pc c

   :big_dividend
     cmp a b
     b nb .more

     mov b #0
     ret

    struct fr {
      int spill_d
      int tmp
      int answer
      ptr return_address
    }

    :more
     mov c #0
     push c  ; answer
     push c  ; tmp
     push b  ; spill_d

     mov c a ; i
     call ..count_leading_zeros  ; a is untouched
     st [sp->fr.tmp] c
     ld c [sp->fr.spill_d]
     call ..count_leading_zeros
     ld b [sp->fr.tmp]
     
     ; b = clz(i)
     ; c = clz(d)
     rsb b c

     ; b is how much to shift up d.
     ld c [sp->fr.spill_d]
     set_shl b
     shift c b
     push c
     mov c #1
     shift c b
     pop b

    :loop
     cmp a b
     b cs .toobig

     sub a b

     st [sp->fr.tmp] b
     ld b [sp->fr.answer]
     add b c
     st [sp->fr.answer] b
     ld b [sp->fr.tmp]

    :toobig
     shr b #1
     shr c #1
     b nz .loop

     ld b [sp->fr.answer]
     ret #6
  """;

  int get initial_a => 54321;
  int get initial_b => 77;

  void check() {
    if (cpu.rA != 54321 % 77) throw "A expected ${54321 % 77} ${cpu.rA} instead";
    if (cpu.rB != 54321 ~/ 77) throw "B expected ${54321 ~/ 77} ${cpu.rB} instead";
  }
}
