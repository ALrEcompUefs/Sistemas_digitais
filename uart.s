@----------------------------------------------------------------------------------------------
@ Define as constantes usadas, do tipo string
	.align 2
	.data
	memdev: .asciz "/dev/mem"
	sucesso: .ascii "Abrimos /dev/gpiomen com sucesso\n"
	mapeado: .ascii "Mapeamos com sucesso\n"

@----------------------------------------------------------------------------------------------

@----------------------------------------------------------------------------------------------
@ Paramêtros relacionados a abertura de aquivo e mapeamento da memoria 
.global gpiobase
gpiobase: .word 0
.global pwmbase
pwmbase: .word 0
.global uart0base
uart0base: .word 0
.global clkbase
clkbase: .word 0

.equ PERI_BASE, 0x200000 @ start of all devices @ Endereço base da Raspberry
.equ UART0_BASE,(PERI_BASE + 0x20201) @ Endereço base da UART

.equ MAP_SHARED, 1 @Indica que o mapeamento da memória virtual é compartilhado
.equ PROT_READ, 1 @Modo de leitura
.equ PROT_WRITE, 2 @Modo de escrita
.equ PROT_RDWR,PROT_READ|PROT_WRITE @Modo de leitura e escrita 

@ constantes da biblioteca from fcntl.h usadas na syscall para abertura de arquivo
.equ O_RDONLY, 00000000
.equ O_WRONLY, 00000001
.equ O_RDWR, 00000002
.equ O_TRUNC, 00001000
.equ O_APPEND, 00002000
.equ O_SYNC, 00010000
.equ O_FSYNC, O_SYNC
.equ O_ASYNC, 00020000

@----------------------------------------------------------------------------------------------
@	ENDEREÇOS DO REGISTRADORES DA UART E DEFINIÇÃO DOS VALORES DO REGISTRADORES

@--------- REGISTRADORES---------------------------
.equ UART_DR, 0x00 	@ Registrador de dados
.equ UART_LCRH, 0x2C 	@ Registrador de controle de linha
.equ UART_FR, 0x18 	@ Flag Register
.equ UART_IBRD, 0x24 	@ Divisor de baud rate inteiro
.equ UART_FBRD, 0x28 	@ Divisor de baud rate fracionário
.equ UART_CR, 0x30 	@ Registrador de controle

@-------------Bits do LCRH---------------------------------------------------------------------
@ Disposição do bits do registrador de controle de linha e definindo valor 1
.equ UART_SPS, (1<<7) @ enable stick parity
.equ UART_WLEN1, (1<<6) @ MSB do tamanho de mensagem
.equ UART_WLEN0, (1<<5) @ LSB do tamanho de mensagem
.equ UART_FEN, (1<<4) @ Habilita FIFOs
.equ UART_FEND, (0<<4) @ Desabilita FIFOs
.equ UART_STP2, (1<<3) @ Define a quantidade de stop bits como 2
.equ UART_EPS, (1<<2) @ Seleciona o tipo de paridade: PAR
.equ UART_PEN, (1<<1) @ Habilita paridade
.equ UART_BRK, (1<<0) @ Envia pausa de dados


@-------------Bits do DR-----------------------------
@ Configura paramêtros do data register que verificam erros
.equ UART_OE, (1<<11) @ erro de bit de superação
.equ UART_BE, (1<<10) @ erro de bit de parada
.equ UART_PE, (1<<9) @ bit de erro de paridade
.equ UART_FE, (1<<8 ) @ bit de erro de enquadramento

@ Configura parametros (bits) do FLAG register
.equ UART_TXFE, (1<<7) @ FIFO de Transmissão vazia
.equ UART_RXFF, (1<<6) @ FIFO de recepção cheia
.equ UART_TXFF, (1<<5) @ FIFO de transmissão cheia
.equ UART_RXFE, (1<<4) @ FIFO de recepção vazia
.equ UART_BUSY, (1<<3) @ Indica que a uart está ocupada trasmitindo
.equ UART_CTS, (1<<0) @ Limpa para enviar


@ Bits do registrador CR
.equ UART_RXE, (1<<9) @ Habilita recepção
.equ UART_RXD, (0<<9) @ Desabilita recepção
.equ UART_TXE, (1<<8) @ Habilita transmissão
.equ UART_TXD, (0<<8) @ Desabilita transmissão
.equ UART_LBE, (1<<7) @ Habilita loopback
.equ UART_LBD, (0<<7) @ Desabilita loopback
.equ UART_UARTEN, (1<<0) @ Habilita UART
.equ UART_UARTDS, (0<<0) @ Desabilita UART

.equ HabilitarUART, (UART_UARTEN | UART_TXE | UART_RXE) @ binario equivalente a configuração a ser dwefinida no registrador CR

@----------------------------------------------------------------------------------------------

.global _start

.section .text

_start:
    ldr r0, file
    ldr r1, flag @ Leitura e Escrita do arquivo aberto / Flag O_RDWR
    ldr r2, openMode
    mov r7, #5 @Sycall Open
    svc 0
    subs r3,r0,#0
    bge aberto @Se foi 0, abre
    b mensagem_erro @se foi diferente de 0

@-----------------Função da abertura de arquivo Correta----------------------------------------

aberto:
    @stdin - 0
    @stdout - 1
    @stderr - 2
    mov r4,r0 @ Movendo o file descriptor pro r4
    @ mostrar mensagem de sucesso
    mov r0,#1 @ printar mensagem no terminal
    ldr r1,=sucesso @ a mensagem em si
    mov r2,#33 @ tamanho da mensagem
    mov r7,#4 @ syscall pro write
    svc 0 @ chamando a syscall
    b mapear_gpio

