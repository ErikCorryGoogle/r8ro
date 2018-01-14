import 'cpu.dart';
import 'memory.dart';
import 'mnemonics.dart';
import 'util.dart';

class Label {
  Label(this.memory, this.name);

  Memory memory;
  String name;
  bool bound = false;
  int address = 0;
  List<int> links_8 = <int>[];
  List<int> links_16 = <int>[];
  List<int> links_imm16 = <int>[];

  void _patch8(int loc, int addr) {
    int base = loc + 1;
    int off = addr - base;
    if (off < -0x80 || off > 0x7f) throw "Out of range forward branch to $name";
    memory.store8(loc, off);
  }

  void _patch_imm16(int loc, int addr) {
    int hi = addr >> 8;
    int lo = addr & 0xff;
    if (lo > 0x80) {
      lo -= 0x100;
      hi++;
    }
    lo = -lo;
    memory.store8(loc, hi);
    memory.store8(loc + 2, lo);
  }

  void bind(int addr) {
    if (bound) throw "Tried to bind $name twice";
    bound = true;
    address = addr;
    for (int loc in links_8) _patch8(loc, addr);
    for (int loc in links_16) memory.store16(loc, addr);
    for (int loc in links_imm16) _patch_imm16(loc, addr);
  }

  void link8(int loc) {
    if (bound) {
      _patch8(loc, address);
    } else {
      links_8.add(loc);
    }
  }

  void link16(int loc) {
    if (bound) {
      memory.store16(loc, address);
    } else {
      links_16.add(loc);
    }
  }

  void link_imm16(int loc) {
    if (bound) {
      _patch_imm16(loc, address);
    } else {
      links_imm16.add(loc);
    }
  }
}

class Field {
  Field(this.name, this.offset, this.size);

  String name;
  int offset;
  int size;
}

class Struct {
  Struct(this.name) {}

  void add(String name, int position, int size) {
    if (names.containsKey(name)) throw "Duplicate field $name in struct";
    names[name] = new Field(name, position, size);
  }

  Field lookup(String name) {
    if (!names.containsKey(name)) throw "No such field in struct: $name";
    return names[name];
  }

  Map<String, Field> names = <String, Field>{};
  String name;
}

class Assembler {
  Assembler(this.memory, this.pc, this.end) {
    mnemonics = <String, Function>{
      "sub": () => parseBinary(SUB),
      "and": () => parseBinary(AND),
      "or": () => parseBinary(OR),
      "xor": () => parseBinary(XOR),
      "shift": () => parseBinary(SHIFT),
      "movhi": () => parseBinary(MOVHI),
      "rsb": () => parseBinary(RSB),
      "add": () => parseBinary(ADD),
      "cmp": () => parseBinary(CMP),
      "mul": () => parseBinary(MUL),
      "div": () => parseBinary(DIV),
      "neg": () => parseUnary(NEG),
      "not": () => parseUnary(NOT),
      "adc": () => parseUnary(ADC),
      "zer": () => parseUnary(ZER),
      "sbc": () => parseUnary(SBC),
      "inc": () => parseUnary(INC),
      "dec": () => parseUnary(DEC),
      "square": () => parseUnary(SQUARE),
      "popcnt": () => parseUnary(POPCNT),
      "shr": () => parseShift(SHR),
      "sar": () => parseShift(SAR),
      "shl": () => parseShift(SHL),
      "rol": () => parseShift(ROL),
      "set_shr": () => parseSetShiftOp(SHR),
      "set_sar": () => parseSetShiftOp(SAR),
      "set_shl": () => parseSetShiftOp(SHL),
      "set_rol": () => parseSetShiftOp(ROL),
      "clear_shift": parseClearShiftOp,
      "ld8": parseLoadStore,
      "st8": parseLoadStore,
      "ld": parseLoadStore,
      "st": parseLoadStore,
      "mov": parseMove,
      "ret": parseReturn,
      "rti": parseReturn,
      "jmp": parseJump,
      "call": parseJump,
      "pop8": parsePushPop,
      "push8": parsePushPop,
      "pop": parsePushPop,
      "push": parsePushPop,
      "b": parseBranch,
      "hlt": () => parseSimple((MOV << 4) + 0xa), // mov c c encoding is hlt.
      "brk": () => parseSimple((MOV << 4) + 5), // mov b b encoding is brk.
      "nop": () => parseSimple((MOV << 4)), // mov a a encoding is nop.
      ":": parseLabel,
      "::": parseLabel,
      ":::": parseLabel,
      "struct": parseStruct,
      '"': parseString,
      "char": parseConstant,
      "int": parseConstant,
      "ptr": parseJump,
    };
    List<String> keywords = <String>["struct", "char", "int", "ptr"];
    mnemonics.keys.forEach(addName);
    reg_names.keys.forEach(addName);
    COND_NAMES.keys.forEach(addName);
    keywords.forEach(addName);
    local_labels = new Map<String, Label>();
    global_labels = new Map<String, Label>();
    pos = 0;
  }

