LIST	p=16f887
    #INCLUDE	<p16f887.inc>
    
;-------------------------------
; Variables externas
;-------------------------------
; Nos indica si estamos esperando un numero y si se ingreso el primer digito
; B0 = 1 = Esperando - B0 = 0 = No Esperando
; B1 = 0 = No se ingreso el primer digito - B1 = 1 = Se ingreso el primer digito
INGRESAR    EQU 0X20

; Temperatura de Referencia
TEMPREF	    EQU 0X21

; Indice de tecla pulsada (0-15)
INDICE	    EQU 0X22

; En que columna estoy (1-4)
COL	    EQU 0X23

; Mascara de columna
COLMASK	    EQU 0X24    

; Banderas
; B0: Bandera de 1 segundo - Si =1 comienza la conversion en ADC - Si =0 no compienza la conversion - Bandera activada por TMR1 cada 1 segundo
FLAG	    EQU	0X31
	    
	    
; Displays
DIGITO_0    EQU 0X25        ; Unidad
DIGITO_1    EQU 0X26        ; Decena
DISPLAY_FLAG	EQU	0X27        ; Alterna entre display 0 y 1

; Contador delay
CONT0 EQU 0X28       
CONT1 EQU 0X29 
DIG1 EQU 0X2A        ; Primer dígito temporal
WREG_TEMP EQU 0X2B   ; Variable temporal para cálculos
WREG_TEMP2 EQU 0X2C  ; Variable temporal para cálulos
FLAG_1SEG EQU 0X2D   ; Bandera activada por TMR1 cada 1 segundo
FLAG_ADC_OK EQU 0X2E ; Bandera que indica que el ADC terminó
FLAG_TX EQU 0X2F     ; Bandera para indicar que hay que transmitir
TEMPACTUAL EQU 0X30  ;Temperatura actual

; Para guardar contexto
WTEMP   EQU 0X70
STATUST EQU 0X71
; --------------------------------------------
    ORG     0X0
    GOTO    MAIN    ; El programa comienza en la direccion 0 y salta a la rutina principal MAIN.
; --------------------------------------------
    ORG     0X04
    GOTO    ISR     ; Si ocurre una interrupcion, el programa salta a la rutina ISR.
; --------------------------------------------
    ORG 0X05
MAIN:
    CLRF        INGRESAR    ; -- Limpieza de Banderas
    CLRF        TEMPREF
    CLRF        FLAG_1SEG
    CLRF        FLAG_ADC_OK
    CLRF        FLAG_TX
    CLRF        DIGITO_0        
    CLRF        DIGITO_1     
    CLRF        DISPLAY_FLAG

    BANKSEL     TRISD	    ; -- Configuracion de Puertos
    MOVLW       B'11110000' ; RD7-RD4 Entradas (filas), RD3-RD0 Filas (columnas)
    MOVWF       TRISD
    CLRF        TRISC       ; Display segmentos como salida
    MOVLW       B'00000001' ; Configura el puerto B: RBO para el pulsador y RB1 -RB2 los habilitadores del display.
    MOVWF       TRISB
    BSF         TRISE,RE0   ; Configura el puerto E: RE0 como entrada analogica para el sensor y RE1 como salida para el LED.
    BCF         TRISE,RE1   
    CLRF        TRISA       ; Configura el puerto A como salida para enviar datos al display.
    BANKSEL     PORTA
    CLRF        PORTD        ; Asegura que columnas inician en 0
    CLRF        PORTB
    CLRF        PORTE
    CLRF        PORTA
    BANKSEL     ANSELH      ; Configura RB0 como entrada digital (no analógica).
    BCF         ANSELH,ANS12
    
    BANKSEL     OSCCON	    ; -- Configura el oscilador interno del microcontrolador a 2 MHz.
    MOVLW       B'01011000'
    MOVWF       OSCCON	    
    
    BANKSEL	ADCON0	    ; -- Configuracion del ADC
    MOVLW	B'00010101' ; Canal AN5 (RE0), ADC habilitado pero no convirtiendo 
    MOVWF	ADCON0	    ; Frecuencia = Fosc/2 = 1[MHz]
    CLRF	ADRESH	    ; Limpio registro donde se guarda la conversion
    BANKSEL	ADCON1
    CLRF	ADCON1	    ; Justificado a la izquierda, Vref = VDD-VSS
    
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
    MOVWF       T1CON            ; Inicializa el temporizador TMR1 y lo configura.
    
    BANKSEL OPTION_REG	    ; -- Timer 0
    MOVLW   B'00000111'     ; TMR0 con prescaler 1:256
    MOVWF   OPTION_REG
    CLRF    TMR0
    
    BANKSEL     INTCON		; -- Configuracion de Interrupciones y TMR0
    MOVLW       B'11110000'     ; Habilito GIE - PEIE - T0IE- INTE y limpio bandera INTF
    MOVWF       INTCON 
    CLRF	PIR1		; Limpio banderas de ADC - Tx - TRM1iF
    BANKSEL     OPTION_REG
    MOVLW	B'10010111'	; Flanco de bajada para INT - Frecuencia interna para TMR0 - Prescaler para TMR0 - 1:256
    MOVWF	OPTION_REG	
    BANKSEL	PIE1		
    MOVLW       B'01010001'     ; Habilito interrupciones por ADC - TX - TMR1
    MOVWF       PIE1            

    ;Activo TMR1
    BANKSEL     T1CON
    BSF         T1CON,0             
