import 'memory.dart';
import 'disassembler.dart';

class CPU {
  CPU(this.memory) {
    pc = memory.load16(0xfffe);
    sp = 0x200;
    rA = rB = rC = 0;
    status = new Status();
    dummy = new Status();
    binaries = [
      sub,
      and,
      or,
      xor,
      shift,
      sethi,
      rsb,
      add,
      sub /* cmp */,
      mul,
      mov,
      div
    ];
    unaries = [
      unarysub,
      unarynot,
      unaryadc,
      unaryzer,
      unarysbc,
      unaryinc,
      unarydec,
      unaryshl,
      unarycmp,
      unarysquare,
      unarynop,
      unarypopcnt
    ];
  }

  Memory memory;
  int pc;
  int sp;
  int rA;
  int rB;
  int rC;
  Status status;
  Status dummy;

  List binaries;
  List unaries;
  List<String> cond_name_list;

  void push(int x) {
    sp -= 2;
    memory.store16(sp, x);
  }

  void push8(int x) {
    sp -= 1;
    memory.store8(sp, x);
  }

  int pop() {
    int result = memory.load16(sp);
    sp += 2;
    return result;
  }

  int pop8() {
    int result = memory.load8(sp);
    sp += 2;
    return result;
  }

  int reg_get(int reg) {
    switch (reg) {
      case RA:
        return rA;
      case RB:
        return rB;
      case RC:
        return rC;
      case RZ:
        return 0;
      case SP:
        return sp;
      case PC:
        return pc;
    }
    return 0;
  }

  void reg_set(int reg, int value) {
    switch (reg) {
      case RA:
        rA = value;
        break;
      case RB:
        rB = value;
        break;
      case RC:
        rC = value;
        break;
      case SP:
        sp = value;
        break;
      case PC:
        pc = value;
        break;
    }
  }

  bool step(bool dis) {
    if (dis) Disassembler.disassemble(memory, pc, this);
    int bytecode = memory.load8(pc);
    int op = bytecode >> 4;
    int reg1 = (bytecode >> 2) & 3;
    int reg2 = bytecode & 3;
    int memop_code = (bytecode >> 4) & 3;
    int imm = 0;
    pc++;
    if ((bytecode & 3) == 3 || (bytecode & 0xc) == 0xc) {
      imm = get_imm8();
    }
    if (op < 12 && reg1 != 3) {
      // ALU operations.
      if (op == MOV && reg1 == reg2) {
        if (reg1 == RA) return false; // NOP
        if (reg1 == RB) return true; // BRK
	if (reg1 == RC) return true; // HLT
        throw "Invalid instruction";
      }
      int value = reg2 == 3 ? imm : reg_get(reg2);
      int result = 0;
      if (reg1 == reg2) {
        result = unaries[op](reg_get(reg1), status);
      } else {
        result = binaries[op](reg_get(reg1), value, status);
      }
      if (op != CMP) reg_set(reg1, result);
    } else if ((bytecode & 0xce) == 0xc8) {
      special(bytecode);
    } else if ((bytecode & 0xcc) == 0xcc) {
      branch(bytecode, imm);
    } else if (reg1 == 3 || (bytecode & 0xc2) == 0xc2) {
      memop(bytecode, reg1, reg2, memop_code, imm);
    }
    return false;
  }

  void special(int opcode) {
    int code = ((opcode >> 3) & 6) + (opcode & 1);
    switch (code) {
      case 0:
        rC = pc;
        break;
      case 1:
        pc = rC;
        break;
      case 2:
        rC = sp;
        break;
      case 3:
        sp = rC;
        break;
      case 4:
        rC = get_flags();
        break;
      case 5:
        set_flags(rC);
        break;
      case 6:
        status.carry = status.carry8;
        status.overflow = status.overflow8;
        status.sign = status.sign8;
        status.zero = status.zero8;
        status.test_zero = status.test_zero8;
        break;
      case 7:
        // TODO - reserved.
        break;
    }
  }