  void addName(String name) {
    int code = name.codeUnitAt(0);
    if (!lookup.containsKey(code)) {
      lookup[code] = <String>[];
    }
    List<String> names = lookup[code]; // Names with this starting letter.
    if (!names.contains(name)) names.add(name);
  }

  String source;
  String current;
  int current_int = 0;
  String current_string;
  String current_field_name;
  int pos;
  int previous_pos;
  int line_number = 1;
  int start_of_line = 0;
  int just_before_newline = 0;
  Map<String, Label> local_labels;
  Map<String, Label> global_labels;
  Map<String, Function> mnemonics;
  Map<int, List<String>> lookup = new Map<int, List<String>>();

  int lookupSymbol(String name) => global_labels[name].address;
  Label getLabel(String name) => global_labels[name];
  bool hasSymbol(String name) => global_labels.containsKey(name);

  void set_line_break(int prev, int next) {
    if (prev != null) just_before_newline = prev;
    start_of_line = next;
  }

  bool accept(String s) {
    if (s == current) {
      getNext();
      return true;
    }
    return false;
  }

  void expect(String s) {
    if (current == "" && s == "\n") return;  // Imaginary newline at eof.
    if (s != current) {
      if (current == "\n") {
	pos = just_before_newline;
	throw "Expected $s, found newline";
      }
      if (s == "\n") {
	throw "Expected newline, found $current";
      } else {
	throw "Expected $s, found $current";
      }
    }
    getNext();
  }

