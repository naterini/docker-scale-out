#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	while (1) {
		malloc(1024 * 4);
		fork();
	}
}
