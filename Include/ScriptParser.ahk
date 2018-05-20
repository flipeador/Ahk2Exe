PreprocessScript(Script, Tree := "", FileList := "", Directives := "")
{
    If (FileList == "")
    {
        Util_AddLog("INFO", "Se ha iniciado el procesado del script", Script)

        FileList := []    ; almacena una lista con todos los archivos incluidos (para evitar varias inclusiones de un mismo archivo)
        ; almacena los archivos a añadir luego de la compilación al archivo EXE resultante y otras configuraciones
        Directives := {         MainIcon: g_data.IcoFile
                      ,        Subsystem: IMAGE_SUBSYSTEM_WINDOWS_GUI
                      ,     ResourceLang: SUBLANG_ENGLISH_US
                      ,         PostExec: ""
                      ,      VersionInfo: {      FileVersion: FileGetVersion(g_data.BinFile)    ; estos son los valores por defecto de la información de versión
                                          ,   ProductVersion: FileGetVersion(g_data.BinFile)
                                          , OriginalFilename: PATH(Script).FN
                                          ,         Comments: "Compiled with https://github.com/flipeador/Ahk2Exe" }
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
        Util_AddLog("ERROR", "No se ha encontrado el script", Script)
        Return Util_Error("El archivo de código fuente AHK no existe.", Script, CMDLN(ERROR_CANNOT_OPEN_SCRIPT))
    }

    If (!FileOpen(Script, "r"))    ; comprobamos permisos de lectura
    {
        Util_AddLog("ERROR", "No se ha podido abrir el Script para lectura", Script)
        Return Util_Error("No se ha podido abrir el Script para lectura.", Script, CMDLN(ERROR_CANNOT_OPEN_SCRIPT))
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

        If (IgnoreBegin)    ; ignorar líneas especificadas entre @Ahk2Exe-IgnoreBegin[32/64] y @Ahk2Exe-IgnoreEnd[32/64]
        {
            If (A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-IgnoreEnd" . IgnoreBegin.Bits)
                IgnoreBegin := FALSE

            Else If (!(A_LoopReadLine ~= "^\s*;") && IgnoreBegin.Lines != "" && !--IgnoreBegin.Lines)
                IgnoreBegin := FALSE

            Continue
        }

        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos comentarios en bloque
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (A_LoopReadLine ~= "^\s*/\*")
        {
            InComment := !(A_LoopReadLine ~= "\*/\s*$")    ; ¿el comentario en bloque termina en la misma línea o no? (/* comentario */)
            Keep := A_LoopReadLine ~= "i)^\s*/\*@Ahk2Exe-Keep"
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos secciones de continuación var:="`n(`n)"
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

                NewCode .= ( InStr(ContSection.Options, "C") ? RegExReplace(LineTxt, "\s+;((?!'|`").)*$") : LineTxt ) . "`n"    ; C = Comments (si se permite comentarios los quitamos con regex)
                Continue
            }
            ContSection := "*"
        }

        Else If (A_LoopReadLine ~= "^\s*\(((?!\)).)*$")    ; ¿la línea empieza por "(" y no contiene ningún ")" en ella?
            ContSection := { Options: Trim(SubStr(A_LoopReadLine, 2)) }


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
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-UseResourceLang.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else If (!(bar is "Integer") || !LCIDToLocaleName(bar))
                    Util_AddLog("ERROR", "El valor de idioma en @Ahk2Exe-UseResourceLang es inválido", Script, A_Index)
                  , Util_Error("El valor de idioma en @Ahk2Exe-UseResourceLang es inválido.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(Directives, "ResourceLang", Integer(bar))
            }

            Else If (foo = "PostExec")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-PostExec", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-PostExec.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(Directives, "PostExec", bar)
            }

            Else If (foo = "AddResource")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-AddResource", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-AddResource.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjPush(Directives.Resources, ParseResourceStr(bar, Script, A_Index))
            }

            Else If (foo = "SetMainIcon")
            {
                If (!g_data.IgnoreSetMainIcon)
                {
                    If (bar == "")
                        Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-SetMainIcon", Script, A_Index)
                      , Util_Error("Uso inválido de la directiva @Ahk2Exe-SetMainIcon.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                    Else If (!IS_FILE(bar := GetFullPathName(bar)))
                        Util_AddLog("ERROR", "El icono especificado en @Ahk2Exe-SetMainIcon no existe", Script, A_Index)
                      , Util_Error("El icono especificado en @Ahk2Exe-SetMainIcon no existe.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                    Else
                        ObjRawSet(Directives, "MainIcon", bar)
                }
            }

            Else If (foo ~= "i)^Set") ;.+
            {
                If ( !StrLen(SubStr(foo, 4)) )
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-Set", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-Set.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))

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
            Else If (foo ~= "i)^IgnoreBegin(32|64)?$")
            {
                bar := StrSplit(bar, A_Space)[1]    ; @Ahk2Exe-IgnoreBegin Lines Comment
                If (bar != "" && (!(bar is "Integer") || bar < 1 || bar > 1000000))
                    Util_AddLog("ERROR", "El parámetro en @Ahk2Exe-IgnoreBegin no es correcto", Script, A_Index)
                  , Util_Error("El parámetro en @Ahk2Exe-IgnoreBegin no es correcto.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))

                Else If (foo = "IgnoreBegin")
                    IgnoreBegin := {  Bits: "", Lines: bar == "" ? "" : Integer(bar) }
                Else If (foo = "IgnoreBegin32" && !g_data.Compile64)
                    IgnoreBegin := {  Bits: "32", Lines: bar == "" ? "" : Integer(bar) }
                Else If (foo = "IgnoreBegin64" && g_data.Compile64)
                    IgnoreBegin := {  Bits: "64", Lines: bar == "" ? "" : Integer(bar) }
            }

            Else If (foo ~= "i)^IgnoreEnd(32|64)?$")
                Continue

            Else If (foo ~= "i)^Keep(32|64)?$")
            {
                If (bar == "" || foo ~= "^;")    ; bar == "" || line == ;@Ahk2Exe-Keep ;comment
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-Keep", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-Keep.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))

                Else If (foo = "Keep")
                    NewCode .= RegExReplace(bar, "\s+;((?!'|`").)*$") . "`n"
                Else If (foo = "Keep32" && !g_data.Compile64)
                    NewCode .= RegExReplace(bar, "\s+;((?!'|`").)*$") . "`n"
                Else If (foo = "Keep64" && g_data.Compile64)
                    NewCode .= RegExReplace(bar, "\s+;((?!'|`").)*$") . "`n"
            }

            Else If (foo = "Bin")
            {
                If (!g_data.IgnoreBinFile)
                {
                    ObjRawSet(g_data, "BinFile", Util_CheckBinFile(bar, foo))
                    ObjRawSet(g_data, "Compile64", foo == SCS_64BIT_BINARY)

                    If (!g_data.BinFile)
                        Util_AddLog("ERROR", "El archivo BIN especificado en @Ahk2Exe-Bin no existe", Script, A_Index)
                      , Util_Error("El archivo BIN especificado en @Ahk2Exe-Bin no existe.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_BIN_FILE_NOT_FOUND))
                }
            }

            Else
                Util_AddLog("ERROR", "El comando de directiva @Ahk2Exe especificado es inválido", Script, A_Index)
              , Util_Error("El comando de directiva @Ahk2Exe especificado es inválido.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_UNKNOWN_DIRECTIVE_COMMAND))


            If (ERROR)
                Return FALSE
            Continue
        }


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
        ContSection := ContSection == "*" ? FALSE : ContSection


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Procesamos los #Includes
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        IncludeAgain := FALSE
        If (LineTxt ~= "i)^#IncludeAgain\s")
            LineTxt := RegExReplace(LineTxt, "i)^#IncludeAgain\s*", "#Include "), IncludeAgain := TRUE
        If (LineTxt ~= "i)^#Include\s")
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
            If (LineTxt[1] == "<")    ; ¿el archivo a incluir debe buscarse en la carpeta "Lib"?
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
                        Util_AddLog("ERROR", "No se a encontrado el archivo a incluir", Script, A_Index)
                        Return Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include <" . LineTxt . ">`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INCLUDE_FILE_NOT_FOUND))
                    }
                    Else    ; omitir archivo inexistente
                        Util_AddLog("INCLUDE", "Archivo a incluir omitido", Script, A_Index)
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
                        Util_AddLog("ERROR", "No se ha encontrado el archivo a incluir", Script, A_Index)
                        Return Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INCLUDE_FILE_NOT_FOUND))
                    }
                    Else
                        Util_AddLog("INCLUDE", "Archivo a incluir omitido", Script, A_Index)
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
                    Util_AddLog("INCLUDE", "Directorio a incluir no encontrado", Script, A_Index)
                    Return Util_Error("Error en directorio #Include. El directorio a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . A_Index . ".", Script,  CMDLN(ERROR_INCLUDE_DIR_NOT_FOUND))

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
                Util_AddLog("ERROR", "Error de sintaxis en FileInstall", Script, A_Index)
                Return Util_Error("Error de sintaxis en FileInstall.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_FILEINSTALL_SYNTAX))
            }

            If (!IS_FILE(foo))
            {
                    Util_AddLog("ERROR", "Archivo a incluir no encontrado", Script, A_Index)
                    Return Util_Error("Error en archivo FileInstall. El archivo a incluir no existe.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_FILEINSTALL_FILE_NOT_FOUND))
            }

            ObjPush(Directives.Resources, ParseResourceStr("*10 " . foo, Script, A_Index))    ; 10 = RT_RCDATA
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
        ,  InComment := FALSE
        ,       Skip := 0
        ,       Char := []

    Local NewTxt := ""
    VarSetCapacity(NewTxt, StrLen(Txt := Trim(Txt)) * 2)

    Loop ( StrLen(Txt) )
    {
        If (InStr("`t`s", Skip) && !(Skip := 0))    ; Skip x1
            Continue

        If (Skip ~= "^R")    ; Skip \s{2,}
        {
            If (Skip ~= "=$" && Txt[A_Index] == "=")
            {
                NewTxt .= "="
                Continue
            }
            If (Txt[A_Index] ~= "\s")
                Continue
            Skip := 0
        }

        If (Skip-- > 0)
            Continue

        If (InComment)    ; expr/*comment*/expr
        {
            If (Txt[A_Index] == "*" && Txt[A_Index+1] == "/")
            {
                NewTxt := RTrim(NewTxt) . (Txt[A_Index+2] ~= "\s" ? "" : A_Space)    ; corrige espacios en los casos "expr/*comment*/expr" y "expr /*comment*/ expr"
                Skip := 1    ; omitir "/"
                InComment := FALSE
            }
            Continue
        }

        ; aquí se procesan las cadenas de caracteres
        If (Char[0] == "`"" || Char[0] == "'")    ; expr "string" 'string' expr
        {
            If (Data.ContSection || (!Escape && Txt[A_Index] == Char[0]))
                Char[0] := "", Data.ContSection := FALSE
            If (!Escape && Txt[A_Index] == "``")
                NewTxt .= InStr(EscSequ, Txt[A_Index+1], TRUE) ? (Txt[A_Index+1] == "t" ? Skip:=A_Tab    ; "`x`n" --> "x`n"  ||  "`t" --> A_Tab  ||  "`s" --> A_Space
                                                                                          : Txt[A_Index+1] == "s" ? Skip:=A_Space 
                                                                                                                   : Txt[A_Index])
                                                                : ""
            Else
                NewTxt .= Txt[A_Index]
            Escape := !Escape && Txt[A_Index] == "``" && Skip != A_Tab
            Continue
        }

        ; todo aquí abajo procesa las expresiones
        ;Txt[A_Index] := Format("{:L}", Txt[A_Index])    ; transforma todos los caracteres a minúsculas

        If (Txt[A_Index] == ";")    ; foo ;comment
        {
            If (A_Index != 1 && !(SubStr(Txt, A_Index-1, 1) ~= "\s"))    ; expr;comment  ||  "string";comment
                Return ERROR
            Break
        }

        If (Txt[A_Index] == "/" && Txt[A_Index+1] == "*")    ; expr/*comment*/expr
        {
            InComment := TRUE
            Continue
        }

        If (Txt[A_Index] ~= "\s")
        {
            If (Txt[A_Index+1] ~= "\s")    ; omitimos más de un espacio en expresiones  |  expr{space xn>1}expr --> expr{space x1}expr
                Continue

            Else If (Txt[A_Index+1] == "." && Txt[A_Index+2] ~= "\s")    ; expr . expr --> expr expr
            {
                NewTxt .= A_Space, Skip := 2    ; omitimos ". "
                Continue
            }

            Else If (Txt[A_Index+1,3] ~= "i)OR\s")    ; expr OR expr --> expr||expr
            {
                NewTxt .= "||", Skip := 3    ; omitimos "OR "
                Continue
            }

            Else If (Txt[A_Index+1,4] ~= "i)AND\s")    ; expr AND expr --> expr&&expr
            {
                NewTxt .= "&&", Skip := 4    ; omitimos "AND "
                Continue
            }
        }

        If (InStr(".~:=", Txt[A_Index]) && Txt[A_Index+1] == "=")    ; expr .= expr --> expr.=expr
            NewTxt := RTrim(NewTxt), Skip := "R="

        Else If (InStr("+-*/^&|", Txt[A_Index]))    ; expr + expr --> expr+expr
        {
            Char[-1] := RTrim(SubStr(Txt, 1, A_Index-1))
            If (RegExReplace(Char[-1], "\w") != "" || Char[-1] ~= "\s")    ; evita "Return -1" --> "Return-1" || "XXX -1" --> "XXX-1" al comienzo de la línea siendo X letras o números (una función sin parentesis)
                                                                           ; esto tiene una limitante, y es que si se utiliza una función sin parentesis que contiene por lo menos una letra que no sea del alfabeto
                                                                           ; inglés generará un código con errores; Como por ejemplo "FuncionÑ -1" --> "FuncionÑ-1" que es inválido
                NewTxt := RTrim(NewTxt), Skip := "R"
        }

        Else If (InStr(",", Txt[A_Index]))
        {
            If (Txt[A_Index+1] ~= "\s")    ; expr, expr --> expr,expr
                Skip := "R"    ; expr,{space xn>0} --> expr,{no space}
        }

        NewTxt .= Char[Escape := 0] := Txt[A_Index]
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
    If (!IS_FILE(Script) || !FileOpen(Script, "r"))
        Return FALSE

    Local      WD := new TempWorkingDir( DirGetParent(Script) )
        ,    Data :=  { MainIcon: "", BinFile: "" }
        , LineTxt := ""

    Loop Read, Script
    {
        LineTxt := Trim(A_LoopReadLine)
        If (LineTxt ~= "i)^;@Ahk2Exe-SetMainIcon")
            ObjRawSet(Data, "MainIcon", GetFullPathName(LTrim(SubStr(LineTxt, 22))))
        Else If (LineTxt ~= "i)^;@Ahk2Exe-Bin")
            ObjRawSet(Data, "BinFile", PATH(LTrim(SubStr(LineTxt, 14), A_ScriptDir)).FNNE)
    }

    Return Data
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





ParseResourceStr(String, Script, Line)    ;@Ahk2Exe-AddResource [*Type] FileName [, ResName] [, LangID]
{
    Static ResTypes := { cur: 1                      ; RT_CURSOR
                       , bmp: 2, dib: 2              ; RT_BITMAP
                       , ico: 3                      ; RT_ICON
                       , htm: 23, html: 23, mht: 23  ; RT_HTML
                       , manifest: 24                ; RT_MANIFEST
                       ; otros
                       , png: ".PNG" }

    Local Data := { ResType: "", FileName: "", ResName: "", LangID: "" }
        ,  Pos := 0, Skip := 0, Char := [""]
        ,  Key := ["FileName", "ResName", "LangID"]

    If (String ~= "^\*")
    {
        If (String ~= "^\*`"")
        {
            If (!(Pos := InStr(String, "`"",, 3)) || (Data.ResType := SubStr(String, 3, Pos - 3)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis en @Ahk2Exe-AddResource no es correcta", Script, Line)
                Return Util_Error("La sintaxis en @Ahk2Exe-AddResource no es correcta.`nLínea: " . Line ".", Script)
            }
        }
        Else
        {
            If (!(Pos := InStr(String, A_Space,, 2)) || (Data.ResType := SubStr(String, 2, Pos - 2)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis en @Ahk2Exe-AddResource no es correcta", Script, Line)
                Return Util_Error("La sintaxis en @Ahk2Exe-AddResource no es correcta.`nLínea: " . Line ".", Script)
            }
        }
        String := LTrim(SubStr(String, Pos + 1))
    }

    Pos := 1
    Loop Parse, String
    {
        If ((Skip && A_LoopField ~= "\s") || Skip-- > 0)
            Continue
        If (A_LoopField == ",")
            ++Pos
        Else If (A_LoopField == "``")
            Skip := 1, Data[Key[Pos]] .= SubStr(String, A_Index+1, 1)
        Else
         Data[Key[Pos]] .= A_LoopField
    }

    If (!IS_FILE(Data.FileName))
    {
        Util_AddLog("ERROR", "El archivo especificado en @Ahk2Exe-AddResource no existe", Script, Line)
        Return Util_Error("El archivo especificado en @Ahk2Exe-AddResource no existe.`nLínea: " . Line ".", Script)
    }

    If (Data.LangID != "" && (!(Data.LangID is "Integer") || !LCIDToLocaleName(Data.LangID)))
    {
        Util_AddLog("ERROR", "El código de idioma especificado en @Ahk2Exe-AddResource es inválido", Script, Line)
        Return Util_Error("El código de idioma especificado en @Ahk2Exe-AddResource es inválido.`nLínea: " . Line ".", Script)
    }

    Local Path := PATH(Data.FileName)
    ObjRawSet(Data, "ResName", Data.ResName == "" ? (Path.Ext = "manifest" ? "1" : Path.FN) : Data.ResName)
    ObjRawSet(Data, "ResType", Data.ResType == "" ? (ObjHasKey(ResTypes, Path.Ext) ? ResTypes[Path.Ext] : RT_RCDATA) : Data.ResType)

    ;MsgBox "ResType: _" . Data.ResType . "_`nFileName: _" . Data.FileName . "_`nResName: _" . Data.ResName . "_`nLangID: _" . Data.LangID . "_"
    Return Data
}
