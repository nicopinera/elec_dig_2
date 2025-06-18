LIST    p=16F887
#include <p16f887.inc>

    __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    ORG 0x00
    GOTO MAIN
    ORG 0x04
    GOTO ISR
; --- Variables ---
    CBLOCK 0x20
        cont1
        cont2
        temp_adc     ; <-- Variable para guardar el valor del ADC
    ENDC

MAIN
    ; Configurar PORTA como salida (bus de datos para displays)
    BANKSEL TRISA
    CLRF TRISA

    ; Configurar RB1 y RB2 como salida (habilitadores displays)
    BANKSEL TRISB
    BCF TRISB, 1
    BCF TRISB, 2

    ; Configurar RC3 como salida (LED)
    BANKSEL TRISC
    BCF TRISC, 3

    ; Configurar RE0/AN5 como entrada analógica
    BANKSEL TRISE
    BSF TRISE, 0         ; RE0 como entrada
    BANKSEL ANSEL
    MOVLW b'00100000'    ; AN5 analógico, resto digital
    MOVWF ANSEL
    BANKSEL ANSELH
    CLRF ANSELH          ; Solo AN5 analógico

    ; Configurar ADC
    BANKSEL ADCON1
    MOVLW b'10000000'    ; Justificado a la izquierda, Vref=Vdd
    MOVWF ADCON1
    BANKSEL ADCON0
    MOVLW b'00010101'    ; Canal AN5 (CHS=101), ADC ON, Fosc/16
    MOVWF ADCON0

    ; Apagar displays y limpiar PORTA
    BANKSEL PORTA
    CLRF PORTA
    BANKSEL PORTB
    BCF PORTB, 1
    BCF PORTB, 2

    ; Apagar LED al inicio
    BANKSEL PORTC
    BCF PORTC, 3

    ; Habilitar interrupciones del ADC
    BANKSEL PIE1
    BSF PIE1, ADIE      ; Habilita interrupción ADC
    BANKSEL PIR1
    BCF PIR1, ADIF      ; Limpia bandera ADC
    BANKSEL INTCON
    BSF INTCON, PEIE    ; Habilita interrupciones periféricas
    BSF INTCON, GIE     ; Habilita interrupciones globales

LOOP
    ; Iniciar conversión ADC (el resultado se guarda en la ISR)
    BANKSEL ADCON0
    BSF ADCON0, GO

    ; --- Multiplexado displays y LED (igual que antes) ---
    ; --- Mostrar "0" en display de decenas (RB2) ---
    BANKSEL PORTA
    CLRF PORTA            ; Limpia segmentos antes de cambiar habilitadores
    BANKSEL PORTB
    BCF PORTB, 1          ; Apaga RB1 (unidades)
    BCF PORTB, 2          ; Apaga RB2 (decenas)
    BANKSEL PORTA
    MOVLW 0x3F            ; Código 7 segmentos para "0"
    MOVWF PORTA
    BANKSEL PORTB
    BSF PORTB, 2          ; Enciende RB2 (decenas)
    CALL DELAY_10MS

    ; Apagar display decenas y limpiar segmentos
    BANKSEL PORTB
    BCF PORTB, 2
    BANKSEL PORTA
    CLRF PORTA

    ; --- Mostrar "1" en display de unidades (RB1) ---
    BANKSEL PORTA
    CLRF PORTA            ; Limpia segmentos antes de cambiar habilitadores
    BANKSEL PORTB
    BCF PORTB, 1          ; Apaga RB1 (unidades)
    BCF PORTB, 2          ; Apaga RB2 (decenas)
    BANKSEL PORTA
    MOVLW 0x06            ; Código 7 segmentos para "1"
    MOVWF PORTA
    BANKSEL PORTB
    BSF PORTB, 1          ; Enciende RB1 (unidades)
    CALL DELAY_10MS

    ; Apagar display unidades y limpiar segmentos
    BANKSEL PORTB
    BCF PORTB, 1
    BANKSEL PORTA
    CLRF PORTA

    ; Encender LED en RC3 (mantener encendido)
    BANKSEL PORTC
    BSF PORTC, 3

    ; Retardo de 200 ms entre lecturas de temperatura
    CALL DELAY_200MS

    GOTO LOOP

; --- Interrupción de alta prioridad ---
ISR
    BANKSEL PIR1
    BTFSS PIR1, ADIF
    GOTO ISR_EXIT
    ; Interrupción ADC
    BANKSEL ADRESH
    MOVF ADRESH, W
    BANKSEL temp_adc
    MOVWF temp_adc
    BANKSEL PIR1
    BCF PIR1, ADIF
ISR_EXIT
    RETFIE

; --- Retardo de 10 ms ---
DELAY_10MS
    BANKSEL cont1
    MOVLW   D'20'
    MOVWF   cont1
D10MS1
    MOVLW   D'250'
    MOVWF   cont2
D10MS2
    NOP
    DECFSZ  cont2, f
    GOTO    D10MS2
    DECFSZ  cont1, f
    GOTO    D10MS1
    RETURN

; --- Retardo de 200 ms ---
DELAY_200MS
    BANKSEL cont1
    MOVLW   D'40'
    MOVWF   cont1
D200MS1
    MOVLW   D'250'
    MOVWF   cont2
D200MS2
    NOP
    DECFSZ  cont2, f
    GOTO    D200MS2
    DECFSZ  cont1, f
    GOTO    D200MS1
    RETURN

    END

