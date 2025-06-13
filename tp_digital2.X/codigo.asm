LIST	p=16f887
    #INCLUDE	<p16f887.inc>

    ; Variables externas
CBLOCK 0X20
;VARIABLE QUE NOS DICE SI ESTAMOS ESPERANDO UN NUMERO -- B0 = 1 = ESPERANDO - B0 = 0 = NO ESPERANDO
INGRESAR

;TEMPERATURA DE REFERENCIA
TEMPREF

;Indice de tecla pulsada (0?15)
INDICE    

;en que columna estoy (1-4)
COL   

; Mascara de columna
COLMASK    

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

WTEMP   EQU 0X70
STATUST EQU 0X71

    ORG     0X0
    GOTO    MAIN    ;Parte principal
    ; El programa comienza en la dirección 0 y salta a la rutina principal MAIN.
    
    ORG     0X04
    GOTO    ISR     ; Direccion de interrupciones
    ; Si ocurre una interrupción, el programa salta a la rutina ISR.

    ORG 0X05
MAIN:
    CLRF        INGRESAR     ;LIMPIO BANDERA DE INGRESAR NUMERO
    CLRF        TEMPREF
    CLRF        FLAG_1SEG
    CLRF        FLAG_ADC_OK
    CLRF        FLAG_TX
    ; Se inicializan todas las banderas y variables de control en cero.

    ;PUERTOS
    BANKSEL     TRISD
    MOVLW       B'11110000' ; RD7-RD4 Entradas (filas), RD3-RD0 Filas (columnas)
    MOVWF       TRISD
    CLRF        PORTD        ; Asegura que columnas inician en 0
    ; Configura el puerto D para el teclado matricial: las filas como entradas y las columnas como salidas.

    BANKSEL     TRISB
    MOVLW       B'00000001' ; RB0 Entrada del pulsador - RB1 y RB2 habilitadores de display
    MOVWF       TRISB
    CLRF        PORTB
    ; Configura el puerto B para el pulsador y los habilitadores del display.

    BANKSEL     TRISE
    BSF         TRISE,RE0   ;RE0 Entrada analogica AN5 - donde entra la señal del sensor
    BCF         TRISE,RE1   ;RE1 Salida del led si esta pasando la temperatura de referencia
    CLRF        PORTE
    ; Configura el puerto E: RE0 como entrada analógica para el sensor y RE1 como salida para el LED.

    BANKSEL     TRISA
    CLRF        TRISA        ; PORTA como bus de datos para display
    CLRF        PORTA
    ; Configura el puerto A como salida para enviar datos al display.

    BANKSEL     ANSELH
    BCF         ANSELH,ANS12 ; RB0 como entrada digital
    ; Configura RB0 como entrada digital (no analógica).

    ;OSCILADOR INTERNO
    BANKSEL     OSCCON
    MOVLW       B'01011000'  ; Oscilador interno de 2[MHz]
    MOVWF       OSCCON
    ; Configura el oscilador interno del microcontrolador a 2 MHz.

    ;ADC
    ; Aquí se debe agregar la configuración del ADC si se utiliza.

    ;TRANSMICION
    ; Aquí se debe agregar la configuración de la transmisión si se utiliza.

    ;TMR1
    BANKSEL     T1CON
    CLRF        TMR1L
    CLRF        TMR1H
    MOVLW       B'00110000'
    MOVWF       T1CON
    ; Inicializa el temporizador TMR1 y lo configura.

    ;INTERRUPCIONES
    BANKSEL     INTCON 
    MOVLW       B'11010000'         ; Habilito GIE - PEIE - INTE y limpio bandera INTF
    MOVWF       INTCON 
    BCF         PIR1,ADIF
    BCF         PIR1,TXIF
    BCF         PIR1,TMR1IF
    BANKSEL     OPTION_REG
    BCF         OPTION_REG,INTEDG   ; FLANCO DE BAJADA PARA INT - PULSADOR EN PULL-UP
    MOVLW       B'01010001'         ; HABILITO INTERRUPCION POR ADC - TRANSMICION - TMR1
    MOVWF       PIE1
    ; Habilita las interrupciones globales y periféricas, y configura las fuentes de interrupción.

    ;ACTIVADO DEL TMR1
    BANKSEL     T1CON
    BSF         T1CON,0             ; ACTIVO EL TMR1
    ; Activa el temporizador TMR1.