  void getNext() {
    current_int = 999;
    while (pos < source.length && source.startsWith(" ", pos)) {
      pos++;
    }
    if (pos == source.length) {
      current = ""; // EOF.
      return;
    }
    String c = source[pos];

    previous_pos = pos;

    if (c == "\n" || c == ";") {
      current = "\n";
      just_before_newline = pos - 1;
      while (pos != source.length) {
        c = source[pos];
	if (c == "\n") {
	  line_number++;
	  start_of_line = pos + 1;
	}
        if (c == "\n" || c == " ") {
          pos++;
          continue;
        }
        if (c == ";") {
          while (pos != source.length) {
            if (source[pos] == "\n") {
	      line_number++;
	      start_of_line = pos + 1;
	      break;
	    }
            pos++;
          }
          continue;
        }
        break;
      }
      return;
    }
    if (c == "[" || c == "]" || c == "{" || c == "}") {
      current = c;
      pos++;
      return;
    }
    if (source[pos] == "#") {
      pos++;
      bool positive = true;
      int base = 10;
      if (pos == source.length) throw "Unexpected end";
      if (pos + 1 < source.length && source[pos] == "-") {
        pos++;
        positive = false;
      }
      if (pos + 2 < source.length &&
          source[pos] == "0" &&
          source[pos + 1] == "x") {
        base = 16;
        pos += 2;
      }
      int imm = 0;
      int digit = valueOfDigit(source.codeUnitAt(pos));
      if (digit < 0 || digit >= base) throw "Malformed immediate";
      while (0 <= digit && digit < base) {
        imm *= base;
        imm += digit;
        if (++pos == source.length) break;
        digit = valueOfDigit(source.codeUnitAt(pos));
      }
      current_int = positive ? imm : -imm;
      current = "#";
      return;
    }

    if (source[pos] == '"') {
      pos++;
      int end = pos;
      while (end < source.length && source.codeUnitAt(end) != '"'.codeUnitAt(0)) {
	if (source.codeUnitAt(end) == 0xa) {
	  just_before_newline = pos - 1;
	  line_number++;
	  start_of_line = pos + 1;
	}
        end++;
      }
      if (end == source.length) throw "Unexpected end during string";
      current_string = source.substring(pos, end);
      pos = end + 1;
      current = '"';
      return;
    }

    if (source.startsWith(".", pos) ||
        source.startsWith(":", pos) ||
        source.startsWith("->", pos)) {
      if (source.startsWith(":::", pos)) {
        current = ":::";
        pos += 3;
      } else if (source.startsWith("::", pos)) {
        current = "::";
        pos += 2;
      } else if (source.startsWith("..", pos)) {
        current = "..";
        pos += 2;
      } else if (source.startsWith("->", pos)) {
        current = "->";
        pos += 2;
      } else {
        current = source[pos];
        pos++;
      }
      // Read label.
      int end = pos;
      while (end < source.length && _isAlnum(source.codeUnitAt(end))) end++;
      current_string = source.substring(pos, end);
      current_field_name = null;
      pos = end;
      if (current == "->" &&
          pos < source.length &&
          source.codeUnitAt(pos) == '.'.codeUnitAt(0)) {
        pos++;
        if (pos == source.length) throw "Unexpected end of input";
        if (!_isAlnum(source.codeUnitAt(pos))) throw "Missing field name";
        end = pos + 1;
        while (end < source.length && _isAlnum(source.codeUnitAt(end))) end++;
        current_field_name = source.substring(pos, end);
        pos = end;
      }
      return;
    }

    // Get any lower case alpha token.
    int code = source.codeUnitAt(pos);
    if (lookup.containsKey(code)) {
      for (String candidate in lookup[code]) {
        if (source.startsWith(candidate, pos)) {
          int end = pos + candidate.length;
          int code = source.length == end ? 0 : source.codeUnitAt(end);
          if (_isAlnum(code)) continue;
          current = candidate;
          pos = end;
          return;
        }
      }
    }
    if (_isAlnum(code)) {
      int end = pos;
      while (end < source.length) {
        code = source.codeUnitAt(end);
        if (!_isAlnum(code)) break;
        end++;
      }
      String token = source.substring(pos, end);
      current_string = token;
      current = "token";
      pos = end;
      return;
    }
    throw ("Unexpected token '$c' (ascii ${c.codeUnitAt(0)})");
  }

  bool _isAlnum(int code) {
    return (48 <= code && code <= 57) ||
        (65 <= code && code <= 90) ||
        (97 <= code && code <= 122) ||
        code == 95;
  }

  int valueOfDigit(int asc) {
    if (97 <= asc && asc <= 122) {
      return asc - 87;
    } else if (65 <= asc && asc <= 90) {
      return asc - 55;
    } else if (48 <= asc && asc <= 57) {
      return asc - 48;
    } else {
      return -1;
    }
  }

  Map<String, int> reg_names = <String, int>{
    "a": 0,
    "b": 1,
    "c": 2,
    "sp": 4,
    "pc": 5,
    "status": 6,
  };

