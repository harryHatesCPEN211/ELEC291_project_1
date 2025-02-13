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
TIMER0_RATE       EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD     EQU ((65536-(CLK/TIMER0_RATE)))
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))

; PITCH PIANO
PITCH_C           EQU 2048
TIMER0_C          EQU ((65536-(CLK/PITCH_C)))
PITCH_CS          EQU 2220
TIMER0_CS         EQU ((65536-(CLK/PITCH_CS)))
PITCH_D           EQU 2360
TIMER0_D          EQU ((65536-(CLK/PITCH_D)))
PITCH_DS          EQU 2500
TIMER0_DS         EQU ((65536-(CLK/PITCH_DS)))
PITCH_E           EQU 2640
TIMER0_E          EQU ((65536-(CLK/PITCH_E)))
PITCH_F           EQU 2760
TIMER0_F          EQU ((65536-(CLK/PITCH_F)))
PITCH_FS          EQU 2980
TIMER0_FS         EQU ((65536-(CLK/PITCH_FS)))
PITCH_G           EQU 3140
TIMER0_G          EQU ((65536-(CLK/PITCH_G)))
PITCH_GS          EQU 3350
TIMER0_GS         EQU ((65536-(CLK/PITCH_GS)))
PITCH_A           EQU 3500
TIMER0_A          EQU ((65536-(CLK/PITCH_A)))
PITCH_AS          EQU 3700
TIMER0_AS         EQU ((65536-(CLK/PITCH_AS)))
PITCH_B           EQU 4010
TIMER0_B          EQU ((65536-(CLK/PITCH_B)))
PITCH_CC          EQU 4096
TIMER0_CC         EQU ((65536-(CLK/PITCH_CC)))
PITCH_CCS         EQU 4380
TIMER0_CCS        EQU ((65536-(CLK/PITCH_CCS)))
PITCH_DD          EQU 4760
TIMER0_DD         EQU ((65536-(CLK/PITCH_DD)))
PITCH_DDS         EQU 5000
TIMER0_DDS        EQU ((65536-(CLK/PITCH_DDS)))
; END PITCH PIANO

; Output
PWM_OUT    EQU P1.0 ; Logic 1=oven on
SOUND_OUT     equ P1.6 ; Logic 1 = speaker on

BSEG
mf: dbit 1
s_flag: dbit 1 ; set to 1 every time a second has passed
START: dbit 1
state1_flag: dbit 1
state2_flag: dbit 1
state3_flag: dbit 1
state4_flag: dbit 1
state5_flag: dbit 1
speaker_on_flag: dbit 1


;push buttons:
; These five bit variables store the value of the pushbuttons after calling 'LCD_PB' below
PB0: dbit 1
PB1: dbit 1
PB2: dbit 1
PB3: dbit 1
PB4: dbit 1

DSEG at 0x30
pwm_counter:  ds 1 ; Free running counter 0, 1, 2, ..., 100, 0
pwm:          ds 1 ; pwm percentage
seconds:      ds 2 ; a seconds counter attached to Timer 2 ISR
x:   ds 4
y:   ds 4
bcd: ds 5
temp_reading: ds 4
minutes: ds 2  ; Stores elapsed minutes
VAL_LM4040: ds 2
temp_tick:      ds 1
FSM1_state: ds 1
Display_mode: ds 1 
seconds_2: ds 2
minutes_2: ds 2
soak_sec: ds 2
soak_temp: ds 2
reflow_sec: ds 2
reflow_temp: ds 2

alarm_tick: ds 2
pitch: ds 2

Ambient_Reading: ds 4
Oven_Reading: ds 4
Oven_Display: ds 4
Ambient_Display: ds 4

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

;                     1234567890123456    <- This helps determine the location of the counter

time_message:   db 'TM', 0
state0:       	db 'State0', 0
state1:    		db 'State1', 0
state2:         db 'State2     ', 0
state3:         db 'State3', 0
state4:         db 'State4', 0
state5:         db 'State5', 0
state_error:    db '**ERROR**', 0
mode_label:     db 'M:',0
oven_temp:      db 'To:',0
ambi_temp:      db 'Ta:', 0


Average_ADC:
    Load_x(0)
    mov R5, #100
	Sum_loop0:
    lcall Read_ADC
    mov y+3, #0
    mov y+2, #0
    mov y+1, R1
    mov y+0, R0
    lcall add32
    djnz R5, Sum_loop0
    load_y(100)                  
    lcall div32
    ret

