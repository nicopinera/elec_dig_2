LIST    p=16F887
    #include <p16f887.inc>

    __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    ORG 0x00
    GOTO MAIN
    ORG 0x04
    GOTO ISR

; Variables
    CBLOCK 0x20
        TEMP_ADC
        TEMP_C
        DECENAS
        UNIDADES
        TEMP_REF
        DISP_FLAG
        TMP
    ENDC

MAIN
    ; Configurar oscilador interno a 2MHz
    BANKSEL OSCCON
    MOVLW b'01010000' ; IRCF=010 (2MHz), SCS=00 (osc interno)
    MOVWF OSCCON

    BANKSEL ANSEL
    MOVLW 0x20        ; AN5 (RE0) como analógico, resto digital
    MOVWF ANSEL
    BANKSEL ANSELH
    CLRF ANSELH       ; PORTB digital

    BANKSEL TRISA
    CLRF TRISA        ; PORTA salida

    BANKSEL TRISB
    CLRF TRISB        ; PORTB salida

    BANKSEL TRISE
    MOVLW 0x01        ; RE0 como entrada, RE1 como salida
    MOVWF TRISE

    BANKSEL PORTA
    CLRF PORTA        ; Limpiar PORTA

    BANKSEL PORTB
    CLRF PORTB        ; Limpiar PORTB

    BANKSEL ADCON1
    MOVLW 0x80        ; Justificado a la izquierda, Vref=Vdd
    MOVWF ADCON1

    BANKSEL ADCON0
    MOVLW 0x51        ; Canal AN5 (RE0), ADC ON
    MOVWF ADCON0

    ; Configurar Timer0 para interrupciones (~5ms)
    BANKSEL OPTION_REG
    MOVLW b'00000111' ; Prescaler 1:256
    MOVWF OPTION_REG

    BANKSEL INTCON
    BSF INTCON, T0IE  ; Habilita interrupción Timer0
    BSF INTCON, PEIE  ; Habilita periféricos
    BSF INTCON, GIE   ; Habilita global

    ; Establecer temperatura de referencia en 10
    MOVLW 10
    MOVWF TEMP_REF

    CLRF DISP_FLAG    ; Inicia con decenas

    ; Configurar UART (9600bps, Fosc=2MHz, BRGH=1, SPBRG=12)
    BANKSEL TXSTA
    BSF TXSTA, BRGH      ; Alta velocidad
    BANKSEL SPBRG
    MOVLW 12
    MOVWF SPBRG
    BANKSEL RCSTA
    BSF RCSTA, SPEN      ; Habilita serial
    BANKSEL TXSTA
    BSF TXSTA, TXEN      ; Habilita transmisión

    ; Configurar TMR1 para 1s (Fosc=2MHz, Fcy=500kHz, prescaler 1:8)
    ; 500kHz/8 = 62500Hz, 1s = 62500 ciclos, 65536-62500 = 3036 = 0x0BDC
    BANKSEL T1CON
    MOVLW b'00110001'    ; TMR1 ON, prescaler 1:8
    MOVWF T1CON
    BANKSEL PIR1
    BCF PIR1, TMR1IF     ; Limpia bandera TMR1
    BANKSEL PIE1
    BSF PIE1, TMR1IE     ; Habilita interrupción TMR1

    ; Cargar TMR1 para 1s
    BANKSEL TMR1H
    MOVLW 0x0B
    MOVWF TMR1H
    MOVLW 0xDC
    MOVWF TMR1L

    ; Habilitar interrupciones globales y periféricas (ya hecho)

    ; Configurar RB0/INT como entrada (ya está por defecto con CLRF TRISB)
    ; Habilitar interrupción externa INT en RB0 (flanco de bajada)
    BANKSEL OPTION_REG
    BCF OPTION_REG, INTEDG   ; Interrupción en flanco de bajada (pulsador a GND)
    BANKSEL INTCON
    BSF INTCON, INTE         ; Habilita INT externa en RB0

LOOP
    ; Comparar TEMP_C con TEMP_REF y controlar LED en RE1
    MOVF TEMP_REF, W
    SUBWF TEMP_C, W    ; W = TEMP_C - TEMP_REF
    BTFSS STATUS, C    ; Si C=0, TEMP_C < TEMP_REF
    GOTO LED_OFF
    BANKSEL PORTE
    BSF PORTE, 1       ; Enciende LED en RE1
    GOTO CONT_LOOP
LED_OFF
    BANKSEL PORTE
    BCF PORTE, 1       ; Apaga LED en RE1
CONT_LOOP
    GOTO LOOP

