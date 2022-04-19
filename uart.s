@ Define as constantes usadas, do tipo string
	.align 2
	.data
	memdev: .asciz "/dev/mem"
	sucesso: .ascii "Abrimos /dev/gpiomen com sucesso\n"
	mapeado: .ascii "Mapeamos com sucesso\n"

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

@-------------Bits do LCRH------------------------------
@ Disposição do bits do registrador de controle de linha
.equ UART_SPS, (1<<7) @ enable stick parity
.equ UART_WLEN1, (1<<6) @ MSB do tamanho de mensagem
.equ UART_WLEN0, (1<<5) @ LSB do tamanho de mensagem
.equ UART_FEN, (1<<4) @ Habilita FIFOs
.equ UART_FEND, (0<<4) @ Desabilita FIFOs
.equ UART_STP2, (1<<3) @ Define a quantidade de stop bits como 2
.equ UART_EPS, (1<<2) @ Seleciona o tipo de paridade: PAR
.equ UART_PEN, (1<<1) @ Habilita paridade
.equ UART_BRK, (1<<0) @ Envia pausa de dados

@ Configura paramêtros (bits) do data register, que verificam erros
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

.equ HabilitarUART, (UART_UARTEN | UART_TXE | UART_RXE) @ binario equivalente a habilitação da UART, da transmissão e recepção de dados

@----------------------------------------------------------------

.global _start

.section .text

_start:
    ldr r0, file
    ldr r1, flag @ Leitura e Escrita do arquivo aberto / Flag O_RDWR
    ldr r2, openMode @modo de abertura
    mov r7, #5 @Sycall Open 
    svc 0
    subs r3,r0,#0 @verifica o valor de retorno da abertura do arquivo
    bge aberto @Se foi 0, abre
    b mensagem_erro @se não abriu

@-----------------Função da abertura de arquivo -----------------
aberto:
    mov r4,r0 @ Movendo a descriçaõ do arquivo pro r4
    mov r0,#1 @ printar mensagem de sucesso no terminal
    ldr r1,=sucesso @ a mensagem em si
    mov r2,#33 @ tamanho da mensagem
    mov r7,#4 @ syscall pra escrita
    svc 0 @ chamando a syscall
    b mapear_uart

@---------------Função mapear UART------------------------------
@ Com o arquivo dev/Mem aberto realiza o mapeamento da memoria virtual da raspberry

mapear_uart:
    mov r7,#192 		@ syscall do mmap2
    mov r0,#0 			@ kernel escolhe a memoria
    mov r1,#4096 		@ Tamanho de memória que será alocado
    ldr r2,=PROT_RDWR           @ leitura e escrita
    ldr r3,=MAP_SHARED          @ o endereço da memória física
    ldr r5,=baseUART0		@ Carrega no registrador r5  o enereço base da UART ( definido no cabeçalho)
    svc 0
    cmp r0,#0
    mov r5,r0 @armazena o endereco base da UART0
    bge map_sucesso @printa se mapeou

@---------------------------------------------------------------------
@printa a mensagem informando que mapeou
map_sucesso:
    mov r0,#1
    ldr r1,=mapeado
    mov r2,#21
    mov r7,#4
    svc 0
    b desabilitar_uart @procedimento que desabilita a uart

@-------------------------------------------------------------------
@ Desabilita a UART no registrador CR, para que as configurações possam ser feitas
desabilitar_uart: 
	mov r0,#0
	str r0,[r5,#UART_CR] @ Zera o CR
	str r0,[r5,#UART_DR] @ Zera o DR
	b desabilitar_fifo @ Procedimento para desabilitar a FIFO

@-----------------Desabilitar FIFO----------------------------------
desabilitar_fifo: 
	loop: 
	ldr r2,[r5,#UART_FR] @ Ler o registrador de flags
	tst r2,#UART_TXFF @Verifica se a FIFO de transmissão está cheia
	bne loop @ Continua no loop enquanto estiver cheia
	mov r0, #0
	str r0, [r5,#UART_LCRH] @Desabilita a FIFO
	b configurar_baudrate @Configura Baud Rate

@----------------- Configurar o baudrate----------------------------
@@ (3Mhz / (9600 * 16)) = 19,53125
@ Valor de Baud rate: 19,53
@@ 10011 no integerBaud (19)
@@ 110101 no fractionalBaud (53)
configurar_baudrate:
	mov r0, #19
	str r0,[r5,#UART_IBRD]
	mov r0, #53
	str r0,[r5,#UART_FBRD]
	b configurar_LCRH

@-----------------Configura os parâmetros de comunicação--------------------
@stick parity desabilitado, tamanho de mensagem 8, FIFO ativa, 2 stop bits, paridade habilitada e ímpar
configurar_LCRH:
	.equ UART_CONFIG, (UART_WLEN1 | UART_WLEN0 | UART_FEN | UART_STP2 | UART_PEN ) @Define as configurações
	mov r0,#UART_CONFIG
	str r0,[r5,#UART_LCRH] @Salva as configurações no registrador LCRH
	b configurar_CR @Configurar o registrador CR
	
@--------------------DEFINIR CR----------------------------------------------
@Habilita a UART, a transmissão e recepção de dados
configurar_CR:
	ldr r0,=Final_Bits	@ carrega no registrador r0 a configuração em Final_bits (da mémoria)
	str r0,[r5,#UART_CR]	@ Salva no registrador CR, as configurações
	b escrever_dados           @Inicia a transmissão de dados

@----------------------------------------------------------------------------
@ Escreve no data register DR a palavra a ser enviada
escrever_dados:
	ldr r0,=A @caractere a ser enviado
	ldr r0,[r0]
	str r0,[r5,#UART_DR] @ Escreve o primeiro caractere na FIFO
	ldr r8,=B @segundo caractere a ser enviado
	ldr r8,[r8]
	str r8,[r5,#UART_DR] @ Escreve o segundo caractere na FIFO
	b receber_dados @Procedimento para receber os dados enviados

@---------------------------------------------------------------------
@ Lê a mensagem enviada, no registrador DR
receber_dados:
	loop_vazio:
	ldr r2,[r5,#UART_FR] @ Ler o registrador de flags
	tst r2,#UART_RXFE @Verifica se a FIFO de recepção está vazia
	bne loop_vazio @Continua enquanto a fifo estiver vazia
	ldr r6,[r5,#UART_DR] @Ler o caractere recebido
	b printar_valor
	b fechar_programa
	
@---------------------------------------------------------------------
@ Fecha o programa chamando a syscall do linux
fechar_programa:
    mov r0,#0
    mov r7,#1
    svc 0
@------------------------------------------------------------------------
@ Mensagem de erro quando ocorre erro no mapeamento
mensagem_erro:
    mov r0,#1 @ printar mensagem no terminal
    ldr r1,=erro @ mensagem
    mov r2,#55 @ tamanho da mensagem
    mov r7,#4 @ syscall pra escrita
    svc 0 @ chamando a syscall
    b fechar_programa

@-------------------------Constantes-------------------------------
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

