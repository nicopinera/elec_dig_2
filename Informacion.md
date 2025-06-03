# Cuestiones a tener en cuenta:
El trabajo debe contar con el uso del modulo ADC, el de transmisión en serie, display y teclado

---

Aquí van **ideas sencillas y viables** para un trabajo práctico de *Electrónica Digital 2* usando el **PIC16F887**, programado en **assembler**, que involucren:
* **ADC (Conversor Analógico-Digital)**
* **Transmisión serie EUSART**
* **Multiplexado de display de 7 segmentos o teclado matricial**
* Fácil implementación en protoboard

### 🟢 Opción 1: **Termómetro digital con envío serial**
**Descripción:**
* Usar un sensor de temperatura analógico como el **LM35** (0.01V/°C).
* Leer la temperatura con el **ADC**.
* Mostrar el valor en un **display de 3 dígitos multiplexado**.
* Enviar la temperatura por **EUSART** cada cierto tiempo (por ejemplo, 1 vez por segundo).

**Componentes:**
* LM35
* 3 Displays de 7 segmentos (ánodo común preferentemente)
* PIC16F887
* Conexión RS232-TTL o adaptador USB-Serial

**Ventajas:**
* Simple
* Visualmente atractivo
* Fácil de debuggear por terminal serial

### 🟢 Opción 2: **Voltímetro digital con visualización y salida serial**
**Descripción:**
* Leer una entrada analógica (0–5V) con el **ADC**.
* Mostrar el valor en un **display de 7 segmentos** (por ejemplo, 0.00 a 5.00 V).
* Enviar el valor por EUSART a la PC.

**Componentes:**
* Divisor resistivo para simular señales de entrada
* 3 Displays de 7 segmentos
* PIC16F887
* UART a PC

**Extras:**
* Puedes agregar una indicación de sobrevoltaje (por ejemplo, LED o mensaje serial)

### 🟢 Opción 3: **Controlador de luz con teclado matricial**
**Descripción:**
* Usar un **teclado matricial 4x4** para ingresar un número del 0 al 99.
* Mostrar el número en un display de 2 dígitos.
* Convertir el número a un voltaje proporcional (usando PWM y filtro RC).
* Leer la luz con un **LDR** (opcional) por el ADC para retroalimentación.
* Enviar el valor por **EUSART**.

**Módulos usados:**
* Teclado matricial (entrada)
* Display 7 segmentos (salida)
* ADC (LDR o potenciómetro)
* EUSART (monitor)

### 🟢 Opción 4: **Medidor de nivel con potenciómetro y transmisión**
**Descripción:**
* Usar un **potenciómetro** para simular un nivel (por ejemplo, de 0 a 100%).
* Leer el valor con **ADC**.
* Mostrar el nivel en un display 3 dígitos o en barras (tipo gráfico).
* Enviar por **EUSART**: `Nivel = XX %`

**Extras:**
* Podés usar LEDs para mostrar el nivel también.
* Sencillo pero bien completo en cuanto a uso de periféricos.

### 🟢 Opción 5: **Sistema de clave digital con ingreso por teclado y envío por UART**
**Descripción:**
* Usar un **teclado matricial** para ingresar una clave.
* Mostrar los dígitos en un display mientras se ingresan (opcionalmente ocultos).
* Verificar la clave y enviar un mensaje de “Acceso Correcto” o “Incorrecto” por **EUSART**.
* Podés usar ADC como verificación extra (e.g., nivel de voltaje para activar el sistema).

### Consejos para implementación:
* Usá delays simples y control de refresco en display para multiplexado.
* Iniciá el EUSART en modo asincrónico, 9600 baudios, 8N1.
* Usá un solo canal del ADC al comienzo.
* Para el ensamblador, trabajá por módulos: ADC.asm, display.asm, serial.asm, etc.
* No uses interrupciones al inicio, hacelo todo en polling si querés mantenerlo simple.

---

# Clases:
* Clase teórica sobre AD: https://drive.google.com/file/d/1m0CuEAg5N_XGyQn5EkkpFoGVpFZBmOWu/view
* Clase Teórica sobre comunicación: https://drive.google.com/file/d/1-OzEk3Gd9JGqM7VAiljeCQ1kqgmKCDBX/view