;------------------------------------------
; Rutina de interrupción
ISR
    ; --- INT RB0: Toggle RE1 ---
    BANKSEL INTCON
    BTFSC INTCON, INTF
    GOTO INT_RB0_ISR

    BANKSEL PIR1
    BTFSC PIR1, TMR1IF
    GOTO TMR1_ISR

    BANKSEL INTCON
    BCF INTCON, T0IF   ; Limpia bandera Timer0

    ; Alternar display
    MOVF DISP_FLAG, W
    BTFSS STATUS, Z    ; Si DISP_FLAG != 0, mostrar unidades
    GOTO SHOW_UNI
    ; Mostrar decenas (RB2)
    MOVF DECENAS, W
    CALL DISPLAY7SEG
    BANKSEL PORTA
    MOVWF PORTA            ; Enviar segmentos de decenas a PORTA
    BANKSEL PORTB
    BCF PORTB, 1           ; Apaga RB1 (unidades)
    BSF PORTB, 2           ; Enciende RB2 (decenas)
    INCF DISP_FLAG, F
    GOTO ADC_START
SHOW_UNI
    ; Mostrar unidades (RB1)
    MOVF UNIDADES, W
    CALL DISPLAY7SEG
    BANKSEL PORTA
    MOVWF PORTA            ; Enviar segmentos de unidades a PORTA
    BANKSEL PORTB
    BSF PORTB, 1           ; Enciende RB1 (unidades)
    BCF PORTB, 2           ; Apaga RB2 (decenas)
    CLRF DISP_FLAG

ADC_START
    ; Iniciar conversión ADC solo cuando se alterna display
    BANKSEL ADCON0
    BSF  ADCON0, 1    ; GO/DONE=1

WAIT_ADC_ISR
    BTFSC ADCON0, 1
    GOTO WAIT_ADC_ISR

    ; Leer resultado (justificado a la izquierda: ADRESH tiene los 8 MSB)
    BANKSEL ADRESH
    MOVF ADRESH, W
    MOVWF TEMP_ADC

    ; TEMP_C = TEMP_ADC / 2
    MOVF TEMP_ADC, W
    MOVWF TEMP_C
    RRF TEMP_C, F

    ; Separar decenas y unidades usando TMP
    MOVF TEMP_C, W
    MOVWF TMP
    CLRF DECENAS
SEP_DECENAS_ISR
    MOVLW 10
    SUBWF TMP, W
    BTFSS STATUS, C
    GOTO SEP_FIN_ISR
    MOVF TMP, W
    ADDLW -10
    MOVWF TMP
    INCF DECENAS, F
    GOTO SEP_DECENAS_ISR
SEP_FIN_ISR
    MOVF TMP, W
    MOVWF UNIDADES

    RETFIE

TMR1_ISR
    ; Recargar TMR1 para 1s
    BANKSEL TMR1H
    MOVLW 0x0B
    MOVWF TMR1H
    MOVLW 0xDC
    MOVWF TMR1L
    BANKSEL PIR1
    BCF PIR1, TMR1IF

    ; Habilitar transmisión UART y enviar TEMP_C en binario
    BANKSEL TXSTA
    BSF TXSTA, TXEN        ; Habilita transmisión (por si acaso)
    BANKSEL TEMP_C
    MOVF TEMP_C, W
WAIT_TX
    BANKSEL PIR1
    BTFSS PIR1, TXIF       ; Espera buffer libre
    GOTO WAIT_TX
    BANKSEL TXREG
    MOVWF TXREG            ; Enviar TEMP_C

    RETFIE

INT_RB0_ISR
    ; Limpiar bandera de interrupción externa
    BCF INTCON, INTF
    ; Cambiar el estado del LED en RE1 (toggle manual)
    BANKSEL PORTE
    BTFSS PORTE, 1
    GOTO TURN_ON_RE1
    BCF PORTE, 1      ; Si está encendido, apaga
    RETFIE
TURN_ON_RE1
    BSF PORTE, 1      ; Si está apagado, enciende
    RETFIE

;------------------------------------------
; Rutina para convertir número 0-9 a 7 segmentos
; Entrada: W (0-9)
; Salida: W = código 7 segmentos
DISPLAY7SEG
    ADDWF PCL, F
    RETLW 0x3F ; 0
    RETLW 0x06 ; 1
    RETLW 0x5B ; 2
    RETLW 0x4F ; 3
    RETLW 0x66 ; 4
    RETLW 0x6D ; 5
    RETLW 0x7D ; 6
    RETLW 0x07 ; 7
    RETLW 0x7F ; 8
    RETLW 0x6F ; 9

DELAY
    MOVLW D'250'
    MOVWF 0x20
LOOP1
    MOVLW D'250'
    MOVWF 0x21
LOOP2
    NOP
    DECFSZ 0x21, f
    GOTO LOOP2
    DECFSZ 0x20, f
    GOTO LOOP1
    RETURN
    END

