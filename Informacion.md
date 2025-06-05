# Flujo del programa

## MAIN
Tendremos una variable (INGRESAR - bit 0) que nos indicara si se esta por ingresar una tecla, la cual limpiaremos al principio del programa.
Luego utilizaremos el PORTD para la lectura del teclado.
El pin RB0 tiene que estar configurado como entrada digital (ademas como Interrupcion general del PIC).
El PORTD sera seteado como salida para utilizarlo como bus de datos a los displays y el PORTB (RB1 y RB2) sera utilizado para la multiplexacion de los dos O SEA COMO SALIDAS
Configuracion del Oscilador interno para bajar la frecuencia de intstrucion y poder contar 1 [s] con el TMR1
Configuramos el ADC y el modulo UART
Congiguramos el TMR1 y realizamos su limpieza para que interrumpa cada 1 [s] y avisarnos para realizar la transmicion
Configuramos el pin RB3 para que sea el que encienda el led que nos indica cuando la temperatura pasa cierto nivel.
configuraciones del registro INTCON - PIE1 - OPTION_REG

## MAIN_LOPP

## ISR



# Tareas a Realizar

## 1. Codificación

- [ ] Inicialización de puertos (entrada/salida según periférico)
- [ ] Configuración y uso del ADC para leer el LM35
- [ ] Conversión del valor ADC a temperatura en °C
- [ ] Implementación del teclado matricial (lectura y decodificación)
- [ ] Manejo del pulsador para activar/desactivar carga de referencia
- [ ] Multiplexación y control de displays de 7 segmentos
- [ ] Comparación de temperatura actual con referencia y control del LED
- [ ] Configuración y uso de UART para envío serial de temperatura
- [ ] Implementación de temporizador (Timer) para temporización de envío UART
- [ ] Manejo de banderas (flags) para comunicación entre ISR y main_loop

## 2. Configuración de módulos y puertos

- [ ] Configurar puertos analógicos/digitales (ANSEL, TRISx)
- [ ] Configurar ADC (canal, justificación, reloj, etc.)
- [ ] Configurar puertos para teclado matricial (filas/columnas)
- [ ] Configurar puertos para displays (segmentos y dígitos)
- [ ] Configurar puerto para LED indicador
- [ ] Configurar UART (baud rate, bits, sin paridad)
- [ ] Configurar Timer (para ISR de 1 segundo)
- [ ] Configurar interrupciones (Timer, INT/RBIF para pulsador)

## 3. Estructura del main_loop principal

- [ ] Esperar flag de carga de referencia (pulsador)
- [ ] Leer teclado y armar valor de referencia
- [ ] Leer LM35 por ADC periódicamente
- [ ] Convertir valor ADC a temperatura
- [ ] Mostrar temperatura en display multiplexado
- [ ] Comparar temperatura actual con referencia y controlar LED
- [ ] Si flag de envío UART está activo, enviar temperatura y limpiar flag

## 4. ISR necesarias

- [ ] ISR de Timer (cada 1 segundo): setear flag para envío UART
- [ ] ISR de pulsador (INT/RBIF): setear flag para activar/desactivar carga de referencia

## 5. Partes del diagrama de flujo a realizar

- [ ] Inicialización de módulos y variables
- [ ] Espera de pulsador para carga de referencia
- [ ] Rutina de ingreso de referencia por teclado
- [ ] Bucle principal:
    - Lectura de temperatura
    - Conversión y visualización
    - Comparación y control de LED
    - Envío por UART (si corresponde)

## 6. Implementación en Proteus

- [ ] Montar el microcontrolador PIC16F887
- [ ] Conectar sensor LM35 al canal AN0
- [ ] Conectar teclado matricial a los puertos definidos
- [ ] Conectar displays de 7 segmentos (2 o 3 dígitos) a los puertos definidos
- [ ] Conectar LED indicador a la salida correspondiente
- [ ] Conectar pulsador a la entrada correspondiente
- [ ] Conectar módulo UART a un virtual terminal (RS232-TTL)
- [ ] Alimentación y conexiones de masa

---

# Clases:
* Clase teórica sobre AD: https://drive.google.com/file/d/1m0CuEAg5N_XGyQn5EkkpFoGVpFZBmOWu/view
* Clase Teórica sobre comunicación: https://drive.google.com/file/d/1-OzEk3Gd9JGqM7VAiljeCQ1kqgmKCDBX/view

