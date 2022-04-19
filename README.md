# <h1 align="center">Problema 1 - Interface de comunicação serial</h1>
 
## 1. Introdução
Computadores são amplamente utilizados nas mais diversas formas, seja para cálculos, atividades pessoais e comerciais, entre muitas outras, tipicamente os sistemas computacionais interagem com componentes periféricos que são conectados para se comunicar com o computador e também existe a comunicação entre os componentes internos que compõem um computador assim temos a essencial comunicação de dados presentes nos computadores.

A internet das coisas ou IOT (do inglês internet of things) vem ganhando espaço e aplicações comerciais, a IOT consiste em usar a conexão sem fio,sensoriamento e computadores embutidos/ microcontroladores para informatizar e conectar os diversos dispositivos do dia a dia como eletrodoméstico,eletrônicos e projetos mais ambiciosos como cidades inteligentes, com um visão focada no hardware temos que o núcleo dessa tecnologia está atrelado ao sensoriamento que utilizar os sensores conectados fisicamente ao computador por meio de uma interface física.

Geralmente a interface de comunicação usada pelos dispositivos periféricos para comunicação com o computador é por comunicação serial.

## 2. Desenvolvimento
Para o desenvolvimento do sistema proposto, foi utilizado o bloco de notas para a codificação e o computador Raspberry Pi 0. O processo de desenvolvimento, consistiu em codificação e posteriormente testes utilizando a Raspberry para verificar o funcionamento do código.

A Raspberry Pi 0 tem processador ARM, utiliza o ``Assembly ARMv6``, e o seu sistema operacional é o Raspbian, portanto, foi seguido a documentação do mesmo para programar o assembly e suas devidas syscalls. 

Dentro da Raspberry Pi 0 (Rasp0), têm se um hardware chamado Universal Asynchronous Receiver/Transmitter (``UART``) Ele fará a nossa comunicação de maneira serial, utilizando os pinos Receiver (Rx) e Transmitter (Tx), que são especificados na documentação da Rasp0.

O sistema desenvolvido realiza a configuração dos parâmetros de comunicação da ``UART``: a velocidade (baud rate), o tipo de paridade, a quantidade de bits de parada (stop bits) e a quantidade de bits de mensagem.

Inicialmente, foi necessário realizar o mapeamento da memória física da Raspberry para obter-se um endereço virtual. Isso foi feito utilizando a syscall #5 do Linux, a syscall Open.
```s
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
```

Como podemos ver na imagem do código acima, carregamos 4 parâmetros antes de chamarmos a syscall. Esses parâmetros carregam o caminho em que queremos abrir o arquivo, como queremos abrir (somente leitura, leitura e escrita ou só escrita). No ARM, o r7  é o qual colocamos o valor da nossa syscall, e chamamos utilizando o svc 0

A syscall retorna um valor >0 caso tenha conseguido abrir o arquivo e o valor -1 caso não tenha. Utilizamos o subs para verificar se o valor de retorno, que fica no r0, é maior ou não que 0. Caso seja, seguimos com a execução do nosso código.


```s
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

@----------------------------------------------------------------------------------------------
```
No código acima, utilizamos o resultado da syscall Open, feita anteriormente, salvando-a no r4, assim utilizaremos em conjunto com outros 5 parâmetros requisitados pela syscall mmap2.

Nesses parâmetros, informamos o endereço da memória da ``UART`` que queremos mapear, o tamanho do mapeamento (4096), se podemos ler e escrever, quem pode acessar essa memória mapeada, e o endereço que queremos alocar. Precisamos informar onde queremos mapear por conta que o Sistema Operacional (SO) não permite acesso diretamente ao endereço. Então fazemos um mapeamento virtual da memória, que o SO nos permite acessar.

Após o mapeamento da memória, iniciou-se a configuração da ``UART``. Seguindo os seguintes passos:

