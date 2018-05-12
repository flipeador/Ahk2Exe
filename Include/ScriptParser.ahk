﻿PreprocessScript(Script, Tree := "", FileList := "", Directives := "")
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
                      ,      CompanyName: ""
                      ,  FileDescription: ""
                      ,      FileVersion: A_AhkVersion
                      ,   ProductVersion: A_AhkVersion
                      ,   LegalCopyright: ""
                      , OriginalFilename: SubStr(Script, InStr(Script, "\",, -1)+1)
                      ,     InternalName: ""
                      ,      ProductName: ""
                      ,         Comments: ""
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

    VarSetCapacity(NewCode, FileGetSize(Script))    ; establecemos la capacidad de la variable que amlacenará el nuevo código, para mejorar el rendimiento
    VarSetCapacity(LineTxt, 65534 * 2)    ; capacidad de la variable que almacenará el texto de la línea actual

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


            If (Tree == "")    ; ¿estamos en el script principal?
            {
                ; ##############################################################################################################################################
                ; Directivas que controlan los metadatos ejecutables que se añadirán al archivo EXE resultante
                ; ##############################################################################################################################################
                If (foo = "SetMainIcon")    ; anula el ícono EXE personalizado utilizado para la compilación.
                {
                    If (bar == "")    ; ¿no se especificó nada luego del comando?
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-SetMainIcon.`nDebe especificar un icono.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
                    Else If (DirExist(bar := GetFullPathName(bar)) || !FileExist(bar))
                        Util_Error("Error en la directiva @Ahk2Exe-SetMainIcon.`nEl archivo icono especificado no existe.`n" . bar . "`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
                    Else
                        Directives.MainIcon := bar
                }

                Else If (foo = "ConsoleApp")    ; cambia el subsistema ejecutable al modo consola
                    Directives.Subsystem := IMAGE_SUBSYSTEM_WINDOWS_CUI

                Else If (foo = "UseResourceLang")    ; cambia el lenguaje de recursos utilizado por @Ahk2Exe-AddResource
                {
                    If (bar == "")
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-UseResourceLang.`nDebe especificar un código de idioma.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
                    Else If (!(bar is "Integer"))
                        Util_Error("Error en la directiva @Ahk2Exe-UseResourceLang.`nEl valor de idioma especificado es inválido.`n" . bar . "`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
                    Else
                        Directives.ResourceLang := bar
                }

                Else If (foo = "PostExec")    ; especifica un comando que se ejecutará después de una compilación exitosa
                {
                    If (bar == "")
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-PostExec.`nDebe especificar un comando ha ejecutar después de la compilación.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
                    Else
                        Directives.PostExec := bar
                }

                Else If (foo = "AddResource")
                {
                    If (bar == "")
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-AddResource.`nDebe especificar un recurso ha añadir al archivo EXE resultante.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
                    Else
                        ObjPush(Directives.Resources, ParseResourceStr(bar, A_Index, Script))
                }

                Else    ; información de la versión
                {
                    If (foo = "SetCompanyName")
                        Directives.CompanyName := bar
                    If (foo = "SetFileDescription" || foo = "SetDescription")
                        Directives.FileDescription := bar
                    If (foo = "SetFileVersion" || foo = "SetVersion")
                        Directives.FileVersion := bar
                    If (foo = "SetProductVersion" || foo = "SetVersion")
                        Directives.ProductVersion := bar
                    If (foo = "SetLegalCopyright" || foo = "SetCopyright")
                        Directives.LegalCopyright := bar
                    If (foo = "SetOriginalFilename" || foo = "OrigFilename")
                        Directives.OriginalFilename := bar
                    If (foo = "SetInternalName" || foo = "SetName")
                        Directives.InternalName := bar
                    If (foo = "SetProductName" || foo = "SetName")
                        Directives.ProductName := bar
                    If (foo = "SetComments")
                        Directives.Comments := bar
                }
            }


            ; ##############################################################################################################################################
            ; Directivas que controlan el comportamiento del script
            ; ##############################################################################################################################################
            If (foo = "IgnoreBegin")    ; ¿ignorar todas las líneas entre IgnoreBegin y IgnoreEnd?
                IgnoreBegin := TRUE


            If (ERROR)
                Return FALSE
            Continue
        }


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
            ContSection := FALSE
            IgnoreQ := TRUE
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos secciones de continuación
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (ContSection)
        {
            If (!(A_LoopReadLine ~= "^\s*\)(`"|')"))    ; ¿no termina la sección?    )" | )'
            {
                NewCode .= A_LoopReadLine . "`n"
                Continue
            }
            ContSection := "END"
        }
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
                Return Util_Error("Error de sintaxis en FileInstall.`nLínea #" . A_Index . ".", Script, CMDLN ? ERROR_FILEINSTALL_INVALID_SYNTAX : NO_EXIT)
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
        Return {       Code: "; <COMPILER: v" . A_AhkVersion . ">`n" . Trim(NewCode, "`t `r`n")
               , Directives: Directives
               ,     Script: Script }

    Return Trim(NewCode, "`t `r`n")
}






/*
    Procesa una línea de texto. Se realizan las siguientes operaciones.
    Se remueven los comentarios en-línea al final de la línea. Estos son los que comienzan con el caracter ';'.
    Se remueven otros tipos de comentarios actualmente no soportados por AHK.
    Se quita espacios innecesarios.
    Se quitan los caracteres de escape '`' innecesarios en las cadenas, como por ejemplo '`x' --> 'x'. Los literales '``' son detectados correctamente.
    Se reemplaza en las cadenas "`t" por A_Tab para ocupar solo 1 caracter.
    Return:
         String = El procesado se ha realizado con éxito y no ha ocurrido ningún error.
        Integer = Error de sintaxis.
    Por hacer:
        Detectar A_PtrSize y optimizar el código removiendolo y dejando solo el valor dependiendo la versión de AHK que se va a compilar.
        Remover por completo los espacios innecesarios.
    Nota:
        Gran parte del procesamiento aquí realizado es "experimental" y no se ha probado exaustivamente. Podría dejar el código con errores al compilar.
        Este procesamiento relentiza considerablemente la compilación, aunque a costo de reducir el tamaño del archivo compilado, y en ciertos casos favorecer el rendimiento (lo más importante).
*/
ProcessLine(Txt, Data)
{
    Static EscSequ := ";``:nrbtsvaf`"'{}^!+#"    ; por algún motivo extraño (bug?) "``;" se transforma en ";" (imagino que tendra algo que ver con " ;" que debe especificarse "`;")
           , ERROR := 1

    Local     Escape := FALSE
        ,       Char := ["", ""]
        ,  InComment := FALSE
        ,       Skip := 0

    Txt := Trim(Txt)
    Local NewTxt := ""
    VarSetCapacity(NewTxt, StrLen(Txt) * 2)

    Loop Parse, Txt
    {
        If (InStr(A_Tab, Skip) && !(Skip := 0))    ; Skip x1
            Continue

        If (Skip ~= "^R")    ; Skip \s{2,}
        {
            If (Skip ~= "=$" && A_LoopField == "=")
            {
                NewTxt .= "="
                Continue
            }
            If (A_LoopField ~= "\s")
                Continue
            Skip := 0
        }

        If (Skip-- > 0)
            Continue

        Char[1] := SubStr(Txt, A_Index+1, 1), Char[2] := SubStr(Txt, A_Index+2, 1)    ; caracteres A_LoopField[A_Index+1] y A_LoopField[A_Index+2]

        If (InComment)    ; foo/*comment*/bar
        {
            If (A_LoopField == "/" && SubStr(Txt, A_Index-1, 1) == "*")
                InComment := FALSE
            Continue
        }

        If (Char[0] == "`"" || Char[0] == "'")    ; foo "string" 'string' bar
        {
            If (Data.ContSection || (!Escape && A_LoopField == Char[0]))
                Char[0] := "", Data.ContSection := FALSE
            If (!Escape && A_LoopField == "``")
                NewTxt .= InStr(EscSequ, Char[1]) ? (Char[1] == "t" ? Skip:=A_Tab : A_LoopField) : ""    ; "`x`n" --> "x`n"  ||  "`t" --> A_Tab
            Else
                NewTxt .= A_LoopField
            Escape := !Escape && A_LoopField == "``" && Skip != A_Tab
            Continue
        }

        If (A_LoopField == ";")    ; foo ;comment
        {
            If (A_Index != 1 && !(SubStr(Txt, A_Index-1, 1) ~= "\s"))    ; expr;comment  ||  "string";comment
                Return ERROR
            Break
        }

        If (A_LoopField == "/" && Char[1] == "*")    ; foo/*comment*/bar
        {
            InComment := TRUE
            Continue
        }

        If (A_LoopField ~= "\s")
        {
            If (Char[1] ~= "\s")    ; omitimos más de un espacio en expresiones
                Continue

            If (Char[1] == "." && Char[2] ~= "\s")    ; expr . expr --> expr expr
            {
                Skip := 1
                Continue
            }
        }

        If (InStr(".~:", A_LoopField) && Char[1] == "=")    ; expr .= expr --> expr.=expr
            NewTxt := RTrim(NewTxt), Skip := "R="

        Else If (InStr("+-*/^&", A_LoopField))    ; expr + expr --> expr+expr
        {
            Char[3] := RTrim(SubStr(Txt, 1, A_Index-1))
            If (RegExReplace(Char[3], "\w") != "" || Char[3] ~= "\s")    ; evita "Return -1" --> "Return-1" || "XXX -1" --> "XXX-1" al comienzo de la línea siendo X letras o números
                NewTxt := RTrim(NewTxt), Skip := "R"
        }

        NewTxt .= A_LoopField, Escape := FALSE, Char[0] := A_LoopField
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
        ;   A_InitialWorkingDir es el directorio de trabajo especificado por la aplicación que inició nuestro script (no nos interesa)
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
                Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nLa sintaxis es inválida.`nLínea #" . LineNum . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
            }
            String := LTrim(SubStr(String, foo + 1))
        }
        Else
        {
            If (!(foo := InStr(String, A_Space,, 2)) || (Obj.ResType := SubStr(String, 2, foo - 2)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis es inválida", Script, LineNum, "@Ahk2Exe-AddResource",, Obj.File)
                Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nLa sintaxis es inválida.`nLínea #" . LineNum . ".", Script, CMDLN ? ERROR_INVALID_SYNTAX_DIRECTIVE : NO_EXIT)
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