--- 

## Extra: 
División por bloques
1. Lectura de temperatura (ADC + LM35): Canal AN0 (RA0) conectado al LM35. ADC configurado a 10 bits. Convertir el valor leído a °C:
2. Ingreso de temperatura de referencia: Teclado matricial 4x4 conectado a PORTB y PORTD. Pulsador en otra entrada (ej. RA1) para indicar: Presionado 1ra vez: comienza ingreso. Presionado 2da vez: guarda temperatura. Digitos ingresados se muestran en display y se guardan en una variable temp_ref.
3. Display de 7 segmentos multiplexado (3 dígitos): Segmentos conectados a PORTC. Dígitos controlados por PORTA o PORTD. Refrescar en bucle con retardo corto (~5–10 ms).
4. UART (TX por RC6): Configurar EUSART en modo asincrónico. 9600 baudios, 8 bits, sin paridad. Enviar string con temperatura cada 1 segundo, por ejemplo: "Temp: 27°C\r\n"
5. Comparador con LED: Comparar temp_actual con temp_ref. Si temp_actual > temp_ref, encender LED (ej. en RA2).

---

⚙️ Flujo del programa principal

Inicio
│
├─ Inicializar módulos (ADC, UART, puertos, teclado, display)
│
├─ Esperar pulsador para carga de temperatura referencia
│   └─ Leer teclado y armar valor de 2 o 3 dígitos
│   └─ Guardar valor en variable temp_ref
│
└─ Bucle principal:
    ├─ Leer LM35 por ADC
    ├─ Convertir a °C y guardar en temp_actual
    ├─ Mostrar en display multiplexado
    ├─ Enviar valor por UART cada 1 segundo
    └─ Si temp_actual > temp_ref, encender LED

---

Excelente pregunta. Una buena división entre interrupciones y ciclo principal (main_loop) hace tu código más ordenado, eficiente y fácil de mantener.

🧠 Criterio general

Por interrupciones: tareas críticas de tiempo o eventos esporádicos, que no deberían depender del polling del main_loop. En el main_loop: tareas que pueden ejecutarse en forma continua, y que pueden tolerar cierto retardo o ejecución repetitiva.

---

🛎️ Interrupciones recomendadas

✅ 1. Timer (Timer1 o Timer0)

Para: generar interrupción cada 1 segundo
Uso: enviar temperatura por UART
Motivo: evita usar retardos largos en el loop

; En ISR
    bsf FLAG_ENVIO_UART  ; setea flag para que el main envíe por UART

---

✅ 2. Interrupción por cambio (RBIF) o externa (INT)

Para: detectar el pulsador que inicia o finaliza la carga por teclado.
Motivo: evita tener que escanear el pulsador todo el tiempo en el loop.

; En ISR
    btfss BOTON, 0
    goto CONTINUAR
    bsf FLAG_CARGA_TREF

---

🔁 Tareas en el main_loop

🔹 1. Lectura del LM35: Hacer polling periódico del ADC. Lo ideal: leerlo ~10 veces por segundo o menos.

🔹 2. Escaneo de teclado (cuando está activo): Escanear columnas y filas solo cuando el flag de carga de temperatura esté activo.

🔹 3. Conversión ADC a temperatura: División por constantes (puede hacerse en polling).

🔹 4. Mostrar en display 7 segmentos: Actualización rápida y constante (cada ~5ms). Ciclar entre los 3 dígitos en el main.

🔹 5. Comparar con temperatura de referencia: Se hace después de cada lectura de temperatura.

🔹 6. Enviar por UART (si flag está activo): En el main: si FLAG_ENVIO_UART = 1, hacer el envío y limpiar el flag.

🧱 Resumen de división

Tarea	¿Dónde se hace?	Motivo

Envío periódico por UART	Interrupción (Timer)	Preciso y no bloqueante
Lectura de LM35 (ADC)	main_loop	Repetitivo y no urgente
Carga de temperatura por teclado	main_loop	Solo cuando está activo
Activación del modo carga	Interrupción (INT/RBIF)	Evento externo poco frecuente
Visualización en display	main_loop	Refresco rápido necesario
Comparación con temp. referencia	main_loop	Luego de cada lectura ADC


