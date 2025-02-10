$NOLIST
$MODN76E003
$LIST

;----------------------------------------------------------------
; Constant Definitions
;----------------------------------------------------------------
CLK               EQU 16600000      ; System frequency (Hz)
BAUD              EQU 115200        ; UART baud rate (bps)
TIMER1_RELOAD     EQU (0x100 - (CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000 - (CLK/1000))

; Output pin for PWM (oven heater)
PWM_OUT           EQU P1.0

BSEG
mf:				dbit 1
s_flag:         dbit 1   ; Set every second (by Timer2 ISR)
;START:			dbit 1


CSEG
ORG 0x0000
    LJMP main          ; Reset vector

;------------------------------------------------
; Interrupt Vector Table (must be at the beginning)
;------------------------------------------------


ORG 0x0003       ; External Interrupt 0 vector
    reti

ORG 0x000B       ; Timer/Counter 0 overflow vector
    reti

ORG 0x0013       ; External Interrupt 1 vector
    reti

ORG 0x001B       ; Timer/Counter 1 overflow vector
    reti

ORG 0x0023       ; Serial Port RX/TX vector
    reti

ORG 0x002B       ; Timer/Counter 2 overflow vector
    LJMP Timer2_ISR

; LCD I/O pin definitions (assumes LCD_4bit.inc uses these)
LCD_RS            EQU P1.3
LCD_E             EQU P1.4
LCD_D4            EQU P0.0
LCD_D5            EQU P0.1
LCD_D6            EQU P0.2
LCD_D7            EQU P0.3

; Define Start–button input (assume active–high on P3.0)
START             EQU P3.0

; Constant strings (stored in code memory)
test_message:     db '*** ADC TEST ***', 0
value_message:    db 'Temp(C)=        ', 0

state_idle:       db 'Idle      ', 0
state_preheat:    db 'Preheat   ', 0
state_soak:       db 'Soak      ', 0
state_reflow:     db 'Reflow    ', 0
state_cooling:    db 'Cooling   ', 0
state_final:      db 'FinalCool ', 0
temp_label:       db 'Temp:   ', 0

$NOLIST
$include(LCD_4bit.inc)
$LIST

;----------------------------------------------------------------
; Data Segment Definitions
;----------------------------------------------------------------
DSEG at 30H
; Temporary 32-bit registers for math routines:
x:              ds 4    ; used for ADC-to–voltage conversion
y:              ds 4    ; used for intermediate math
bcd:            ds 5    ; BCD representation for display
VAL_LM4040:		ds 2
; Other variables (for averaging, etc.)
adc_accumulator: ds 4
count:          ds 1
prev_avg:       ds 3

; PWM and timer variables (updated by Timer2 ISR)
pwm_counter:    ds 1    ; 0–100 counter used for PWM timing
seconds:        ds 1    ; Seconds counter (incremented every 100 PWM cycles)

; --- FSM and Control Variables ---
FSM1_state:     ds 1    ; Finite State Machine state: 0=Idle, 1=Preheat, etc.
pwm:            ds 1    ; PWM duty cycle (0–100)
sec:            ds 1    ; Seconds counter for the FSM (reset on transitions)
temp:           ds 1    ; Binary temperature reading (for control comparisons)

;----------------------------------------------------------------
; Bit Segment Definitions
;----------------------------------------------------------------

$NOLIST
$include(math32.inc)
$LIST



main:
    mov sp, #0x7F
    lcall Init_All
    lcall LCD_4BIT

    ; Initial display in Idle state
    Set_Cursor (1,1)
    Send_Constant_String  (#state_idle)
    Set_Cursor (2,1)
    Send_Constant_String  (#temp_label)

    
;wait_adc:
    ;jnb ADCF, wait_adc

    ; For a 10-bit ADC, assume ADCRH holds the 2 MSB (in its lower two bits)
    ;mov A, ADCRH
    ;anl A, #0x03       ; Mask out other bits
    ;mov R1, A
    ;mov A, ADCRL
    ;mov R2, A         ; ADCRL holds the lower 8 bits

Forever:
    ;----------------------------------------------------------------
    ; ADC Sample Acquisition and Conversion
    ;----------------------------------------------------------------
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x00
    lcall read_ADC
  	mov VAL_LM4040+0, R0
  	MOV VAL_LM4040+1, R1
  	
  	
  	anl ADCCON0, #0xF0
    orl ADCCON0, #0x07
    lcall read_ADC
    ; Build a 16-bit ADC value (only 10 bits are valid)
    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0

    ; Convert ADC to Voltage in millivolts:
    ;   Voltage (mV) = (ADC_value * 50300) / 4095
    Load_y(50300)
    lcall mul32
    mov y+0, VAL_LM4040+0
    mov y+1, VAL_LM4040+1
    ;Pad other bits with 0
    mov y+2, #0
    mov y+3, #0
    
    Load_y(4095)
    lcall div32

     ;Convert Voltage to Temperature (°C):
    ;   For example, Temp = (Voltage - 27300) * 100
    Load_y(27300)
    lcall sub32
    Load_y(100)
    lcall mul32

    ; Assume the low byte of the result now holds a temperature in °C.
    ; Store the binary temperature into variable 'temp' (for FSM comparisons)
    mov temp, A

    ; Convert binary temperature to BCD for display.
    mov A, temp
    lcall hex2bcd

    ;----------------------------------------------------------------
    ; Update LCD and Serial Port with the Temperature Reading
    ;----------------------------------------------------------------
    lcall Display_formatted_BCD

    ; Send temperature via UART (hundreds, decimal point, tens, units)
    mov A, bcd+2
    Send_BCD (A)
    mov A, #'.'
    lcall putchar
    mov A, bcd+1
    Send_BCD (A)
    mov A, bcd+0
    Send_BCD (A)
    lcall send_newline

    ; Wait about 500 ms (2×250 ms delay)
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms

    ; Toggle a status LED (assume on P1.7)
    cpl P1.7

    ;----------------------------------------------------------------
    ; Call the Finite State Machine Update routine
    ;----------------------------------------------------------------
    acall FSM_Update

    Ljmp Forever

;----------------------------------------------------------------
; Initialization Routine (runs once)
;----------------------------------------------------------------
Init_All:
    ; Configure all I/O ports as bidirectional
    mov P3M1, #0x00
    mov P3M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P0M1, #0x00
    mov P0M2, #0x00

    ; Setup Timer1 for UART (baud rate generation)
    orl CKCON, #0x10
    orl PCON,  #0x80
    mov SCON,  #0x52
    anl T3CON, #0b11011111
    anl TMOD,  #0x0F
    orl TMOD,  #0x20
    mov TH1,  #TIMER1_RELOAD
    setb TR1

    ; Setup Timer0 for 1ms delay routine
    clr TR0
    orl CKCON, #0x08
    anl TMOD,  #0xF0
    orl TMOD,  #0x01
    
    ;initialize the pins used by the ADC (p1.1, and P1.7) as inputs:
    orl P1M1, #0b10000010
    anl P1M2, #0b01111101


    ; Setup ADC: select channel 7, etc.
    anl ADCCON0, #0xF0
    orl ADCCON0, #0x07
    mov AINDIDS, #0x00
    orl AINDIDS, #0b10000000
    orl ADCCON1, #0x01
 
    ; Setup Timer2 for PWM and timing:
    mov T2CON, #0x00           ; (Configure mode if required)
    ; Load Timer2 for a 1ms reload (using TIMER0_RELOAD_1MS constant)
    mov TH2, #high(TIMER0_RELOAD_1MS)
    mov TL2, #low(TIMER0_RELOAD_1MS)
    setb TR2                   ; Start Timer2

    ; Initialize variables
    mov pwm_counter, #0
    mov seconds,     #0
    mov FSM1_state,  #0      ; Begin in Idle state.
    mov pwm,         #0
    mov sec,         #0
    ret

;----------------------------------------------------------------
; Timer2 Interrupt Service Routine (PWM & Timing)
;----------------------------------------------------------------
Timer2_ISR:
    clr TF2                  ; Clear Timer2 overflow flag
    push psw
    push acc

    inc pwm_counter
    clr C
    mov A, pwm
    subb A, pwm_counter      ; Compare pwm (duty) with counter
    cpl C                    ; Invert carry so that output is HIGH when pwm_counter <= pwm
    mov PWM_OUT, C

    mov A, pwm_counter
    cjne A, #100, Timer2_ISR_done
        mov pwm_counter, #0
        inc seconds
        inc sec
        setb s_flag
Timer2_ISR_done:
    pop acc
    pop psw
    reti

;----------------------------------------------------------------
; UART and Delay Routines
;----------------------------------------------------------------
UART_Send:
    mov SBUF, A
    jnb TI, $           ; Wait until transmission is complete
    clr TI
    ret

UART_Send_Ascii:
    ; Convert lower nibble of A into proper hex digit (0–9, A–F)
    anl A, #0x0F
    cjne A, #10, convert_decimal
        mov A, #'A'
        sjmp send_char
convert_decimal:
    add A, #0x30
send_char:
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
    ; Assume bcd holds three BCD digits:
    Set_Cursor (2,10)
    Display_BCD (bcd+2)    ; hundreds digit
    Display_char (#'.')
    Display_BCD (bcd+1)    ; tens digit
    Display_BCD (bcd+0)    ; units digit
    ret
    
read_ADC:
    ; Start a new ADC conversion
    clr   ADCF        ; Clear any pending ADC flag
    setb  ADCS        ; Start conversion
adc_wait:
    jnb   ADCF, adc_wait  ; Wait until ADC finishes

    ; ADCRH: bits 11..4 of the ADC
    ; ADCRL: bits  3..0 of the ADC
    mov   A, ADCRH    
    anl   A, #0x0F    ; keep only lower 4 bits of ADCRH
    mov   R1, A       ; R1 holds bits 11..8 in its low nibble

    mov   A, ADCRL
    mov   R0, A       ; R0 holds bits 7..0, but only bits 3..0 are meaningful

    ; Now R1:R0 has a 12-bit number:  [R1(4 bits) : R0(8 bits)]
    ; R1's upper nibble is zero, lower nibble is bits 11..8
    ; R0 is bits 7..0 (the bottom nibble is bits 3..0 of the ADC)
    ret

	

putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, A
    ret

send_newline:
    mov A, #'\r'
    lcall putchar
    mov A, #'\n'
    lcall putchar
    ret

SendToSerialPort:
    mov B, #100
    div AB
    orl A, #0x30
    lcall putchar
    mov A, B
    mov B, #10
    div AB
    orl A, #0x30
    lcall putchar
    mov A, B
    orl A, #0x30
    lcall putchar
    ret

;----------------------------------------------------------------
; FSM_Update: Finite State Machine for Reflow Logic
;----------------------------------------------------------------
; This subroutine uses the binary temperature in 'temp' (updated by ADC)
; and a seconds timer ('sec') to decide when to transition.
; The LCD is updated with the appropriate state message.
; (After state changes, the FSM variable is updated.)
FSM_Update:
    mov A, FSM1_state
    ; --- State 0: Idle ---
    cjne A, #0, FSM_NotIdle
        ; Idle: Heater off.
        mov pwm, #0
        Set_Cursor (1,1)
        Send_Constant_String  (#state_idle)
        Set_Cursor (2,1)
        Send_Constant_String  (#temp_label)
        lcall Display_formatted_BCD
        ; Check start button (active high)
        jb START, FSM_Idle_Pressed
        ret
    FSM_Idle_Pressed:
        acall DebounceButton
        mov FSM1_state, #1
        ret

    ; --- For states 1 to 5 ---
FSM_NotIdle:
    ; --- State 1: Preheat (wait until temp >= 150°C) ---
    cjne A, #1, FSM_CheckState2
        mov pwm, #100
        mov sec, #0         ; Reset state timer
        Set_Cursor (1,1)
        Send_Constant_String  (#state_preheat)
        Set_Cursor (2,1)
        Send_Constant_String  (#temp_label)
        lcall Display_formatted_BCD
        mov A, temp
        clr C
        subb A, #150
        jnc FSM_SetState2   ; If temp >= 150, go to next state
        ret
    FSM_SetState2:
        mov FSM1_state, #2
        ret

    ; --- State 2: Soak (wait until sec >= 60 seconds) ---
FSM_CheckState2:
    cjne A, #2, FSM_CheckState3
        mov pwm, #20
        Set_Cursor (1,1)
        Send_Constant_String  (#state_soak)
        Set_Cursor (2,1)
        Send_Constant_String  (#temp_label)
        lcall Display_formatted_BCD
        mov A, sec
        clr C
        subb A, #60
        jnc FSM_SetState3
        ret
    FSM_SetState3:
        mov FSM1_state, #3
        ret

    ; --- State 3: Reflow (wait until temp >= 220°C) ---
FSM_CheckState3:
    cjne A, #3, FSM_CheckState4
        mov pwm, #100
        mov sec, #0
        Set_Cursor (1,1)
        Send_Constant_String  (#state_reflow)
        Set_Cursor (2,1)
        Send_Constant_String  (#temp_label)
        lcall Display_formatted_BCD
        mov A, temp
        clr C
        subb A, #220
        jnc FSM_SetState4
        ret
    FSM_SetState4:
        mov FSM1_state, #4
        ret

    ; --- State 4: Cooling (wait until sec >= 45 seconds) ---
FSM_CheckState4:
    cjne A, #4, FSM_CheckState5
        mov pwm, #20
        Set_Cursor (1,1)
        Send_Constant_String  (#state_cooling)
        Set_Cursor (2,1)
        Send_Constant_String  (#temp_label)
        lcall Display_formatted_BCD
        mov A, sec
        clr C
        subb A, #45
        jnc FSM_SetState5
        ret
    FSM_SetState5:
        mov FSM1_state, #5
        ret

    ; --- State 5: Final Cooling (wait until temp < 60°C) ---
FSM_CheckState5:
    cjne A, #5, FSM_Update_End
        mov pwm, #0
        Set_Cursor (1,1)
        Send_Constant_String  (#state_final)
        Set_Cursor (2,1)
        Send_Constant_String  (#temp_label)
        lcall Display_formatted_BCD
        mov A, temp
        clr C
        subb A, #60
        jc FSM_SetIdle     ; if temp < 60, transition to Idle
        ret
    FSM_SetIdle:
        mov FSM1_state, #0
        ret

FSM_Update_End:
    ret

;----------------------------------------------------------------
; DebounceButton: Simple delay routine for button debounce
;----------------------------------------------------------------
DebounceButton:
    mov R2, #50
debounce_loop:
    lcall wait_1ms
    djnz R2, debounce_loop
    ret
