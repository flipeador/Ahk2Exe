# Ahk2Exe
Compilador no oficial para AutoHotkey v2 en español.
<p align="center">
  <img src="https://github.com/flipeador/Ahk2Exe/raw/master/preview.jpg" alt="Ahk2Exe For AHKv2"/>
</p>

⠀

# Notas:
- Los archivos `Ahk2Exe.exe` y `Ahk2Exe64.exe` son totalmente independientes, no requieren de ningún otro archivo para su funcionamiento, aunque para poder compilar los scripts es necesario tener los archivos `BIN` en el mismo directorio que `Ahk2Exe.exe`.
- Para poder comprimir el archivo `EXE` resultante, es necesario tener `UPX` y/o `MPRESS` en el mismo directorio que `Ahk2Exe.exe`.
- La versión de 64-bit (`Ahk2Exe64.exe`) no soporta el efecto de agua en el logo `AHK`. La funcionalidad es exactamente la misma que en la de 32-bit.

⠀

# Características:
- [x] Compilar Scripts (función principal).
- [x] La configuración se guarda en el registro, en donde se incluye las últimas opciones conocidas al momento de cerrar el compilador y además, almacena una lista con los 10 primeros archivos fuente e iconos en el control.
- [x] Detección de errores y registro de los mismos.
- [x] Detectar y remover comentarios en el script.
- [x] Detectar y remover espacios innecesarios al inicio, final y otras partes en cada línea.
- [x] Detectar y optimizar secciones de continuación.
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

⠀

# Compilación por línea de comandos
- Sintaxis
  - **Ahk2Exe.exe** [/in] infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin binfile.bin] [/upx] [/mpress]
- Descripción
  - `infile.ahk` Es el archivo fuente AHK a compilar. Utiliza el directorio de trabajo del compilador. El archivo fuente es obligatorio.
  - `outfile.exe` Es el archivo EXE de salida compilado. Utiliza el directorio de trabajo de `infile.ahk` o el directorio del compilador si `infile.ahk` no se especificó antes. Si no se especifica, se establece por defecto a `infile.exe`.
  - `iconfile.ico` Es el icono principal del archivo compilado. Utiliza el directorio de trabajo de `infile.ahk` o el directorio del compilador si `infile.ahk` no se especificó antes. Si no se especifica, se mantiene el icono por defecto de AutoHotkey. El icono principal puede ser establecido por medio de la directiva del compilador `@Ahk2Exe-SetMainIcon`, en este caso el icono especificado se ignora.
  - `binfile.bin` Es el archivo BIN de AutoHotkey. Utiliza el directorio de trabajo del compilador. Si no se especifica, se establece en el último archivo BIN utilizado. En caso de no haber una configuración válida guardada del último archivo BIN utiliza, se establece automáticamente dependiendo de la aqrquitectura del compilador `Unicode %8*A_PtrSize%-bit`. Por ejemplo, puede especificar `Unicode 64-bit` (la extensión no es necesaria).
  - `/upx` o `/mpress` Especifica el método de compresión del archivo EXE resultante. Estos archivos deben estar en el mismo directorio que el compilador.

⠀

