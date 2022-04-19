# My first makefile

all: PBL_1

uart: uart.o
	ld -o uart uart.o

uart.o: uart.s
	as -o uart.o main.s -Wall

clean:
	rm -rf *.o *~ PBL_1
