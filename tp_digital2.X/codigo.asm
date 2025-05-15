    LIST	p=16f887
    #INCLUDE	<p16f887.inc>

    ; Variables externas
CONT    EQU 0x20
    ORG 0X0
    GOTO    MAIN
    
    ORG 0X04
    GOTO    IRS
    
MAIN
    MOVLW   .20
    MOVWF   CONT
    GOTO    $
    
    
; Seccion de interrupciones
IRS
    GOTO MAIN

    
    
    END