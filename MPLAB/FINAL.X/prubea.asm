; PIC16F887 Configuration Bit Settings
#include "p16f887.inc"

; CONFIG1
    __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_ON & _LVP_OFF
; CONFIG2
    __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

;----------------------------------------------------------------------
; Variables
CONT1   EQU 0x20
CONT2   EQU 0x21
CONT3   EQU 0x22
TEMP    EQU 0x23    ; Temperatura leída (entera)
DECENAS EQU 0x24    ; Decenas para display
UNIDADES EQU 0x25   ; Unidades para display
TEMPACTUAL  EQU 0x26
WTEMP   EQU 0x70    ; Variables para contexto de interrupción
STATUST EQU 0x71

REF_TEMP EQU 0x27  ; Temperatura de referencia (10°C)

    ORG 0x00
    GOTO INICIO
    org 0x04
    GOTO    ISR

;---------------------------------------------------------------------
INICIO:
    BANKSEL REF_TEMP
    MOVLW .30 ; Temperatura de referencia (20°C)
    MOVWF REF_TEMP
    BANKSEL ANSEL
    CLRF ANSEL
    BSF ANSEL, 5 ; AN5 (RE0) como analógico
    CLRF ANSELH
    
    BANKSEL TRISA
    CLRF TRISA
    CLRF TRISD
    CLRF TRISC
    BCF TRISE, 1 ; RE1 como entrada (AN5)
    BSF TRISE, 1 ; RE1 como entrada (AN5)

    BANKSEL PORTA
    CLRF PORTA
    CLRF PORTD
    CLRF PORTC
    ;Configuracion del ADC
    BANKSEL ADCON0
    MOVLW B'11011001' ; Canal AN5 (RE0), ADC habilitado pero no convirtiendo
    MOVWF ADCON0
    CLRF ADRESH
    BANKSEL ADCON1
    CLRF ADCON1 ; Justificado a la izquierda, Vref = VDD-VSS

;---------------------------------------------------------------------
MAIN_LOOP:
    ; Iniciar conversión ADC
    BANKSEL ADCON0
    BSF ADCON0, 1 ; GO/DONE = 1
ESPERA_ADC:
    BTFSC ADCON0, 1 ; Espera que termine la conversión
    GOTO ESPERA_ADC
    BANKSEL ADRESH
    MOVF ADRESH, W   ; Usar ADRESH como valor de temperatura
    BANKSEL TEMP
    MOVWF   TEMP    ;AUX DE TEMPERATURA
    MOVWF   TEMPACTUAL

    ; Comparar TEMP con REF_TEMP
    BANKSEL TEMP
    MOVF TEMP, W
    BANKSEL REF_TEMP
    SUBWF REF_TEMP, W   ; W = REF_TEMP - TEMP
    BTFSS STATUS, C ; Si REF_TEMP < TEMP (TEMP > REF_TEMP)
    GOTO MAYOR_REF
    ; TEMP <= REF_TEMP
    ; Mostrar "LO"
    ; L = 0b00111000, O = 0b00111111 (catodo comun)
    BANKSEL PORTD
    BCF PORTD, 0
    BCF PORTD, 1
    MOVLW b'00111000' ; L
    MOVWF PORTA
    BSF PORTD, 1
    CALL DELAY_5MS
    BCF PORTD, 1
    MOVLW b'00111111' ; O
    MOVWF PORTA
    BSF PORTD, 0
    CALL DELAY_5MS
    BCF PORTD, 0
    BSF PORTC, 3
    GOTO MAIN_LOOP
MAYOR_REF:
    ; TEMP > REF_TEMP
    ; Mostrar "HI"
    ; H = 0b01110110, I = 0b00000110 (catodo comun)
    BANKSEL PORTD
    BCF PORTD, 0
    BCF PORTD, 1
    MOVLW b'01110110' ; H
    MOVWF PORTA
    BSF PORTD, 1
    CALL DELAY_5MS
    BCF PORTD, 1
    MOVLW b'00000110' ; I
    MOVWF PORTA
    BSF PORTD, 0
    CALL DELAY_5MS
    BCF PORTD, 0
    BSF PORTC, 3
    GOTO MAIN_LOOP

;----------------------------------------------------------------------
DELAY_5MS:
    MOVLW .50
    MOVWF CONT3
DELAY_LOOP:
    NOP
    DECFSZ CONT3, F
    GOTO DELAY_LOOP
    RETURN
;-----------------------------------------------------------------------
ISR:
    RETFIE
; --------------------------------------------
    END