  void parse(String s) {
    source = s;
    pos = 0;
    previous_pos = 0;
    getNext();
    accept("\n");
    //print("Got $current");
    try {
    while (current != "") {
      for (int i = pos; i < source.length; i++) {
        if (source[i] == "\n") {
          // print("0x${pc.toRadixString(16)}: $current ${source.substring(pos, i)}");
          break;
        }
      }
      if (mnemonics.containsKey(current)) {
        mnemonics[current]();
      } else {
        throw "Unexpected token '$current'";
      }
    }
    } catch (parseError) {
      int end = previous_pos;
      if (end < 0) end = 0;
      while (source.length > end && source.codeUnitAt(end) != 0xa) end++;
      if (end > source.length) end = source.length;
      if (start_of_line >= source.length) start_of_line = source.length - 1;
      if (start_of_line <= 0) start_of_line = 0;
      if (end < start_of_line) end = start_of_line;
      int spaces = previous_pos - start_of_line;
      if (spaces < 0) spaces = 0;
      String message = "Parse error on line $line_number\n" +
	  source.substring(start_of_line, end) + "\n" +
	  "".padLeft(previous_pos - start_of_line) + "^ " + parseError;
      throw message;
    }
  }

  void parseSimple(int opcode) {
    accept(current);
    emit(opcode);
    expect("\n");
  }

  int parseRegister() {
    if (!reg_names.containsKey(current))
      throw "Expected register, found $current";
    int reg = reg_names[current];
    accept(current);
    return reg;
  }

  int parseCondition() {
    if (!COND_NAMES.containsKey(current))
      throw "Expected condition, found $current";
    int cond = COND_NAMES[current];
    accept(current);
    return cond;
  }

  int parseRegularRegister() {
    int reg = parseRegister();
    if (reg >= 3) throw "Unsupported register for operation";
    return reg;
  }

  void parseBinary(int index) {
    accept(current);
    int reg1 = parseRegister();
    int imm = current_int;
    if (accept("#")) {
      // Immediate case.  For non-regular registers we have only ADD and for
      // regular registers we don't have ADD.
      if (reg1 >= 3) {
        if (index == SUB) {
          imm = -imm;
          index = ADD;
        } else if (index != ADD) {
          throw "For non-regular registers only 'add' is allowed";
        }
      } else if (index == ADD) {
        index = SUB;
        imm = -imm;
      }
      if (reg1 < 3 && index == SUB && (imm == 1 || imm == -1)) {
        // Unary inc or dec is better for 1 and -1.
        index = imm == 1 ? DEC : INC;
        emit((index << 4) + (reg1 << 2) + reg1);
        expect("\n");
        return;
      }
      if (imm < -0x80 || imm > 0x7f) throw "Immediate out of range: $imm";
      if (reg1 == SP)
        reg1 = 0;
      else if (reg1 == PC)
        reg1 = 1;
      else if (reg1 == STATUS)
        reg1 = 2;
      else if (reg1 >= 3) throw "Illegal register for operation";
      emit((index << 4) + (reg1 << 2) + 3);
      emit(imm);
      expect("\n");
      return;
    }
    int reg2 = parseRegularRegister();
    bool emitted = false;
    if (reg1 == reg2) {
      if (index == MOVHI) {
        // Can't movhi to same reg, but we can use shl #8 instead.
        emit((SHIFT << 4) + (reg1 << 2) + 3);
        emit((SHL << 6) + 8);
        emitted = true;
      } else if (index == SUB || index == RSB) {
        emit((ZER << 4) + (reg1 << 2) + reg1);
        emitted = true;
      } else if (index == AND || index == OR) {
        emit((MOV << 4)); // Nop.
      } else if (index != ADD && index != XOR && index != MUL) {
        throw "Can't repeat same register for op";
      }
    }
    if (!emitted) {
      emit((index << 4) + (reg1 << 2) + reg2);
    }
    expect("\n");
  }

  // Set the control bits on a variable shift register to a given operation.
  // We assume the register is already masked down to the range 0-15.
  void parseSetShiftOp(int op) {
    accept(current);
    int reg = parseRegularRegister();
    if (op != 0) {
      const OR = 3;
      emit((OR << 4) + (reg << 2) + 3);
      emit(op << 6);
    }
    expect("\n");
  }

