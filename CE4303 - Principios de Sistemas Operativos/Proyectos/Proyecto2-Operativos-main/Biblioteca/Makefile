CC=gcc
AR=ar

librobomano.a: robomano.o
	$(AR) rcs $@ $^

robomano.o: robomano.c robomano.h
	$(CC) -c -O2 -Wall $<

demo: demo.c librobomano.a
	$(CC) demo.c -L. -lrobomano -o demo

clean:
	rm -f *.o librobomano.a demo
