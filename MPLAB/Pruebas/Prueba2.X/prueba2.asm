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
TEMPACTUAL  EQU	0X26
WTEMP   EQU 0x70    ; Variables para contexto de interrupción
STATUST EQU 0x71

    ORG 0x00
    GOTO INICIO
    org	0x04
    GOTO    ISR

;---------------------------------------------------------------------
INICIO:
    ; Configura todos los pines analÃ³gicos como digitales
    BANKSEL ANSEL
    CLRF ANSEL
    BSF ANSEL, 5 ; AN5 (RE0) como analÃ³gico
    CLRF ANSELH
    
    BANKSEL	TXSTA	    ; -- Configuracion de la Tx
    MOVLW	B'00100100' ; TXEN=1, BRGH=1 (alta velocidad)
    MOVWF	TXSTA
    BANKSEL	RCSTA
    MOVLW	B'10000000' ; SPEN=1 habilita transmisor
    MOVWF	RCSTA
    BANKSEL	SPBRG
    MOVLW	.12         ; Baud Rate 9600 con Fosc = 2MHz (BRGH=1): SPBRG=12
    MOVWF	SPBRG
    
    BANKSEL     T1CON	    ; -- Timer 1
    CLRF        TMR1L
    CLRF        TMR1H
    MOVLW       B'00110000'
    MOVWF       T1CON
    
    ; Configura todos los puertos como salida
    BANKSEL TRISA
    CLRF TRISA
    CLRF TRISD
    CLRF TRISC
    BCF TRISE, 0 ; RE0 como entrada (AN5)
    BSF TRISE, 0 ; RE0 como entrada (AN5)

    ; Apaga todos los puertos
    BANKSEL PORTA
    CLRF PORTA
    CLRF PORTD
    CLRF PORTC
    
    BANKSEL     INTCON	    ; -- Configuracion de Interrupciones y TMR0
    MOVLW       B'11000000' ; Habilito GIE - PEIE - T0IE- INTE y limpio bandera INTF
    MOVWF       INTCON 
    CLRF	PIR1	    ; Limpio banderas de tx y tmr1
    BANKSEL	PIE1		
    MOVLW       B'00000001' ; Habilito interrupciones por  TMR1
    MOVWF       PIE1            
	
    BANKSEL ADCON0    ; -- Configuracion del ADC
    MOVLW B'11010101' ; Canal AN5 (RE0), ADC habilitado pero no convirtiendo
    MOVWF ADCON0      ; Frecuencia = Fosc/2 = 1[MHz]
    CLRF ADRESH       ; Limpio registro donde se guarda la conversion
    BANKSEL ADCON1
    MOVLW b'10000000'   ; Justificado a la derecha
    MOVWF ADCON1	; Vref = VDD-VSS

;---------------------------------------------------------------------
MAIN_LOOP:
    ; Iniciar conversiÃ³n ADC
    BANKSEL ADCON0
    BSF ADCON0, 1 ; GO/DONE = 1
ESPERA_ADC:
    BTFSC ADCON0, 1 ; Espera que termine la conversiÃ³n
    GOTO ESPERA_ADC
    BANKSEL STATUS
    BCF	STATUS,C
    BANKSEL ADRESL
    RRF	ADRESL,W
    BANKSEL TEMP
    MOVWF   TEMP    ;AUX DE TEMPERATURA
    MOVWF   TEMPACTUAL	;PARA ENVIAR POR TX

;        MOVF ADRESL, W  ; Tomar el resultado de 8 bits (justificado a la izquierda)
;    MOVWF TEMP      ; Guardar valor temporal
    ;-------
DIGITOS:
    BANKSEL DECENAS
    CLRF    DECENAS
    CLRF    UNIDADES
    MOVF   TEMP, W  ; Cargar el valor de temperatura
    MOVWF CONT1
DIV_LOOP:    
;    MOVF ADRESL,W
    MOVLW   .10
    SUBWF   CONT1,W
    BTFSS   STATUS,C
    GOTO    fin_loop
    INCF    DECENAS,F
    MOVLW   .10
    SUBWF   CONT1,F
    GOTO    DIV_LOOP