  void branch(int bytecode, int offset) {
    if ((bytecode & 3) != 3) {
      conditional_branch(bytecode, offset);
    } else {
      jumps_and_calls(bytecode, offset);
    }
  }

  void conditional_branch(int bytecode, int offset) {
    int cond = ((bytecode & 3) << 2) + ((bytecode >> 4) & 3);
    bool branch = false;
    switch (cond) {
      case C_ZERO:
        branch = status.zero == 1;
        break;
      case C_NOT_ZERO:
        branch = status.zero == 0;
        break;
      case C_CARRY:
        branch = status.carry == 1;
        break;
      case C_NOT_CARRY:
        branch = status.carry == 0;
        break;
      case C_LESS:
        branch = status.sign != status.overflow;
        break;
      case C_GREATER_EQUAL:
        branch = status.sign == status.overflow;
        break;
      case C_TEST_ZERO:
        branch = status.test_zero == 1;
        break;
      case C_TEST_NOT_ZERO:
        branch = status.test_zero == 0;
        break;
      case C_BELOW_EQUAL:
        branch = status.carry == 1 || status.zero == 1;
        break;
      case C_ABOVE:
        branch = status.carry == 0 && status.zero == 0;
        break;
      case C_LESS_EQUAL:
        branch = status.zero == 1 || status.sign != status.overflow;
        break;
      case C_GREATER:
        branch = status.zero == 0 && status.sign == status.overflow;
        break;
    }
    if (branch) {
      //print("offset = $offset, pc = 0x${pc.toRadixString(16)}");
      pc += offset;
      //print("new pc = 0x${pc.toRadixString(16)}");
      pc &= 0xffff;
    }
  }

  int get_flags() {
    int r = status.carry;
    r += status.overflow << 1;
    r += status.sign << 2;
    r += status.zero << 3;
    r += status.test_zero << 4;
    r += status.carry8 << 5;
    r += status.overflow8 << 6;
    r += status.sign8 << 7;
    r += status.zero8 << 8;
    r += status.test_zero8 << 9;
    r += status.interrupt << 10;
    return r;
  }

  void set_flags(int x) {
    status.carry = x & 1;
    status.overflow = (x >> 1) & 1;
    status.sign = (x >> 2) & 1;
    status.zero = (x >> 3) & 1;
    status.test_zero = (x >> 4) & 1;
    status.carry8 = (x >> 5) & 1;
    status.overflow8 = (x >> 6) & 1;
    status.sign8 = (x >> 7) & 1;
    status.zero8 = (x >> 8) & 1;
    status.test_zero8 = (x >> 9) & 1;
    status.interrupt = (x >> 10) & 1;
  }

  void jumps_and_calls(int opcode, int offset) {
    if ((opcode & 0x20) == 0) {
      // RET and RTI.
      sp += offset;
      pc = memory.load16(sp);
      sp += 2;
      if ((opcode & 0x10) == 1) status.interrupt = 1;
    } else {
      // Call and jmp.
      int return_address = pc + 1;
      pc = memory.load16(pc - 1);
      if ((opcode & 0x10) == 0x10) {
        sp -= 2;
        memory.store16(sp, return_address);
      }
    }
  }

  void memop(int bytecode, int reg1, int reg2, int memop_code, int imm) {
    int addr = 0;
    int data = 0;
    if (reg1 == 3) {
      data = bytecode >> 6;
      addr = reg_get(reg2 == 3 ? SP : reg2) + imm;
    } else {
      data = reg1;
      if ((bytecode & 1) == 0) {
        if (memop_code == STORE8)
          sp = sub(sp, 1, dummy);
        else if (memop_code == STORE16) sp = sub(sp, 2, dummy);
        addr = reg_get(SP);
        if (memop_code == LOAD8)
          sp = add(sp, 1, dummy);
        else if (memop_code == LOAD16) sp = add(sp, 2, dummy);
      } else {
        addr = imm & 0xff;
      }
    }
    memop_helper(memop_code, addr, data);
  }

  int get_imm8() {
    int imm = memory.load8(pc);
    pc++;
    // Sign extend.
    if ((imm & 0x80) != 0) imm |= 0xff00;
    return imm;
  }