  // Clear the control bits on a variable shift register.
  void parseClearShiftOp() {
    accept(current);
    int reg = parseRegularRegister();
    const AND = 2;
    emit((AND << 4) + (reg << 2) + 3);
    emit(0x3f);
    expect("\n");
  }

  void parseShift(int op) {
    accept(current);
    int reg1 = parseRegularRegister();
    int imm = current_int;
    if (!accept("#")) imm = 1;
    if (imm < 0 || imm > 0xf) throw "Immediate out of range: $imm";
    if (imm == 1 && op == SHL) {
      emit((ADD << 4) + (reg1 << 2) + reg1); // Unary plus is shl 1.
    } else {
      emit((SHIFT << 4) + (reg1 << 2) + 3);
      emit((op << 6) + imm);
    }
    expect("\n");
    return;
  }

  void parseUnary(int index) {
    accept(current);
    int reg1 = parseRegister();
    if (reg1 >= 3) {
      // For irregular registers, only inc and dec are allowed.
      if (index != INC && index != DEC) throw "Illegal register for operation";
      int imm = index == INC ? 1 : -1;
      index = ADD;
      if (reg1 == SP)
        reg1 = 0;
      else if (reg1 == PC)
        reg1 = 1;
      else if (reg1 == STATUS)
        reg1 = 2;
      else
        throw ("Illegal register for operation");
      emit((index << 4) + (reg1 << 2) + 3);
      emit(imm);
    } else {
      emit((index << 4) + (reg1 << 2) + reg1);
    }
    expect("\n");
  }

  void parseLoadStore() {
    bool load = false;
    int memop = 0;
    if (current == "ld" || current == "ld8") {
      load = true;
      memop = current == "ld8" ? LOAD8 : LOAD16;
    } else {
      memop = current == "st8" ? STORE8 : STORE16;
    }
    accept(current);
    int data_reg = 0;
    if (load) data_reg = parseRegularRegister();
    expect("[");
    int imm = parseOffset();
    if (imm != null) {
      // Absolute address.
      bool out_of_range = imm > 0x7f && imm < 0xff80;
      if (out_of_range && !load) throw "Address out of range";
      expect("]");
      if (!load) data_reg = parseRegularRegister();
      if (out_of_range) {
        // We need to first load the address into the data register.
        // This only works for load, because we need an extra register
        // that is not available for store.
        int hi = imm >> 8;
        imm &= 0xff;
        if (imm > 0x7f) {
          hi++;
          imm -= 0x100;
        }
        // Load high bits of address.
        emit((MOVHI << 4) + (data_reg << 2) + 3);
        emit(hi);
        // Load using 8 bit offset to high bits.
        emit(0xc + (data_reg << 6) + (memop << 4) + data_reg);
        emit(imm);
      } else {
        // Within range for a single instruction.
        emit(0xc3 + (memop << 4) + (data_reg << 2));
        emit(imm);
      }
    } else {
      // Register relative.
      int addr_reg = parseRegister();
      if (addr_reg >= 3 && addr_reg != SP)
        throw "Disallowed base register for memory op";
      imm = parseOffset();
      if (imm == null) imm = 0;
      expect("]");
      if (!load) data_reg = parseRegularRegister();
      if (imm < -0x80 || imm > 0x7f) throw "Address offset out of range";
      if (addr_reg == SP) addr_reg = 3;
      emit(0xc + (data_reg << 6) + (memop << 4) + addr_reg);
      emit(imm);
    }
    expect("\n");
    return;
  }

  int parseOffset() {
    int imm = current_int;
    String struct_name = current_string;
    String field = current_field_name;
    if (accept("#")) {
      field = struct_name = null;
    } else if (!accept("->")) {
      return null;
    }
    if (struct_name != null) {
      if (field == null) throw "Expected ->struct.fieldname";
      if (!structs.containsKey(struct_name))
        throw "Unknown struct $struct_name";
      Struct struct = structs[struct_name];
      imm = struct.lookup(field).offset;
    }
    imm &= 0xffff;
    return imm;
  }