; --------------------------------------------
MAIN_LOOP:                      ; -- Loop Principal
    BTFSC       INGRESAR,0	    ; Si está esperando ingreso de número
    CALL        TECLADO		    ; Llama a la rutina de teclado
    BTFSC       INGRESAR,0      ; Si sigue esperando ingreso, no hace nada más
    GOTO        MAIN_LOOP

    BTFSC	    FLAG_1SEG, 0    ; Si pasó 1 segundo, inicio conversión ADC
    GOTO        INICIAR_ADC
    ; Si no pasó 1 segundo, sigue

    BTFSC       FLAG_ADC_OK, 0	; Si el ADC finalizó, preparar para transmitir
    GOTO        PREPARAR_TX

    BTFSC       FLAG_TX, 0      ; Si hay que transmitir, enviar por UART
    GOTO        ENVIAR_UART

    ; Comparación de temperatura actual con la temperatura de referencia para prender el led
    MOVF        TEMPREF,W
    SUBWF       TEMPACTUAL,W
    BTFSC       STATUS,C	    ; Si TEMPACTUAL >= TEMPREF
    BSF         PORTE,RE1	    ; Enciende LED
    ; FALTA: Apagar el LED si TEMPACTUAL < TEMPREF
    BTFSS       STATUS,C
    BCF         PORTE,RE1
    GOTO        MAIN_LOOP

INICIAR_ADC:
    BCF		    FLAG_1SEG, 0	
    BANKSEL	    ADCON0
    BSF		    ADCON0, GO     ; Iniciar conversión del ADC
    BSF		    ADCON0, ADON
    GOTO        MAIN_LOOP

PREPARAR_TX:
    BCF         FLAG_ADC_OK, 0
    BSF         FLAG_TX, 0     ; Listo para enviar por UART
    GOTO        MAIN_LOOP

ENVIAR_UART:
    ; Enviar TEMPACTUAL por UART como ASCII (2 dígitos)
    MOVF    TEMPACTUAL, W
    MOVWF   WREG_TEMP
    MOVLW   .10
    MOVWF   WREG_TEMP2
    CLRF    DIG1

    ; Dividir por 10 para obtener decena
DIV_LOOP:
    MOVF    WREG_TEMP, W
    SUBWF   WREG_TEMP2, W
    BTFSS   STATUS, C
    GOTO    ENVIAR_DIGITOS
    INCFSZ  DIG1, F
    SUBWF   WREG_TEMP, F
    GOTO    DIV_LOOP

ENVIAR_DIGITOS:
    ; Enviar decena
    MOVF    DIG1, W
    ADDLW   '0'
    MOVWF   TXREG
ESPERO_TX1:
    BTFSS   PIR1,TXIF
    GOTO    ESPERO_TX1

    ; Enviar unidad
    MOVF    WREG_TEMP, W
    ADDLW   '0'
    MOVWF   TXREG
ESPERO_TX2:
    BTFSS   PIR1,TXIF
    GOTO    ESPERO_TX2

    BCF     FLAG_TX, 0
    GOTO    MAIN_LOOP

