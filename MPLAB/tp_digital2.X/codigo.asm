LIST	p=16f887
    #INCLUDE	<p16f887.inc>

    ; Palabras de configuracion 
    ; CONFIG1
    ; __config 0x3FF5
    __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
    ; CONFIG2
    ; __config 0x3FFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF
;-------------------------------
; Variables externas
;-------------------------------
; Nos indica si estamos esperando un numero y si se ingreso el primer digito
; B0: Nos indica si estamos esperando una tecla- Si = 1 = Esperando - Si = 0 = No Esperando
; B1: Indica si se ingreso el primer digito - Si = 0 = No se ingreso el primer digito - Si = 1 = Se ingreso el primer digito
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
; B0: Bandera de 1 segundo - Si =1 comienza la conversion en ADC - Si =0 no compienza la conversion - Bandera activada por TMR1 cada 1 segundo (FLAG_1SEG)
; B1: Bandera del ADC - Si = 1 el ADC finalizo - Si = 0 el ADC no termino (FLAG_ADC_OK)
; B2: Bandera para Tramistir - Si = 1 Hay que enviar la info por EUSART - Si = 0 no hay que inviar (FLAG_TX)
; B3: Display que se prende - 0 = Display 2 (UNIDAD - RB2) - 1 = Display 1 (DECENA - RB1)
FLAG	    EQU	0X25
	    
; Displays

; Unidad
DIGITO_0    EQU 0X26

; Decena
DIGITO_1    EQU 0X27        

; Contador delay
CONT0 EQU 0X29

CONT1 EQU 0X2A

; Primer digito temporal
DIG1 EQU 0X2B

; Variable temporal para calculos
WREG_TEMP EQU 0X2C

; Variable temporal para calculos
WREG_TEMP2 EQU 0X2D

;Temperatura actual
TEMPACTUAL EQU 0X2E  

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
    CLRF        FLAG
    CLRF        DIGITO_0        
    CLRF        DIGITO_1     

    BANKSEL     TRISD	    ; -- Configuracion de Puertos
    MOVLW       B'11110000' ; RD7-RD4 Entradas (filas), RD3-RD1 Filas (columnas) para teclado
    MOVWF       TRISD
    MOVLW       B'00000001' ; Configura el puerto B: RBO para el pulsador y RB1 -RB2 los habilitadores del display.
    MOVWF       TRISB
    BSF         TRISE,RE0   ; Configura el puerto E: RE0 como entrada analogica para el sensor y RE1 como salida para el LED.
    BCF         TRISE,RE1   
    CLRF        TRISA       ; Configura el puerto A como salida para enviar datos al display.
    BANKSEL     PORTA
    CLRF        PORTD       ; Asegura que columnas inician en 0
    CLRF        PORTB
    CLRF        PORTE
    CLRF        PORTA
    BANKSEL     ANSELH      ; Configura RB0 como entrada digital (no analógica).
    BCF         ANSELH,ANS12
    
    BANKSEL     OSCCON	    ; -- Configura el oscilador interno del microcontrolador a 2 MHz.
    MOVLW       B'01011000'
    MOVWF       OSCCON	    
    
    BANKSEl	ADCON0	    ; -- Configuracion del ADC
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
    MOVWF       T1CON	    ; Inicializa el temporizador TMR1 y lo configura.
    
    BANKSEL     INTCON	    ; -- Configuracion de Interrupciones y TMR0
    MOVLW       B'11110000' ; Habilito GIE - PEIE - T0IE- INTE y limpio bandera INTF
    MOVWF       INTCON 
    CLRF	PIR1	    ; Limpio banderas de ADC - Tx - TRM1iF
    BANKSEL     OPTION_REG
    MOVLW	B'10010100' ; Flanco de bajada para INT - Frecuencia interna para TMR0 - Prescaler para TMR0 - 1:32
    MOVWF	OPTION_REG	
    BANKSEL	PIE1		
    MOVLW       B'01000001' ; Habilito interrupciones por ADC - TMR1
    MOVWF       PIE1            

    BANKSEL     T1CON       ; -- Activo TMR1
    BSF         T1CON,0         
    
    BANKSEL	PORTC
    BCF		TRISC,RC3
    BSF		PORTC,RC3