@----------------------------------------------------------------------------------------------

@---------------Função mapear GPIO-------------------------------------------------------------
@ Com o arquivo dev/Mem aberto realiza o mapeamento da memoria virtual da raspberry

mapear_gpio:
    @ Mapear a GPIO
    mov r7,#192 		@ syscall do mmap2
    ldr r5,=baseUART0		@ Carrega no registrador r5  o enereço base da UART ( definido no cabeçalho)
    mov r0,#0 			@kernel escolhe a memoria
    mov r1,#4096 		@ Page size
    ldr r2,=PROT_RDWR
    ldr r3,=MAP_SHARED
    svc 0
    cmp r0,#0
    mov r5,r0 @r5 eh o endereco da base da UART0
    bge map_sucesso

@----------------------------------------------------------------------------------------------

@----------------------------------------------------------------------------------------------
map_sucesso:
    mov r0,#1
    ldr r1,=mapeado
    mov r2,#21
    mov r7,#4
    svc 0
    b desabilitar_uart

@----------------------------------------------------------------------------------------------
@ Desabilita a UART no registrador CR
@ Para que as configurações possam ser feitas

desabilitar_uart: @ Zera o CR
	mov r0,#0
	str r0,[r5,#UART_CR]
	str r0,[r5,#UART_DR]
	b desabilitar_fifo

@----------------------------------------------------------------------------------------------

@-----------------Desabilitar FIFO-------------------------------------------------------------
@ Zera o LCRH
@ Com a UART desabilitada o LCRH pode ser configurado e a FIFO então é desativada
desabilitar_fifo: @ Zera o LCRH
	putlp:
	ldr r2,[r5,#UART_FR] @ read the flag resister
	tst r2,#UART_TXFF @Verifica se a FIFO transmiter esta cheia
	bne putlp
	mov r0, #0
	str r0, [r5,#UART_LCRH]
	b configurar_baudrate

@----------------------------------------------------------------------------------------------

@----------------- Configurar o baudrate-------------------------------------------------------
@ Definindo os valore nos registradores  IBRD e FBRD configura o valor do Baud rate da transmissão

configurar_baudrate: @ Escolhemos 9600 baud
@@ (3Mhz / (9600 * 16)) = 19,53125
@@ 10011 no integerbaud (19)
@@ 110101 no fractionalbaud (53)
@@ numero seria 19,53
	mov r0, #19
	str r0,[r5,#UART_IBRD]
	mov r0, #53
	str r0,[r5,#UART_FBRD]
	b configurar_LCRH

@-----------------DEFINIR LCRH-----------------------------------------------------------------

configurar_LCRH:
	.equ UART_CONFIG, (UART_WLEN1 | UART_WLEN0 | UART_FEN | UART_STP2 | UART_PEN ) @ stick parity desabilitado, tamanho de mensagem 8, FIFO ativa, 2 stop bits, paridade Impar, paridade ativada
	mov r0,#UART_CONFIG
	str r0,[r5,#UART_LCRH]
	b configurar_CR
	
@-----------------DEFINIR CR-------------------------------------------------------------------
	
configurar_CR:
	ldr r0,=Final_Bits	@ carrega no registrador a configuração em Final_bits( da mémoria)
	str r0,[r5,#UART_CR]	@ carrega no data register a configuração em r0
	b escrever_DR
@----------------------------------------------------------------------------------------------

@----------------------------------------------------------------------------------------------
@ Escreve no data register DR a palavra a ser enviada
escrever_DR:
	@ A fifo de transmissao esta vazia
	ldr r0,=A
	ldr r0,[r0]
	str r0,[r5,#UART_DR] @ write the char to the FIFO @Verificar se esta sendo escrito no endereco correto	
	ldr r8,=B
	ldr r8,[r8]
	str r8,[r5,#UART_DR]
	b ler_DR

@----------------------------------------------------------------------------------------------
@ Habilita a FIFO no Registrador LCRH
habilitar_fifo: @Habilitamos a FIFO
	mov r0, #UART_FEN
	str r0, [r5,#UART_LCRH]
	b ler_DR

@---------------------------------------------------------------------
@ Lê a menssagem em rx
ler_DR:
	getlp:
	ldr r2,[r5,#UART_FR] @ read the flag resister
	tst r2,#UART_RXFE @
	@ Preso aqui
	bne getlp
	ldr r6,[r5,#UART_DR] @ read the char to the FIFo
	b printar_valor_reg
	b fechar_programa

loop:
	
@---------------------------------------------------------------------
@ Fecha o programa chamando a syscall do linux
fechar_programa:
    mov r0,#0
    mov r7, #1
    svc 0
@----------------------------------------------------------------------------------------------
@ Mensagem de erro quando ocorre erro no mapeamento
mensagem_erro:
    mov r0,#1 @ printar mensagem no terminal
    ldr r1,=erro @ a mensagem em si
    mov r2,#55 @ tamanho da mensagem
    mov r7,#4 @ syscall pro write
    svc 0 @ chamando a syscall
    b fechar_programa

@----------------------------------------------------------------------------------------------
printar_valor_reg: @Isso nao funcionou pra ler valor de um registrador
	mov r0,#1
	@r6 eh o UART_DR
	mov r6,#30
	@ldr r7,=aux
	@str r6,[r7,#0]
	mov r1,r6
	mov r2,#10
	mov r7,#4
	svc 0
	b fechar_programa

@ ===============================================
	.align 2
file:
	.word memdev
openMode:
	.word 0
flag:
	.word 0666
gpioTest:
	.word 0x20200

baseUART0:
	.word UART0_BASE
Final_Bits:
	.word HabilitarUART

A: .word 'A'
B: .word 'B'

aux:
	.ascii "TEST"

