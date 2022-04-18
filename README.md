# <h1 align="center">Problema 1 - Interface de comunicação serial</h1>
 
## 1. Introdução
Computadores são amplamente utilizados nas mais diversas formas, seja para cálculos, atividades pessoais e comerciais, entre muitas outras, tipicamente os sistemas computacionais interagem com componentes periféricos que são conectados para se comunicar com o computador e também existe a comunicação entre os componentes internos que compõem um computador assim temos a essencial comunicação de dados presentes nos computadores.

A internet das coisas ou IOT (do inglês internet of things) vem ganhando espaço e aplicações comerciais, a IOT consiste em usar a conexão sem fio,sensoriamento e computadores embutidos/ microcontroladores para informatizar e conectar os diversos dispositivos do dia a dia como eletrodoméstico,eletrônicos e projetos mais ambiciosos como cidades inteligentes, com um visão focada no hardware temos que o núcleo dessa tecnologia está atrelado ao sensoriamento que utilizar os sensores conectados fisicamente ao computador por meio de uma interface física.

Geralmente a interface de comunicação usada pelos dispositivos periféricos para comunicação com o computador é por comunicação serial.

## 2. Desenvolvimento
Para o desenvolvimento do sistema proposto, foi utilizado o bloco de notas para a codificação e o computador Raspberry Pi 0. O processo de desenvolvimento, consistiu em codificação e posteriormente testes utilizando a Raspberry para verificar o funcionamento do código.
A Raspberry Pi 0 tem processador ARM, utiliza o Assembly ARMv6, e o seu sistema operacional é o Raspbian, portanto, foi seguido a documentação do mesmo para programar o assembly e suas devidas syscalls. 
Dentro da Raspberry Pi 0 (Rasp0), têm se um hardware chamado Universal Asynchronous Receiver/Transmitter (UART) Ele fará a nossa comunicação de maneira serial, utilizando os pinos Receiver (Rx) e Transmitter (Tx), que são especificados na documentação da Rasp0.
O sistema desenvolvido realiza a configuração dos parâmetros de comunicação da UART: a velocidade (baud rate), o tipo de paridade, a quantidade de bits de parada (stop bits) e a quantidade de bits de mensagem.
Inicialmente, foi necessário realizar o mapeamento da memória física da Raspberry para obter-se um endereço virtual. Isso foi feito utilizando a syscall #5 do Linux, a syscall Open.
```s
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
    
aberto:     @ mostrar mensagem de sucesso
    mov r4,r0 @ Movendo o file descriptor pro r4
    mov r0,#1 @ printar mensagem no terminal
    ldr r1,=sucesso @ a mensagem em si
    mov r2,#33 @ tamanho da mensagem
    mov r7,#4 @ syscall pro write
    svc 0 @ chamando a syscall
    b mapear_gpio
```