fin_loop:
    MOVF CONT1,W
    MOVWF UNIDADES ; Guardar el resto en UNIDADES
;    BTFSC   STATUS,C
;    GOTO    DIV_LOOP
;    DECF    DECENAS,F
;    ADDWF   TEMP,W
;    MOVWF   UNIDADES
    
    BANKSEL PORTD
    BCF PORTD, 0
    BCF PORTD, 1

    ; Mostrar decenas (RD1)
    MOVF DECENAS, W
    CALL TABLA_7SEG
    MOVWF PORTA
    BSF PORTD, 1
    CALL DELAY_5MS
    BCF PORTD, 1

    ; Apaga ambos displays antes de cambiar el valor
    BCF PORTD, 0
    BCF PORTD, 1

    ; Mostrar unidades (RD0)
    MOVF UNIDADES, W
    CALL TABLA_7SEG
    MOVWF PORTA
    BSF PORTD, 0
    CALL DELAY_5MS
    BCF PORTD, 0

    ; LED siempre encendido
    BSF PORTC, 3
    GOTO MAIN_LOOP

;---------------------------------------------------------------------
; Tabla de conversiÃ³n a 7 segmentos (0-9)
TABLA_7SEG:
    ADDWF PCL, F
    RETLW b'00111111' ; 0
    RETLW b'00000110' ; 1
    RETLW b'01011011' ; 2
    RETLW b'01001111' ; 3
    RETLW b'01100110' ; 4
    RETLW b'01101101' ; 5
    RETLW b'01111101' ; 6
    RETLW b'00000111' ; 7
    RETLW b'01111111' ; 8
    RETLW b'01101111' ; 9
;----------------------------------------------------------------------
; Retardo visible (parpadeo LED)
;DELAY:
 ;   MOVLW .250
 ;   MOVWF CONT1
;L2:
;    MOVLW .250
;    MOVWF CONT2
;L1:
;    NOP
;    DECFSZ CONT2, F
;    GOTO L1
;    DECFSZ CONT1, F
;    GOTO L2
;    RETURN

;----------------------------------------------------------------------
; Retardo corto (~5ms)
DELAY_5MS:
    MOVLW .50
    MOVWF CONT3
DELAY_LOOP:
    NOP
    DECFSZ CONT3, F
    GOTO DELAY_LOOP
    return
;-----------------------------------------------------------------------
ISR:                    ; Rutina principal de atenciÃ³n a interrupciones: verifica la fuente y salta a la rutina correspondiente.
    MOVWF       WTEMP       ;Guardo el contexto previo a la interrupcion
    SWAPF       STATUS,W
    MOVWF       STATUST
    BTFSC       PIR1,TMR1IF  ; Bandera del TMR1
    GOTO        ISR_TMR1
    BTFSC       PIR1,TXIF   ;Bandera de Tx
    GOTO        ISR_TRANSMICION 
    GOTO        SALIR
; --------------------------------------------
ISR_TMR1:   ; Atiende la interrupciÃ³n del temporizador 1 y activa la bandera de 1 segundo.
    BANKSEL	PIR1
    BCF         PIR1,TMR1IF
    BANKSEL     PIE1
    BSF         PIE1,TXIE   ; Habilito la transmicion luego de 1 segundo
    GOTO        SALIR
; --------------------------------------------
ISR_TRANSMICION:    ; Interrumpe cuando el buffer esta limpio
    BANKSEL     PIR1
    BCF         PIR1,TXIF   ;Limpio la bandera
    BANKSEL     PIE1
    BCF         PIE1,TXIE   ; Deshabilito la interrupcion de transmicion
    BANKSEL     TEMPACTUAL      ; -- Proceso de Tx
    MOVF        TEMPACTUAL,W    
    BTFSS       STATUS,Z        ; SI ESTA VACIO NO ENVIO NADA
    MOVWF       TXREG
    GOTO        SALIR
; --------------------------------------------
SALIR:	    ; Restaura el contexto y retorna de la interrupciÃ³n.
    SWAPF       STATUST,W
    MOVWF       STATUST
    SWAPF       WTEMP,F
    SWAPF       WTEMP,W
    RETFIE
; --------------------------------------------
    END
