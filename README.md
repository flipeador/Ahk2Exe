# <p align="center">Ahk2Exe 1.1.0.5 | Alpha v2.0-a097-60f26de</p>
###### Compilador no oficial para AutoHotkey v2 en español.

Puedes reportar errores, proponer nueva funcionalidad o hacer cualquier otro tipo de comentarios acerca del compilador en el sitio en el foro de AutoHotkey: [autohotkey.com/boards/viewtopic.php?f=44&t=48953](https://autohotkey.com/boards/viewtopic.php?f=44&t=48953).

<p align="center">
  <img src="https://github.com/flipeador/Ahk2Exe/raw/master/preview.jpg" alt="Ahk2Exe For AHKv2"/>
</p>

##### Durante el procesado del script, se tienen en cuenta los siguientes factores, ordenados en forma descendente de importancia.

  1. `Mejorar el rendimiento`, por más insignificante que éste sea. Este es el objetivo más importante, debido a la lentitud extrema de los lenguajes interpretados como lo es AHK.
  2. Lograr `reducir al máximo el tamaño del código`, quitando espacios y utilizando equivalentes más cortos en expresiones.

##### Debe tener en cuenta los siguientes puntos con respecto al compilador.

  - La compilación no garantiza la protección del código fuente.
  - La compilación no garantiza mejoras significativas de rendimiento.
  - AutoHotkey es un lenguaje interpretado, por lo que realmente no posee un compilador **real**, `Ahk2Exe` no realiza ningún pasaje de código AHK a código máquina, realmente no compila nada, sino que procesa el script para reducir su tamaño y facilita la adición de recursos en el archivo destino EXE. Al momento de "Compilar" un script, lo que en realidad se esta haciendo, es copiar el archivo `BIN` al destino especificado con la extensión `EXE`, y luego se le añade el script como un recurso en `RT_RCDATA`.

##### Compatibilidad / Requisitos

  - Microsoft **Windows Vista** en adeltante.
  - El compilador es únicamente para **AutoHotkey versión 2**.
  - La interfaz gráfica de usuario (GUI) no ha sido probada en pantallas con un DPI ([PPP](https://es.wikipedia.org/wiki/P%C3%ADxeles_por_pulgada)) alto (mayor a 96). Si **la interfaz no se visualiza correctamente** haga clic en el botón `High-DPI Settings`.





* * *


<br><br>


# Notas:
- Los archivos `Ahk2Exe.exe` y `Ahk2Exe64.exe` son totalmente independientes, **no requieren de ningún otro archivo para su funcionamiento**, aunque para poder compilar los scripts es necesario tener los archivos `BIN` en el mismo directorio que `Ahk2Exe.exe`.
- Para poder **comprimir el archivo** `EXE` resultante, es necesario tener `UPX` y/o `MPRESS` en el mismo directorio que `Ahk2Exe.exe`. **Tenga en cuenta que comprimir un script puede aumentar la probabilidad de ser detectado por los antivirus, por lo que no se recomienda**.
- La **versión de 64-bit** (`Ahk2Exe64.exe`) no soporta el efecto de agua en el logo `AHK`. La funcionalidad es exactamente la misma que en la de 32-bit.
- Por lo general, **la compilación no mejora el rendimiento de un script**.
- En el caso de una falla, `Ahk2Exe` tiene **códigos de salida** que indican el tipo de error que ocurrió.
- La **codificación por defecto** utilizada es `UTF-8 con BOM` (unicode), esto quiere decir que, si va a compilar un script sin `BOM`, el script compilado lo incluirá automáticamente, para asegurarse de que todos los caracteres (ej. `á`) se visualizen correctamente.





* * *


<br><br>


# Características:
- [x] Compilar Scripts (función principal).
- [x] La configuración se guarda en el registro, en donde se incluye las últimas opciones conocidas al momento de cerrar el compilador y además, almacena una lista con los 10 primeros archivos fuente e iconos en el control.
- [x] Detección de errores y registro de los mismos. Se incluye un control `ListView` dedicado explícitamente a guardar los registros de la compilación, para ayudarle a detectar los errores.
- [x] Detectar errores de sintaxis mediante `AutoHotkey.exe`.
- [x] Detectar y remover comentarios en bloque y comentarios en línea.
- [x] Detectar y remover espacios innecesarios de cada línea.
- [x] Detectar y optimizar secciones de continuación.
- [x] Detectar y optimizar expresiones y cadenas.
- [x] Soporte para compilar por medio de la línea de comandos + códigos de errores.
- [x] Soporte para cambiar el icono principal.
- [x] Soporte para añadir cualquier tipo de iconos y cursores.
- [x] Soporte variado para añadir recursos en el ejecutable y crear nuevos tipos.
- [x] Soporte para establecer el lenguaje de los recursos añadidos
- [x] Soporte para cambiar la información de la versión.
- [x] Soporte para cambiar el sub-sistema del ejecutable a modo consola.
- [x] Soporte completo para las directivas `#Include` y `#IncludeAgain`. Soporte para variables (debe encerrarlas entre `%`).
- [x] Soporte para inclusión automática de biblioteca (incluir funciones automáticamente sin la declaración explícita de `#Include`).
- [x] Soporte **parcial** para la función `FileInstall`. Evite los parentesis, expresiones (que no sean variables) y escriba la función en una línea completamente dedicada a ella. Soporte para variables.
- [x] Soporte para compresión del archivo compilado con `UPX` y `MPRESS`.





* * *


<br><br>


# Compilación por línea de comandos
Aquí se detalla la sintaxis para poder compilar por medio de la línea de comandos. Puede ver los códigos de salida más abajo.

El orden de los parámetros especificados importa, por ejemplo, si especifica primero `iconfile.ahk` sin una ruta absoluta, se tendra en cuenta el directorio del compilador si se especifica una ruta parcial en `iconfile`; por el contrario, si especifica `infile.ahk` antes, se tendra en cuenta el directorio de `infile.ahk`. Para indicar el comando puede utilizar `/` como se describe a continuación, o `-` también es válido.

- ##### Sintaxis

  ```Ahk2Exe.exe [/in] infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin binfile.bin] [/upx] [/mpress] [/nocheck] [/quiet]```

- ##### Descripción
| Parámetro  | Descripción | Directorio de trabajo |
| ---------- | ----------- | --------------------- |
| **infile.ahk** | Archivo fuente AHK (script) que se va a compilar (obligatorio). | Compilador |
| [&ast;]**outfile.exe** | Archivo destino EXE compilado. Si no se especifica, se establece en `infile.exe`. Si se especifica un directorio se establece en `\infile.exe`. Si no se especifica la extensión se añade automáticamente `.exe`; puede especificar cualquier extensión. Si el archivo ya existe, lo intenta sobreescribir. Si el directorio no existe la compilación falla. Para forzar la creación del directorio destino en caso de que no exista especifique como prefijo `*`. | infile.ahk o compilador |
| [&ast;]**iconfile.ico** | Icono principal del archivo compilado. Si no se especifica se mantiene el icono por defecto de AutoHotkey. Si se especificó la directiva `@Ahk2Exe-SetMainIcon` se utilizará el icono allí especificado. Puede añadir el caracter `*` como prefijo para ignorar la directiva `@Ahk2Exe-SetMainIcon` y forzar el uso de este icono. Tenga en cuenta que establecer un icono elimina todos los iconos por defecto de AHK, incluyendo iconos de _pausa_ (pause) y _suspensión_ (suspend). | infile.ahk o compilador |
| [&ast;]**binfile.bin** | Archivo BIN AutoHotkey. Si no se especifica utiliza el último archivo BIN utilizado. En caso de no haber una configuración válida guardada se establece dependiendo de la arquitectura del compilador `Unicode %8*A_PtrSize%-bit`. Por ejemplo: `Unicode 64-bit` (la extensión es opcional). Si se especificó la directiva `@Ahk2Exe-Bin` se utilizará el archivo BIN allí especificado. Puede añadir el caracter `*` como prefijo para ignorar la directiva `@Ahk2Exe-Bin` y forzar el archivo BIN aquí especificado. | Compilador |
| **/upx** o **/mpress** | Especifica el método de compresión del archivo EXE resultante. Los archivos `upx.exe` y `mpress.exe` deben estar en el directorio junto al compilador. | Compilador |
| **/nocheck** | Omite la comprobación de sintaxis por medio de `AutoHotkey.exe`. Si especifica este parámetro, no se autoincluirá ninguna función automáticamente. | - |
| **/quiet** o **/q** | Especifica que deben suprimirse todos los mensajes, diálogos y ventanas durante la compilación. Esta opción es útil si se aprovecha el código de salida, que le permite identificar el error ocurrido, si lo hubo. | - |





* * *


<br><br>


# Directivas específicas del compilador
El compilador acepta ciertas directivas que le permiten personalizar aún más el script compilado `.exe`.

Para asegurarse de que todas las directivas funcionen correctamente, considere **utilizar solo espacios** (y no tabulaciones).

En ciertas directivas, se permiten comentarios únicamente mediante el uso del caracter `;` y/o los parámetros se saparan por medio de comas, puede añadir un caracter de estos de forma literal utilizando el caracter de escape de AHK ```.

- ##### Directivas que controlan el comportamiento del script

  - **`;@Ahk2Exe-IgnoreBegin`**`[Lines]`

    Es posible **eliminar secciones de código** del script compilado al encerrarlas en las directivas `@Ahk2Exe-IgnoreBegin` y `@Ahk2Exe-IgnoreEnd` como si fueran comentarios multilinea en bloque `/**/`.

    `Lines` Es la cantidad de **líneas a ignorar** a partir de `IgnoreBegin`. Las líneas en blanco y comentarios no se tienen en cuenta (no cuentan como una línea). Si no se especifica, se ignora todo el código hasta encontrar un `IgnoreEnd`. Si se encuentra un `IgnoreEnd` antes de terminar el conteo de líneas especificadas, se terminará en ese punto y las líneas restantes de código a excluir se terminarán incluyendo en la compilación.

    `IgnoreBegin32` indica que el código no debe incluirse en la compilación de **32-bit**; La directiva de cierre es `IgnoreEnd32`. `IgnoreBegin64` Indica que el código no debe incluirse en la compilación de **64-bit**; La directiva de cierre es `IgnoreEnd64`.

    ```autohotkey
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-IgnoreBegin
    MsgBox "Este mensaje no aparece en el script compilado"
    ;@Ahk2Exe-IgnoreEnd
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ```

    ```autohotkey
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-IgnoreBegin32
    MsgBox "Este mensaje solo aparecerá en la compilación AHK de 64-Bit"
    ;@Ahk2Exe-IgnoreEnd32
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-IgnoreBegin64
    MsgBox "Este mensaje solo aparecerá en la compilación AHK de 32-Bit"
    ;@Ahk2Exe-IgnoreEnd64
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ```

    ```autohotkey
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-IgnoreBegin 2
    MsgBox "Este mensaje no aparece en el script compilado"
    ; comentario
    MsgBox "Este mensaje no aparece en el script compilado"
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ```

  - **`;@Ahk2Exe-Keep`**`[Code]`

    Lo contrario también es posible, es decir, marcar una sección de código para que solo se ejecute en el script compilado. Esta directiva también acepta las variantes `@Ahk2Exe-Keep32` y `@Ahk2Exe-Keep64`.

    ```autohotkey
    /*@Ahk2Exe-Keep
    MsgBox "Este mensaje aparece solo en el script compilado"
    MsgBox "Este mensaje aparece solo en el script compilado"
    */
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-Keep MsgBox "Este mensaje aparece solo en el script compilado"
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ```

  - **`;@Ahk2Exe-Define`**`Identifier [Replacement]`

    Define un identificador (variable) en el valor especificado. Este identificador podrá ser utilizado con otras directivas del compilador que soporten esta característica.

    `Identifier` Es un nombre cualquiera sin espacio que será utilizado como identificador. El nombre no puede ser una cadena vacía. Si bien el identificador puede contener cualquier texto, tenga en cuenta que éste es tratado como `RegEx` en la directiva `If` al evaluar expresiones.

    `Replacement` Es el valor de `Identifier`. Puede ser cualquier cadena, incluyendo espacios. Si no se especifica, se establece en una cadena vacía.

  - **`;@Ahk2Exe-UnDef`**`Identifier`

    Elimina un identificador definido anteriormente mediante la directiva `@Ahk2Exe-Define`. Si el identificador especificado no se encuentra definido, se mostrará un error y la compilación será cancelada; Para evitar esto compruebe antes mediante la directiva `;@Ahk2Exe-IfDef` si el identificador ya se encuentra definido o no.

  - **`;@Ahk2Exe-If/EndIf/IfDef/IfNDef`**`Condition`

    Estas directivas están basadas en [Preprocessor directives (C++)](http://www.cplusplus.com/doc/tutorial/preprocessor/), permiten incluir o descartar parte del código de un programa si se cumple una determinada condición.

    La directiva `;@Ahk2Exe-If` soporta expresiones mediante el uso de la función [Eval](https://github.com/flipeador/AutoHotkey/blob/master/Lib/math/Eval.ahk). Puede consultar el enlace a esa función para ver las limitantes y las características soportadas.

    Los identificadores en `Condition` son reemplazados por sus correspondientes valores asignados mediante `If`. Tenga en cuenta que a la hora de reemplazar los identificadores por sus correspondientes valores se utiliza `RegEx` de la siguiente manera: `RegExReplace(Condition, "\bIdentifier\b", Replacement)`.

    ```autohotkey
    ;@Ahk2Exe-define A
    ;@Ahk2Exe-define B 115
    ;@Ahk2Exe-define C 255
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-ifdef A
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-endif
    ;@Ahk2Exe-ifndef B
    MsgBox "Este mensaje no aparece en el script compilado"
    ;@Ahk2Exe-endif
    ;@Ahk2Exe-if C > (B + 58)
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ;@Ahk2Exe-endif
    ;@Ahk2Exe-if B = 125
    MsgBox "Este mensaje no aparece en el script compilado"
    ;@Ahk2Exe-endif
    MsgBox "Este mensaje aparece tanto en el script compilado como en el no compilado"
    ```

	**Nota: Actualmente estas directivas tienen ciertas limitantes, no soporta ifs anidados y el comportamiento puede no ser el deseado.**

<br><br>

- ##### Directivas que controlan los metadatos ejecutables

  - **`;@Ahk2Exe-SetProp`**`Valor`

    Cambia una propiedad en la información de versión del ejecutable compilado. En la tabla siguiente se describen las propiedades disponibles y su descripción. Puede utilizar las propiedades descritas entre parentesis para evitar utilizar, por ejemplo, la propiedad `Name`, que cambia tanto el nombre del producto como el nombre interno. Si desea un mayor control sobre la información de la versión, considere utilizar las directivas `@Ahk2Exe-VerInfo`, `@Ahk2Exe-FileVersion` y `@Ahk2Exe-ProductVersion`.

    `Prop` Debe reemplazarse por el nombre de la propiedad a cambiar. Puede ser cualquier cadena/texto que no contenga espacios.

    `Value` Es el valor a establecer a la propiedad. Puede ser cualquier cadena/texto con cualquier caracter, incluido espacios. Este valor puede ser una cadena vacía.

    | Propiedad | Descripción |
    | --------- | ----------- |
    | Name | Cambia el nombre del producto (`ProductName`) y el nombre interno (`InternalName`). |
    | Description | Cambia la descripción del archivo (`FileDescription`). |
    | Version | Cambia la versión del archivo (`FileVersion`) y la versión del producto (`ProductVersion`). Si esta propiedad no se modifica, se usa de forma predeterminada la versión de AutoHotkey utilizada para compilar el script. Esto tambien establece la versión binaria (`VS_FIXEDFILEINFO`) en el archivo; Si algún valor no es un número se establece en cero, por ejemplo: `1.A.5 -> 1.0.5.0`. Para especificar una versión binaria diferente a este valor, utilize las directivas `@Ahk2Exe-FileVersion` y `@Ahk2Exe-ProductVersion`. |
    | Copyright  | Cambia la información legal de copyright (derechos de autor). |
    | OrigFilename | Cambia la información del nombre de archivo original (`OriginalFileName`). |
    | CompanyName | Cambia el nombre de la compañía. |
	| Comments | Contiene cualquier información adicional que se debe mostrar con fines de diagnóstico. Este valor se establece por defecto con información sobre el compilador. |
	| XXX | `XXX` es cualquier otro nombre que no sea los comunes de arriba. [Aquí](https://goo.gl/DtVHA5) puede ver los nombres de propiedad más comunes para la información de la versión. Puede especificar cualquier nombre excepto aquellos que interfieran con el nombre de otra directiva. |

  - **`;@Ahk2Exe-FileVersion`**`0.0.0.0`

    Establece el número de versión binaria del archivo, esto es, `VS_FIXEDFILEINFO.dwFileVersionMS` y `VS_FIXEDFILEINFO.dwFileVersionLS`. Este es el número que recupera la función incorporada de AutoHotkey `FileGetVersion`. Este valor se establece automáticamente cuando se establece la propiedad `FileVersion` en la directiva `@Ahk2Exe-SetProp`.

    `0.0.0.0` Especifica la versión. Debe especificar 4 numeros enteros positivos separados por un punto. Si el valor especificado es inválido se mostrará un error y la compilación será cancelada.

  - **`;@Ahk2Exe-ProductVersion`**`0.0.0.0`

    Establece el número de versión binaria del producto con el que se distribuyó este archivo, esto es, `VS_FIXEDFILEINFO.dwProductVersionMS` y `VS_FIXEDFILEINFO.dwProductVersionLS`. Este valor se establece automáticamente cuando se establece la propiedad `ProductVersion` en la directiva `@Ahk2Exe-SetProp`.

  - **`;@Ahk2Exe-VerInfo`**`Prop [, Value] [, Delete?]`

    Esta directiva es una alternativa a `@Ahk2Exe-SetProp`. Hace modificaciones en la información de la versión, permite añadir, modificar y eliminar propiedades. Esta directiva le será útil si desea eliminar las propiedades por defecto que se añaden a la información de la versión (`Comments`, `FileVersion` y `ProductVersion`), además de añadir propiedades cuyo nombre contenga espacios. Puede especificar una coma `,` literal utilizando el caracter de escape de AHK.

    `Prop` El nombre de la propiedad. A diferencia de `@Ahk2Exe-SetProp` aquí se admiten espacios. Este parámetro únicamente puede ser omitido (cadena vacía) si `Delete` se estableció en el número `2`.

    `Value` El valor de la propiedad. Si no se especifica, se establece en una cadena vacía.

    `Delete` Especifica si desea eliminar una propiedad o si se desea eliminar todas las propiedades. Para eliminar la propiedad especificada debe establecerse en el número `1` (en este caso el segundo parámetro se ignora). Para eliminar todas las propiedades debe especificar el número `2` (en este caso los dos primeros parámetros se ignoran). Si se va a añadir o modificar una propiedad, debe omitir este parámetro.

  - **`;@Ahk2Exe-SetMainIcon`**`IcoFile`

    Establece el icono principal, esta directiva sobreescribe el icono especificado en la interfaz y línea de parámetros del compilador. Si utiliza esta directiva, antes de añadir el icono se eliminan todos los iconos por defecto de AHK, incluyendo los iconos de `Pausa` y `Suspensión`, quedando únicamente el icono por defecto especificado. El nombre del grupo en `RT_GROUP_ICON` es `159`, por lo que debe evitar añadir recursos iconos con este nombre mediante `AddResource`. El idioma utilizado para el icono principal es 0x0409 (`SUBLANG_ENGLISH_US`). Esta directiva será ignorada si se especificó un asterisco `*` al inicio del nombre del archivo ICO en la línea de parámetros.

  - **`;@Ahk2Exe-PostExec`**`Command [, WorkingDir] [, Options]`

    Especifica un **comando que se ejecutará después de una compilación exitosa**. El compilador no espera al nuevo proceso.

    `Command` el **comando** que será ejecutado mediante la función incorporada en **AHK** `Run`.

    `WorkingDir` el **directorio de trabajo** a utilizar. Si el directorio especificado no existe, se establecerá en el directorio del archivo compilado destino. Si se especificó un asterisco en `Options` este parámetro establece el directorio de trabajo del Script, en caso contrario actúa también como el segundo parámetro de la función incorporada en **AHK** `Run`.

    `Options` especifica las **opciones** de la función `Run`. Para ejecutar cualquier otro código **AHK** especifique un asteristo, vea más abajo.

    Si se detecta la ruta de `AutoHotkey.exe` este comando se ejecutará en un **nuevo proceso** de **AHK** (el compilador no espera al comando). El compilador dará prioridad a la versión de **64-Bit** o **32-Bit** dependiendo la arquitectura del sistema en donde se ejecuta el compilador.

    Si desea **ejecutar otro comando o varios** comandos **AHK**, debe especificar un asterisco `*` en el parámetro `Options`, en cuyo caso `Command` representa cualquier código **AHK**. Tenga en cuenta que si no se puede encontrar una versión de `AutoHotkey.exe` este comando se omitirá y se añadirá la información correspondiente al registro. Al ejecutar un nuevo proceso, puede que se requieran permisos administrativos. Puede separar varios comandos utilizando comas, utilize el caracter de espape para ello.

    Por ejemplo, `;@Ahk2Exe-PostExec "notepad.exe"` y `;@Ahk2Exe-PostExec Run "notepad.exe",,*` son idénticos, ambos ejecutan el Bloc de notas, pero el último requiere de `AutoHotkey.exe` ya que utiliza un nuevo proceso.

  - **`;@Ahk2Exe-ConsoleApp`**

    Cambia el subsistema ejecutable al modo consola. Cuando se ejecute el archivo compilado EXE, se abrirá una ventana de consola. Esto modifica el valor de `IMAGE_OPTIONAL_HEADER.Subsystem` a `IMAGE_SUBSYSTEM_WINDOWS_CUI`.

  - **`;@Ahk2Exe-AddResource`**`[*Type] FileName [, ResourceName] [, LangID]`

    Agrega un recurso al ejecutable compilado. Si en el tipo o en el nombre especifica un número entero comprendido entre 0 y 65535 inclusive (puede ser un número hexadecimal, en cuyo caso debe tener el prefijo `0x`), se tratará como un número entero, en caso contrario se tratará como una cadena.

    Puede tratar una coma literal utilizando el caracter de escape de AHK.

    `Type` (opcional) Es el tipo de recurso (como un entero o una cadena). Ahk2Exe detecta automáticamente ciertos tipos dependiendo de la extensión del archivo especificado. Se puede especificar explícitamente anteponiendo un asterisco a él: `*16 FileName, ResourceName`. En caso de que el tipo contenga espacios, debe ponerlo entre comillas: `*"type x" FileName`.

    `FileName` Es el nombre del archivo para agregar como recurso en el ejecutable. Si el archivo no existe se mostrará un error. En caso de que el archivo no pueda ser abierto para lectura se omitirá y se añadirá al registro.

    `ResourceName` (opcional) Es el nombre que tendrá el recurso (puede ser una cadena o un número entero). Si se omite, el valor predeterminado es el nombre (sin ruta) del archivo, en mayúsculas (incluye la extensión). Puede especicar un número hexadecimal, en cuyo caso debe tener el prefijo `0x`.

    `LangID` (opcional) Es el [código de idioma](https://msdn.microsoft.com/en-us/library/windows/desktop/dd318693%28v=vs.85%29.aspx) para este recurso. Si no se especifica, utiliza el código de idioma especificado en la directiva `UseResourceLang`.

    Aquí hay una lista de tipos de recursos estándar comunes y las extensiones que los desencadenan de forma predeterminada.

    | Tipo de recurso | Extensiones |
    | --------------- | ------------ |
    | 2 (RT_BITMAP) | .bmp; .dib |
    | 4 (RT_MENU) | - |
    | 5 (RT_DIALOG) | - |
    | 6 (RT_STRING) | - |
    | 9 (RT_ACCELERATORS) | - |
    | 10 (RT_RCDATA) | Cualquier otra extensión. Este es el recurso utilizado por la función `FileInstall`. |
    | 11 (RT_MESSAGETABLE) | - |
    | 12 (RT_GROUP_CURSOR) | .cur (cursores) |
    | 14 (RT_GROUP_ICON) | .ico (iconos) |
    | 23 (RT_HTML) | .htm; .html; .mht |
    | 24 (RT_MANIFEST) | .manifest (El nombre por defecto para este tipo de recurso es el número entero `1`) |

    Además de los recursos especificados en la tabla de arriba, el compilador soporta los siguientes tipos de recursos que son detectados automáticamente por la extensión, o que puede especificarse de forma explícita: `*tipo`. Tenga en cuenta que en este caso se distingue entre mayúsculas y minúsculas.

    | Tipo de recurso | Descripción |
    | --------------- | ----------- |
    | .PNG (RT_ICON) | Imágenes PNG |

  - **`;@Ahk2Exe-RequireAdmin`**

    La aplicación se ejecutará con permisos de administrador. El usuario que inicia la aplicación debe ser un miembro del grupo Administradores. Si el proceso de apertura no se ejecuta con permisos administrativos, el sistema solicitará credenciales.

  - **`;@Ahk2Exe-UseResourceLang`**`LangCode`

    Cambia el lenguaje por defecto de los recursos añadidos por medio de la directiva `@Ahk2Exe-AddResource`. Tenga en cuenta que este valor no se tendrá en cuenta si se especificó el código de idioma en la directiva `AddResource`. El código de idioma utilizado por defecto es 0x0409 (`SUBLANG_ENGLISH_US`). Esto también afecta al idioma del recurso de información de versión (`@Ahk2Exe-SetProp`).

    `LangCode` Es el [código de idioma](https://msdn.microsoft.com/en-us/library/windows/desktop/dd318693). Tenga en cuenta que los números hexadecimales deben tener un prefijo `0x`. Si se especifica un código de idioma inválido/desconocido ocurrirá un error; Se utiliza la función [LCIDToLocaleName](https://goo.gl/pTQtjp) para comprobar que el código sea válido.

  - **`;@Ahk2Exe-Bin`**`BinFile`

    Especifica el archivo BIN a utilizar durante la compilación. Esta directiva será ignorada si se especificó un asterisco `*` al inicio del nombre del archivo BIN en la línea de parámetros.

  - **`;@Ahk2Exe-AddStream`**`Name, Value [, IsText]`

    Añade un [stream](https://msdn.microsoft.com/en-us/library/windows/desktop/aa364404) al archivo destino. Puede entender un stream como archivos que están contenidos en un archivo principal. Se utilizan generalmente para almacenar ciertos datos/atributos en un archivo. Se puede acceder a un stream utilizando, por ejemplo: `C:\nombre_archivo:nombre_stream`. Para eliminar un stream puede utilizar la función de AHK incorporada `FileDelete`.

    `Name` es el nombre del stream, se aplican las mismas reglas que con el nombre de un archivo, por lo que no puede contener los siguientes caracteres: `<>:"/\|?*`. 

    `Value` representa los datos a añadir. Este valor depende del valor especificado en `IsText`. Si va a añadir texto, este parámetro puede ser una cadena vacía.

    `IsText` determina si el valor en `Value` debe interpretarse como texto, en cuyo caso debe especificar **1**. Si este parámetro no se especifica, `Value` se interpretará como un archivo. Si el archivo no se puede abrir para lectura se omite y se añade una advertencia al registro. El texto se añade utilizando la codificación **UTF-8** sin **BOM**. Si se va a añadir un archivo, éste se interpretará en forma binaria (se incluye entero, sin modificaciones).

    Tenga en cuenta que los streams solo son soportados en sistemas de archivos [NTFS](https://es.wikipedia.org/wiki/NTFS) y [ReFS](https://en.wikipedia.org/wiki/ReFS)[+](https://docs.microsoft.com/en-us/windows-server/storage/refs/refs-overview), este último tiene un tamaño límite de 128K. Si copia el archivo a otro sistema de archivos todos los streams son eliminados (esto también ocurre si sube el archivo a ciertos sitios de almacenamiento en la nube). Puede administrar los streams en un archivo utilizando [ADS Manager](https://dmitrybrant.com/adsmanager).





* * *


<br><br>


# Códigos de salida (exitcodes)
Los códigos de salida indican el tipo de error que ocurrió durante la compilación. Esto le será útil cuando compila un script por medio de la línea de comandos.
  - **General**

     | Código de salida | Constante | Descripción |
     | --- | --- | --- |
     | 0x00 | ERROR_SUCCESS | Todas las operaciones se han realizado con éxito |
     | 0x01 | UNKNOWN_ERROR | Error desconocido |
     | 0x02 | ERROR_NOT_SUPPORTED | No soportado |
     | 0x03 | ERROR_INVALID_PARAMETER | Los parámetros pasados son inválidos |

  - **Apertura de archivos y directorios**

     | Código de salida | Constante | Descripción |
     | ---------------- | --------- | ----------- |
     | 0x10 | ERROR_SOURCE_NO_SPECIFIED | El archivo fuente no se ha especificado |
     | 0x11 | ERROR_SOURCE_NOT_FOUND | El archivo fuente no existe |
     | 0x12 | ERROR_CANNOT_OPEN_SCRIPT | No se ha podido abrir el archivo fuente script (incluyendo includes) para lectura |
     | 0x13 | ERROR_BIN_FILE_NOT_FOUND | El archivo BIN no existe |
     | 0x14 | ERROR_BIN_FILE_CANNOT_OPEN | No se ha podido abrir el archivo BIN para lectura |
     | 0x15 | ERROR_MAIN_ICON_NOT_FOUND | El icono principal no existe |
     | 0x16 | ERROR_MAIN_ICON_CANNOT_OPEN | No se ha podido abrir el icono principal para lectura |
     | 0x17 | ERROR_INVALID_MAIN_ICON | El icono principal es inválido |
     | 0x18 | ERROR_INCLUDE_FILE_NOT_FOUND | El archivo a incluir no existe |
     | 0x19 | ERROR_INCLUDE_DIR_NOT_FOUND | El directorio a incluir no existe |
     | 0x20 | ERROR_FILEINSTALL_FILE_NOT_FOUND | El archivo a incluir especificado en FileInstall no existe |
     | 0x21 | ERROR_RESOURCE_FILE_NOT_FOUND | El archivo de recurso a incluir no existe |
     | 0x22 | ERROR_DEST_DIR_NOT_FOUND | El directorio destino para el archivo destino EXE no existe |

  - **Escritura de archivos y directorios**

     | Código de salida | Constante | Descripción |
     | ---------------- | --------- | ----------- |
     | 0x30 | ERROR_CANNOT_COPY_BIN_FILE | No se ha podido copiar el archivo BIN al destino |
     | 0x31 | ERROR_CANNOT_OPEN_EXE_FILE | No se ha podido abrir el archivo destino EXE para escritura |
     | 0x32 | ERROR_CANNOT_CREATE_DEST_DIR | No se ha podido crear el directorio destino para archivo destino EXE |

  - **Sintaxis**

     | Código de salida | Constante | Descripción |
     | ---------------- | --------- | ----------- |
     | 0x50 | ERROR_INVALID_DIRECTIVE_SYNTAX | La sintaxis de la directiva es inválida |
     | 0x51 | ERROR_UNKNOWN_DIRECTIVE_COMMAND | Comando de directiva desconocido |
     | 0x52 | ERROR_INVALID_FILEINSTALL_SYNTAX | La sintaxis de FileInstall es inválida |
     | 0x53 | ERROR_INVALID_SYNTAX | La sintaxis en el código fuente AHK es inválida |





* * *


<br><br>


# Pensamientos para futuras actualizaciones
  - **Mejorar el procesado del Script** para reducir al máximo el tamaño del archivo compilado y, si es posible, mejorar el rendimiento.
  - **Mejorar el soporte para incluir recursos**.
  - Mejorar soporte de la función `FileInstall`.
  - **Implementar más opciones en la interfaz**.
  - **Implementar mas directivas**.
  - Si te interesa alguna característica o funcionalidad actualmente no soportada, puedes dejar un comentario en el foro en AutoHotkey y veré si la implemento o no. De todas formas, puedes hacer una copia del código fuente y modificarlo tu mismo.





* * *


<br><br>


# Agradecimientos
  - ##### [Chris Mallet](https://autohotkey.com/boards/memberlist.php?mode=viewprofile&u=2) - Por el fantástico AutoHotkey.
  - ##### [lexikos](https://autohotkey.com/boards/memberlist.php?mode=viewprofile&u=77) - Por continuar dando soporte a AutoHotkey, especialmente por la versión 2.
  - ##### [fincs](https://autohotkey.com/boards/memberlist.php?mode=viewprofile&u=100)   - Este compilador esta basado en [Ahk2Exe de fincs](https://autohotkey.com/boards/viewtopic.php?f=24&t=521). Fue de mucha ayuda su clase **VersionInfo**, gracias a ella este compilador soporta modificación nativa en AHK para la información de la versión.
  - ##### [just me](https://autohotkey.com/boards/memberlist.php?mode=viewprofile&u=148) - Por sus increibles funciones [ImageButton](https://autohotkey.com/boards/viewtopic.php?f=6&t=1103) y [LinearGradient](https://autohotkey.com/boards/viewtopic.php?f=6&t=3593&p=18573).
  - ##### [tmplinshi](https://autohotkey.com/boards/memberlist.php?mode=viewprofile&u=133) - Por su aporte sobre `waterctrl.dll` ([enlace](https://autohotkey.com/boards/viewtopic.php?f=22&t=3302&p=16261)). [Sitio oficial](http://restools.hanzify.org/article.asp?id=80). [[VirusTotal](https://www.virustotal.com/es-ar/file/bbc65291a3bcfb6559c391e251bca12d6b935a8a8de0825443642aa2b5e39e78/analysis/1526309617/)].
  - ##### Toda la comunidad de [AutoHotkey.com](https://autohotkey.com/). [AutoHotkey.com/logos](https://autohotkey.com/logos/) por el logo.





* * *


<br><br>


# Archivos de terceros utilizados durante el desarrollo y otros útiles para la compilación.
  - ##### [Visual Studio Community](https://www.visualstudio.com/es/vs/community/) - Para las constantes y comprobaciones de tamaño de ciertas estructuras.
  - ##### [Cool Pix Bar](https://toolslib.net/downloads/viewdownload/157-cool-pix-bar/) - Para la selección de colores RGB.
  - ##### [FastStone Capture](http://www.faststone.org/FSCaptureDetail.htm) y [ShareX](https://getsharex.com/) - Exelente capturador de imagenes, de gran ayuda con el LOGO y colores.
  - ##### [UPX](https://upx.github.io/) - Compresor de archivos ejecutables.
  - ##### [MPRESS](http://www.matcode.com/mpress.htm) - Empaquetador ejecutable de alto rendimiento.
  - ##### [SublimeText](https://www.sublimetext.com/) - Para la edición de los scripts ([IDE](https://es.wikipedia.org/wiki/Entorno_de_desarrollo_integrado)).
  - ##### [AutoGUI](https://autohotkey.com/boards/viewforum.php?f=64) - Para la creación de la interfaz gráfica de usuario ([GUI](https://es.wikipedia.org/wiki/Interfaz_gr%C3%A1fica_de_usuario)).
