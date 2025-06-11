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

; primer dígito temporal
DIG1        

; <--- variable temporal para cálculos
WREG_TEMP   

; <--- variable temporal para cálculos
WREG_TEMP2
FLAG_1SEG  ; bandera activada por TMR1 cada 1 segundo
FLAG_ADC_OK ; bandera que indica que el ADC terminó
FLAG_TX ; bandera para indicar que hay que transmitir
ENDC

WTEMP   EQU 0X70
STATUST EQU 0X71

    ;PARTE PRINCIPAL
    ORG     0X0
    GOTO    MAIN
    
    ; DIRECCION DE INTERRUPCIONES
    ORG     0X04
    GOTO    ISR


    ORG 0X05
MAIN:
    CLRF        INGRESAR     ;LIMPIO BANDERA DE INGRESAR NUMERO
    CLRF        TEMPREF

    ;PUERTOS
    BANKSEL     TRISD
    MOVLW       B'11110000' ; RD7-RD4 ENTRADA (filas), RD3-RD0 SALIDA (columnas)
    MOVWF       TRISD
    CLRF        PORTD        ; <--- Asegura que columnas inician en 0

    BANKSEL     TRISB
    MOVLW       B'00000001' ; RB0 ENTRADA DEL PULSADOR - RB1 Y RB2 SALIDAS A LOS Q
    MOVWF       TRISB
    CLRF        PORTB

    BANKSEL     TRISA
    CLRF        TRISA        ; PUERTO A COMO SALIDA PARA DATOS DEL DISPLAY
    CLRF        PORTA

    BANKSEL     ANSELH
    BCF         ANSELH,ANS12 ; RB0 COMO DIGITAL

    ;OSCILADOR INTERNO
    BANKSEL     OSCCON
    MOVLW       B'01011000'  ; OSCILADOR INTERNO DE 2MHz
    MOVWF       OSCCON

    ;ADC

    ;TRANSMICION

    ;TMR1
    BANKSEL     T1CON
    CLRF        TMR1L
    CLRF        TMR1H
    MOVLW       B'00110000'
    MOVWF       T1CON

    ;INTERRUPCIONES
    BANKSEL     INTCON 
    MOVLW       B'11010000' ; HABILITO GIE - PEIE - INTE Y LIMPIO BANDERA INTF
    MOVWF       INTCON 
    BCF         PIR1,ADIF
    BCF         PIR1,TXIF
    BCF         PIR1,TMR1IF
    BANKSEL     OPTION_REG
    BCF         OPTION_REG,INTEDG   ; FLANCO DE BAJADA PARA INT - PULSADOR EN PULL-UP
    MOVLW       B'01010001' ; HABILITO INTERRUPCION POR ADC - TRANSMICION - TMR1
    MOVWF       PIE1

    ;ACTIVADO DEL TMR1
    BANKSEL     T1CON
    BSF         T1CON,0 ; ACTIVO EL TMR1

;LOOP PRINCIPAL
MAIN_LOOP:  
    BTFSC       INGRESAR,0  ;SI ESTA EN 0 NO ESPERO UNA TECLA, SI ESTA EN 1 SI
    CALL        TECLADO
    ;MULTIPLEXADO DISPLAY
    GOTO        MAIN_LOOP

; SUBRUTINA DE TECLADO
TECLADO:
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
	RETURN	                ; no hay teclas presionadas -> vuelvo al MAIN_LOOP --- Si -> voy a escanear las teclas
	CALL        ESCANEAR_TECLAS
	MOVF        INDICE, W
    SUBLW       0x0F	    
	BTFSS       STATUS, C	    ; Indice < = que 15?
	RETURN          	        ; no -> indice no válido
	MOVF        INDICE, W	    ; si -> buscar ASCII en tabla TECLAS
	CALL        TECLAS          ; La tabla TECLAS ya devuelve el valor decimal (0-9)
    MOVWF   WREG_TEMP    ; WREG_TEMP = valor numérico de la tecla
    BTFSS   INGRESAR, 1  ; ¿Ya se ingresó el primer dígito? (usamos INGRESAR,1 como flag)
    GOTO    TECLADO_PRIMER_DIGITO

; Segundo dígito: combinar con el primero y guardar en TEMPREF
TECLADO_SEGUNDO_DIGITO:
    MOVF    DIG1, W
    MOVWF   TEMPREF
    RLF     TEMPREF, F   ; TEMPREF = DIG1 * 2
    RLF     TEMPREF, F   ; TEMPREF = DIG1 * 4
    RLF     TEMPREF, F   ; TEMPREF = DIG1 * 8
    RLF     TEMPREF, F   ; TEMPREF = DIG1 * 16
    ; Ahora TEMPREF = DIG1 * 16, pero queremos *10, así que sumamos (DIG1*8 + DIG1*2)
    MOVF    DIG1, W
    ADDWF   TEMPREF, F   ; TEMPREF += DIG1 (ahora *17)
    ADDWF   TEMPREF, F   ; TEMPREF += DIG1 (ahora *18)
    ; Ahora TEMPREF = DIG1*18, pero queremos *10, así que restamos DIG1*8
    MOVF    DIG1, W
    MOVWF   WREG_TEMP2
    RLF     WREG_TEMP2, F   ; WREG_TEMP2 = DIG1*2
    RLF     WREG_TEMP2, F   ; WREG_TEMP2 = DIG1*4
    RLF     WREG_TEMP2, F   ; WREG_TEMP2 = DIG1*8
    SUBWF   TEMPREF, F      ; TEMPREF = (DIG1*18) - (DIG1*8) = DIG1*10
    ; Ahora sumamos el segundo dígito
    MOVF    WREG_TEMP, W
    ADDWF   TEMPREF, F

    ; Limpiamos la bandera de INGRESAR para terminar la carga
    BCF     INGRESAR, 0
    BCF     INGRESAR, 1
    RETURN

; Guardar primer dígito y setear flag para esperar el segundo
TECLADO_PRIMER_DIGITO:
    MOVF    WREG_TEMP, W
    MOVWF   DIG1
    BSF     INGRESAR, 1   ; Seteamos flag de primer dígito ingresado
    RETURN

; ESCANEAR_TECLAS
ESCANEAR_TECLAS:
    CLRF    COL	        ; col 1
    MOVLW   0x01	    ; RD0 activa (columna 1)
    MOVWF   COLMASK	    ; en alto
ESCANEAR_FILAS:		    ; detectar fila
    MOVF    COLMASK, W
    MOVWF   PORTD        ; activa una columna a la vez
    NOP                 ; pequeño retardo para estabilizar
    NOP
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

;RUTINA DE RB0
ISR_RB0
    BCF     INTCON,INTF
    COMF    INGRESAR,F  ;SETTEO EL BIT 0
    GOTO    SALIR

;RUTINA DEL TMR1
ISR_TMR1:
    BCF     PIR1,TMR1F
    BSF     FLAG_1SEG,0
    GOTO    SALIR

;RUTINA DE INTERRUPCION ADC
ISR_ADC:
    NOP
    BCF     PIR1,ADIF   
    GOTO    SALIR

;RUTINA DE INTERRUPCION RECEPCION EUSART
ISR_TRANSMICION:
    NOP
    BCF     PIR1,TXIF
    GOTO    SALIR

;RECUPERACION DE CONTEXTO, LIMPIEZA DE BANDERA Y SALIDA
SALIR:    
    SWAPF   STATUST,W
    MOVWF   STATUST
    SWAPF   WTEMP,F
    SWAPF   WTEMP,W
    RETFIE
    
    END
