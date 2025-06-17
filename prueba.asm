; PIC16F887 Configuration Bit Settings
; Assembly source line config statements
#include "p16f887.inc"

; CONFIG1
; __config 0x28E4
 __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_ON & _LVP_OFF
; CONFIG2
; __config 0x3EFF
 __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF
;----------------------------------------------------------------------------------------------------------------------------------------------
 ;Variables:
 w_temp         EQU 0x7D ;Para guardar contexto
 status_temp    EQU 0x7E
 RESULTADO_ADC  EQU 0x20
 AUX_ADC        EQU 0x21
 AUX_ADC1       EQU 0x22
 COUNT1         EQU 0x23
 BCD_DECENAS    EQU 0x24
 BCD_UNIDADES   EQU 0x25
 TMR0_FLAG      EQU 0x26
 COUNT2         EQU 0x27
   
ORG 0x00
GOTO INICIO
ORG 0x04
GOTO ISR
      


INICIO:
    
    BCF STATUS,RP1 ;Banco 01
    BSF STATUS,RP0
    
    ;MOVLW b'01100000' ;Configuro al 4Mhz
    ;MOVWF OSCCON 
    BSF TRISA,0 ;Defino al AN0 como entrada
    
    CLRF TRISD  ;Defino el Puerto D como salidas
    CLRF TRISE  ;Defino el Puerto E como salida para el multiplexado
    
    MOVLW b'01100000' ;Defino el INTCON habilito el GIE, el PEIE Y eL T0IE
    MOVWF INTCON
    MOVLW b'10000110'
    MOVWF OPTION_REG ;Defino el Preescaler a 1:128
    
    MOVLW b'10000000' ;Defino el resultado a la derecha con Vref+ y Vref-
    MOVWF ADCON1
    
    BSF STATUS,RP1 ;Banco 3
    MOVLW b'00000001'
    MOVWF ANSEL    ;Coloco el AN0 como analogica lo demas como digital, incluido los RE's para el multiplexado
    
    BCF STATUS,RP1 ;Banco 0
    BCF STATUS,RP0
    MOVLW b'11000001' ;Configuro el Adcon0 FRC, ANS0 como entrada y Activo el ADC
    MOVWF ADCON0
    
    
    BCF PIR1,ADIF ;Limpio la Flag del ADC
    
    
    BSF STATUS,RP0 ;Banco 1
    BSF PIE1,ADIE  ;Habilito la interrupcion para el ADC
    
    BCF STATUS,RP0 ;Banco 0
    MOVLW .100
    MOVWF TMR0
    
    MOVLW b'11111111'
    MOVWF PORTA
    CLRF BCD_UNIDADES
    CLRF BCD_DECENAS
    CLRF PORTE
    CLRF PORTD
    CLRW
    BCF STATUS,C 
    BCF STATUS,Z
    BSF INTCON,GIE
    
    
    

    CALL SAMPLE_TIME
    BSF ADCON0,GO

SAMPLE_TIME: ;Delay 12uS
    MOVLW .3
    MOVWF COUNT1
bucle11:
    NOP 
    DECFSZ COUNT1,F 
    GOTO bucle11
    RETURN
    
ISR:
    BANKSEL w_temp
    MOVWF  w_temp      ;Guarda contexto
    SWAPF  STATUS,W          
    MOVWF  status_temp
    
    BTFSC INTCON,T0IF
    GOTO MULTIPLEXADO
    BTFSC PIR1,ADIF
    GOTO ADC
    
    GOTO EXIT_INTERRUPCION


    
MULTIPLEXADO:
   
    
    MOVLW .100
    MOVWF TMR0
    
    BCF PORTE,0
    BSF PORTE,1
    MOVF BCD_DECENAS,W
    CALL TABLA_7SEG
    MOVWF PORTD
    CALL DELAY_5MS
    
    BCF PORTE,1
    BSF PORTE,0
    MOVF BCD_UNIDADES,W
    CALL TABLA_7SEG
    MOVWF PORTD
    
    CALL DELAY_5MS
    BCF INTCON,T0IF
    RETURN

DELAY_5MS:
    BANKSEL TMR0
    MOVLW .216
    MOVWF TMR0
    BANKSEL INTCON
bucle_A:
    BTFSS INTCON,2
    GOTO bucle_A
    RETURN
    
TABLA_7SEG:
    ADDWF PCL, F
    RETLW b'00111111'  ; 0
    RETLW b'00000110'  ; 1
    RETLW b'01011011'  ; 2
    RETLW b'01001111'  ; 3
    RETLW b'01100110'  ; 4
    RETLW b'01101101'  ; 5
    RETLW b'01111101'  ; 6
    RETLW b'00000111'  ; 7
    RETLW b'01111111'  ; 8
    RETLW b'01101111'  ; 9
    
    
ADC: 
    BSF STATUS,RP0
    BCF STATUS,RP1 ;Banco 01
    BCF STATUS,C
    RRF ADRESL,W   ;Roto hacia la derecha los bits
    BCF STATUS,RP0 ;Banco 00
    MOVWF RESULTADO_ADC ;Guardo en Resultado_adc
    MOVWF AUX_ADC1  ;Y ademas en otra variable auxiliar
    CALL DIGITOS   
    BCF PIR1,ADIF   ;Limpio la bandera
    GOTO EXIT_INTERRUPCION

DIGITOS:
    CLRF BCD_DECENAS
    CLRF BCD_UNIDADES ;(QUIZAS TENGAS QUE SACAR ESTO Y SUMARLE UN 1 O ALGO)
    MOVLW .10
bucled:
    SUBWF RESULTADO_ADC,F
    INCF BCD_DECENAS
    BTFSC STATUS,C
    GOTO bucled
    DECF BCD_DECENAS,F
    ADDWF RESULTADO_ADC,W
    MOVWF BCD_UNIDADES
    RETURN
    
    
EXIT_INTERRUPCION:
    SWAPF  status_temp,W	    ; Recupera contexto
    MOVWF  STATUS            
    SWAPF  w_temp,F
    SWAPF  w_temp,W          
    RETFIE			    ; Vuelve de la interrupción

        END