; --------------------------------------------
TECLADO:                    ; Subrutina de Teclado
    BANKSEL     PORTD
    MOVLW       0x0F	    ; pongo 1 todas las columnas
    MOVWF       PORTD
    MOVF        PORTD, W	; y veo todas las filas
    ANDLW       0xF0        ; enmascarar filas
    BTFSC       STATUS, Z
    GOTO        TECLADO	    ; no hay teclas presionadas -> vuelvo al loop
    CALL        RETARDO_20ms
    MOVF        PORTD, W 
    ANDLW       0xF0 
    BTFSC       STATUS, Z
    GOTO        TECLADO     ; no hay teclas presionadas -> vuelvo al Teclado --- Si -> voy a escanear las teclas
    CALL        ESCANEAR_TECLAS
    MOVF        INDICE, W
    SUBLW       0x0F	    
    BTFSS       STATUS, C	    ; Indice < = que 15?
    RETURN          	            ; no -> indice no válido
    MOVF        INDICE, W	    ; si -> buscar valor en tabla TECLAS
    CALL        TECLAS          ; La tabla TECLAS ya devuelve el valor decimal (0-9)
    MOVWF       WREG_TEMP       ; WREG_TEMP = valor numérico de la tecla
    BTFSS       INGRESAR, 1     ; ¿Ya se ingresó el primer dígito? (usamos INGRESAR,1 como flag) - Si NO se ingresó el primer dígito, lo guardo como decena y retorno
    GOTO        TECLADO_PRIMER_DIGITO
    ; Si YA se ingresó el primer dígito, este es el segundo (unidad)
    ; Combinar decena y unidad

    CALL        TECLADO_SEGUNDO_DIGITO
    RETURN

TECLADO_SEGUNDO_DIGITO:
    MOVF    DIG1, W            ; decena
    MOVWF   TEMPREF
    RLF     TEMPREF, F         ; TEMPREF = DIG1 * 2
    RLF     TEMPREF, F         ; TEMPREF = DIG1 * 4
    RLF     TEMPREF, F         ; TEMPREF = DIG1 * 8
    RLF     TEMPREF, F         ; TEMPREF = DIG1 * 16
    ; TEMPREF = DIG1 * 16, queremos *10, sumamos (DIG1*8 + DIG1*2)
    MOVF    DIG1, W
    ADDWF   TEMPREF, F         ; TEMPREF += DIG1 (ahora *17)
    ADDWF   TEMPREF, F         ; TEMPREF += DIG1 (ahora *18)
    ; Ahora TEMPREF = DIG1*18, restamos DIG1*8
    MOVF    DIG1, W
    MOVWF   WREG_TEMP2
    RLF     WREG_TEMP2, F      ; WREG_TEMP2 = DIG1*2
    RLF     WREG_TEMP2, F      ; WREG_TEMP2 = DIG1*4
    RLF     WREG_TEMP2, F      ; WREG_TEMP2 = DIG1*8
    SUBWF   TEMPREF, F         ; TEMPREF = (DIG1*18) - (DIG1*8) = DIG1*10
    ; Ahora sumamos el segundo dígito (unidad)
    MOVF    WREG_TEMP, W
    ADDWF   TEMPREF, F
    CALL    ACTUALIZAR_DISPLAY  ;Para que se carguen los dos digitos de temperatura en el display

    ; Limpiamos la bandera de INGRESAR para terminar la carga
    BCF     INGRESAR, 0
    BCF     INGRESAR, 1
    RETURN
    ; Cuando se ingresa el segundo dígito, se calcula el valor final y se limpia la bandera de ingreso.
; --------------------------------------------
TECLADO_PRIMER_DIGITO:
    MOVF    WREG_TEMP, W
    MOVWF   DIG1
    BSF     INGRESAR, 1   ; Seteamos flag de primer dígito ingresado
    GOTO	TECLADO
    ; Cuando se ingresa el primer dígito, se guarda como decena y se activa la bandera para esperar el segundo dígito.

;-----------------------------------------------------------
; ESCANEAR_TECLAS: Escanea el teclado 4x3 y devuelve en INDICE el índice físico (0-11)
; Si no hay tecla válida, INDICE = 0xFF
;-----------------------------------------------------------
ESCANEAR_TECLAS:
    CLRF    COL             ; Inicializa columna en 0
    MOVLW   0x02            ; Empieza con RD1 (columna 1)
    MOVWF   COLMASK         ; COLMASK = 0x02
