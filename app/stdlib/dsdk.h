#ifndef DRIFTLESS_SDK_STD_H
#define DRIFTLESS_SDK_STD_H

__attribute__((visibility("hidden"))) extern void WriteString(const char *str);
__attribute__((visibility("hidden"))) extern void ExitProgram(void);
__attribute__((visibility("hidden"))) extern void WriteChar(char c);
__attribute__((visibility("hidden"))) extern void ReadChar(void);

#endif