;-------------------------------------PUSHBUTTONS-----------------------------------------------:
LCD_PB:
	; Set variables to 1: 'no push button pressed'
	setb PB0
	setb PB1
	setb PB2
	setb PB3
	setb PB4
	; The input pin used to check set to '1'
	setb P1.5
	
	; Check if any push button is pressed
	clr P0.0
	clr P0.1
	clr P0.2
	clr P0.3
	clr P1.3
	jb P1.5, LCD_PB_Done

	; Debounce
	mov R2, #50
	lcall waitms
	jb P1.5, LCD_PB_Done

	; Set the LCD data pins to logic 1
	setb P0.0
	setb P0.1
	setb P0.2
	setb P0.3
	setb P1.3
	
	; Check the push buttons one by one
	clr P1.3
	mov c, P1.5
	mov PB4, c
	setb P1.3

	clr P0.0
	mov c, P1.5
	mov PB3, c
	setb P0.0
	
	clr P0.1
	mov c, P1.5
	mov PB2, c
	setb P0.1
	
	clr P0.2
	mov c, P1.5
	mov PB1, c
	setb P0.2
	
	clr P0.3
	mov c, P1.5
	mov PB0, c
	setb P0.3

LCD_PB_Done:		
	ret
    
;--------------------------------------------------------------------------------------;
Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	mov seconds+0, #0
	mov seconds+1, #0
	mov seconds_2+0, #0
	mov seconds_2+1, #0
	mov temp_tick, #0
	mov temp_reading+3, #0
	mov temp_reading+2, #0
	mov temp_reading+1, #0
	mov temp_reading+0, #0
	mov FSM1_state, #0
	mov Display_mode, #0
	clr state1_flag
	clr state2_flag
	clr state3_flag
	clr state4_flag
	clr state5_flag
	clr START
	mov soak_temp+1, #0x01
	mov soak_temp+0, #0x40
	mov soak_sec+1, #0x00
	mov soak_sec+0, #0x60
	mov reflow_temp+1, #0x02
	mov reflow_temp+0, #0x20
	mov reflow_sec+1, #0x00
	mov reflow_sec+0, #0x30
	
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
	setb TR0
	
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
	
	call_speaker:
		setb speaker_on_flag ; needs time delay still
		mov pitch+1, #high(TIMER0_RELOAD)
		mov pitch+0, #low(TIMER0_RELOAD)
		
		mov alarm_tick+1, #high(5000)
		mov alarm_tick+0, #low(5000)

	ret

Timer0_ISR:
		;clr TF0  ; According to the data sheet this is done for us already.
		; Timer 0 doesn't have 16-bit auto-reload, so
		jnb speaker_on_flag, Timer0_ISR_Done
		clr TR0
		;mov TH0, #high(TIMER0_RELOAD)
		;mov TL0, #low(TIMER0_RELOAD)
		mov TH0, pitch+1
		mov TL0, pitch+0
		setb TR0
		cpl SOUND_OUT
		
		djnz alarm_tick+0, Timer0_ISR_Done
		djnz alarm_tick+1, Timer0_ISR_Done
		;mov alarm_tick+0, #0xFF  ; Useless?
		clr speaker_on_flag
Timer0_ISR_Done:
	reti

speaker_tick:
	;jnb beep_length_flag, beep_length
	
	;mov pitch+1, #high(TIMER0_RELOAD)
	;mov pitch+0, #low(TIMER0_RELOAD)
	mov pitch+1, R1
	mov pitch+0, R0
	lcall speaker_1tick

	;djnz R2, speaker_tick
	;djnz alarm_tick+0, speaker_tick
	;mov alarm_tick+0, #0xFF
	;djnz alarm_tick+1, speaker_tick
	
	djnz R2, speaker_tick
	djnz R3, speaker_tick
	
	;clr beep_length_flag
	ret
	
speaker_1tick:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, pitch+1
	mov	TL0, pitch+0
	setb TR0
	cpl SOUND_OUT
	jnb	TF0, $ ; Wait for overflow
	ret


;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	;push P0
	push psw
	push acc


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
	mov a, seconds+0
	cjne a, #0x99, Inc_Seconds
	mov seconds+0, #0x00
	mov a, seconds+1
	add a, #0x01
	da a
	mov seconds+1, a
	sjmp Done_Updating_Time

