# TP Electrónica Digital 2

Trabajo Práctico de Electrónica Digital 2 utilizando el microcontrolador **PIC16F887**. El proyecto implementa los módulos de ADC y UART, multiplexación de display de 7 segmentos y lectura de teclado matricial.

---

## Descripción General

Este proyecto consiste en un **termómetro digital** con envío de datos por comunicación serial. Permite ingresar una temperatura de referencia mediante un teclado matricial y, utilizando un sensor LM35, mide la temperatura ambiente. Si la temperatura medida supera la referencia, se enciende un LED indicador. Además, la temperatura se muestra en un display de 2 dígitos y se envía periódicamente por UART.

---

## Características

- Lectura de temperatura analógica con sensor LM35 (0.01V/°C)
- Conversión analógica-digital con el módulo ADC del PIC16F887
- Ingreso de temperatura de referencia por teclado matricial
- Visualización de la temperatura en dos displays de 7 segmentos multiplexados
- Indicación visual (LED) si la temperatura supera la referencia
- Envío periódico de la temperatura por UART (RS232-TTL o USB-Serial)
- Control de ingreso de referencia mediante pulsador

---

## Componentes Utilizados

- **LM35** (sensor de temperatura)
- **2 Displays de 7 segmentos** (ánodo común preferentemente)
- **PIC16F887** (microcontrolador)
- **Conexión RS232-TTL** o adaptador **USB-Serial**
- **Pulsador**
- **Teclado matricial 4x4** (opcional, según diseño)

---

## Requisitos

Para trabajar en este proyecto, asegúrate de tener instalados los siguientes programas:

- **MPLAB X IDE** (desarrollo del código del microcontrolador)
- **Proteus** (simulación del circuito)
- **Git** (control de versiones)

---

## Estructura del Proyecto

- **Proteus**: Archivos de simulación del circuito.
- **tp_digital2.x**: Código fuente del microcontrolador (MPLAB).
- **README.md**: Información sobre el proyecto.

---

## Instrucciones de Uso

1. **Clona el repositorio:**
   ```sh
   git clone https://github.com/nicopinera/elec_dig_2.git
   ```
2. **Abre el proyecto en MPLAB X IDE** y compílalo.
3. **Carga el archivo HEX** generado en el microcontrolador PIC16F887.
4. **Simula el circuito** en Proteus o monta el hardware real según el esquema.
5. **Utiliza el pulsador** para iniciar la carga de la temperatura de referencia desde el teclado.
6. **Observa la temperatura** en el display y el estado del LED indicador.
7. **Recibe los datos** enviados por UART en tu PC usando un programa de terminal serial (por ejemplo, PuTTY o RealTerm).

---

## Funcionamiento

- Al presionar el pulsador, el sistema permite ingresar una temperatura de referencia.
- El valor ingresado se almacena y se compara continuamente con la temperatura leída por el LM35.
- Si la temperatura medida supera la referencia, se enciende un LED.
- La temperatura actual se muestra en los displays y se envía por UART cada segundo.

---

## Comandos básicos de Git

A continuación se detallan los comandos más comunes para utilizar git:

- Para clonar el repositorio la primera vez:  
  `git clone https://github.com/nicopinera/elec_dig_2.git`
- Para añadir cambios localmente:  
  `git add .`
- Para realizar el commit de los cambios:  
  `git commit -m "Mensaje"`
- Para ver el estado de los archivos:  
  `git status`
- Para subir los cambios al repositorio en github:  
  `git push origin master`
- Para descargar o bajar los cambios del repositorio en github:  
  `git pull origin master`



