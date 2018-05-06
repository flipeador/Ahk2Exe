# Ahk2Exe
Compilador no oficial para AutoHotkey v2 en español.
<p align="center">
  <img src="https://github.com/flipeador/Ahk2Exe/raw/master/preview.jpg" alt="Ahk2Exe For AHKv2"/>
</p>


# Notas:
- Los archivos `Ahk2Exe.exe` y `Ahk2Exe64.exe` son totalmente independientes, no requieren de ningún otro archivo para su funcionamiento, aunque para poder compilar los scripts es necesario tener los archivos `BIN` en el mismo directorio que `Ahk2Exe.exe`.
- Para poder comprimir el archivo `EXE` resultante, es necesario tener `UPX` y/o `MPRESS` en el mismo directorio que `Ahk2Exe.exe`.
- La versión de 64-bit (`Ahk2Exe64.exe`) no soporta el efecto de agua en el logo `AHK`. La funcionalidad es exactamente la misma que en la de 32-bit.


# Características:
- [x] Compilar Scripts (función principal).
- [x] La configuración se guarda en el registro, en donde se incluye las últimas opciones conocidas al momento de cerrar el compilador y además, almacena una lista con los 10 primeros archivos fuente e iconos en el control.
- [x] Detección de errores y registro de los mismos.
- [x] Detectar y remover comentarios en el script.
- [x] Detectar y remover espacios innecesarios al inicio y final de la línea.
- [x] Detectar secciones de continuación
- [x] Soporte para compilar por medio de la línea de comandos.
- [x] Soporte para cambiar el icono principal.
- [x] Soporte para añadir cualquier tipo de iconos y cursores.
- [x] Soporte variado para añadir recursos en el ejecutable y crear nuevos tipos.
- [x] Soporte para establecer el lenguaje de los recursos añadidos
- [ ] Soporte para cambiar la información de la versión.
- [x] Soporte para cambiar el sub-sistema del ejecutable a modo consola.
- [x] Soporte completo para las directivas `#Include` y `#IncludeAgain`.
- [x] Soporte para la función `FileInstall`.
- [x] Soporte para compresión del archivo compilado con `UPX` y `MPRESS`.


# Compilación por línea de comandos
- Sintaxis
  - Ahk2Exe.exe [/in] infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin binfile.bin] [/upx] [/mpress]
- Descripción
  - `infile.ahk` Es el archivo fuente AHK a compilar. Utiliza el directorio de trabajo del compilador. El archivo fuente es obligatorio.
  - `outfile.exe` Es el archivo EXE de salida compilado. Utiliza el directorio de trabajo de `infile.ahk` o el directorio del compilador si `infile.ahk` no se especificó antes. Si no se especifica, se establece por defecto a `infile.exe`.
  - `iconfile.ico` Es el icono principal del archivo compilado. Utiliza el directorio de trabajo de `infile.ahk` o el directorio del compilador si `infile.ahk` no se especificó antes. Si no se especifica, se mantiene el icono por defecto de AutoHotkey. El icono principal puede ser establecido por medio de la directiva del compilador `@Ahk2Exe-SetMainIcon`.
  - `binfile.bin` Es el archivo BIN de AutoHotkey. Utiliza el directorio de trabajo del compilador. Si no se especifica, se establece en el último archivo BIN utilizado. Se recomienda especificar este archivo, por ejemplo `Unicode 64-bit.bin`.
  - `/upx` o `/mpress` Especifica el método de compresión del archivo EXE resultante. Estos archivos deben estar en el mismo directorio que el compilador.


# Pensamientos para futuras actualizaciones
- Mejorar el procesado del Script para reducir al máximo el tamaño del archivo compilado.
- Añadir soporte para modificar la información de la versión.
