; 76E003 ADC test program: Reads channel 7 on P1.1, pin 14 and transmits temperature over UART
$NOLIST
$MODN76E003
$LIST

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200   ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))

ORG 0x0000
    ljmp main

test_message:     db '*** ADC TEST ***', 0
value_message:    db 'Temp(C)=        ', 0

cseg
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3
;START equ....       ASSIGN START BUTTON HERE

$NOLIST
$include(LCD_4bit.inc)
$LIST

;-------------------------------------------------------
; Data Segment Definitions
;-------------------------------------------------------
DSEG at 30H
x:   ds 4              ; Used for ADC-to-voltage conversion
y:   ds 4              ; Used for calculations
bcd: ds 5              ; BCD representation of temperature
adc_accumulator: ds 4  ; Holds accumulated ADC readings for averaging
count: ds 1            ; Counter for averaging
prev_avg: ds 3         ; Stores previous temperature value for UART consistency

; ---FSM and Control Variables ---
FSM1_state: ds 1       ; Current state of the FSM
pwm:         ds 1       ; PWM duty cycle (power level)
sec:         ds 1       ; Seconds counter (timer)
temp:        ds 1       ; Temperature (e.g. integer part in °C)

temp_soak: ds 1
Time_soak: ds 1
Temp_refl: ds 1
Time_refl: ds 1

;-------------------------------------------------------
; Bit Segment Definitions
;-------------------------------------------------------
BSEG
mf:    dbit 1
; Define START as a bit variable. (If the Start button is connected
; to a port bit—for example, P1.0—you could alternatively define:
;    START EQU P1.0 )
START: dbit 1

$NOLIST
$include(math32.inc)
$LIST

;---------------------------------;
; Send a BCD number to PuTTY      ;
;---------------------------------;
Send_BCD mac
    push ar0
    mov r0, %0
    lcall ?Send_BCD
    pop ar0
endmac

?Send_BCD:
    push acc
    ; Write most significant digit
    mov a, r0
    swap a
    anl a, #0fh
    orl a, #30h
    lcall putchar
    ; Write least significant digit
    mov a, r0
    anl a, #0fh
    orl a, #30h
    lcall putchar
    pop acc
    ret

;---------------------------------;
; Initialization Routines         ;
;---------------------------------;
Init_All:
    ; Configure all the pins for bidirectional I/O
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00

    orl CKCON, #0x10      ; CLK input for timer 1
    orl PCON, #0x80       ; Double baud rate
    mov SCON, #0x52       ; Set UART mode
    anl T3CON, #0b11011111
    anl TMOD, #0x0F
    orl TMOD, #0x20
    mov TH1, #TIMER1_RELOAD
    setb TR1

    clr TR0
    orl CKCON, #0x08
    anl TMOD, #0xF0
    orl TMOD, #0x01

    orl P1M1, #0b00000010
    anl P1M2, #0b11111101

    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07   ; Select channel 7
    mov AINDIDS, #0x00
    orl AINDIDS, #0b10000000
    orl ADCCON1, #0x01

    ret

;---------------------------------;
; UART and Delay Routines         ;
;---------------------------------;
UART_Send:
    mov SBUF, A
    jnb TI, $
    clr TI
    ret

UART_Send_Ascii:
    anl A, #0x0F
    add A, #0x30
    lcall UART_Send
    ret

wait_1ms:
    clr TR0
    clr TF0
    mov TH0, #high(TIMER0_RELOAD_1MS)
    mov TL0, #low(TIMER0_RELOAD_1MS)
    setb TR0
    jnb TF0, $
    ret

waitms:
    lcall wait_1ms
    djnz R2, waitms
    ret

