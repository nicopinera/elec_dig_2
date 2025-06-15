LIST	p=16f887
    #INCLUDE	<p16f887.inc>

    ; Variables externas
CBLOCK 0X20
; Nos indica si estamos esperando un numero y si se ingreso el primer digito
; B0 = 1 = Esperando - B0 = 0 = No Esperando
; B1 = 0 = No se ingreso el primer digito - B1 = 1 = Se ingreso el primer digito
INGRESAR

;Temperatura de Referencia
TEMPREF

;Indice de tecla pulsada (0?15)
INDICE    

;en que columna estoy (1-4)
COL   

; Mascara de columna
COLMASK    

; Displays
DIGITO_0        ; Unidad
DIGITO_1        ; Decena
DISPLAY_FLAG    ; Alterna entre display 0 y 1

; Contador delay
CONT0       
CONT1 
DIG1        ; Primer dígito temporal
WREG_TEMP   ; Variable temporal para cálculos
WREG_TEMP2  ; Variable temporal para cálulos
FLAG_1SEG   ; Bandera activada por TMR1 cada 1 segundo
FLAG_ADC_OK ; Bandera que indica que el ADC terminó
FLAG_TX     ; Bandera para indicar que hay que transmitir
TEMPACTUAL  ;Temperatura actual
ENDC

; Para guardar contexto
WTEMP   EQU 0X70
STATUST EQU 0X71
; --------------------------------------------
    ORG     0X0
    GOTO    MAIN    ;Parte principal
    ; El programa comienza en la dirección 0 y salta a la rutina principal MAIN.
; --------------------------------------------
    ORG     0X04
    GOTO    ISR     ; Direccion de interrupciones
    ; Si ocurre una interrupción, el programa salta a la rutina ISR.
; --------------------------------------------
    ORG 0X05
MAIN:
    CLRF        INGRESAR
    CLRF        TEMPREF
    CLRF        FLAG_1SEG
    CLRF        FLAG_ADC_OK
    CLRF        FLAG_TX
    CLRF        DIGITO_0        
    CLRF        DIGITO_1     
    CLRF        DISPLAY_FLAG
    ; Se inicializan todas las banderas y variables de control en cero.

    ;Configuracion de Puertos
    BANKSEL     TRISD
    MOVLW       B'11110000' ; RD7-RD4 Entradas (filas), RD3-RD0 Filas (columnas)
    MOVWF       TRISD
    CLRF        TRISC       ; Display segmentos como salida
    MOVLW       B'00000001' ; Configura el puerto B: RBO para el pulsador y RB1 -RB2 los habilitadores del display.
    MOVWF       TRISB
    BSF         TRISE,RE0   
    BCF         TRISE,RE1   ; Configura el puerto E: RE0 como entrada analógica para el sensor y RE1 como salida para el LED.
    CLRF        TRISA       ; Configura el puerto A como salida para enviar datos al display.
    BANKSEL     PORTA
    CLRF        PORTD        ; Asegura que columnas inician en 0
    CLRF        PORTB
    CLRF        PORTE
    CLRF        PORTA
    BANKSEL     ANSELH      ; Configura RB0 como entrada digital (no analógica).
    BCF         ANSELH,ANS12
    
    ;Configuracion de Oscilador Interno
    BANKSEL     OSCCON
    MOVLW       B'01011000'
    MOVWF       OSCCON
    ; Configura el oscilador interno del microcontrolador a 2 MHz.
;-------------------------------------------------------------------
    ;---------CONFIGURACION ADC--------------
    BANKSEL ADCON0
    MOVLW   B'00010101'   ; Canal AN5 (RE0), ADC off por ahora
    MOVWF   ADCON0
    BANKSEL ADCON1
    MOVLW   B'00000000'   ; Justificado a la izquierda, Vref = VDD-VSS
    MOVWF   ADCON1

    ;----------CONFIGURACION TRANSMISION----------
    BANKSEL TXSTA
    MOVLW   B'00100100'   ; TXEN=1, BRGH=1 (alta velocidad)
    MOVWF   TXSTA

    BANKSEL RCSTA
    MOVLW   B'10000000'   ; SPEN=1 habilita transmisor
    MOVWF   RCSTA

    BANKSEL SPBRG
    MOVLW   .12          ; Baud Rate 9600 con Fosc = 2MHz (BRGH=1): SPBRG=12
    MOVWF   SPBRG
;--------------------------------------------------------------
    ;Timer 0
    BANKSEL OPTION_REG
    MOVLW   B'00000111'         ; TMR0 con prescaler 1:256
    MOVWF   OPTION_REG
    CLRF    TMR0

    ;Timer 1
    BANKSEL     T1CON
    CLRF        TMR1L
    CLRF        TMR1H
    MOVLW       B'00110000'
    MOVWF       T1CON            ; Inicializa el temporizador TMR1 y lo configura.

    ;Configuracion de Interrupciones
    BANKSEL     INTCON 
    MOVLW       B'11110000'         ; Habilito GIE - PEIE - T0IE- INTE y limpio bandera INTF
    MOVWF       INTCON 
    BCF         PIR1,ADIF
    BCF         PIR1,TXIF
    BCF         PIR1,TMR1IF
    BANKSEL     OPTION_REG
    BCF         OPTION_REG,INTEDG   ; Flanco de Bajada para INT, el pulsador esta en 1 siempre
    MOVLW       B'01010001'         ; Habilito interrupciones por ADC - TX - TMR1
    MOVWF       PIE1                ; Habilita las interrupciones globales y periféricas, y configura las fuentes de interrupción.

    ;Activo TMR1
    BANKSEL     T1CON
    BSF         T1CON,0             