MAIN_LOOP:                          ; LOOP PRINCIPAL
    BTFSC       INGRESAR,0          ;SI ESTA EN 0 NO ESPERO UNA TECLA, SI ESTA EN 1 SI
    CALL        TECLADO
    ; Si se está esperando el ingreso de un número, llama a la rutina de teclado.

    ;MULTIPLEXADO DISPLAY
    ; Aquí se debe agregar el código para multiplexar el display.

    ;Comparacion de temperatura actual con la temperatura de referencia para prender el led
    MOVF        TEMPREF,W
    SUBWF       TEMPACTUAL,W
    BTFSC       STATUS,Z
    BSF         PORTE,RE1           ;Prendo el led si la temperatura es mayor
    ; Compara la temperatura actual con la de referencia y enciende el LED si corresponde.

    GOTO        MAIN_LOOP
    ; Vuelve al inicio del loop principal.

TECLADO:                    ; SUBRUTINA DE TECLADO
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
	RETURN          	        ; no -> indice no válido
	MOVF        INDICE, W	    ; si -> buscar valor en tabla TECLAS
	CALL        TECLAS          ; La tabla TECLAS ya devuelve el valor decimal (0-9)
    MOVWF       WREG_TEMP       ; WREG_TEMP = valor numérico de la tecla

    BTFSS       INGRESAR, 1     ; ¿Ya se ingresó el primer dígito? (usamos INGRESAR,1 como flag)
    ; Si NO se ingresó el primer dígito, lo guardo como decena y retorno
    GOTO        TECLADO_PRIMER_DIGITO
    ; Si YA se ingresó el primer dígito, este es el segundo (unidad)
    ; Combinar decena y unidad

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

    ; Limpiamos la bandera de INGRESAR para terminar la carga
    BCF     INGRESAR, 0
    BCF     INGRESAR, 1
    RETURN
    ; Cuando se ingresa el segundo dígito, se calcula el valor final y se limpia la bandera de ingreso.

TECLADO_PRIMER_DIGITO:
    MOVF    WREG_TEMP, W
    MOVWF   DIG1
    BSF     INGRESAR, 1   ; Seteamos flag de primer dígito ingresado
    GOTO	TECLADO
    ; Cuando se ingresa el primer dígito, se guarda como decena y se activa la bandera para esperar el segundo dígito.

ESCANEAR_TECLAS:        ; ESCANEAR TECLAS
    CLRF    COL	        ; col 1
    MOVLW   0x01	    ; RD0 activa (columna 1)
    MOVWF   COLMASK	    ; en alto
ESCANEAR_FILAS:		    ; detectar fila
    MOVF    COLMASK, W
    MOVWF   PORTD       ; activa una columna a la vez
    MOVF    PORTD, W
    ANDLW   0xF0        ; enmascara filas
    BTFSS   STATUS, Z
    GOTO    DETECTA_FILA
    INCF    COL, F
    RLF     COLMASK, F  ; siguiente columna (RD0->RD1->RD2->RD3)
    MOVLW   0x04
    SUBWF   COL, W
    BTFSS   STATUS, Z   ; ¿todas las columnas?
    GOTO    ESCANEAR_FILAS
    MOVLW   0xFF        ; no se detectó tecla
    MOVWF   INDICE
    RETURN
    ; Escanea el teclado matricial activando una columna a la vez y detectando si alguna fila está activa.

; Busca cuál fila está activa
DETECTA_FILA:
    MOVF    PORTD, W
    ANDLW   0xF0
    SWAPF   WREG, W     ; filas ahora en bits bajos
    MOVWF   WREG_TEMP
    CLRF    INDICE
    MOVLW   0x10
    BTFSS   WREG_TEMP, 4
    GOTO    F1
    INCF    INDICE, F
F1:
    MOVLW   0x20
    BTFSS   WREG_TEMP, 5
    GOTO    F2
    INCF    INDICE, F