1. Desabilitar a ``UART``;
2. Esperar o fim de uma transmissão;
3. Esvaziar/desabilitar a FIFO de transmissão e recepção;
4. Configurar os parâmetros de comunicação;
5. Reprogramar o registrador de controle da UART;
6. Habilitar a ``UART``.

Para realizar os passos citados acima, se tornou necessário utilizar registradores. O registrador responsável por desabilitar e habilitar a ``UART`` é o registrador de controle (CR). Já o registrador responsável por desabilitar a FIFO e configurar os parâmetros de comunicação é o registrador de controle de linha (LCRH). 

Para desabilitar a ``UART``, setou o bit 0 (UARTEN) do CR para 0. 

```s
@ Desabilita a UART no registrador CR, para que as configurações possam ser feitas
desabilitar_uart: 
	mov r0,#0
	str r0,[r5,#UART_CR] @ Zera o CR
	str r0,[r5,#UART_DR] @ Zera o DR
```
Para analisar se está acontecendo uma transmissão de dados, verifica em um loop se o valor do bit 5 (TXFF) do registrador de flags (UART_FR) é igual a 1, se sim, indica que a FIFO está cheia e continua no loop até que o valor seja 0, indicando que a FIFO está vazia. Em seguida, para desabilitar a FIFO, define-se o bit 4(FEN) do LCRH como 0.