SCAN_COL_LOOP:
    MOVLW   0x0F            ; Todas las columnas en 1 (RD3-RD1)
    IORWF   PORTD, F        ; Asegura columnas en 1
    COMF    COLMASK, W      ; Invierte máscara: columna activa en 0
    ANDLW   0x0E            ; Solo columnas RD3-RD1 (0b00001110)
    IORLW   0xF1            ; Mantiene filas (RD7-RD4) en 1, RD0 en 1
    MOVWF   PORTD           ; Aplica a PORTD: una columna en 0, el resto en 1
    NOP                     ; Pequeño retardo para estabilizar
    NOP
    MOVF    PORTD, W
    ANDLW   0xF0            ; Enmascara filas (RD7-RD4)
    XORLW   0xF0            ; Si todas filas en 1, resultado será 0 (ninguna tecla)
    BTFSC   STATUS, Z
    GOTO    NEXT_COL        ; Si no hay tecla en esta columna, pasa a la siguiente

    ; Alguna fila está en 0, detectar cuál
    MOVF    PORTD, W
    ANDLW   0xF0
    XORLW   0xF0            ; Invierte filas: la presionada será 1
    MOVWF   WREG_TEMP       ; WREG_TEMP = bits de fila activa
    CLRF    INDICE          ; INDICE = número de fila (0-3)
    MOVLW   0x10            ; Empieza con RD4 (fila 4)
    MOVWF   WREG_TEMP2      ; WREG_TEMP2 = máscara de fila a chequear

SCAN_ROW_LOOP:
    MOVF    WREG_TEMP, W
    ANDWF   WREG_TEMP2, W
    BTFSS   STATUS, Z
    GOTO    FOUND_ROW       ; Si bit de fila está en 1, es la fila activa
    INCF    INDICE, F
    RLF     WREG_TEMP2, F   ; Siguiente bit de fila (RD4->RD5->RD6->RD7)
    MOVLW   0x80
    SUBWF   WREG_TEMP2, W
    BTFSS   STATUS, C
    GOTO    NEXT_COL        ; Si ya chequeó las 4 filas, pasa a la siguiente columna
    GOTO    SCAN_ROW_LOOP

FOUND_ROW:
    ; INDICE = número de fila (0-3)
    ; Calcula índice físico: INDICE = fila*3 + columna
    MOVF    INDICE, W
    MOVWF   WREG_TEMP2
    RLF     WREG_TEMP2, F   ; *2
    ADDWF   INDICE, W       ; W = fila*3 + fila
    ADDWF   COL, W          ; W = fila*3 + columna
    MOVWF   INDICE          ; Guarda índice físico en INDICE
    RETURN

NEXT_COL:
    INCF    COL, F
    MOVLW   0x03
    SUBWF   COL, W
    BTFSS   STATUS, Z       ; ¿Ya se probaron las 3 columnas?
    RLF     COLMASK, F      ; Siguiente columna (RD1->RD2->RD3)
    GOTO    SCAN_COL_LOOP
    MOVLW   0xFF            ; No se detectó tecla
    MOVWF   INDICE
    RETURN

;-----------------------------------------------------------
; TECLAS: Traduce el índice físico (0-11) a valor numérico (0-9)
; Si no es un número, devuelve 0xFF
;-----------------------------------------------------------
TECLAS:
    ADDWF   PCL, F
    RETLW   0xFF    ; 0: * (fila 1, col 1)
    RETLW   0x00    ; 1: 0 (fila 1, col 2)
    RETLW   0xFF    ; 2: # (fila 1, col 3)
    RETLW   0x07    ; 3: 7 (fila 2, col 1)
    RETLW   0x08    ; 4: 8 (fila 2, col 2)
    RETLW   0x09    ; 5: 9 (fila 2, col 3)
    RETLW   0x04    ; 6: 4 (fila 3, col 1)
    RETLW   0x05    ; 7: 5 (fila 3, col 2)
    RETLW   0x06    ; 8: 6 (fila 3, col 3)
    RETLW   0x01    ; 9: 1 (fila 4, col 1)
    RETLW   0x02    ; 10: 2 (fila 4, col 2)
    RETLW   0x03    ; 11: 3 (fila 4, col 3)
    RETLW   0xFF    ; 12: A (fila 4, col 3)

;----------------------------------------------------------
;Subrutina del display
;------------------------------------------------------------------------
ACTUALIZAR_DISPLAY:
    MOVF    TEMPACTUAL, W ; o TEMPREF
    MOVWF   WREG_TEMP
    MOVLW   .10
    MOVWF   WREG_TEMP2
    CLRF    DIGITO_1
BUCLE_RESTA:
    SUBWF   WREG_TEMP, W
    BTFSS   STATUS, C
    GOTO    GUARDAR_UNIDAD
    INCF    DIGITO_1, F
    MOVF    WREG_TEMP, W
    SUBWF   WREG_TEMP2, W
    MOVWF   WREG_TEMP
    GOTO    BUCLE_RESTA
GUARDAR_UNIDAD:
    MOVF    WREG_TEMP, W
    MOVWF   DIGITO_0
    RETURN
