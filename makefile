# My first makefile

all: uart

uart: uart.o
	ld -o uart uart.o

uart.o: uart.s
	as -o uart.o main.s -Wall

clean:
	rm -rf *.o *~ uart