```s
desabilitar_fifo: 
	loop: 
	ldr r2,[r5,#UART_FR] @ Ler o registrador de flags
	tst r2,#UART_TXFF @Verifica se a FIFO de transmissão está cheia
	bne loop @ Continua no loop enquanto estiver cheia
	mov r0, #0
	str r0, [r5,#UART_LCRH] @Desabilita a FIFO
```
Os parâmetros de comunicação solicitados para esse sistema podem ser definidos através do LCRH como: 
- A paridade é definida através do bit 1(PEN) e bit 2 (EPS), o bit PEN habilita a paridade quando seu valor é 1 e desabilita quando é 0, já o bit EPS define o tipo de paridade, 0 indica paridade ímpar e 1 indica paridade par;
- A quantidade de stop bits é configurada pelo bit 3 (STP2), no qual, definido como 0 envia um bit de parada é definido como 1 envia dois bits de parada; 
- O tamanho da mensagem nesse sistema pode variar entre 7 ou 8 bits, e é definido nos bits 5-6 (WLEN), quando está em ``1 0`` indica que o tamanho da mensagem é de 7 bits e em ``1 1`` indica que o tamanho da mensagem é de 8 bits.
Para que seja possível o envio de dados, é necessário habilitar neste momento a FIFO, configurando o bit FEN como 1. 
```s
@stick parity desabilitado, tamanho de mensagem 8, FIFO ativa, 2 stop bits, paridade habilitada e ímpar
configurar_LCRH:
	.equ UART_CONFIG, (UART_WLEN1 | UART_WLEN0 | UART_FEN | UART_STP2 | UART_PEN ) @Define as configurações
	mov r0,#UART_CONFIG
	str r0,[r5,#UART_LCRH] @Salva as configurações no registrador LCRH
```
Outro parâmetro a ser configurado é o baud rate, o baud rate é a taxa de transmissão de bits da mensagem. No manual da UART é informado que o baud rate é definido junto a frequência de clock da ``UART`` e sendo assim, varia conforme o clock varia.  Para configurar o baud rate é preciso definir o valor do BAUDDIV parâmetro interno que é usado para o seu cálculo.  Usando a equação (BAUDDIV =  Freq / (BAUD_RATE*16) obtemos o valor a ser informado. Como o valor do BAUDDIV pode ser com ponto decimal, a ``UART`` disponibiliza dois registradores o IBRD (integral baud rate divisor) e o FBRD (fracitional baud rate divisor)  para representar o número, inserindo a parte inteira no IBRD e a fracional no FRBD.

```s
@@ (3Mhz / (9600 * 16)) = 19,53125
@ Valor de Baud rate: 19,53
@@ 10011 no integerBaud (19)
@@ 110101 no fractionalBaud (53)
configurar_baudrate:
	mov r0, #19
	str r0,[r5,#UART_IBRD]
	mov r0, #53
	str r0,[r5,#UART_FBRD]
```

Após a configuração dos parâmetros de comunicação, reprograma-se o registrador de controle para habilitar a ``UART`` e a transmissão e recepção de dados. Para isso, o bit UARTEN é definido como 1 para habilitar a UART, e os bits 8(TXE) e 9(RXE) são definidos como 1 para habilitar respectivamente a transmissão e recepção de dados.

```s
@Habilita a UART, a transmissão e recepção de dados
.equ HabilitarUART, (UART_UARTEN | UART_TXE | UART_RXE)
Final_Bits:
	.word HabilitarUART
	
configurar_CR:
	ldr r0,=Final_Bits	@ carrega no registrador r0 a configuração em Final_bits (da mémoria)
	str r0,[r5,#UART_CR]	@ Salva no registrador CR, as configurações
	b escrever_dados        @Inicia a transmissão de dados
```

Para transmitir os dados através da ``UART``, salva-se o dado que deseja enviar em um registrador e armazena no registrador DR. Ao receber os dados, o receptor também deverá ler da memória o valor do registrador DR para obter o dado. Com o registrador DR, os dados são transmitidos ou recebidos um byte de cada vez, escrever nele significa escrever na FIFO.

```s
@----------------------------------------------------------------------------------------------
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
```
Para a realização do teste de loopback, utilizou-se um fio conector entre o pino TX e RX da UART e um osciloscópio para analisar os dados que estavam sendo enviados e recebidos. Para testar apenas a transmissão de dados, conectou-se à ponta de prova do osciloscópio no pino TX, no entanto, os dados enviados não estavam sendo exibidos no osciloscópio. Devido a esse problema, não conseguiu realizar os testes de loopback.

A principais instruções utilizadas para o desenvolvimento do código foram:

- str:  Essa instrução armazena o valor de um registrador na memória. Foi utilizada para alterar os valores dos registradores da UART, como o registrador CR, LCRH e baud rate.
```s 
@Exemplo
str r3,[r4,#2] @ Salva o valor de r3 em r4, entretando, salva o valor com um Offset de 3
```
<hr>

- ldr: Essa instrução carrega um valor salvo na memória para um registrador destino. Foi usada para impressões de caracteres no terminal e verificação de valores de alguns registradores da UART.

```s
@Exemplo
ldr r2,[r5,#3] @ Carrega o valor de r5 em r2, entretanto
```
<hr>

- mov: A instrução mov é usada para carregar o valor de um registrador (fonte) para outro registrador (destino), além disso, pode ser usado para carregar um valor constante para um registrador destino. <br><br>Essa instrução foi utilizada para realizar chamadas de sistema (Syscall) e para a configuração do baud rate.

```s
@Exemplos
mov r1,r5 @ Coloca o valor do registrador r5 em r1

mov r1,#10 @ Coloca o valor 10 decimal no r1
```
<hr>

- tst: É uma instrução condicional que testa o valor de um registrador com um operando e atualiza os sinalizadores de condição. Foi usada para identificar se a FIFO estava cheia e ler os dados da FIFO.

```s
@Exemplo
tst r2,#0x3E8 @ Compara bit a bit utilizando a operação lógica AND
```

<hr>

- b: Essa instrução é utilizada para desvio incondicional. Foi utilizada no código para direcionar a outro procedimento.

```s
@Exemplo
b procedimento2
```
<hr>

- bge e bne: São usadas para desvio condicional em conjunto com sinalizadores de condição. A bge desvia o fluxo quando um valor é maior ou igual ao outro e a bne quando dois valores são diferentes entre si. No sistema, foram usadas em resultados de chamadas de sistema e para analisar valores de registradores da UART.

```s
@Exemplos
bge nomeProcedimento

bne nomeProcedimento
```