; --------------------------------------------
RETARDO_20ms:           ; Rutina de retardo aproximado de 20 ms usando bucles anidados.
    MOVLW       .10
    MOVWF       CONT0
L2  MOVLW       .250
    MOVWF       CONT1
L1  NOP             
    DECFSZ      CONT1, 1
    GOTO        L1
    DECFSZ      CONT0,1
    GOTO        L2
    RETURN
;-----------------------------------------------------------------------------
TABLA_7SEG:
    RETLW   B'11000000' ; 0
    RETLW   B'11111001' ; 1
    RETLW   B'10100100' ; 2
    RETLW   B'10110000' ; 3
    RETLW   B'10011001' ; 4
    RETLW   B'10010010' ; 5
    RETLW   B'10000010' ; 6
    RETLW   B'11111000' ; 7
    RETLW   B'10000000' ; 8
    RETLW   B'10010000' ; 9
; --------------------------------------------
ISR:                    ; Rutina principal de atención a interrupciones: verifica la fuente y salta a la rutina correspondiente.
    MOVWF   WTEMP       ;Guardo el contexto previo a la interrupcion
    SWAPF   STATUS,W
    MOVWF   STATUST
    BTFSC   INTCON, T0IF  ;Testeo del Timer0
    GOTO    ISR_TMR0   
    BANKSEL PIR1        ; Testeo de banderas
    BTFSC   INTCON,INTF ; Bandera del Pulsador
    GOTO    ISR_RB0
    BTFSC   PIR1,TMR1IF  ; Bandera del TMR1
    GOTO    ISR_TMR1
    BTFSC   PIR1,ADIF   ; Bandera del ADC
    GOTO    ISR_ADC
    BTFSC   PIR1,TXIF   ;Bandera de Tx
    GOTO    ISR_TRANSMICION 
    GOTO    SALIR
; --------------------------------------------
ISR_TMR0:
    BCF     INTCON, T0IF
    BCF     PORTA, 0
    BCF     PORTA, 1
    MOVF    DISPLAY_FLAG, W
    BTFSC   STATUS, Z
    GOTO    MUX_DISPLAY_1
    ; Mostrar unidad
    MOVF    DIGITO_0, W
    CALL    TABLA_7SEG
    MOVWF   PORTC
    BSF     PORTA, 1
    CLRF    DISPLAY_FLAG
    GOTO    SALIR
MUX_DISPLAY_1:
    MOVF    DIGITO_1, W
    CALL    TABLA_7SEG
    MOVWF   PORTC
    BSF     PORTA, 0
    MOVLW   0x01
    MOVWF   DISPLAY_FLAG
    GOTO    SALIR
;----------------------------------------------
ISR_RB0     ; Atiende la interrupción por el pulsador en RB0 y conmuta la bandera de ingreso.
    BCF     INTCON,INTF
    BANKSEL INGRESAR
    MOVLW   .1
    XORWF   INGRESAR,F   ;si estaba en 1 pasa a 0, si estaba en 0 pasa a 1
    GOTO    SALIR
; --------------------------------------------
ISR_TMR1:   ; Atiende la interrupción del temporizador 1 y activa la bandera de 1 segundo.
    BCF     PIR1,TMR1IF
    BSF     FLAG_1SEG,0
    GOTO    SALIR
; --------------------------------------------
ISR_ADC:    ; Atiende la interrupción del ADC y limpia la bandera correspondiente.
    BCF     PIR1,ADIF
    BANKSEL ADRESH
    MOVF    ADRESH, W           ; Leemos solo ADRESH (justificado a la izquierda)
    MOVWF   TEMPACTUAL          ; Guardamos la temperatura
    CALL    ACTUALIZAR_DISPLAY  ; Cada vez que se complete una conversion del ADC se actualizan los displays *(REVISAR POR LAS DUDAS)*
    BSF     FLAG_ADC_OK, 0
    GOTO    SALIR
; --------------------------------------------
ISR_TRANSMICION:    ; Atiende la interrupción de transmisión y limpia la bandera correspondiente.
    BCF     PIR1,TXIF
    BCF     FLAG_TX, 0
    GOTO    SALIR
; --------------------------------------------
SALIR:    ; Restaura el contexto y retorna de la interrupción.
    SWAPF   STATUST,W
    MOVWF   STATUST
    SWAPF   WTEMP,F
    SWAPF   WTEMP,W
    RETFIE
; --------------------------------------------
    END
    SWAPF   WTEMP,W
    RETFIE
; --------------------------------------------
    END
