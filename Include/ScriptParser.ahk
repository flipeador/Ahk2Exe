PreprocessScript(Script, Parent := "", FileList := "")
{
    LastError := 0
    If (Parent == "")
    {
        Log := "Inicializando pre-procesado del script`n"
        FileList := []    ; almacena una lista con todos los archivos incluidos (para evitar varias inclusiones de un mismo archivo)
    }
    FileList.Push(Script)    ; incluimos este script a la lista de archivos incluidos
    Log .= "Include [" . Script . "]`n"



    ; ======================================================================================================================================================
    ; Comprobación del archivo de código fuente AHK
    ; ======================================================================================================================================================
    If (DirExist(Script) || !FileExist(Script))
    {
        Util_Error("El archivo de código fuente AHK no existe.", Script . (Parent == "" ? "" : "`nParent: " . Parent))
        Log .= "Archivo script no encontrado [" . Script . "]`n"
        Return FALSE    ; terminamos pre-procesado debido a un error
    }
    Local WorkingDir := new TempWorkingDir(GetDirParent(Script))    ; establece temporalmente el directorio de trabajo actual al del script ha procesar


    ; ======================================================================================================================================================
    ; Iniciar procesado
    ; ======================================================================================================================================================
    Local NewCode := ""    ; almacena el código procesado
        , LineTxt := ""       ; almacena el texto de la línea actual
        , LineNum := 0        ; almacena el número de línea actual
        , foo := bar := ""    ; variables generales de uso temporal
        , IncludeAgain := FALSE    ; determina si se debe ignorar archivos ya incluidos
        ,    InComment := FALSE    ; determina si se está en un comentario en bloque
        ,  ContSection := FALSE    ; determina si se está en una continuación de una sección

    VarSetCapacity(NewCode, FileGetSize(Script))    ; establecemos la capacidad de la variable que amlacenará el nuevo código, para mejorar el rendimiento
    VarSetCapacity(LineTxt, 65534 * 2)    ; capacidad de la variable que almacenará el texto de la línea actual

    Loop Read, Script    ; abrimos el archivo para lectura y leemos línea por línea
    {
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Buscamos el final de secciones de continuación
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (ContSection)
        {
            If (SubStr(LTrim(A_LoopReadLine), 1, 2) == ")`"")    ; ¿termina la sección?
                ContSection := FALSE
            NewCode .= A_LoopReadLine . "`n"
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Removemos espacios al inicio y final de la línea, ignoramos líneas en blanco y comentarios al inicio de la línea, almacenamos la línea actual
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If ((LineTxt := Trim(A_LoopReadLine)) == "" || SubStr(LineTxt, 1, 1) == ";")
            Continue    ; continuamos con la próxima línea
        LineNum := A_Index    ; línea actual
        IncludeAgain := FALSE
        ContSection := FALSE


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Buscamos el inicio de secciones de continuación
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (SubStr(LineTxt, 1, 1) == "(" && !InStr(LineTxt, ")"))    ; ¿la línea empieza por "(" y no contiene ningún ")" en ella?
            ContSection := TRUE


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Omitimos comentarios en bloque
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (InComment)    ; ¿estamos en un comentario en bloque multilínea?
        {
            If (SubStr(LineTxt, 1, 2) == "*/")    ; ¿encontramos el cierre del comentario en bloque?
                InComment := FALSE    ; hecho, terminamos la parte de comentarios
            Continue
        }
        If (SubStr(LineTxt, 1, 2) == "/*")    ; ¿es el comienzo de un comentario en bloque?
        {
            InComment := SubStr(LineTxt, -2) != "*/"    ; ¿el comentario en bloque termina en la misma línea o no? (/* comentario */)
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Eliminamos comentarios en línea y espacios innecesarios de la línea actual
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        foo := "", bar := 0
        Loop Parse, LineTxt    ; analizamos caracter por caracter, A_Index contiene la posición actual
        {
            If (foo == "`"" || foo == "'")    ; ¿estamos dentro de una cadena?
            {
                If (A_LoopField == foo && Mod(bar, 2) == 0)    ; ¿aquí termina la cadena? ¿se trata de una comilla de cierre o una literal?
                    foo := ""    ; terminamos la cadena
                ; si bar es múltiplo de 2, entonces "`" hace referencia a otro "`"; esto ayuda a diferenciar correctamente var:="cadena`"" de var:="cadena``"
                bar := A_LoopField == "``" ? bar + 1 : 0    ; ¿es el caracter "`" o no?
                Continue    ; continuamos con el próximo caracter
            }

            If (A_LoopField == ";" || (A_LoopField == "/" && foo == "*"))    ; ¿es el inicio de un comentario? (;[ comentario]) (/*[ comentario */]) 
            {
                bar := SubStr(LineTxt, A_Index-1, 1)    ; almacena el caracter anterior
                If (bar != A_Space && bar != A_Tab)    ; ¿el anterior caracter no fue un espacio o una tabulación? (var:=1;comentario)
                {
                    Util_Error("Error de sintaxis.`nDebe dejar por lo menos un espacio entre un comentario y otros caracteres.`nLine #" . LineNum . ".", Script)
                    Return FALSE
                }
                LineTxt := Trim(SubStr(LineTxt, 1, A_Index-2))    ; eliminamos el comentario de la línea
                Break    ; terminamos el bucle Loop-parse
            }

            foo := A_LoopField    ; almacena el caracter actual (útil para detectar el comienzo de una cadena, objeto o cualquier otra cosa del estilo)
        }

        If (foo == "`"" || foo == "'")    ; ¿hay alguna cadena sin cerrar?
        {
            ; comentado debido a continuaciones de secciones ( var := "`n(`n)" )
            ;Util_Error("Error de sintaxis.`nNo se ha encontrado la comilla de cierre.`nLínea #" . LineNum . "; Carácter " . foo . ".", Script)
            ;Return FALSE
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Procesamos los #Includes
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (SubStr(LineTxt, 1, 14) = "#IncludeAgain ")
            LineTxt := StrReplace(LineTxt, "#IncludeAgain ", "#Include "), IncludeAgain := TRUE
        If (SubStr(LineTxt, 1, 9) = "#Include ")    ; ¿en esta línea hay un #Include?
        {
            LineTxt := Trim(SubStr(LineTxt, 9))    ; eliminamos la palabra "#Include" del inicio y luego espacios en blanco
            DerefVar(LineTxt, A_WorkingDir)    ; desreferenciamos las variables incluidas entre signos de porcentaje

            If (SubStr(LineTxt, 1, 2) == "*i")    ; ¿el archivo a incluir es opcional?
            {
                LineTxt := Trim(SubStr(LineTxt, 3))    ; eliminamos "*i" del inicio y luego espacios en blanco
                foo := TRUE
            }
            Else
                foo := FALSE


            ; ##############################################################################################################################################
            ; Buscamos en las carpetas "Lib", primero en el directorio de instalación de AHK, luego en Documentos del usuario actual
            ; ##############################################################################################################################################
            If (SubStr(LineTxt, 1, 1) == "<")    ; ¿el archivo a incluir debe buscarse en la carpeta "Lib"?
            {
                If ((LineTxt := SubStr(LineTxt, 2)) == ">" || !(bar := InStr(LineTxt, ">")))    ; ¿es la sintaxis inválida?
                {
                    Util_Error("Error de sintaxis.`n#Include <" . LineTxt . "`nLínea #" . LineNum . ".", Script)
                    Return FALSE
                }
                LineTxt := Trim(SubStr(LineTxt, 1, bar-1))    ; removemos el caracter de cierre ">" y luego eliminamos espacios en blanco
                LineTxt .= InStr(LineTxt, ".") ? "" : ".ahk"    ; añadimos la extensión ".ahk" si no se especificó una extensión

                bar := GetDirParent(FileList[1]) . "\Lib\"   ; recupera el directorio "Lib" ubicado en el directorio del script principal seleccionado para compilar
                If (FileExist(bar . LineTxt))    ; ¿existe el archivo a incluir en la carpeta "Lib" del script principal?
                {
                    If (!IsAlreadyIncluded(FileList, bar . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(bar . LineTxt, Script, FileList) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (LastError == 1)    ; ¿ha ocurrido un error en el procesado del script incluido?
                        Return FALSE
                }
                Else If (AhkLib[1] != "" && FileExist(AhkLib[1] . "\" . LineTxt))    ; ¿existe el archivo a incluir en la carpeta "Lib" en el directorio de instalación de AHK?
                {
                    If (!IsAlreadyIncluded(FileList, AhkLib[1] . "\" . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(AhkLib[1] . "\" . LineTxt, Script, FileList) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (LastError == 1)    ; ¿ha ocurrido un error en el procesado del script incluido?
                        Return FALSE
                }
                Else If (AhkLib[2] != "")
                {
                    If (!IsAlreadyIncluded(FileList, AhkLib[2] . "\" . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(AhkLib[2] . "\" . LineTxt, Script, FileList) . "`n"   ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (LastError == 1)    ; ¿ha ocurrido un error en el procesado del script incluido?
                        Return FALSE
                }
                Else If (!foo)    ; ¿no se debe permitir omitir archivos inexistentes?
                {
                    Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include <" . LineTxt . ">`nLínea #" . LineNum . ".", Script)
                    Log .= "Archivo a incluir no encontrado [<" . LineTxt . ">]`n"
                    Return FALSE
                }
                Else
                    Log .= "Archivo a incluir omitido [<" . LineTxt . ">]`n"
            }


            ; ##############################################################################################################################################
            ; Buscamos en el directorio de trabajo del Script o en la ruta absoluta
            ; ##############################################################################################################################################
            Else If (InStr(LineTxt, ".") && !DirExist(LineTxt))    ; ¿es un archivo?
            {
                LineTxt := Util_GetFullPathName(LineTxt)    ; recuperamos la ruta completa del archivo
                If (DirExist(LineTxt) || !FileExist(LineTxt))    ; ¿el archivo a incluir no existe?
                {
                    If (!foo)
                    {
                        Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . LineNum . ".", Script)
                        Log .= "Archivo a incluir no encontrado [" . LineTxt . "]`n"
                        Return FALSE
                    }
                    Else
                        Log .= "Archivo a incluir omitido [" . LineTxt . "]`n"
                }
                Else
                {
                    If (!IsAlreadyIncluded(FileList, LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(LineTxt, Script, FileList) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (LastError == 1)    ; ¿ha ocurrido un error en el procesado del script incluido?
                        Return FALSE
                }
            }


            ; ##############################################################################################################################################
            ; Se especificó un directorio en #Include, cambiamos el directorio de trabajo
            ; ##############################################################################################################################################
            Else    ; es un directorio
            {
                LineTxt := Util_GetFullPathName(LineTxt)    ; recuperamos la ruta completa del supuesto directorio
                If (!DirExist(LineTxt))    ; ¿el directorio a incluir no existe?
                {
                    Util_Error("Error en directorio #Include. El directorio a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . LineNum . ".", Script)
                    Log .= "Directorio a incluir no encontrado [" . LineTxt . "]`n"
                    Return FALSE
                }
                A_WorkingDir := LineTxt    ; cambiamos el directorio de trabajo actual
            }


            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Añadimos la línea procesada al nuevo código
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        NewCode .= LineTxt . "`n"
    }



    ; ======================================================================================================================================================
    ; Terminar y devolver el código procesado
    ; ======================================================================================================================================================
    If (NewCode == "")
        Log .= "Archivo script no contiene datos [" . Script . "]`n"

    Return (Parent == "" ? "; <COMPILER: v" . A_AhkVersion . ">`n" : "") . Trim(NewCode, "`t `r`n")
}





IsAlreadyIncluded(FileList, AhkFile, IncludeAgain)
{
    If (!IncludeAgain)    ; ¿no permitir múltiples inclusiones del mismo archivos?
        Loop (ObjLength(FileList))
            If (FileList[A_Index] = AhkFile)
                Return TRUE
    Return FALSE
}





DerefVar(ByRef String, WorkingDir)
{
    String := StrReplace(String,     "%A_ScriptDir%",      WorkingDir)
    String := StrReplace(String,       "%A_AppData%",       A_AppData)
    String := StrReplace(String, "%A_AppDataCommon%", A_AppDataCommon)
    String := StrReplace(String,      "%A_LineFile%",      A_LineFile)
    String := StrReplace(String,       "%A_Desktop%",       A_Desktop)
    String := StrReplace(String,   "%A_MyDocuments%",   A_MyDocuments)
}





class TempWorkingDir
{
    __New(WorkingDir)
    {
        this.OldWorkingDir := A_WorkingDir
        A_WorkingDir := WorkingDir
    }
    __Delete()
    {
        A_WorkingDir := this.OldWorkingDir
    }
}





ParseVersionInfo(Script)
{
    Global VerInfo
    If (DirExist(Script) || !FileExist(Script))
        Return FALSE

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