Inc_Seconds: 
	add a, #0x01
	da a
	mov seconds+0, a
Done_Updating_Time:
	
Updating_Time_2:
	mov a, seconds_2+0
	cjne a, #0x99, Inc_Seconds_2
	mov seconds_2+0, #0x00
	mov a, seconds_2+1
	add a, #0x01
	da a
	mov seconds_2+1, a
	sjmp Done_Updating_Time_2

Inc_Seconds_2: 
	add a, #0x01
	da a
	mov seconds_2+0, a
Done_Updating_Time_2:

	setb s_flag

Timer2_ISR_done:


	pop acc
	pop psw
	reti
	
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret
	
wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret
	
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

	load_y(27300)
	lcall sub32
	
	load_y(100)
	lcall mul32
	
	; Convert to BCD and display
	
	mov Ambient_Reading+0, x+0
	mov Ambient_Reading+1, x+1
	mov Ambient_Reading+2, x+2
	mov Ambient_Reading+3, x+3

	lcall hex2bcd
	mov Ambient_Display+0, bcd+0
	mov Ambient_Display+1, bcd+1
	mov Ambient_Display+2, bcd+2
	mov Ambient_Display+3, bcd+3


	
;;; End of Ambient Reading


;;; Oven Reading
    ; Read the signal connected to AIN4 on pin 1
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x04 ; Select channel 4  (changed to 4)!!1
    
    lcall Read_ADC 
    lcall Average_ADC                

    ; Convert to voltage
    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0
	load_y(410) ;;;;;;;;
	lcall mul32
	load_y(100)
	lcall mul32
		; Retrive the ADC LM4040 value
	mov y+0, VAL_LM4040+0
	mov y+1, VAL_LM4040+1
	; Pad other bits with zero
	mov y+2, #0
	mov y+3, #0
	lcall div32
	
	
	
	mov Oven_Reading+0, x+0
	mov Oven_Reading+1, x+1
	mov Oven_Reading+2, x+2
	mov Oven_Reading+3, x+3
	
	mov x+0, Ambient_Reading+0
    mov x+1, Ambient_Reading+1
    mov x+2, Ambient_Reading+2
    mov x+3, Ambient_Reading+3
    
    load_y(100)
    lcall div32
    
    mov y+0, Oven_Reading+0
    mov y+1, Oven_Reading+1
    mov y+2, Oven_Reading+2
    mov y+3, Oven_Reading+3
	lcall add32
	
	lcall hex2bcd

	mov Oven_Display+0, bcd+0
	mov Oven_Display+1, bcd+1
	mov Oven_Display+2, bcd+2
	mov Oven_Display+3, bcd+3
	
	

sample_end:
	pop AR0
	pop AR1
	pop ADCCON0
	pop acc
	ret
	
Read_ADC:
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
	ret
	
	


	

    ;---------------;
    ; Display Stuff ;
    ;---------------;


displays:
	mov a, FSM1_state
	cjne a, #0, not_display_0
	ljmp display_0
not_display_0:
	ljmp display_1