; --------------------------------------------
MAIN_LOOP:                  ; -- Loop Principal
    BTFSC       INGRESAR,0  ; Si está esperando ingreso de número
    CALL        TECLADO		    ; Llama a la rutina de teclado
    BTFSC       INGRESAR,0      ; Si sigue esperando ingreso, no hace nada más
    GOTO        MAIN_LOOP   
    BTFSC	FLAG,0          ; Si pasó 1 segundo, inicio conversión ADC
    GOTO        INICIAR_ADC     ; Si no pasó 1 segundo, sigue
    MOVF        TEMPREF,W       ; Comparación de temperatura actual con la temperatura de referencia para prender el led
    SUBWF       TEMPACTUAL,W
    BTFSC       STATUS,C	    ; Si TEMPACTUAL >= TEMPREF
    BSF         PORTE,RE1	    ; Enciende LED
    BTFSS       STATUS,C
    BCF         PORTE,RE1
    GOTO        MAIN_LOOP

INICIAR_ADC:    ; Iniciar conversión del ADC
    BCF		FLAG,0
    BANKSEL	ADCON0
    BSF		ADCON0, GO     
    BSF		ADCON0, ADON
    GOTO        MAIN_LOOP
; --------------------------------------------
TECLADO:                    ; Subrutina de Teclado
    BANKSEL     PORTD
    MOVLW       0x0E        ; RD3-RD1 en 1 (columnas), RD7-RD4 entradas (filas)
    IORWF       PORTD, F    ; Asegura columnas en 1
    MOVF        PORTD, W    ; Lee filas
    ANDLW       0xF0        ; Enmascara filas
    BTFSC       STATUS, Z
    GOTO        TECLADO     ; No hay teclas presionadas
    CALL        RETARDO_20ms
    MOVF        PORTD, W
    ANDLW       0xF0
    BTFSC       STATUS, Z
    GOTO        TECLADO     ; No hay teclas presionadas
    CALL        ESCANEAR_TECLAS
    MOVF        INDICE, W
    SUBLW       0x0B        ; Solo índices 0-11 válidos
    BTFSS       STATUS, C
    RETURN                  ; No válido
    MOVF        INDICE, W
    CALL        TECLAS
    MOVWF       WREG_TEMP
    MOVF        WREG_TEMP, W
    XORLW       0xFF
    BTFSC       STATUS, Z
    RETURN      ; Si es 0xFF, no hacer nada
    BTFSS       INGRESAR, 1
    GOTO        TECLADO_PRIMER_DIGITO
    CALL        TECLADO_SEGUNDO_DIGITO
    RETURN
TECLADO_SEGUNDO_DIGITO:
    ; Guardar el segundo dígito (unidad) en el nibble inferior de TEMPREF
    MOVF        TEMPREF, W
    ANDLW       0xF0            ; Mantener nibble superior (decena)
    MOVWF       TEMPREF
    MOVF        WREG_TEMP, W
    IORWF       TEMPREF, F      ; Insertar unidad en nibble inferior
    CALL        ACTUALIZAR_DISPLAY
    BCF         INGRESAR, 0
    BCF         INGRESAR, 1
    RETURN
TECLADO_PRIMER_DIGITO:
    ; Guardar el primer dígito (decena) en el nibble superior de TEMPREF usando SWAP
    MOVF        WREG_TEMP, W
    SWAPF       WREG_TEMP, W    ; Intercambia nibbles
    ANDLW       0xF0            ; Deja solo nibble superior
    MOVWF       TEMPREF         ; TEMPREF = decena << 4, unidad = 0
    BSF         INGRESAR, 1
    GOTO        TECLADO
ESCANEAR_TECLAS:
    CLRF        COL
    MOVLW       0x02            ; RD1 (columna 1)
    MOVWF       COLMASK
