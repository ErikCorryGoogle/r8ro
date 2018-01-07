import 'cpu.dart';

Map<String, int> COND_NAMES = <String, int>{
  "z": C_ZERO,
  "eq": C_ZERO, // equal.
  "nz": C_NOT_ZERO,
  "ne": C_NOT_ZERO, // not equal.
  "c": C_CARRY,
  "cs": C_CARRY, // carry set.
  "b": C_CARRY, // below (unsigned).
  "nae": C_CARRY, // not above or equal (unsigned).
  "nc": C_NOT_CARRY,
  "cc": C_NOT_CARRY, // carry clear.
  "nb": C_NOT_CARRY, // not below (unsigned).
  "ae": C_NOT_CARRY, // above or equal (unsigned).
  "l": C_LESS, // (signed): sign != overflow.
  "nge": C_LESS, // not greater or equal (signed).
  "ge": C_GREATER_EQUAL, // (signed): sign == overflow.
  "nl": C_GREATER_EQUAL, // not less (signed).
  "tz": C_TEST_ZERO, // if the cmp insn had been a tst insn...
  "tnz": C_TEST_NOT_ZERO, // ...would the zero flag be set.
  "o": C_OVERFLOW, // Does not work for cmp instructions.
  "no": C_NOT_OVERFLOW, // Does not work for cmp instructions.
  "be": C_BELOW_EQUAL, // (unsigned).
  "na": C_BELOW_EQUAL, // not above (unsigned).
  "a": C_ABOVE, // (unsigned).
  "nbe": C_ABOVE, // not below or equal (unsigned).
  "le": C_LESS_EQUAL, // (signed): sign != overflow.
  "ng": C_LESS_EQUAL, // not greater (signed).
  "g": C_GREATER, // (signed): sign == overflow.
  "nle": C_GREATER, // not less or equal (signed).
};