  void memop_helper(int memop, int address, int value_reg) {
    address &= 0xffff;
    switch (memop) {
      case LOAD8:
        reg_set(value_reg, memory.load8(address));
        break;
      case LOAD16:
        reg_set(value_reg, memory.load16(address));
        break;
      case STORE8:
        if (address >= 0x8000) throw "Segmentation fault";
        memory.store8(address, reg_get(value_reg));
        break;
      case STORE16:
        if (address >= 0x7fff) throw "Segmentation fault";
        memory.store16(address, reg_get(value_reg));
        break;
    }
  }

  int add(int x, int y, Status status) => generic(x, y, true, status);

  int sub(int x, int y, Status status) => generic(x, y, false, status);

  int rsb(int x, int y, Status status) => generic(y, x, false, status);

  int generic(int x, int y, bool add, Status status) {
    x &= 0xffff;
    y &= 0xffff;
    status.test_zero = (x & y) == 0 ? 1 : 0;
    status.test_zero8 = (x & y & 0xff) == 0 ? 1 : 0;
    int r = add ? x + y : x - y;
    status.overflow = r >> 16 == ((r >> 15) & 1) ? 0 : 1;
    status.overflow8 = ((r >> 8) & 1) == ((r >> 7) & 1) ? 0 : 1;
    if (r < 0 || r > 0xffff) {
      status.carry = 1;
      r &= 0xffff;
    } else {
      status.carry = 0;
    }
    status.carry8 = ((x & 0xff) + (y & 0xff)) > 0xff ? 1 : 0;
    status.zero = r == 0 ? 1 : 0;
    status.zero8 = (r & 0xff) == 0 ? 1 : 0;
    status.sign = r >> 15;
    status.sign8 = (r >> 7) & 1;
    return r;
  }

  int and(int x, int y, Status status) {
    status.carry = status.carry8 = 0;
    status.overflow = status.overflow8 = 0;
    int r = x & y;
    status.zero = r == 0 ? 1 : 0;
    status.zero8 = (r & 0xff) == 0 ? 1 : 0;
    return r;
  }

  int or(int x, int y, Status status) {
    status.carry = status.carry8 = 0;
    status.overflow = status.overflow8 = 0;
    int r = x | y;
    status.zero = r == 0 ? 1 : 0;
    status.zero8 = (r & 0xff) == 0 ? 1 : 0;
    return r;
  }

  int xor(int x, int y, Status status) {
    status.carry = status.carry8 = 0;
    status.overflow = status.overflow8 = 0;
    int r = x ^ y;
    status.zero = r == 0 ? 1 : 0;
    status.zero8 = (r & 0xff) == 0 ? 1 : 0;
    return r;
  }

  int sethi(int x, int y, Status status) {
    status.carry8 = 0;
    status.overflow = status.overflow8 = 0;
    status.carry = (y & 0x100) >> 8;
    int r = (y << 8) & 0xffff;
    status.zero = r == 0 ? 1 : 0;
    status.zero8 = 1;
    return r;
  }

  int mov(int x, int y, Status status) {
    int r = y;
    return r;
  }

  int mul(int x, int y, Status status) {
    throw ("No mul instruction in the 1980s, pc=${pc}");
  }

  int div(int x, int y, Status status) {
    throw ("No div instruction in the 1980s, pc=${pc}");
  }