SCAN_COL_LOOP:
    MOVLW       0x0E            ; RD3-RD1 en 1
    IORWF       PORTD, F
    COMF        COLMASK, W      ; Columna activa en 0
    ANDLW       0x0E            ; Solo columnas
    IORLW       0xF0            ; Filas en 1
    MOVWF       PORTD
    NOP
    MOVF        PORTD, W
    ANDLW       0xF0
    XORLW       0xF0
    BTFSC       STATUS, Z
    GOTO        NEXT_COL
    MOVF        PORTD, W
    ANDLW       0xF0
    XORLW       0xF0
    MOVWF       WREG_TEMP
    CLRF        INDICE
    MOVLW       0x80            ; RD7 (fila 1)
    MOVWF       WREG_TEMP2
SCAN_ROW_LOOP:
    MOVF        WREG_TEMP, W
    ANDWF       WREG_TEMP2, W
    BTFSS       STATUS, Z
    GOTO        FOUND_ROW
    INCF        INDICE, F
    RRF         WREG_TEMP2, F   ; Siguiente fila (RD7->RD6->RD5->RD4)
    MOVF        WREG_TEMP2, W
    BTFSC       STATUS, Z
    GOTO        NEXT_COL
    GOTO        SCAN_ROW_LOOP
FOUND_ROW:
    ; INDICE = número de fila (0-3)
    ; Calcula índice físico: INDICE = fila*3 + (columna-1)
    MOVF        INDICE, W
    MOVWF       WREG_TEMP2
    RLF         WREG_TEMP2, F   ; *2
    ADDWF       INDICE, W       ; W = fila*3 + fila
    MOVF        COL, W
    ADDWF       WREG_TEMP2, W   ; W = fila*3 + columna
    MOVWF       INDICE
    RETURN
NEXT_COL:
    INCF        COL, F
    MOVLW       0x03
    SUBWF       COL, W
    BTFSS       STATUS, Z
    RLF         COLMASK, F
    GOTO        SCAN_COL_LOOP
    MOVLW       0xFF            ; No se detectó tecla
    MOVWF       INDICE
    RETURN
TECLAS:
    ADDWF       PCL, F
    RETLW       0xFF    ; 0: * (fila 1, col 1)
    RETLW       0x00    ; 1: 0 (fila 1, col 2)
    RETLW       0xFF    ; 2: # (fila 1, col 3)
    RETLW       0x07    ; 3: 7 (fila 2, col 1)
    RETLW       0x08    ; 4: 8 (fila 2, col 2)
    RETLW       0x09    ; 5: 9 (fila 2, col 3)
    RETLW       0x04    ; 6: 4 (fila 3, col 1)
    RETLW       0x05    ; 7: 5 (fila 3, col 2)
    RETLW       0x06    ; 8: 6 (fila 3, col 3)
    RETLW       0x01    ; 9: 1 (fila 4, col 1)
    RETLW       0x02    ; 10: 2 (fila 4, col 2)
    RETLW       0x03    ; 11: 3 (fila 4, col 3)
    ; Eliminado el índice 12, ya que solo hay 12 teclas en 4x3
;----------------------------------------------------------
ACTUALIZAR_DISPLAY: ;Subrutina del display
    MOVF        TEMPACTUAL, W ; o TEMPREF
    MOVWF       WREG_TEMP
    MOVLW       .10
    MOVWF       WREG_TEMP2
    CLRF        DIGITO_1
BUCLE_RESTA:
    SUBWF       WREG_TEMP, W
    BTFSS       STATUS, C
    GOTO        GUARDAR_UNIDAD
    INCF        DIGITO_1, F
    MOVF        WREG_TEMP, W
    SUBWF       WREG_TEMP2, W
    MOVWF       WREG_TEMP
    GOTO        BUCLE_RESTA
GUARDAR_UNIDAD:
    MOVF        WREG_TEMP, W
    MOVWF       DIGITO_0
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
TABLA_7SEG: ;Catodo Comun (hgfedcba) h=dp
    ADDWF       PCL,F
    RETLW       B'00111111' ; 0 
    RETLW       B'00000110' ; 1 
    RETLW       B'01011011' ; 2 01011011
    RETLW       B'01001111' ; 3 01001111
    RETLW       B'01100110' ; 4 01100110
    RETLW       B'01101101' ; 5 01101101
    RETLW       B'01111101' ; 6 01111101
    RETLW       B'00000111' ; 7 00000111
    RETLW       B'01111111' ; 8 01111111
    RETLW       B'01101111' ; 9 01101111