  void parseMove() {
    accept(current);
    int reg1 = parseRegister();
    int imm = current_int;
    Map<String, Label> map;
    String label_name = current_string;
    if (accept("..")) {
      map = global_labels;
    } else if (accept(".")) {
      map = local_labels;
    }
    if (map != null) {
      // Create patchable mov #imm16 out of movhi and sub.
      emit((MOVHI << 4) + (reg1 << 2) + 3);
      emit(0);
      emit((SUB << 4) + (reg1 << 2) + 3);
      emit(0);
      Label label =
          map.putIfAbsent(label_name, () => new Label(memory, label_name));
      label.link_imm16(pc - 3);
      expect("\n");
      return;
    }
    if (accept("#")) {
      if (reg1 >= 3) throw "Invalid register for mov #immediate";
      if (imm < -0x8000 || imm > 0xffff) throw "Immediate out of range";
      if (imm == 0) {
        // Use zer instruction.
        emit((ZER << 4) + (reg1 << 2) + reg1);
      } else if (imm >= -0x80 && imm <= 0x7f) {
        // mov r #imm8
        emit((MOV << 4) + (reg1 << 2) + 3);
        emit(imm);
      } else {
        // Create 16 bit op out of smaller ops.
        if (imm >= -0x100 && imm <= 0xfe) {
          // Use an immediate and a SHR
          emit((MOV << 4) + (reg1 << 2) + 3);
          emit(imm >> 1);
          emit((ADD << 4) + (reg1 << 2) + reg1); // Unary shr.
        } else {
          // Use a movhi and a sub.
          int hi = (imm >> 8) & 0xff;
          int lo = imm & 0xff;
          if (lo > 0x80) {
            hi++;
            lo -= 0x100;
          }
          emit((MOVHI << 4) + (reg1 << 2) + 3);
          emit(hi);
          if (lo != 0) {
            emit((SUB << 4) + (reg1 << 2) + 3);
            emit(-lo);
          }
        }
      }
    } else {
      int reg2 = parseRegister();
      if (reg1 < 3 && reg2 < 3) {
        if (reg1 == reg2) {
          reg1 = reg2 = RA; // Nop is mov a a.
        }
        emit((MOV << 4) + (reg1 << 2) + reg2);
      } else {
        int special = -1;
        if (reg1 == 2) {
          if (reg2 == PC) {
            special = MOV_C_PC;
          } else if (reg2 == SP) {
            special = MOV_C_SP;
          } else if (reg2 == STATUS) {
            special = MOV_C_STATUS;
          }
        } else if (reg2 == 2) {
          if (reg1 == PC) {
            special = MOV_PC_C;
          } else if (reg1 == SP) {
            special = MOV_SP_C;
          } else if (reg1 == STATUS) {
            special = MOV_STATUS_C;
          }
        }
        if (special == -1) throw "Invalid register combination in mov";
        emit(0xc8 + ((special >> 1) << 6) + (special & 1));
      }
    }
    expect("\n");
  }

  void parseReturn() {
    emit(current == "ret" ? 0xcf : 0xdf);
    accept(current);
    int imm = current_int;
    if (!accept("#")) imm = 0;
    if (imm < 0 || imm > 0xff) throw "Immediate out of range";
    emit(imm);
    expect("\n");
  }

  void parseJump() {
    if (current != "ptr") emit(current == "jmp" ? 0xef : 0xff);
    accept(current);
    int imm = current_int;
    Map<String, Label> map;
    String label_name = current_string;
    if (accept("..")) {
      map = global_labels;
    } else if (accept(".")) {
      map = local_labels;
    } else {
      if (!accept("#")) imm = 0;
      if (imm > 0xffff) throw "Address out of range";
      emit16(imm);
      expect("\n");
      return;
    }
    Label label =
        map.putIfAbsent(label_name, () => new Label(memory, label_name));
    label.link16(pc);
    pc += 2;
    expect("\n");
    return;
  }

