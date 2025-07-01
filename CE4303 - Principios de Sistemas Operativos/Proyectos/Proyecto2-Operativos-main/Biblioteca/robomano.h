#pragma once
int  robomano_init(void);              /* abre /dev/robomano */
void robomano_write_word(const char*); /* envía toda la palabra */
void robomano_close(void);             /* cierra el descriptor */
