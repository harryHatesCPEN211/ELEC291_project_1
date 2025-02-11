$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK                 EQU 16600000 ; Microcontroller system oscillator frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER2_RATE         EQU 100      ; 100Hz or 10ms
TIMER2_RELOAD       EQU (65536-(CLK/(16*TIMER2_RATE))) ; Need to change timer 2 input divide to 16 in T2MOD
TIMER0_RELOAD_1MS   EQU (0x10000-(CLK/1000))
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))

; Output
PWM_OUT    EQU P1.0 ; Logic 1=oven on

BSEG
mf: dbit 1
s_flag: dbit 1 ; set to 1 every time a second has passed

DSEG at 0x30
pwm_counter:  ds 1 ; Free running counter 0, 1, 2, ..., 100, 0
pwm:          ds 1 ; pwm percentage
seconds:      ds 1 ; a seconds counter attached to Timer 2 ISR
x:   ds 4
y:   ds 4
bcd: ds 5
temp_reading: ds 4
minutes: ds 1  ; Stores elapsed minutes
VAL_LM4040: ds 2



CSEG


; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

$NOLIST
$include(math32.inc)
$LIST

Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	mov seconds, #0
	mov minutes, #0
	
; Timer 1
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1

; Timer 0
	
	; Using timer 0 for delay functions.  Initialize here:
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	mov TH0, #high(TIMER0_RELOAD_1MS)
	mov TL0, #low(TIMER0_RELOAD_1MS)
	; Enable the timer and interrupts
	setb ET0  ; Enable timer 0 interrupt
	
	orl	P1M1, #0b10000010
	anl	P1M2, #0b01111101
	
; Timer 2, used for soak/reflow timing and pwm to oven

	; Initialize timer 2 for periodic interrupts
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov T2MOD, #0b1010_0000 ; Enable timer 2 autoreload, and clock divider is 16
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init the free running 10 ms counter to zero
	mov pwm_counter, #0
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	
	setb EA ; Enable global interrupts
	
	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select channel 0
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10000001 ; P1.1 is analog input
	orl ADCCON1, #0x01 ; Enable ADC
	
	
	ret
	
;---------------------------------;
; ISR for timer 0                 ;
;---------------------------------;
	
Timer0_ISR:
	reti

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	push P0
	push psw
	push acc
	push DPH
	push DPL
	
	push x+0
	push x+1
	push x+2
	push x+3
	
	push BCD+0
	push BCD+1
	push BCD+2
	push BCD+3
	push BCD+4
	
	push y+0
	push y+1
	push y+2
	push y+3
	
	lcall sample_temp
	inc pwm_counter
	clr c
	mov a, pwm
	subb a, pwm_counter ; If pwm_counter <= pwm then c=1
	cpl c
	mov PWM_OUT, c
	
	mov a, pwm_counter
	cjne a, #100, Timer2_ISR_done
	mov pwm_counter, #0
Updating_Time:
	mov a, seconds
	cjne a, #0x59, Inc_Sec
	clr a
	mov seconds, a
UpMin_Main:
	mov a, minutes
	cjne a, #0x59, Inc_Minutes
	clr a
	mov minutes, a
	sjmp Done_Updating_Time 
	
Inc_Sec:
	add a, #0x01
	da a
	mov seconds, a
	ljmp Done_Updating_Time
Inc_Minutes:
	add a, #0x01
	da a
	mov minutes, a
Done_Updating_Time:
	setb s_flag

Timer2_ISR_done:
	pop y+3
	pop y+2
	pop y+1
	pop y+0
	
	pop BCD+4
	pop BCD+3
	pop BCD+2
	pop BCD+1
	pop BCD+0
	
	pop x+3
	pop x+2
	pop x+1
	pop x+0

	pop DPL
	pop DPH
	pop acc
	pop psw
	pop P0
	reti
	
sample_temp:
	push acc
	push ADCCON0
	push AR1
	push AR0
	
	; Read the 2.08V LM4040 voltage connected to AIN0 on pin 6
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select channel 0

	lcall Read_ADC
	; Save result for later use
	mov VAL_LM4040+0, R0
	mov VAL_LM4040+1, R1

	; Read the signal connected to AIN7
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	lcall Read_ADC
    
    ; Convert to voltage
	mov x+0, R0
	mov x+1, R1
	; Pad other bits with zero
	mov x+2, #0
	mov x+3, #0
	Load_y(40959) ; The MEASURED voltage reference: 4.0959V, with 4 decimal places
	lcall mul32
	; Retrive the ADC LM4040 value
	mov y+0, VAL_LM4040+0
	mov y+1, VAL_LM4040+1
	; Pad other bits with zero
	mov y+2, #0
	mov y+3, #0
	lcall div32
	
	lcall hex2bcd

	mov temp_reading+0, bcd+0
	mov temp_reading+1, bcd+1
	mov temp_reading+2, bcd+2
	mov temp_reading+3, bcd+3
	
sample_end:
	pop AR0
	pop AR1
	pop ADCCON0
	pop acc
	ret
	
Read_ADC:
	push acc
	clr ADCF
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRL
    anl a, #0x0f
    mov R0, a
    mov a, ADCRH   
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, R0
    mov R0, A

	pop acc
	ret

display:
	
	
	Set_Cursor(1,5)
	display_BCD(temp_reading+3)
	display_BCD(temp_reading+2)
	display_BCD(temp_reading+1)
	display_BCD(temp_reading+0)
	Set_Cursor(2,1)
	display_BCD(minutes)
	Set_Cursor (2,4)
	display_BCD(seconds)
	ret

line1:
	DB 'PWM Example     '
	DB 0
line2:
	DB 'Chk pin 15:P1.0 '
	DB 0

main:
	mov sp, #07FH
	lcall INIT_ALL
    lcall LCD_4BIT

;	Set_Cursor(1, 1)
;	mov dptr, #line1
;	lcall ?Send_Constant_String
;	Set_Cursor(2, 1)
;	mov dptr, #Line2
;	lcall ?Send_Constant_String
	
	mov pwm, #20 ; The pwm in percentage (0 to 100) we want.  Change and check with oscilloscope.

Forever:
	lcall display
	ljmp Forever	
END
