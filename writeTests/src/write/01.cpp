#include <cstdio>

int main()
{
	FILE* out = fopen("bin/output.txt", "w");

	for (int i = 0; i < 1000000; ++i)
		fprintf(out, "a");

	return 0;
}