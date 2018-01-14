import "../r8ro/memory_map.dart";

Map<String, String> sources = populate();

Map<String, String> populate() {
  Map<String, String> map = new Map<String, String>();
  // These divmod-n functions all take their argument i in a as an unsigned 16
  // bit int.
  // Output: in b: i / n
  //         in a: i % n
  map["divmod1"] = """
    mov b a
    mov a #0
    ret
  """;
  map["divmod2"] = """
    mov b a
    shr b #1
    and a #1
    ret
  """;
  map["divmod3"] = """
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
  map["divmod4"] = """
    mov b a
    shr b #2
    and a #3
    ret
  """;
  // If we see input as 4 bit nibbles, we can represent it as x * 16 + y where
  // 0 ≤ y ≤ 15.
  // x * 16 + y = x * 15 + (x + y).
  map["divmod5"] = """
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
  map["divmod6"] = """
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
  map["divmod7"] = """
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
    cmp a #64
    b ae .loop1

    :loop2
    inc b
    sub a #7
    b ae .loop2

    dec b
    add a #7
    ret
  """;
  map["divmod8"] = """
    mov b a
    shr b #3
    and a #7
    ret
  """;
  map["divmod9"] = """
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
    cmp a #64
    b ae .loop1

    :loop2
    inc b
    sub a #9
    b ae .loop2

    dec b
    add a #9
    ret
  """;
  map["divmod10"] = """
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
  // Input: i: unsigned integer in c
  // Output: in c: number of leading (high) zeros.
  // a is untouched
  // b is used as scratch
  map["count_leading_zeros"] = """
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
  // Args are pushed on stack like standard memset.  All args are 16 bit.
  map["memset"] = """
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
  map["memcpy"] = """
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
  """;
  map["init_cursor"] = """
    struct globals {
      char break
      ptr cursor_address
      char cursor_x
      char cursor_y
      char graphics_mode
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
  """;
  map["screen_address_table"] = """
    int #${0x8000 - 10 * 1024}   ; Mode 0 is a 10k mode.
    char #40
    int #${0x8000 - 20 * 1024}   ; Mode 1 is a 20k mode.
    char #80
    int #${0x8000 - 5 * 1024}    ; Mode 2 is a 5k mode.
    char #20
    int #${0x8000 - 10 * 1024}   ; Mode 3 is a 10k mode.
    char #40
  """;
  map["blank_sprite_sequence"] = """
    int #0xf     ; 64 pixels of transparency.
    int #0xf     ; 64 pixels of transparency.
    int #0xf     ; 64 pixels of transparency.
    int #0xf     ; 64 pixels of transparency.
    int #0xf     ; 64 pixels of transparency.
  """;
  map["set_screen_mode"] = """
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
  map["print_char"] = """
    struct args {
      ptr return_addr;
      char character;
    }

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
  // Input x y.
  // Output: a: low part of x * y
  map["mul"] = """
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
  map["divmod_table"] = """
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
  // Input: i: unsigned integer in a
  //        d: unsinged integer in b
  // Output: in b: i / d
  //         in a: i % d
  map["divmod"] = """
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
  return map;
}