; --------------------------------------------
MAIN_LOOP:                          ; Loop Principal
    BTFSC       INGRESAR,0          ; Si esta en 0 no espero una tecla
    CALL        TECLADO             ; Si se está esperando el ingreso de un número, llama a la rutina de teclado.
 
    MOVF        TEMPREF,W           ; Compara la temperatura actual con la de referencia y enciende el LED si corresponde.
    SUBWF       TEMPACTUAL,W
    BTFSC       STATUS,Z
    BSF         PORTE,RE1           ; Prendo el led si la temperatura es mayor

    ;---ADC---------
    ; Si pasó 1 segundo, inicio conversión
    BTFSS   FLAG_1SEG, 0
    GOTO    CHECK_ADC_OK
    BCF     FLAG_1SEG, 0
    BANKSEL ADCON0
    BSF     ADCON0, GO     ; Iniciar conversión ADC
    BSF     ADCON0, ADON
    GOTO    CHECK_ADC_OK

CHECK_ADC_OK:
    BTFSS   FLAG_ADC_OK, 0
    GOTO    CHECK_TX
    BCF     FLAG_ADC_OK, 0
    BSF     FLAG_TX, 0     ; Listo para enviar por UART

CHECK_TX:
    BTFSS   FLAG_TX, 0
    GOTO    FIN_LOOP

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
    GOTO    SEND_DIGITS
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
    
    GOTO        MAIN_LOOP           ; Vuelve al inicio del loop principal.
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
; --------------------------------------------
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
; ESCANEAR_TECLAS: Escanea el teclado 4x4 y devuelve en INDICE el índice físico (0-15)
; Si no hay tecla válida, INDICE = 0xFF
;-----------------------------------------------------------
ESCANEAR_TECLAS:
    CLRF    COL             ; Inicializa columna en 0
    MOVLW   0x01
    MOVWF   COLMASK         ; Máscara para seleccionar columna (empieza en RD0)
SCAN_COL_LOOP:
    MOVLW   0x0F            ; Todas las columnas en 1
    MOVWF   PORTD
    COMF    COLMASK, W      ; Invierte máscara: columna activa en 0
    ANDLW   0x0F            ; Solo columnas (RD3-RD0)
    IORLW   0xF0            ; Mantiene filas (RD7-RD4) en 1
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
    MOVLW   0x01
    MOVWF   WREG_TEMP2      ; WREG_TEMP2 = máscara de fila a chequear

SCAN_ROW_LOOP:
    MOVF    WREG_TEMP, W
    ANDWF   WREG_TEMP2, W
    BTFSS   STATUS, Z
    GOTO    FOUND_ROW       ; Si bit de fila está en 1, es la fila activa
    INCF    INDICE, F
    RLF     WREG_TEMP2, F   ; Siguiente bit de fila
    MOVLW   0x10
    SUBWF   WREG_TEMP2, W
    BTFSS   STATUS, C
    GOTO    NEXT_COL        ; Si ya chequeó las 4 filas, pasa a la siguiente columna
    GOTO    SCAN_ROW_LOOP

FOUND_ROW:
    ; INDICE = número de fila (0-3)
    ; Calcula índice físico: INDICE = fila*4 + columna
    MOVF    INDICE, W
    MOVWF   WREG_TEMP2
    RLF     WREG_TEMP2, F   ; *2
    RLF     WREG_TEMP2, F   ; *4
    MOVF    COL, W
    ADDWF   WREG_TEMP2, W   ; W = fila*4 + columna
    MOVWF   INDICE          ; Guarda índice físico en INDICE
    RETURN

NEXT_COL:
    INCF    COL, F
    MOVLW   0x04
    SUBWF   COL, W
    BTFSS   STATUS, Z       ; ¿Ya se probaron las 4 columnas?
    RLF     COLMASK, F      ; Siguiente columna (RD0->RD1->RD2->RD3)
    GOTO    SCAN_COL_LOOP
    MOVLW   0xFF            ; No se detectó tecla
    MOVWF   INDICE
    RETURN

;-----------------------------------------------------------
; TECLAS: Traduce el índice físico (0-15) a valor numérico (0-9)
; Si no es un número, devuelve 0xFF
;-----------------------------------------------------------
TECLAS:
    ADDWF   PCL, F
    RETLW   0xFF    ; 0: *
    RETLW   0x00    ; 1: 0
    RETLW   0xFF    ; 2: #
    RETLW   0xFF    ; 3: D
    RETLW   0x07    ; 4: 7
    RETLW   0x08    ; 5: 8
    RETLW   0x09    ; 6: 9
    RETLW   0xFF    ; 7: C
    RETLW   0x04    ; 8: 4
    RETLW   0x05    ; 9: 5
    RETLW   0x06    ; 10: 6
    RETLW   0xFF    ; 11: B
    RETLW   0x01    ; 12: 1
    RETLW   0x02    ; 13: 2
    RETLW   0x03    ; 14: 3
    RETLW   0xFF    ; 15: A

;----------------------------------------------------------
Subrutina del display
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
    BTFSC   PIR1,TMR1F  ; Bandera del TMR1
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
    MOVLW   0X01
    XORWF   INGRESAR,INGRESAR   ;si estaba en 1 pasa a 0, si estaba en 0 pasa a 1
    GOTO    SALIR
; --------------------------------------------
ISR_TMR1:   ; Atiende la interrupción del temporizador 1 y activa la bandera de 1 segundo.
    BCF     PIR1,TMR1F
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