display_0:
	Set_Cursor(1, 4)
	Display_One_BCD(Oven_Display+2)
 	Display_BCD(Oven_Display+1)
	display_char(#'C')
	Set_Cursor(1, 1)
	Send_Constant_String(#oven_temp)
	Set_Cursor(1, 14)
	display_BCD(Ambient_Display+2)
	Set_Cursor(1, 16)
	display_char(#'C')
	Set_Cursor(1, 11)
	Send_Constant_String(#ambi_temp)
	Set_Cursor(2, 2)
	Display_One_BCD(soak_temp+1)
	display_BCD(soak_temp+0)
	Set_Cursor(2, 6)
	Display_One_BCD(soak_sec+1)
	display_BCD(soak_sec+0)
	Set_Cursor(2, 10)
	Display_One_BCD(reflow_temp+1)
	display_BCD(reflow_temp+0)
	Set_Cursor(2, 14)
	Display_One_BCD(reflow_sec+1)
	display_BCD(reflow_sec+0)
	
	Set_Cursor(2, 1)
	display_char(#'S')
	Set_Cursor(2, 5)
	display_char(#',')
	Set_Cursor(2, 9)
	display_char(#'R')
	Set_Cursor(2, 13)
	display_char(#',')

display_0_done:
	ret

display_1:
	Set_Cursor(1, 1)
	lcall state_display
	Set_Cursor(1, 14)
	Display_One_BCD(Oven_Display+2)
  	Display_BCD(Oven_Display+1)
	Set_Cursor(1, 11)
	Send_Constant_String(#oven_temp)
	Set_Cursor(2, 1)
	Send_Constant_String(#time_message)
	display_BCD(seconds_2+1)
	display_BCD(seconds_2+0)
	display_char(#',')
	display_BCD(seconds+1)
	display_BCD(seconds+0)
	Set_Cursor(2, 12)
	Send_Constant_String(#ambi_temp)
	display_BCD(Ambient_Display+2)
	
	
display_1_done:
	ret
	
state_display:	
	mov a, FSM1_State
	cjne a, #0, display_1_not_state0
	Send_Constant_String(#state0)
	ljmp state_display_done
display_1_not_state0:
	mov a, FSM1_State
	cjne a, #1, display_1_not_state1
	Send_Constant_String(#state1)
	ljmp state_display_done
display_1_not_state1:
	mov a, FSM1_State
	cjne a, #2, display_1_not_state2
	Send_Constant_String(#state2)
	ljmp state_display_done
display_1_not_state2:
	mov a, FSM1_State
	cjne a, #3, display_1_not_state3
	Send_Constant_String(#state3)
	ljmp state_display_done
display_1_not_state3:
	mov a, FSM1_State
	cjne a, #4, display_1_not_state4
	Send_Constant_String(#state4)
	ljmp state_display_done
display_1_not_state4:
	mov a, FSM1_State
	cjne a, #5, display_1_not_state5
	Send_Constant_String(#state5)
	ljmp state_display_done
display_1_not_state5:
	Send_Constant_String(#state_error)
	ljmp state_display_done	
state_display_done:
	ret


;line1:
;	DB 'PWM Example     '
;	DB 0
;line2:
;	DB 'Chk pin 15:P1.0 '
;	DB 0
	

	
    ;---------------------------------------------;
    ; Finite State Machine (FSM) for Reflow Logic ;
    ;---------------------------------------------;
    
    
FSM_Update:

FSM_CheckState0:
    mov A, FSM1_state
    ; --- State 0: Idle ---
    cjne A, #0, FSM_CheckState1
        ; Idle: Heater off.
        mov seconds, #0
    	mov seconds+1, #0
    	mov seconds_2, #0
    	mov seconds_2+1, #0
        mov pwm, #100 ;No Heat
        ; Check start button (active high)
        lcall LCD_PB
        jnb PB0, FSM_Idle_Pressed ;;;;;;;;;;;;;;;;;;;;;;
        ret
    FSM_Idle_Pressed:
    ;;; Need debouncing
    	;setb START                ;;;;;;;;ADDED THIS TO STOP TIMER FROM STARTING BEFORE PB0 IS PRESSED
    	mov FSM1_State, #1
    	;lcall state_display
       
        ret

    ; --- For states 1 to 5 ---
FSM_CheckState1:
    ; --- State 1: Heat to Soak (wait until temp >= 150C) ---
    cjne A, #1, FSM_CheckState2
        ;If it's the first time entering this state this cycle, reset timer:
    jb state1_flag, FSM_State1
    mov seconds, #0
    mov seconds+1, #0
    setb state1_flag
FSM_State1:
    mov pwm, #0 ;Full Blast
    
FSM_State1_Abort_Check1:
    mov A, seconds+0
    clr C
    subb A, #0x60
    jnc FSM_State1_Abort_Check2
    sjmp FSM_State1_Check_1

FSM_State1_Abort_Check2:
	mov A, seconds+1
    clr C
    subb A, #0x00
    jnc FSM_SetIdle_1 ;Abort
    sjmp FSM_State1_Check_1  

FSM_SetIdle_1:
    mov FSM1_State, #0
    mov seconds, #0
    mov seconds+1, #0
    mov seconds_2, #0
    mov seconds_2+1, #0
    setb state1_flag
    setb state2_flag
    setb state3_flag
    setb state4_flag
    setb state5_flag
    ret
    
FSM_State1_Check_1:
    mov A, Oven_Reading+1
    clr C
    subb A, soak_temp+0 
    jnc FSM_State1_Check_2  
    ret
FSM_State1_Check_2:
	mov A, Oven_Reading+2
    clr C
    subb A, soak_temp+1 
    jnc FSM_SetState2   
    ret
        
FSM_SetState2:
    mov FSM1_State, #2
    ret

    ; --- State 2: Soak (wait until sec >= 60 seconds) ---
FSM_CheckState2:
    cjne A, #2, FSM_CheckState3
    jb state2_flag, FSM_State2
    mov seconds, #0
    mov seconds+1, #0
    setb state2_flag
FSM_State2:
    mov pwm, #80 ;Power at 20% at pwm = 80
    mov A, seconds+0
    clr C
    subb A, soak_sec+0
    jnc FSM_State2_Check2
    ret
FSM_State2_Check2:
    mov A, seconds+1
    clr C
    subb A, soak_sec+1
    jnc FSM_SetState3
    ret
FSM_SetState3:
    mov FSM1_State, #3
    ret

    ; --- State 3: Heat to Reflow (wait until temp >= 220C) ---
FSM_CheckState3:
    cjne A, #3, FSM_CheckState4
    ;If it's the first time entering this state this cycle, reset timer:
    jb state3_flag, FSM_State3
    mov seconds, #0
    mov seconds+1, #0
    setb state3_flag
FSM_State3:
    mov pwm, #0 ;Full Blast
    mov A, Oven_Reading+1
    clr C
    subb A, reflow_temp+0 
    jnc FSM_State3_Check_2  
    ret
FSM_State3_Check_2:
	mov A, Oven_Reading+2
    clr C
    subb A, reflow_temp+1 
    jnc FSM_SetState4   
    ret
FSM_SetState4:
    mov FSM1_State, #4
    ret

    ; --- State 4: Reflow (wait until sec >= 45 seconds) ---
FSM_CheckState4:
    cjne A, #4, FSM_CheckState5
;If it's the first time entering this state this cycle, reset timer:
    jb state1_flag, FSM_State4
    mov seconds, #0
    mov seconds+1, #0
    setb state4_flag
FSM_State4:
    mov pwm, #80 ;PMW at 20% on
    mov A, seconds+0
    clr C
    subb A, reflow_sec+0
    jnc FSM_State4_Check2
    ret
FSM_State4_Check2:
    mov A, seconds+1
    clr C
    subb A, reflow_sec+1
    jnc FSM_SetState5
    ret
FSM_SetState5:
    mov FSM1_State, #5
    ret

    ; --- State 5: Cooling (wait until temp < 60C) ---
FSM_CheckState5:
    cjne A, #5, FSM_Update_End
;If it's the first time entering this state this cycle, reset timer:
    jb state5_flag, FSM_State5
    mov seconds, #0
    mov seconds+1, #0
    setb state5_flag
FSM_State5:
    mov pwm, #100 ;No heat
    mov A, temp_reading
    clr C
    subb A, #60 ;;; Need to adjust for temp_reading value & magnitude
    jc FSM_SetIdle     ; if temp < 60, transition to Idle
    ret
FSM_SetIdle:
    mov FSM1_State, #0
    mov seconds, #0
    mov seconds+1, #0
    mov seconds_2, #0
    mov seconds_2+1, #0
    setb state1_flag
    setb state2_flag
    setb state3_flag
    setb state4_flag
    setb state5_flag
    ret

FSM_Update_End:
    ret
    
Play_song:
	mov R3, #high(1000)
		mov R2, #low(1000)
		mov R1, #high(TIMER0_C)
		mov R0, #low(TIMER0_C)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(1533)
		mov R2, #low(1533)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(6000) ;2000
		mov R2, #low(6000)
		mov R1, #high(TIMER0_CC)
		mov R0, #low(TIMER0_CC)
		lcall speaker_tick
	mov R3, #high(6973) ;4760
		mov R2, #low(6973)
		mov R1, #high(TIMER0_DD)
		mov R0, #low(TIMER0_DD)
		lcall speaker_tick
	mov R3, #high(1958)
		mov R2, #low(1958)
		mov R1, #high(TIMER0_B)
		mov R0, #low(TIMER0_B)
		lcall speaker_tick
	mov R3, #high(1709)
		mov R2, #low(1709)
		mov R1, #high(TIMER0_A)
		mov R0, #low(TIMER0_A)
		lcall speaker_tick
	mov R3, #high(1533)
		mov R2, #low(1533)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(5127)
		mov R2, #low(5127)
		mov R1, #high(TIMER0_A)
		mov R0, #low(TIMER0_A)
		lcall speaker_tick
	mov R3, #high(4599)
		mov R2, #low(4599)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(1000)
		mov R2, #low(1000)
		mov R1, #high(TIMER0_C)
		mov R0, #low(TIMER0_C)
		lcall speaker_tick
	mov R3, #high(1152)
		mov R2, #low(1152)
		mov R1, #high(TIMER0_D)
		mov R0, #low(TIMER0_D)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(4599)
		mov R2, #low(4599)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(5127)
		mov R2, #low(5127)
		mov R1, #high(TIMER0_A)
		mov R0, #low(TIMER0_A)
		lcall speaker_tick
	mov R3, #high(1533)
		mov R2, #low(1533)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(1000)
		mov R2, #low(1000)
		mov R1, #high(TIMER0_C)
		mov R0, #low(TIMER0_C)
		lcall speaker_tick
	mov R3, #high(6600) ;6912
		mov R2, #low(6600)
		mov R1, #high(TIMER0_D)
		mov R0, #low(TIMER0_D)
		lcall speaker_tick
	mov R3, #high(1533)
		mov R2, #low(1533)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(1533)
		mov R2, #low(1533)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(6000) ;2000
		mov R2, #low(6000)
		mov R1, #high(TIMER0_CC)
		mov R0, #low(TIMER0_CC)
		lcall speaker_tick
	mov R3, #high(5127)
		mov R2, #low(5127)
		mov R1, #high(TIMER0_A)
		mov R0, #low(TIMER0_A)
		lcall speaker_tick
	mov R3, #high(1533)
		mov R2, #low(1533)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(1000)
		mov R2, #low(1000)
		mov R1, #high(TIMER0_C)
		mov R0, #low(TIMER0_C)
		lcall speaker_tick
	mov R3, #high(3000)
		mov R2, #low(3000)
		mov R1, #high(TIMER0_C)
		mov R0, #low(TIMER0_C)
		lcall speaker_tick
	mov R3, #high(3456)
		mov R2, #low(3456)
		mov R1, #high(TIMER0_D)
		mov R0, #low(TIMER0_D)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(1152)
		mov R2, #low(1152)
		mov R1, #high(TIMER0_D)
		mov R0, #low(TIMER0_D)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(4599)
		mov R2, #low(4599)
		mov R1, #high(TIMER0_G)
		mov R0, #low(TIMER0_G)
		lcall speaker_tick
	mov R3, #high(5127)
		mov R2, #low(5127)
		mov R1, #high(TIMER0_A)
		mov R0, #low(TIMER0_A)
		lcall speaker_tick
	mov R3, #high(1152)
		mov R2, #low(1152)
		mov R1, #high(TIMER0_D)
		mov R0, #low(TIMER0_D)
		lcall speaker_tick
	mov R3, #high(1289)
		mov R2, #low(1289)
		mov R1, #high(TIMER0_E)
		mov R0, #low(TIMER0_E)
		lcall speaker_tick
	mov R3, #high(1152)
		mov R2, #low(1152)
		mov R1, #high(TIMER0_D)
		mov R0, #low(TIMER0_D)
		lcall speaker_tick
	mov R3, #high(6000)
		mov R2, #low(6000)
		mov R1, #high(TIMER0_C)
		mov R0, #low(TIMER0_C)
		lcall speaker_tick
ret
    
    
   send_python:
   	send_BCD(Oven_Display+2)
  	send_BCD(Oven_Display+1)
  	mov a, #'\n'
  	lcall putchar
  	mov a, #'\r'
  	lcall putchar
  	
   
   ret
    ;------------;
    ;    Main    ;
    ;------------;

main:
	mov sp, #07FH
	lcall INIT_ALL
    lcall LCD_4BIT	
	mov pwm, #50 ; The pwm in percentage (0 to 100) we want.  Change and check with oscilloscope.
	
	;lcall Play_song
	;lcall call_speaker

Forever:
	sample_temp_start:
	mov a, temp_tick
	cjne a, #49, inc_temp_tick
	mov temp_tick, #0
	lcall sample_temp
	lcall send_python
	sjmp done_temp_sample
inc_temp_tick:
	inc temp_tick
done_temp_sample:
	lcall FSM_Update
	lcall displays
	ljmp Forever	
END