; --------------------------------------------
ISR:                    ; Rutina principal de atención a interrupciones: verifica la fuente y salta a la rutina correspondiente.
    MOVWF       WTEMP       ;Guardo el contexto previo a la interrupcion
    SWAPF       STATUS,W
    MOVWF       STATUST
    BTFSC       INTCON, T0IF  ;Testeo del Timer0
    GOTO        ISR_TMR0   
    BANKSEL     PIR1        ; Testeo de banderas
    BTFSC       INTCON,INTF ; Bandera del Pulsador
    GOTO        ISR_RB0
    BTFSC       PIR1,TMR1IF  ; Bandera del TMR1
    GOTO        ISR_TMR1
    BTFSC       PIR1,ADIF   ; Bandera del ADC
    GOTO        ISR_ADC
    BTFSC       PIR1,TXIF   ;Bandera de Tx
    GOTO        ISR_TRANSMICION 
    GOTO        SALIR
; --------------------------------------------
ISR_TMR0:
    BCF         INTCON, T0IF
    BCF         PORTB, RB1
    BCF         PORTB, RB2
    BTFSC       FLAG,3
    GOTO        MUX_DISPLAY_1
    MOVF        DIGITO_0, W ; Mostrar unidad
    CALL        TABLA_7SEG
    MOVWF       PORTA
    BSF         PORTB, RB2
    BSF         FLAG,3
    GOTO        SALIR
MUX_DISPLAY_1:
    MOVF        DIGITO_1, W
    CALL        TABLA_7SEG
    MOVWF       PORTA
    BSF         PORTB, RB1
    BCF         FLAG,3
    GOTO        SALIR
;----------------------------------------------
ISR_RB0:     ; Atiende la interrupción por el pulsador en RB0 y conmuta la bandera de ingreso.
    BCF         INTCON,INTF
    BANKSEL     INGRESAR
    MOVLW       B'00000001'
    XORWF       INGRESAR,F   ;si estaba en 1 pasa a 0, si estaba en 0 pasa a 1
    GOTO        SALIR
; --------------------------------------------
ISR_TMR1:   ; Atiende la interrupción del temporizador 1 y activa la bandera de 1 segundo.
    BCF         PIR1,TMR1IF
    BANKSEL     PIE1
    BSF         PIE1,TXIE   ; Habilito la transmicion luego de 1 segundo
    BANKSEL     FLAG
    MOVLW       B'00000001'
    XORWF       FLAG,F      ;SE COMPLEMENTA LA BANDERA DE 1 SEGUNDO PARA PRENDER EL ADC
    GOTO        SALIR
; --------------------------------------------
ISR_ADC:    ; Atiende la interrupcion del ADC y limpia la bandera correspondiente.
    BCF         PIR1,ADIF
    BANKSEL     ADRESH
    MOVF        ADRESH, W           ; Leemos solo ADRESH (justificado a la izquierda)
    MOVWF       TEMPACTUAL          ; Guardamos la temperatura
    CALL        ACTUALIZAR_DISPLAY  ; Cada vez que se complete una conversion del ADC se actualizan los displays *(REVISAR POR LAS DUDAS)*
    BSF         FLAG,1
    GOTO        SALIR
; --------------------------------------------
ISR_TRANSMICION:    ; Interrumpe cuando el buffer esta limpio
    BANKSEL     PIR1
    BCF         PIR1,TXIF   ;Limpio la bandera
    BANKSEL     PIE1
    BCF         PIE1,TXIE   ; Deshabilito la interrupcion de transmicion
    BANKSEL     FLAG        ; (REVISAR)
    BCF         FLAG,2
    BANKSEL     TEMPACTUAL      ; -- Proceso de Tx
    MOVF        TEMPACTUAL,W    
    BTFSS       STATUS,Z        ; SI ESTA VACIO NO ENVIO NADA
    MOVWF       TXREG
    GOTO        SALIR
; --------------------------------------------
SALIR:	    ; Restaura el contexto y retorna de la interrupción.
    SWAPF       STATUST,W
    MOVWF       STATUST
    SWAPF       WTEMP,F
    SWAPF       WTEMP,W
    RETFIE
; --------------------------------------------
    END
    RETFIE
; --------------------------------------------
    END