# Directivas específicas del compilador
El compilador de scripts acepta ciertas directivas que le permiten personalizar aún más el script compilado (EXE).
- **Directivas que controlan el comportamiento del script**
  - Es posible eliminar secciones de código del script compilado al encerrarlas en las directivas `@Ahk2Exe-IgnoreBegin` y `@Ahk2Exe-IgnoreEnd` como si fueran comentarios multilinea en bloque `/**/`.
    ```autohotkey
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-IgnoreBegin
    MsgBox "Este mensaje no aparece en el script compilado"
    ;@Ahk2Exe-IgnoreEnd
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ```
- **(SIN SOPORTE AÚN) Directivas que controlan los metadatos ejecutables**
  - **`;@Ahk2Exe-SetProp`**`Value`
  Cambia una propiedad en la información de versión del ejecutable compilado.
  • `Prop` debe reemplazarse por el nombre de la propiedad a cambiar.
  • `Value` es el valor a establecer a la propiedad.
  
    | Propiedad | Descripción |
    | --- | --- |
    | Name | Cambia el nombre del producto (`ProductName`) y el nombre interno (`InternalName`). |
    | Description | Cambia la descripción del archivo (`FileDescription`). |
    | Version | Cambia la versión del archivo (`FileVersion`) y la versión del producto (`ProductVersion`). Si esta propiedad no se modifica, se usa de forma predeterminada la versión de AutoHotkey utilizada para compilar el script. |
    | Copyright  | Cambia la información legal de copyright (derechos de autor). |
    | OrigFilename | Cambia la información del nombre del archivo original. |
    | CompanyName | Cambia el nombre de la compañía. |
    
  - **`;@Ahk2Exe-SetMainIcon`**`[IcoFile]`
  Sobrescribe el ícono EXE personalizado utilizado para la compilación. Si utiliza esta directiva, antes de añadir el icono se eliminan todos los iconos por defecto de AHK, incluyendo los iconos de `Pausa` y `Suspensión`, quedando únicamente el icono por defecto especificado. El nombre del grupo en `RT_GROUP_ICON` es `159`, por lo que debe evitar añadir recursos iconos con este nombre mediante `AddResource`.
  - **`;@Ahk2Exe-PostExec`**`Comando`
  Especifica un comando que se ejecutará después de una compilación exitosa. La cadena especificada en `Comando` será ejecutada mediante la función incorporada en AHK `Run`.
  - **`;@Ahk2Exe-ConsoleApp`**
  Cambia el subsistema ejecutable al modo consola. Cuando se ejecute el archivo compilado EXE, se abrirá una ventana de consola. Esto modifica el valor de `IMAGE_OPTIONAL_HEADER.Subsystem` a `IMAGE_SUBSYSTEM_WINDOWS_CUI`.
  - **`;@Ahk2Exe-AddResource`**`FileName [, ResourceName]`
  Agrega un recurso al ejecutable compilado.
  • `FileName` Es el nombre del archivo del recurso para agregar. El tipo del recurso (como un entero o una cadena) se puede especificar explícitamente anteponiendo un asterisco a él: `*tipo Filename` o `*"nombre tipo" Filename` si el nombre del tipo contiene espacios.
  • `ResourceName` (opcional) Es el nombre que tendrá el recurso (puede ser una cadena o un número entero). Si se omite, el valor predeterminado es el nombre (sin ruta) del archivo, en mayúsculas (incluye la extensión).
  
    Aquí hay una lista de tipos de recursos estándar comunes y las extensiones que los desencadenan de forma predeterminada.
    
    |    Tipo de recurso   | Extensiones |
    | --- | --- |
    | 1 (RT_CURSOR) | .cur (cursores) |
    | 2 (RT_BITMAP) | .bmp; .dib |
    | 3 (RT_ICON) | .ico (iconos) |
    | 4 (RT_MENU) | - |
    | 5 (RT_DIALOG) | - |
    | 6 (RT_STRING) | - |
    | 9 (RT_ACCELERATORS) | - |
    | 10 (RT_RCDATA) | Cualquier otra extensión. Este es el recurso utilizado por la función `FileInstall`. |
    | 11 (RT_MESSAGETABLE) | - |
    | 23 (RT_HTML)     | .htm; .html; .mht |
    | 24 (RT_MANIFEST) | .manifest |
    
  
    Además de los recursos especificados en la tabla de arriba, el compilador soporta los siguientes tipos de recursos que son detectados automáticamente por la extensión, o que puedes especificarse de forma explícita: `*tipo`.
    
    | Tipo de recurso | Descripción  |
    | --- | --- |
    | .PNG | Imágenes PNG |
    
  - **`;@Ahk2Exe-UseResourceLang`**`LangCode`
  Cambia el lenguaje de recursos utilizado por `@Ahk2Exe-AddResource`.
  `LangCode` Es el [código de idioma](https://msdn.microsoft.com/en-us/library/windows/desktop/dd318693%28v=vs.85%29.aspx). Tenga en cuenta que los números hexadecimales deben tener un prefijo `0x`.

⠀

# Códigos de salida (exitcodes)
Los códigos de salida indican el tipo de error que ocurrió durante la compilación. Esto le será útil cuando compila un script por medio de la línea de comandos.
**SIN SOPORTE AÚN**

⠀

# Pensamientos para futuras actualizaciones
- Mejorar el procesado del Script para reducir al máximo el tamaño del archivo compilado y, si es posible, mejorar el rendimiento.
- Añadir soporte para modificar la información de la versión.
- Mejorar el soporte para incluir recursos.
- Mejorar soporte de la función `FileInstall`.
- Implementar más opciones en la interfaz.
