String hex(int x) {
  x &= 0xffff;
  if (x < 0x100) return "0x${x.toRadixString(16).padLeft(2, "0")}";
  return "0x${x.toRadixString(16).padLeft(4, "0")}";
}

class IOPorts {
  IOPorts(this.from, this.to, this.callback);

  void store8(int addr, int value) {
    if (from <= addr && addr < to) callback(addr, value);
  }

  int from;
  int to;
  Function callback;
}
