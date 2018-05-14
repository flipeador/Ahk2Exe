PreprocessScript(Script, Tree := "", FileList := "", Directives := "")
{
    If (FileList == "")
    {
        Util_AddLog("INFO", "Se ha iniciado el procesado del script", Script)

        FileList := []    ; almacena una lista con todos los archivos incluidos (para evitar varias inclusiones de un mismo archivo)
        ; almacena los archivos a añadir luego de la compilación al archivo EXE resultante y otras configuraciones
        Directives := {         MainIcon: CMDLN ? g_data.IcoFile : CB_GetText(Gui.Control["ddlico"])
                      ,        Subsystem: IMAGE_SUBSYSTEM_WINDOWS_GUI
                      ,     ResourceLang: SUBLANG_ENGLISH_US
                      ,         PostExec: ""
                      ,      VersionInfo: { FileVersion: A_AhkVersion, ProductVersion: A_AhkVersion, OriginalFilename: SubStr(Script, InStr(Script, "\",, -1)+1) }
                      ,        Resources: [] }
    }

    ObjPush(FileList, Script)
    Util_Status("Procesando.. [" . Script . "]")
    Util_AddLog("INCLUDE", "Se ha incluido un archivo", Script)


    ; ======================================================================================================================================================
    ; Comprobación del archivo de código fuente AHK
    ; ======================================================================================================================================================
    If (!IS_FILE(Script))
    {
        Util_AddLog("ERROR", "No se ha encontrado el script", Script,, StrReplace(Tree, "`n", "|"))
        Return Util_Error("El archivo de código fuente AHK no existe.", Script, CMDLN ? ERROR_CANNOT_OPEN_SCRIPT : NO_EXIT)
    }

    If (!FileOpen(Script, "r"))    ; comprobamos permisos de lectura
    {
        Util_AddLog("ERROR", "No se ha podido abrir el Script para lectura", Script)
        Return Util_Error("No se ha podido abrir el Script para lectura.", Script, CMDLN ? ERROR_CANNOT_OPEN_SCRIPT : NO_EXIT)
    }

    Local WorkingDir := new TempWorkingDir(DirGetParent(Script))    ; establece temporalmente el directorio de trabajo actual al del script ha procesar


    ; ======================================================================================================================================================
    ; Iniciar procesado
    ; ======================================================================================================================================================
    Local NewCode := ""    ; almacena el código procesado
        , LineTxt := ""       ; almacena el texto de la línea actual
        , foo := bar := ""    ; variables generales de uso temporal
        , IncludeAgain := FALSE    ; determina si se debe ignorar archivos ya incluidos
        ,    InComment := FALSE    ; determina si se está en un comentario en bloque
        ,  ContSection := FALSE    ; determina si se está en una continuación de una sección
        ,  IgnoreBegin := FALSE    ; determina si el código siguiente debe ser ignorado
        ,         Keep := FALSE    ; determina si el comentario en bloque debe añadirse en el script compilado (no como comentario)

    VarSetCapacity(NewCode, FileGetSize(Script))    ; establecemos la capacidad de la variable que amlacenará el nuevo código, para mejorar el rendimiento
    VarSetCapacity(LineTxt, 65534 * 2)    ; capacidad de la variable que almacenará el texto de la línea actual

    ; caracteres especiales regex \.*?+[{|()^$
    Loop Read, Script    ; abrimos el archivo para lectura y leemos línea por línea
    {
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Ignoramos líneas en blanco y comentarios
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (A_LoopReadLine ~= "^\s*$")    ; ¿línea en blanco?
            Continue

        If (InComment)    ; ¿comentario en bloque multilínea?
        {
            InComment := !(A_LoopReadLine ~= "^\s*\*/")
            If (!InComment || !Keep)
                Continue
        }

        If (IgnoreBegin)    ; ignorar líneas especificadas entre @Ahk2Exe-IgnoreBegin y @Ahk2Exe-IgnoreEnd
        {
            IgnoreBegin := !(A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-IgnoreEnd")    ; continua hasta que se encuentre ";@Ahk2Exe-IgnoreEnd"
            Continue
        }

        
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos comentarios en bloque
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (A_LoopReadLine ~= "^\s*/\*")
        {
            InComment := !(A_LoopReadLine ~= "\*/\s*$")    ; ¿el comentario en bloque termina en la misma línea o no? (/* comentario */)
            Keep := SubStr(A_LoopReadLine, 3, 13) = "@Ahk2Exe-Keep"
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Directivas específicas del compilador
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-")
        {
            LineTxt := SubStr(Trim(A_LoopReadLine), 11)    ; removemos espacios al principio y final de la línea, luego eliminamos ";@Ahk2Exe-" al principio
            foo := (bar := InStr(LineTxt, A_Space)) ? SubStr(LineTxt, 1, bar - 1) : LineTxt    ; recuperamos el nombre del comando
            bar := bar ? LTrim(SubStr(LineTxt, bar)) : ""    ; recupera el valor


            ; ##############################################################################################################################################
            ; Directivas que controlan los metadatos ejecutables que se añadirán al archivo EXE resultante
            ; ##############################################################################################################################################
            If (foo = "ConsoleApp")
                ObjRawSet(Directives, "Subsystem", IMAGE_SUBSYSTEM_WINDOWS_CUI)

            Else If (foo = "UseResourceLang")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-UseResourceLang", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-UseResourceLang.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
                Else If (!(bar is "Integer") || !LCIDToLocaleName(bar))
                    Util_AddLog("ERROR", "El valor de idioma en @Ahk2Exe-UseResourceLang es inválido", Script, A_Index)
                  , Util_Error("El valor de idioma en @Ahk2Exe-UseResourceLang es inválido.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
                Else
                    ObjRawSet(Directives, "ResourceLang", Integer(bar))
            }

            Else If (foo = "PostExec")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-PostExec", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-PostExec.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
                Else
                    ObjRawSet(Directives, "PostExec", bar)
            }

            Else If (foo = "AddResource")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-AddResource", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-AddResource.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
                Else
                    ObjPush(Directives.Resources, ParseResourceStr(bar, A_Index, Script))
            }

            Else If (foo = "SetMainIcon")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-SetMainIcon", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-SetMainIcon.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
                Else If (!IS_FILE(bar := GetFullPathName(bar)))
                    Util_AddLog("ERROR", "El icono especificado en @Ahk2Exe-SetMainIcon no existe", Script, A_Index)
                  , Util_Error("El icono especificado en @Ahk2Exe-SetMainIcon no existe.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
                Else
                    ObjRawSet(Directives, "MainIcon", bar)
            }

            Else If (foo ~= "i)^Set")
            {
                If ( !StrLen(SubStr(foo, 4)) )
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-Set", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-Set.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)

                Else
                {
                    If (foo = "SetCompanyName")
                        ObjRawSet(Directives.VersionInfo, "CompanyName", bar)
                    Else If (foo = "SetFileDescription" || foo = "SetDescription")
                        ObjRawSet(Directives.VersionInfo, "FileDescription", bar)
                    Else If (foo = "SetFileVersion" || foo = "SetVersion")
                        ObjRawSet(Directives.VersionInfo, "FileVersion", bar)
                    Else If (foo = "SetProductVersion" || foo = "SetVersion")
                        ObjRawSet(Directives.VersionInfo, "ProductVersion", bar)
                    Else If (foo = "SetLegalCopyright" || foo = "SetCopyright")
                        ObjRawSet(Directives.VersionInfo, "LegalCopyright", bar)
                    Else If (foo = "SetOriginalFilename" || foo = "SetOrigFilename")
                        ObjRawSet(Directives.VersionInfo, "OriginalFilename", bar)
                    Else If (foo = "SetInternalName" || foo = "SetName")
                        ObjRawSet(Directives.VersionInfo, "InternalName", bar)
                    Else If (foo = "SetProductName" || foo = "SetName")
                        ObjRawSet(Directives.VersionInfo, "ProductName", bar)
                    Else If (foo = "SetComments")
                        ObjRawSet(Directives.VersionInfo, "Comments", bar)
                    Else
                        ObjRawSet(Directives.VersionInfo, SubStr(foo, 4), bar)    ; SetXXX
                }
            }


            ; ##############################################################################################################################################
            ; Directivas que controlan el comportamiento del script
            ; ##############################################################################################################################################
            Else If (foo = "IgnoreBegin")
            {
                If (bar == "")
                    IgnoreBegin := TRUE
                Else If (bar == "32")
                    IgnoreBegin := !g_data.Compile64
                Else If (bar == "64")
                    IgnoreBegin := g_data.Compile64
                Else
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-IgnoreBegin", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-IgnoreBegin.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)   
            }

            Else If (foo = "IgnoreEnd")
                Continue

            Else
                Util_AddLog("ERROR", "El comando de directiva @Ahk2Exe especificado es inválido", Script, A_Index)
              , Util_Error("El comando de directiva @Ahk2Exe especificado es inválido.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_UNKNOWN_DIRECTIVE_COMMAND : NO_EXIT)


            If (ERROR)
                Return FALSE
            Continue
        }

        If (A_LoopReadLine ~= "i)^\s*/\*@Ahk2Exe-Keep")
            Keep := TRUE


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Buscamos el final de secciones de continuación
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (ContSection)
        {
            If (!(A_LoopReadLine ~= "^\s*\)(`"|')"))    ; ¿no termina la sección?    )" | )'
            {
                LineTxt := A_LoopReadLine

                If (!InStr(ContSection.Options, "LTrim0"))
                    LineTxt := LTrim(LineTxt)

                If (!InStr(ContSection.Options, "RTrim0"))
                    LineTxt := RTrim(LineTxt)

                NewCode .= LineTxt . "`n"
                Continue
            }
            ContSection := "END"
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos secciones de continuación
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        Else If (A_LoopReadLine ~= "^\s*\(.*" && !InStr(A_LoopReadLine, ")"))    ; ¿la línea empieza por "(" y no contiene ningún ")" en ella?
            ContSection := { Options: Trim(SubStr(A_LoopReadLine, 2)) }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Eliminamos comentarios en línea y espacios innecesarios de la línea actual
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If ((LineTxt := ProcessLine(A_LoopReadLine, {ContSection: ContSection})) == "")
            Continue
        If (Type(LineTxt) != "String")
        {
            Util_AddLog("ERROR", "Error de sintaxis", Script, A_Index)
            Return Util_Error("Error de sintaxis.", "[" . A_Index . "] " . Script)
        }

        If (ContSection == "END")
            ContSection := FALSE


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Procesamos los #Includes
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        IncludeAgain := FALSE
        If (SubStr(LineTxt, 1, 14) = "#IncludeAgain ")    ; ¿en esta línea hay un #IncludeAgain?
            LineTxt := StrReplace(LineTxt, "#IncludeAgain ", "#Include "), IncludeAgain := TRUE
        If (SubStr(LineTxt, 1, 9) = "#Include ")    ; ¿en esta línea hay un #Include?
        {
            LineTxt := Trim(SubStr(LineTxt, 9))    ; eliminamos la palabra "#Include" del inicio y luego espacios en blanco
            DerefVar(LineTxt, "%", Script)    ; desreferenciamos las variables incluidas entre signos de porcentaje

            If (SubStr(LineTxt, 1, 2) == "*i")    ; ¿el archivo a incluir es opcional?
            {
                LineTxt := Trim(SubStr(LineTxt, 3))    ; eliminamos "*i" del inicio y luego espacios en blanco
                foo := TRUE
            }
            Else
                foo := FALSE


            ; ##############################################################################################################################################
            ; Buscamos en las carpetas de la biblioteca
            ; ##############################################################################################################################################
            If (SubStr(LineTxt, 1, 1) == "<")    ; ¿el archivo a incluir debe buscarse en la carpeta "Lib"?
            {
                If ((LineTxt := SubStr(LineTxt, 2)) == ">" || !(bar := InStr(LineTxt, ">")))    ; ¿es la sintaxis inválida?
                {
                    Util_Error("Error de sintaxis.`n#Include <" . LineTxt . "`nLínea #" . A_Index . ".", Script)
                    Return FALSE
                }
                LineTxt := Trim(SubStr(LineTxt, 1, bar-1))    ; removemos el caracter de cierre ">" y luego eliminamos espacios en blanco
                LineTxt .= Path(LineTxt).Ext == "" ? ".ahk" : ""    ; añadimos la extensión ".ahk" si no se especificó una extensión

                ObjRawSet(g_data, "Included", FALSE)
                                ; Biblioteca estándar
                For foo, bar in [ DirGetParent(FileList[1]) . "\Lib\"
                                ; Biblioteca de usuario
                                , A_MyDocuments . "\AutoHotkey\Lib\"
                                ; Biblioteca local
                                , DirGetParent(Util_GetAhkPath()) . "\Lib\" ]
                {
                    If (IS_FILE(bar . LineTxt))
                    {
                        If (!IsAlreadyIncluded(FileList, bar . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                            NewCode .= PreprocessScript(bar . LineTxt, Tree . "`n" . Script, FileList, Directives) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                        If (ERROR)
                            Return FALSE
                        ObjRawSet(g_data, "Included", TRUE)
                        Break
                    }
                }

                If (!g_data.Included)
                {
                    If (!foo)
                    {
                        Util_AddLog("ERROR", "No se a encontrado el archivo a incluir", Script, A_Index, "<" . LineTxt . ">")
                        Return Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include <" . LineTxt . ">`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INCLUDE_FILE_NOT_FOUND : NO_EXIT)
                    }
                    Else    ; omitir archivo inexistente
                        Util_AddLog("INCLUDE", "Archivo a incluir omitido", Script, A_Index, "<" . LineTxt . ">")
                }
            }


            ; ##############################################################################################################################################
            ; Buscamos en el directorio de trabajo del Script o en la ruta absoluta
            ; ##############################################################################################################################################
            Else If (InStr(LineTxt, ".") && !DirExist(LineTxt))    ; ¿es un archivo?
            {
                LineTxt := GetFullPathName(LineTxt)    ; recuperamos la ruta completa del archivo
                If (DirExist(LineTxt) || !FileExist(LineTxt))    ; ¿el archivo a incluir no existe?
                {
                    If (!foo)
                    {
                        Util_AddLog("ERROR", "No se ha encontrado el archivo a incluir", Script, A_Index, LineTxt)
                        Return Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INCLUDE_FILE_NOT_FOUND : NO_EXIT)
                    }
                    Else
                        Util_AddLog("INCLUDE", "Archivo a incluir omitido", Script, A_Index, LineTxt)
                }
                Else
                {
                    If (!IsAlreadyIncluded(FileList, LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(LineTxt, Tree . "`n" . Script, FileList, Directives) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (ERROR)
                        Return FALSE
                }
            }


            ; ##############################################################################################################################################
            ; Se especificó un directorio en #Include, cambiamos el directorio de trabajo
            ; ##############################################################################################################################################
            Else    ; es un directorio
            {
                LineTxt := GetFullPathName(LineTxt)    ; recuperamos la ruta completa del supuesto directorio
                If (!DirExist(LineTxt))    ; ¿el directorio a incluir no existe?
                {
                    Util_AddLog("INCLUDE", "Directorio a incluir no encontrado", Script, A_Index, "<" . LineTxt . ">")
                    Return Util_Error("Error en directorio #Include. El directorio a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INCLUDE_DIR_NOT_FOUND : NO_EXIT)

                }
                A_WorkingDir := LineTxt    ; cambiamos el directorio de trabajo actual
            }


            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Buscamos por el comando FileInstall
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (LineTxt ~= "i)^FileInstall")
        {
            foo := ParseFuncParams(SubStr(LineTxt, 12), Script)[1]

            If (ERROR)
            {
                Util_AddLog("ERROR", "Error de sintaxis en FileInstall", Script, A_Index,,, "FileInstall")
                Return Util_Error("Error de sintaxis en FileInstall.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_FILEINSTALL_SYNTAX : NO_EXIT)
            }

            If (!IS_FILE(foo))
            {
                    Util_AddLog("ERROR", "Archivo a incluir no encontrado", Script, A_Index, foo,, "FileInstall")
                    Return Util_Error("Error en archivo FileInstall. El archivo a incluir no existe.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_FILEINSTALL_NOT_FOUND : NO_EXIT)
            }

            ObjPush(Directives.Resources, ParseResourceStr("*10 " . foo, A_Index, Script))    ; incluimos el archivo para ser añadido en RT_RCDATA
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Añadimos la línea procesada al nuevo código
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        NewCode .= LineTxt . "`n"
    }



    ; ======================================================================================================================================================
    ; Terminar y devolver el código procesado
    ; ======================================================================================================================================================
    If (NewCode == "")    ; ¿este script no contiene datos?
        Util_AddLog("ADVERTENCIA", "El script no contiene datos", Script)
    If (Tree == "")    ; ¿estamos procesando el script principal que se va a compilar?
        Return {       Code: "; <COMPILER: v" . A_AhkVersion . ">`n" . Trim(NewCode, "`t`s`r`n")
               , Directives: Directives
               ,     Script: Script }

    Return Trim(NewCode, "`t`s`r`n")
}






/*
    Procesa una línea de texto. Se realizan las siguientes operaciones.
    Se remueven los comentarios en-línea al final de la línea. Estos son los que comienzan con el caracter ';'.
    Se remueven otros tipos de comentarios actualmente no soportados por AHK.
    Se quita espacios innecesarios al inicio y final de la línea y entre operadores.
    Se quitan los caracteres de escape '`' innecesarios en las cadenas, como por ejemplo '`x' --> 'x'. Los literales '``' son detectados correctamente.
    Se reemplaza en las cadenas "`t" por A_Tab para ocupar solo 1 caracter.
    Se reemplaza en las cadenas "`s" por A_Space para ocupar solo 1 caracter.
    Se reemplaza "OR" y "AND" en expresiones por su equivalente "||" y "&&" respectivamente.
    Return:
         String = El procesado se ha realizado con éxito y no ha ocurrido ningún error.
        Integer = Error de sintaxis. Actualmente este valor no tiene un significado, es siempre 1.
    Por hacer:
        Detectar A_PtrSize y optimizar el código removiendolo y dejando solo el valor dependiendo la versión de AHK que se va a compilar.
        Remover por completo los espacios innecesarios.
    Nota:
        Gran parte del procesamiento aquí realizado es "experimental" y no se ha probado exaustivamente. Podría dejar el código con errores al compilar.
        Este procesamiento relentiza considerablemente la compilación, aunque a costo de reducir el tamaño del archivo compilado, y en ciertos casos favorecer el rendimiento (lo más importante).
          El tiempo de compilación en AHK no es demasiado importante, debido a que normalmente no es necesario compilar el código para probarlo. Una vez compilado, debería funcionar correctamente.
        Durante el procesado, se tienen en cuenta los siguientes factores (en orden descentente de importancia):
            1. Mejorar el rendimiento, por más insignificante que éste sea. Este es el objetivo más importante, debido a la lentitud extrema de los lenguajes interpretados como lo es AHK.
            2. Lograr reducir al máximo el tamaño del código, quitando espacios y utilizando equivalentes más cortos en expresiones.
            3. Ofuscar el código (hacerlo lo más confuso posible) sin perdidas de rendimiento ni aumento del tamaño del código en lo absoluto.
*/
;MsgBox ProcessLine("Return -1 +  3 (1) . '`"X ' . /*Comment*/ expr1 OR expr2 AND expr3 `; Comment", {})   ; return -1+3 (1) '"X ' expr1||expr2&&expr3
;MsgBox ProcessLine("expr, expr,  expr", {})    ; expr,expr,expr
ProcessLine(Txt, Data)
{
    Static EscSequ := ";``:nrbtsvaf`"'{}^!+#"    ; por algún motivo extraño (bug?) "``;" se transforma en ";" (imagino que tendra algo que ver con " ;" que debe especificarse "`;")
           , ERROR := 1

    Local     Escape := FALSE
        ,       Char := StrSplit(Txt := Trim(Txt))
        ,  InComment := FALSE
        ,       Skip := 0

    Local NewTxt := ""
    VarSetCapacity(NewTxt, ObjLength(Char) * 2)

    Loop (ObjLength(Char))
    {
        If (InStr("`t`s", Skip) && !(Skip := 0))    ; Skip x1
            Continue

        If (Skip ~= "^R")    ; Skip \s{2,}
        {
            If (Skip ~= "=$" && Char[A_Index] == "=")
            {
                NewTxt .= "="
                Continue
            }
            If (Char[A_Index] ~= "\s")
                Continue
            Skip := 0
        }

        If (Skip-- > 0)
            Continue

        If (InComment)    ; expr/*comment*/expr
        {
            If (Char[A_Index] == "*" && Char[A_Index+1] == "/")
            {
                NewTxt := RTrim(NewTxt) . (Char[A_Index+2] ~= "\s" ? "" : A_Space)    ; corrige espacios en los casos "expr/*comment*/expr" y "expr /*comment*/ expr"
                Skip := 1    ; omitir "/"
                InComment := FALSE
            }
            Continue
        }

        ; aquí se procesan las cadenas de caracteres
        If (Char[0] == "`"" || Char[0] == "'")    ; expr "string" 'string' expr
        {
            If (Data.ContSection || (!Escape && Char[A_Index] == Char[0]))
                Char[0] := "", Data.ContSection := FALSE
            If (!Escape && Char[A_Index] == "``")
                NewTxt .= InStr(EscSequ, Char[A_Index+1], TRUE) ? (Char[A_Index+1] == "t" ? Skip:=A_Tab    ; "`x`n" --> "x`n"  ||  "`t" --> A_Tab  ||  "`s" --> A_Space
                                                                                          : Char[A_Index+1] == "s" ? Skip:=A_Space 
                                                                                                                   : Char[A_Index])
                                                                : ""
            Else
                NewTxt .= Char[A_Index]
            Escape := !Escape && Char[A_Index] == "``" && Skip != A_Tab
            Continue
        }

        ; todo aquí abajo procesa las expresiones
        ;Char[A_Index] := Format("{:L}", Char[A_Index])    ; transforma todos los caracteres a minúsculas

        If (Char[A_Index] == ";")    ; foo ;comment
        {
            If (A_Index != 1 && !(SubStr(Txt, A_Index-1, 1) ~= "\s"))    ; expr;comment  ||  "string";comment
                Return ERROR
            Break
        }

        If (Char[A_Index] == "/" && Char[A_Index+1] == "*")    ; expr/*comment*/expr
        {
            InComment := TRUE
            Continue
        }

        If (Char[A_Index] ~= "\s")
        {
            If (Char[A_Index+1] ~= "\s")    ; omitimos más de un espacio en expresiones  |  expr{space xn>1}expr --> expr{space x1}expr
                Continue

            Else If (Char[A_Index+1] == "." && Char[A_Index+2] ~= "\s")    ; expr . expr --> expr expr
            {
                NewTxt .= A_Space
                Skip := 2    ; omitimos ". "
                Continue
            }

            Else If (Char[A_Index+1] = "O" && Char[A_Index+2] = "R" && Char[A_Index+3] ~= "\s")    ; expr OR expr --> expr||expr
            {
                NewTxt .= "||"
                Skip := 3    ; omitimos "OR "
                Continue
            }

            Else If (Char[A_Index+1] = "A" && Char[A_Index+2] = "N" && Char[A_Index+3] = "D" && Char[A_Index+4] ~= "\s")    ; expr AND expr --> expr&&expr
            {
                NewTxt .= "&&"
                Skip := 4    ; omitimos "AND "
                Continue
            }
        }

        If (InStr(".~:=", Char[A_Index]) && Char[A_Index+1] == "=")    ; expr .= expr --> expr.=expr
            NewTxt := RTrim(NewTxt), Skip := "R="

        Else If (InStr("+-*/^&|", Char[A_Index]))    ; expr + expr --> expr+expr
        {
            Char[-1] := RTrim(SubStr(Txt, 1, A_Index-1))
            If (RegExReplace(Char[-1], "\w") != "" || Char[-1] ~= "\s")    ; evita "Return -1" --> "Return-1" || "XXX -1" --> "XXX-1" al comienzo de la línea siendo X letras o números (una función sin parentesis)
                                                                           ; esto tiene una limitante, y es que si se utiliza una función sin parentesis que contiene por lo menos una letra que no sea del alfabeto
                                                                           ; inglés generará un código con errores; Como por ejemplo "FuncionÑ -1" --> "FuncionÑ-1" que es inválido
                NewTxt := RTrim(NewTxt), Skip := "R"
        }

        Else If (InStr(",", Char[A_Index]))
        {
            If (Char[A_Index+1] ~= "\s")    ; expr, expr --> expr,expr
                Skip := "R"    ; expr,{space xn>0} --> expr,{no space}
        }

        NewTxt .= Char[Escape := 0] := Char[A_Index]
    }

    Return Trim(NewTxt)
}





IsAlreadyIncluded(FileList, AhkFile, IncludeAgain)
{
    If (!IncludeAgain)    ; ¿no permitir múltiples inclusiones del mismo archivo?
        Loop (ObjLength(FileList))
            If (FileList[A_Index] = AhkFile)
                Return TRUE
    Return FALSE
}





class TempWorkingDir
{
    __New(WorkingDir)
    {
        ; nota 1: diferencias entre A_ScriptDir, A_WorkingDir y A_InitialWorkingDir
        ;   A_ScriptDir siempre es el directorio del script (compilado o no)
        ;   A_WorkingDir es el directorio de trabajo actual del script, por defecto al iniciar un script es el mismo que A_ScriptDir
        ;   A_InitialWorkingDir es el directorio de trabajo "especificado por/de la" la aplicación que inició nuestro script
        ; nota 2: el directorio de trabajo es aquel directorio que se utilizará cuando se especifique una ruta no absoluta en cualquier función que espere una ruta de archivo/carpeta
        ObjRawSet(this, "OldWorkingDir", A_WorkingDir)
        A_WorkingDir := WorkingDir
    }
    __Delete()
    {
        A_WorkingDir := this.OldWorkingDir
    }
}





QuickParse(Script)    ; analiza rápidamente el Script a compilar para recuperar ciertos datos
{
    If (DirExist(Script) || !FileExist(Script))
        Return FALSE
    WorkingDir := new TempWorkingDir(DirGetParent(Script))

    Local Data := {VerInfo: ParseVersionInfo(Script), MainIcon: ""}
        ,  foo := "" ;, bar := ""
        ,  Ext := ""

    Loop Read, Script
    {
        If (A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-SetMainIcon")
        {
            If (!DirExist(foo := Trim(SubStr(LTrim(A_LoopReadLine), 22))) && FileExist(foo))
            {
                foo := GetFullPathName(foo), SplitPath(foo,,, Ext)
                If (Ext = "ico")
                    ObjRawSet(Data, "MainIcon", foo)
            }
        }
    }

    Return Data
}

ParseVersionInfo(Script)
{
    Local  LineTxt := "", Name := "", Value := ""
        , VerInfo2 := {}, Pos := 0

    Loop Read, Script
    {
        LineTxt := Trim(A_LoopReadLine)
        If (SubStr(LineTxt, 1, 13) = ";@Ahk2Exe-Set")
            If (Pos := InStr(LineTxt := SubStr(LineTxt, 14), A_Space))
                If (ObjHasKey(VerInfo, Name := SubStr(LineTxt, 1, Pos-1)))
                    Loop ObjLength(VerInfo[Name])
                        ObjRawSet(VerInfo2, VerInfo[Name][A_Index], Trim(SubStr(LineTxt, StrLen(Name)+1)))
    }

    Return VerInfo2
}





DerefVar(ByRef String, Chr, Script)
{
    String := StrReplace(String, Chr .       "A_ScriptDir" . Chr,         A_WorkingDir)
    String := StrReplace(String, Chr .         "A_AppData" . Chr,            A_AppData)
    String := StrReplace(String, Chr .   "A_AppDataCommon" . Chr,      A_AppDataCommon)
    String := StrReplace(String, Chr .        "A_LineFile" . Chr,               Script)
    String := StrReplace(String, Chr .         "A_Desktop" . Chr,            A_Desktop)
    String := StrReplace(String, Chr .   "A_DesktopCommon" . Chr,      A_DesktopCommon)
    String := StrReplace(String, Chr .     "A_MyDocuments" . Chr,        A_MyDocuments)
    String := StrReplace(String, Chr .    "A_ProgramFiles" . Chr,       A_ProgramFiles)
    String := StrReplace(String, Chr .          "A_WinDir" . Chr,             A_WinDir)
    String := StrReplace(String, Chr .            "A_Temp" . Chr,               A_Temp)
    String := StrReplace(String, Chr .       "A_ScriptDir" . Chr, DirGetParent(String))
    String := StrReplace(String, Chr .      "A_ScriptName" . Chr,      Path(String).FN)
    String := StrReplace(String, Chr .       "A_OSVersion" . Chr,          A_OSVersion)
    String := StrReplace(String, Chr .       "A_Is64bitOS" . Chr,          A_Is64bitOS)
    String := StrReplace(String, Chr .        "A_Language" . Chr,           A_Language)
    String := StrReplace(String, Chr .    "A_ComputerName" . Chr,       A_ComputerName)
    String := StrReplace(String, Chr .        "A_UserName" . Chr,           A_UserName)
    String := StrReplace(String, Chr .       "A_StartMenu" . Chr,          A_StartMenu)
    String := StrReplace(String, Chr . "A_StartMenuCommon" . Chr,    A_StartMenuCommon)
    String := StrReplace(String, Chr .        "A_Programs" . Chr,           A_Programs)
    String := StrReplace(String, Chr .  "A_ProgramsCommon" . Chr,     A_ProgramsCommon)
    String := StrReplace(String, Chr .         "A_Startup" . Chr,            A_Startup)
    String := StrReplace(String, Chr .   "A_StartupCommon" . Chr,      A_StartupCommon)

    Return String
}





ParseFuncParams(Params, Script)    ; FileInstall Source, Dest
{
    Local Arr := []
        , prm := 1
        , foo := "", bar := ""

    Loop Parse, Params
    {
        If (foo != "")
        {
            If (A_LoopField == foo)
                foo := ""
            Else
                Arr[prm] .= A_LoopField
        }

        Else IF (bar != "")
        {
            If (InStr("`t`s,", A_LoopField))
                Arr[prm] .= DerefVar(bar, "", Script), bar := "", prm += A_LoopField == ","
            Else
                bar .= A_LoopField
        }

        Else If (A_LoopField == "`"" || A_LoopField == "'")
            foo := A_LoopField

        Else If (A_LoopField == ",")
            ++prm

        Else If (!InStr("`t`s.", A_LoopField))
            bar := A_LoopField
    }

    If (bar != "")
        Arr[prm] .= DerefVar(bar, "", Script)

    Return Arr
}





ParseResourceStr(String, LineNum, Script)    ;@Ahk2Exe-AddResource *[int/str type/"type"] [str filename], [int/str resname]
{
    Static CommonResTypes := { bmp: 2, dib: 2              ; RT_BITMAP
                             , cur: 1                      ; RT_CURSOR
                             , ico: 3                      ; RT_ICON (el nombre del recurso no debe ser 159 ya que es utilizado para el icono por defecto)
                             , htm: 23, html: 23, mht: 23  ; RT_HTML
                             , manifest: 24                ; RT_MANIFEST
                             ; otros
                             , png: ".PNG" }

    Local      Obj := { ResType: "", File: "", ResName: "" }
        ,      foo := "" ;, bar := ""
        , FileName := "", Ext := ""

    If (String ~= "^\*")
    {
        If (SubStr(String, 2, 1) == "`"")
        {
            If (!(foo := InStr(String, "`"",, 3)) || (Obj.ResType := SubStr(String, 3, foo - 3)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis es inválida", Script, LineNum, "@Ahk2Exe-AddResource",, Obj.File)
                Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nLa sintaxis es inválida.`nLínea #" . LineNum . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
            }
            String := LTrim(SubStr(String, foo + 1))
        }
        Else
        {
            If (!(foo := InStr(String, A_Space,, 2)) || (Obj.ResType := SubStr(String, 2, foo - 2)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis es inválida", Script, LineNum, "@Ahk2Exe-AddResource",, Obj.File)
                Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nLa sintaxis es inválida.`nLínea #" . LineNum . ".", Script, CMDLN ? ERROR_INVALID_DIRECTIVE_SYNTAX : NO_EXIT)
            }
            String := LTrim(SubStr(String, foo + 1))
        }
    }

    If (foo := InStr(String, ","))
    {
        Obj.ResName := LTrim(SubStr(String, foo + 1))
        String := RTrim(SubStr(String, 1, foo - 1))
    }

    SplitPath(String, FileName,, Ext)
    If (Obj.ResName == "")
        Obj.ResName := FileName

    If (Obj.ResType == "")
        Obj.ResType := ObjHasKey(CommonResTypes, Ext) ? CommonResTypes[Ext] : RT_RCDATA

    If (DirExist(Obj.File := String) || !FileExist(Obj.File))
    {
        Util_AddLog("ERROR", "El archivo especificado es inválido", Script, LineNum, "@Ahk2Exe-AddResource",, Obj.File)
        Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nEl archivo especificado no existe.`nLínea #" . LineNum . ".", Script, CMDLN ? ERROR_RESOURCE_FILE_NOT_FOUND : NO_EXIT)
    }

    Return Obj
}