  int shift(int x, int y, Status status) {
    x &= 0xffff;
    int r = 0;
    int op = (y >> 6) & 3;
    int shift = y & 0xf;
    int sign_before = x >> 15;
    int sign8_before = (x >> 7) & 1;

    if (op == SHR || op == SAR) {
      int sign = (x >> 15) & 1;
      r = x >> shift;
      if (op == SAR && sign == 1) {
        r |= (0xffff0000 >> shift) & 0xffff;
      }
      int lost_bits = x & ((1 << shift) - 1);
      status.carry = status.carry8 = lost_bits == 0 ? 0 : 1;
      status.overflow = status.overflow8 = 0;
    } else if (op == SHL || op == ROL) {
      r = x << shift;
      if (op == ROL) {
        r |= x >> (16 - shift);
      }
      status.carry = r > 0xffff ? 1 : 0;
      int r8 = (x & 0xff) << shift;
      status.carry8 = r8 > 0xff ? 1 : 0;
    }
    r &= 0xffff;
    status.zero = r == 0 ? 1 : 0;
    status.zero8 = (r & 0xff) == 0 ? 1 : 0;
    status.sign = r >> 15;
    status.sign8 = (r >> 7) & 1;
    status.overflow = status.sign == sign_before ? 0 : 1;
    status.overflow8 = status.sign8 == sign8_before ? 0 : 1;
    return r;
  }

  int unarypopcnt(int x, Status status) {
    x &= 0xffff;
    int r = 0;
    while (x != 0) {
      if ((x & 1) == 1) r++;
      x >>= 1;
    }
    status.carry = status.carry8 = 0;
    status.overflow = status.overflow8 = 0;
    status.zero = status.zero8 = r == 0 ? 1 : 0;
    return r;
  }

  int unaryshl(int x, Status status) => add(x, x, status);

  int unarysub(int x, Status status) => sub(0, x, status);

  int unarycmp(int x, Status status) => sub(x, 0, status);

  int unarynot(int x, Status status) => xor(x, 0xffff, status);

  int unaryadc(int x, Status status) => add(x, status.carry, status);

  int unaryzer(int x, Status status) => xor(x, x, status);

  int unarysbc(int x, Status status) => sub(x, status.carry, status);

  int unaryinc(int x, Status status) => add(x, 1, status);

  int unarydec(int x, Status status) => sub(x, 1, status);

  int unarynop(int x, Status status) => mov(x, x, status);

  int unarysquare(int x, Status status) => mul(x, x, status);
}

class Status {
  Status() {
    carry = 0;
    overflow = 0;
    sign = 0;
    zero = 0;
    test_zero = 0;
    carry8 = 0;
    overflow8 = 0;
    sign8 = 0;
    zero8 = 0;
    test_zero8 = 0;
  }

  int carry;
  int overflow;
  int sign;
  int zero;
  int test_zero;
  int carry8;
  int overflow8;
  int sign8;
  int zero8;
  int test_zero8;
  int interrupt;
}

const RA = 0;
const RB = 1;
const RC = 2;
const RZ = 3;
const SP = 4;
const PC = 5;
const STATUS = 6;

const C_ZERO = 0;
const C_NOT_ZERO = 1;
const C_CARRY = 2;
const C_NOT_CARRY = 3;
const C_LESS = 4;
const C_GREATER_EQUAL = 5;
const C_TEST_ZERO = 6;
const C_OVERFLOW = 6;
const C_TEST_NOT_ZERO = 7;
const C_NOT_OVERFLOW = 7;
const C_BELOW_EQUAL = 8;
const C_ABOVE = 9;
const C_LESS_EQUAL = 10;
const C_GREATER = 11;

const LOAD8 = 0;
const LOAD16 = 1;
const STORE8 = 2;
const STORE16 = 3;

const MOV_C_PC = 0;
const MOV_PC_C = 1;
const MOV_C_SP = 2;
const MOV_SP_C = 3;
const MOV_C_STATUS = 4;
const MOV_STATUS_C = 5;
const MOV_STATUS_STATUS8 = 6;

const SUB = 0;
const AND = 1;
const OR = 2;
const XOR = 3;
const SHIFT = 4;
const MOVHI = 5;
const RSB = 6;
const ADD = 7;
const CMP = 8;
const MUL = 9;
const MOV = 10;
const DIV = 11;
const NEG = 0;
const NOT = 1;
const ADC = 2;
const ZER = 3;
const SBC = 4;
const INC = 5;
const DEC = 6;
const SQUARE = 9;
const POPCNT = 11;

const SHR = 0;
const SAR = 1;
const SHL = 2;
const ROL = 3;