F2:
    MOVLW   0x40
    BTFSS   WREG_TEMP, 6
    GOTO    F3
    INCF    INDICE, F
F3:
    MOVLW   0x80
    BTFSS   WREG_TEMP, 7
    GOTO    F4
    INCF    INDICE, F
F4:
    ; INDICE = fila (0-3)
    ; Ahora calcula el índice final: INDICE = fila + (columna*4)
    MOVF    COL, W
    MOVWF   WREG_TEMP
    RLF     WREG_TEMP, F   ; *2
    RLF     WREG_TEMP, F   ; *4
    ADDWF   INDICE, F
    ; Si el índice es mayor a 9, no es válido
    MOVF    INDICE, W
    SUBLW   0x09
    BTFSS   STATUS, C
    MOVLW   0xFF
    MOVWF   INDICE
    RETURN
    ; Determina qué fila está activa y calcula el índice de la tecla presionada.

;TABLA DE TECLAS (devuelve valor decimal 0-9)
TECLAS:
    ADDWF   PCL, F
    RETLW   0x00    ; 0
    RETLW   0x01    ; 1
    RETLW   0x02    ; 2
    RETLW   0x03    ; 3
    RETLW   0x04    ; 4
    RETLW   0x05    ; 5
    RETLW   0x06    ; 6
    RETLW   0x07    ; 7
    RETLW   0x08    ; 8
    RETLW   0x09    ; 9
    ; Esta tabla traduce el índice de la tecla presionada al valor decimal correspondiente.

;RUTINAS DE RETARDO
RETARDO_20ms:
    MOVLW 0x14
    MOVWF CONT1
RETARDO1:
    MOVLW 0xFA
    MOVWF CONT0
RETARDO2:
    NOP
    DECFSZ CONT0, 1
    GOTO RETARDO2
    DECFSZ CONT1, 1
    GOTO RETARDO1
    RETURN
    ; Rutina de retardo aproximado de 20 ms usando bucles anidados.

; RUTINA DE SERVICIO A LA INTERRUPCION
ISR:    
    ;GUARDADO DE CONTEXTO
    MOVWF   WTEMP
    SWAPF   STATUS,W
    MOVWF   STATUST

    BANKSEL PIR1
    BTFSC   INTCON,INTF
    GOTO    ISR_RB0
    BTFSC   PIR1,TMR1F
    GOTO    ISR_TMR1
    ;TESTEO DE BANDERAS LEVANTADAS
    BTFSC   PIR1,ADIF   ;BANDERA DEL ADC
    GOTO    ISR_ADC
    BTFSC   PIR1,TXIF   ;BANDERA DE TRANSMICION MODULO EUSART
    GOTO    ISR_TRANSMICION 
    GOTO    SALIR
    ; Rutina principal de atención a interrupciones: verifica la fuente y salta a la rutina correspondiente.

;RUTINA DE RB0
ISR_RB0
    BCF     INTCON,INTF
    COMF    INGRESAR,F  ;SETTEO EL BIT 0
    GOTO    SALIR
    ; Atiende la interrupción por el pulsador en RB0 y conmuta la bandera de ingreso.

;RUTINA DEL TMR1
ISR_TMR1:
    BCF     PIR1,TMR1F
    BSF     FLAG_1SEG,0
    GOTO    SALIR
    ; Atiende la interrupción del temporizador 1 y activa la bandera de 1 segundo.

;RUTINA DE INTERRUPCION ADC
ISR_ADC:
    NOP
    BCF     PIR1,ADIF   
    GOTO    SALIR
    ; Atiende la interrupción del ADC y limpia la bandera correspondiente.

;RUTINA DE INTERRUPCION RECEPCION EUSART
ISR_TRANSMICION:
    NOP
    BCF     PIR1,TXIF
    GOTO    SALIR
    ; Atiende la interrupción de transmisión y limpia la bandera correspondiente.

;RECUPERACION DE CONTEXTO, LIMPIEZA DE BANDERA Y SALIDA
SALIR:    
    SWAPF   STATUST,W
    MOVWF   STATUST
    SWAPF   WTEMP,F
    SWAPF   WTEMP,W
    RETFIE
    ; Restaura el contexto y retorna de la interrupción.
    
    END
