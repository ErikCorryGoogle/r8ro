// Screen memory starts at 22k and goes to about 32k by default, but
// programmable.
const screenStart = 1024 * 22;
const screenEnd = screenStart + lines * bytesPerLine;

// Fixed screen vector at 1024.
const screenVectorStart = 4 * 256;
const screenVectorEnd = 8 * 256;
const screenModeStart = 8 * 256;
const screenModeEnd = 8 * 256 + 64;
const screenPalateStart = screenModeEnd;  // 14 or 16 entries.
const screenPalateEnd = screenPalateStart + 16;

// For default mode (320x256, 1 bit).
const bytesPerLine = 320 ~/ 8;
const linesPerCharLine = 11;
const textLines = 23;
const lines = 256;
// 1B8 for 11 lines per char. = 1 10111000 - 23 lines

// 2.5k of font ROM.
const fontRomStart = 256 * 245;
const fontRomEnd = 256 * 255;