  void addUnboundLabel(String s) {
    global_labels.putIfAbsent(s, () => new Label(memory, s));
  }

  Iterable<String> unboundLabels() {
    return global_labels.keys.where((l) => !global_labels[l].bound);
  }

  void parsePushPop() {
    int memop = 0;
    if (current == "pop" || current == "pop8") {
      memop = current == "pop8" ? LOAD8 : LOAD16;
    } else {
      memop = current == "push8" ? STORE8 : STORE16;
    }
    accept(current);
    int reg = parseRegularRegister();
    emit(0xc2 + (memop << 4) + (reg << 2));
    accept("\n");
  }

  void parseBranch() {
    expect("b");
    int cond = parseCondition();
    int offset = current_int;
    if (accept("#")) {
      if (offset < -0x80 || offset > 0x7f) throw "Branch offset out of range";
      emit(0xcc + ((cond & 3) << 4) + (cond >> 2));
      emit(offset);
    } else {
      String label_name = current_string;
      Map<String, Label> map;
      if (accept(".")) {
        map = local_labels;
      } else {
        expect("..");
        map = global_labels;
      }
      Label label =
          map.putIfAbsent(label_name, () => new Label(memory, label_name));
      // TODO: If branch is known to be out of range, reverse the sense and
      // jump over a jmp.
      emit(0xcc + ((cond & 3) << 4) + (cond >> 2));
      label.link8(pc);
      pc++;
    }
    expect("\n");
  }

  void parseLabel() {
    String name = current_string;
    bool global = current.length >= 2;
    bool wipe_locals = current.length >= 3;
    expect(current);
    Map<String, Label> map;
    if (global) {
      map = global_labels;
      if (wipe_locals) {
        for (Label label in local_labels.values) {
          if (!label.bound) throw "Never bound ${label.name}";
        }
        local_labels = new Map<String, Label>();
      }
    } else {
      map = local_labels;
    }
    Label label = map.putIfAbsent(name, () => new Label(memory, name));
    label.bind(pc);
    expect("\n");
  }

  void parseString() {
    String s = current_string;
    accept(current);
    accept("\n");
    for (int i = 0; i < s.length; i++) {
      emit(s.codeUnitAt(i));
    }
    emit(0);
  }

  void parseConstant() {
    bool two_bytes = current == "int";
    accept(current);
    int imm = current_int;
    expect("#");
    if (two_bytes) {
      emit16(imm);
    } else {
      emit(imm);
    }
    expect("\n");
  }

  void parseStruct() {
    expect(current);
    String struct_name = current_string;
    expect("token");
    if (structs.containsKey(struct_name)) throw "Duplicate struct $struct_name";
    Struct struct = new Struct(struct_name);
    expect("{");
    accept("\n");
    int position = 0;
    while (true) {
      if (accept("char")) {
        String field_name = current_string;
        expect("token");
        struct.add(field_name, position, 1);
        position += 1;
      } else if (accept("int") || accept("ptr")) {
        String field_name = current_string;
        expect("token");
        struct.add(field_name, position, 2);
        position += 2;
      } else if (accept("}")) {
        break;
      } else {
        throw "Expected struct type, found $current";
      }
      accept("\n");
    }
    structs[struct_name] = struct;
    accept("\n");
  }

  void finish() {
    for (Label label in local_labels.values) {
      if (!label.bound) throw "Never bound ${label.name}";
    }
  }

  void emit(int x) {
    if (pc == end) throw "Assembler ran out of space";
    memory.store8(pc, x);
    pc++;
  }

  void emit16(int x) {
    if (pc + 1 >= end) throw "Assembler ran out of space";
    memory.store16(pc, x);
    pc += 2;
  }

  int pc;
  int end;
  Memory memory;
  Map<String, Struct> structs = new Map<String, Struct>();
}
