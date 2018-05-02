# Ahk2Exe
Compilador no oficial para AutoHotkey v2 en español.
![Ahk2Exe For AHKv2](https://github.com/flipeador/Ahk2Exe/raw/master/preview.jpg)

Notas:
- Los archivos `Ahk2Exe.exe` y `Ahk2Exe64.exe` son totalmente independientes, no requieren de ningún otro archivo para su funcionamiento, aunque para poder compilar los scripts es necesario tener los archivos `BIN` en el mismo directorio que `Ahk2Exe.exe`.
- Para poder comprimir el archivo `EXE` resultante, es necesario tener `UPX` y/o `MPRESS` en el mismo directorio que `Ahk2Exe.exe`.
- La versión de 64-bit (`Ahk2Exe64.exe`) no soporta el efecto de agua en el logo `AHK`. La funcionalidad es exactamente la misma que en la de 32-bit.

Características:

 - [x] Compilar Scripts (obviamente).
  - [x] La configuración se guarda en el registro, en donde se incluye las últimas opciones conocidas al momento de cerrar el compilador y además, almacena una lista con los 10 primeros archivos fuente e iconos en el control.
  - [x] Detección de errores y registro de los mismos.
   - [x] Detectar y remover comentarios en el script.
 - [x] Detectar y remover espacios innecesarios al inicio y final de la línea.
 - [x] Detectar secciones de continuación
 - [ ] Soporte para compilar por medio de la línea de comandos.
 - [x] Soporte para cambiar el icono principal.
 - [x] Soporte para añadir cualquier tipo de iconos y cursores.
 - [x] Soporte variado para añadir recursos en el ejecutable y crear nuevos tipos.
 - [x] Soporte para establecer el lenguaje de los recursos añadidos
 - [ ] Soporte para cambiar la información de la versión.
 - [x] Soporte para cambiar el sub-sistema del ejecutable a modo consola.
 - [x] Soporte completo para las directivas `#Include` y `#IncludeAgain`.
 - [x] Soporte para función `FileInstall`.
 - [x] Soporte para compresión del archivo compilado con `UPX` y `MPRESS`.

