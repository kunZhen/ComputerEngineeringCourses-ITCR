#include "robomano.h"
int main(void)
{
	if (robomano_init()) return 1;

	robomano_write_word("rf");   /* cambia aquí la palabra a probar */
	robomano_close();
	return 0;
}