Display_formatted_BCD:
    Set_Cursor(2, 10)
    Display_BCD(bcd+2)
    Display_char(#'.')
    Display_BCD(bcd+1)
    Display_BCD(bcd+0)
    ret
    
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret
    
send_newline:
    mov a, #'\n'
    lcall putchar
    mov a, #'\r'
    lcall putchar
    ret
    
SendToSerialPort:
	mov b, #100
	div ab
	orl a, #0x30; convert hundreds to ASCII
	lcall putchar; Send to PuTTY/Python
	mov a, b; Remainder is in register b
	mov b, #10
	div ab
	orl a, #0x30; Covert tens to ASCII
	lcall putchar; Send to PuTTY/Python
	mov a, b
	orl a, #0x30; Conver units to ASCII
	lcall putchar; Send to PuTTY/python
	ret
	
	
; Eight bit number to display passed in 'a'
; Send result to LCD

sendToLCD:
	mov b, #100
	div ab
	orl a, #0x30; Conver hundreds to ASCII
	lcall ?WriteData; Send to LCD
	mov a, b; remainder is in reg b
	mov b, #10
	div ab
	orl a, #0x30; conver tens to ASCII
	lcall ?WriteData; send to LCD
	mov a, b
	orl a, #0x30; convert units to ASCII
	lcall ?WriteData; send LCD
	ret
		     
;---------------------------------;
; Main Program                    ;
;---------------------------------;
main:
    mov sp, #0x7f
    lcall Init_All
    lcall LCD_4BIT

    Set_Cursor(1, 1)
    Send_Constant_String(#test_message)
    Set_Cursor(2, 1)
    Send_Constant_String(#value_message)

Forever:
    ; Reset accumulator and count
    mov adc_accumulator+0, #0
    mov adc_accumulator+1, #0
    mov adc_accumulator+2, #0
    mov adc_accumulator+3, #0
    mov count, #250  ; Take 250 ADC samples for maximum smoothing

adc_loop:
    clr ADCF
    setb ADCS
    jnb ADCF, $

    mov a, ADCRH
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R0, A
 
    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0
    ; Convert ADC to Voltage
    Load_y(50300)
    lcall mul32
    Load_y(4095)
    lcall div32

    ; Convert Voltage to Celsius
    Load_y(27300)
    lcall sub32
    Load_y(100)
    lcall mul32

    lcall hex2bcd
    lcall Display_formatted_BCD
    
    mov a, bcd+2
    Send_BCD(a)
    
    mov a, #'.'
    lcall putchar
    
    mov a, bcd+1
    Send_BCD(a)
    
    mov a, bcd+1
    Send_BCD(a)
    
    mov a, #'\n'
    lcall putchar
    mov a, #'\r'
    lcall putchar

    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms

    cpl P1.7

    ; Store the calculated temperature into the 'temp' variable.
    ; (Here we assume that bcd+2 holds the integer part of the temperature.)
    mov temp, bcd+2

    ;---------------------------------------------;
    ; Finite State Machine (FSM) for Reflow Logic ;
    ;---------------------------------------------;
FSM1:
    mov a, FSM1_state  ; Load current state

;--------------------------------------------------
; State 0: Idle (Default State After Reset)
;--------------------------------------------------
FSM1_state0:
    cjne a, #0, FSM1_state1  ; If FSM1_state != 0, jump to State 1
    mov pwm, #0              ; Set Power = 0% (Heater OFF)
    
    jb  START, FSM1_state0_done  ; If Start button is pressed, proceed
    jnb START, $                ; Wait for Start button release
    
    mov FSM1_state, #1         ; Transition to State 1

FSM1_state0_done:
    ljmp FSM2                  ; Return to main loop

;--------------------------------------------------
; State 1: Preheat (Warmup Phase)
;--------------------------------------------------
FSM1_state1:
    cjne a, #1, FSM1_state2  ; If not state 1, jump to State 2
    mov pwm, #100            ; Set Power = 100% (Full Heating)
    mov sec, #0              ; Reset Timer

FSM1_state1_loop:
    mov a, temp              ; Read current temperature
    clr c
    subb a, #150             ; Check if Temp > 150°C
    jnc FSM1_state1_done     ; If condition met, exit loop

    mov FSM1_state, #2       ; Transition to State 2

FSM1_state1_done:
    ljmp FSM2                ; Return to main loop

;--------------------------------------------------
; State 2: Soak Phase
;--------------------------------------------------
FSM1_state2:
    cjne a, #2, FSM1_state3  ; If not state 2, jump to State 3
    mov pwm, #20             ; Set Power = 20% (Low Heating)
    
FSM1_state2_loop:
    mov a, sec               ; Read elapsed time
    clr c
    subb a, #60              ; Check if Sec > 60 seconds
    jnc FSM1_state2_done     ; If condition met, exit loop

    mov FSM1_state, #3       ; Transition to State 3

FSM1_state2_done:
    ljmp FSM2                ; Return to main loop

;--------------------------------------------------
; State 3: Reflow Phase
;--------------------------------------------------
FSM1_state3:
    cjne a, #3, FSM1_state4  ; If not state 3, jump to State 4
    mov pwm, #100            ; Set Power = 100% (Full Heating)
    mov sec, #0              ; Reset Timer

FSM1_state3_loop:
    mov a, temp              ; Read current temperature
    clr c
    subb a, #220             ; Check if Temp > 220°C
    jnc FSM1_state3_done     ; If condition met, exit loop

    mov FSM1_state, #4       ; Transition to State 4

FSM1_state3_done:
    ljmp FSM2                ; Return to main loop

;--------------------------------------------------
; State 4: Cooling Phase
;--------------------------------------------------
FSM1_state4:
    cjne a, #4, FSM1_state5  ; If not state 4, jump to State 5
    mov pwm, #20             ; Set Power = 20% (Slow Cooling)

FSM1_state4_loop:
    mov a, sec               ; Read elapsed time
    clr c
    subb a, #45              ; Check if Sec > 45 seconds
    jnc FSM1_state4_done     ; If condition met, exit loop

    mov FSM1_state, #5       ; Transition to State 5

FSM1_state4_done:
    ljmp FSM2                ; Return to main loop

;--------------------------------------------------
; State 5: Final Cooling
;--------------------------------------------------
FSM1_state5:
    cjne a, #5, FSM1_state0  ; If not state 5, jump to State 0
    mov pwm, #0              ; Set Power = 0% (Cooling OFF)

FSM1_state5_loop:
    mov a, temp              ; Read current temperature
    clr c
    subb a, #60              ; Check if Temp < 60°C
    jc FSM1_state5_done      ; If condition met, exit loop

    mov FSM1_state, #0       ; Transition to State 0 (Idle)

FSM1_state5_done:
    ljmp FSM2                ; Return to main loop

;--------------------------------------------------
; FSM2: Exit Point for FSM (returns to main loop)
;--------------------------------------------------
FSM2:
    ljmp Forever             ; Jump back to the main loop


