#include <dsdk.h>

void WriteNumber(int num);

void AppMain()
{
	WriteString("FIBONACCI\n\n");

	int a = 0;
	int b = 1;
	int count = 15;

	for (int i = 0; i < count; i++)
	{
		WriteNumber(a);
		WriteChar('\n');

		int next = a + b;
		a = b;
		b = next;
	}
}

void WriteNumber(int num)
{
	if (num == 0)
	{
		WriteChar('0');
		return;
	}

	char buf[12];
	int i = 0;

	while (num > 0)
	{
		buf[i++] = '0' + (num % 10);
		num /= 10;
	}

	while (i > 0)
	{
		WriteChar(buf[--i]);
	}
}
