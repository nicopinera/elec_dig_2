    LIST	p=16f887
    #INCLUDE	<p16f887.inc>

    ; Variables externas
    
    ORG 0X0
    GOTO    MAIN
    
    ORG 0X04
    GOTO    IRS
    
MAIN
    GOTO    $
    
    
; Seccion de interrupciones
IRS
    GOTO MAIN

    
    
    END