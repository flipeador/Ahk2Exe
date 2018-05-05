PreprocessScript(Script, Tree := "", FileList := "", Directives := "")
{
    If (Tree == "")
    {
        Util_AddLog("INFO", "Se ha iniciado el procesado del script", Script)

        FileList := []    ; almacena una lista con todos los archivos incluidos (para evitar varias inclusiones de un mismo archivo)
        ; almacena los archivos a añadir luego de la compilación al archivo EXE resultante y otras configuraciones
        Directives := {         MainIcon: CB_GetText(Gui.Control["ddlico"])
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
    FileList.Push(Script)    ; incluimos este script a la lista de archivos incluidos
    Util_AddLog("INCLUDE", "Se ha incluido un archivo", Script,, StrReplace(Tree, "`n", "|"))


    ; ======================================================================================================================================================
    ; Comprobación del archivo de código fuente AHK
    ; ======================================================================================================================================================
    If (DirExist(Script) || !FileExist(Script))
    {
        Util_AddLog("ERROR", "No se ha encontrado el script", Script,, StrReplace(Tree, "`n", "|"))
        Util_Error("El archivo de código fuente AHK no existe.", Script)
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
        ,      IgnoreQ := 0        ; 
        ,  IgnoreBegin := FALSE    ; determina si el código siguiente debe ser ignorado

    VarSetCapacity(NewCode, FileGetSize(Script))    ; establecemos la capacidad de la variable que amlacenará el nuevo código, para mejorar el rendimiento
    VarSetCapacity(LineTxt, 65534 * 2)    ; capacidad de la variable que almacenará el texto de la línea actual

    Loop Read, Script    ; abrimos el archivo para lectura y leemos línea por línea
    {
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Directivas específicas del compilador
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (IgnoreBegin)    ; ¿ignorar línea?
        {
            IgnoreBegin := !(A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-IgnoreEnd")    ; continua hasta que se encuentre ";@Ahk2Exe-IgnoreEnd"
            Continue
        }
        If (A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-")    ; ¿la línea empieza con ";@Ahk2Exe-"? (ignora espacios antes de ";")
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
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-SetMainIcon.`nDebe especificar un icono.`nLínea #" . A_Index . ".", Script)
                    Else If (DirExist(bar := Util_GetFullPathName(bar)) || !FileExist(bar))
                        Util_Error("Error en la directiva @Ahk2Exe-SetMainIcon.`nEl archivo icono especificado no existe.`n" . bar . "`nLínea #" . A_Index . ".", Script)
                    Else
                        Directives.MainIcon := bar
                }

                Else If (foo = "ConsoleApp")    ; cambia el subsistema ejecutable al modo consola
                    Directives.Subsystem := IMAGE_SUBSYSTEM_WINDOWS_CUI

                Else If (foo = "UseResourceLang")    ; cambia el lenguaje de recursos utilizado por @Ahk2Exe-AddResource
                {
                    If (bar == "")
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-UseResourceLang.`nDebe especificar un código de idioma.`nLínea #" . A_Index . ".", Script)
                    Else If (!(bar is "Integer"))
                        Util_Error("Error en la directiva @Ahk2Exe-UseResourceLang.`nEl valor de idioma especificado es inválido.`n" . bar . "`nLínea #" . A_Index . ".", Script)
                    Else
                        Directives.ResourceLang := bar
                }

                Else If (foo = "PostExec")    ; especifica un comando que se ejecutará después de una compilación exitosa
                {
                    If (bar == "")
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-PostExec.`nDebe especificar un comando ha ejecutar después de la compilación.`nLínea #" . A_Index . ".", Script)
                    Else
                        Directives.PostExec := bar
                }

                Else If (foo = "AddResource")
                {
                    If (bar == "")
                        Util_Error("Uso inválido de la directiva @Ahk2Exe-AddResource.`nDebe especificar un recurso ha añadir al archivo EXE resultante.`nLínea #" . A_Index . ".", Script)
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
                NewCode .= A_LoopReadLine . "`n"
                Continue
            }
            ContSection := FALSE
            IgnoreQ := TRUE
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Removemos espacios al inicio y final de la línea, ignoramos líneas en blanco y comentarios al inicio de la línea
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If ((LineTxt := Trim(A_LoopReadLine)) == "" || SubStr(LineTxt, 1, 1) == ";")
            Continue    ; continuamos con la próxima línea
        LineNum := A_Index    ; línea actual
        IncludeAgain := FALSE
        ContSection := FALSE


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
        ; Buscamos el inicio de secciones de continuación
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (SubStr(LineTxt, 1, 1) == "(" && !InStr(LineTxt, ")"))    ; ¿la línea empieza por "(" y no contiene ningún ")" en ella?
            ContSection := TRUE


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Eliminamos comentarios en línea y espacios innecesarios de la línea actual
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        foo := "", bar := 0
        Loop Parse, LineTxt    ; analizamos caracter por caracter, A_Index contiene la posición actual
        {
            If (foo == "`"" || foo == "'")    ; ¿estamos dentro de una cadena?
            {
                If (IgnoreQ || A_LoopField == foo && Mod(bar, 2) == 0)    ; ¿aquí termina la cadena? ¿se trata de una comilla de cierre o una literal?
                    IgnoreQ := FALSE, foo := ""    ; terminamos la cadena
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


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Procesamos los #Includes
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (SubStr(LineTxt, 1, 14) = "#IncludeAgain ")    ; ¿en esta línea hay un #IncludeAgain?
            LineTxt := StrReplace(LineTxt, "#IncludeAgain ", "#Include "), IncludeAgain := TRUE
        If (SubStr(LineTxt, 1, 9) = "#Include ")    ; ¿en esta línea hay un #Include?
        {
            LineTxt := Trim(SubStr(LineTxt, 9))    ; eliminamos la palabra "#Include" del inicio y luego espacios en blanco
            DerefVar(LineTxt,, Script)    ; desreferenciamos las variables incluidas entre signos de porcentaje

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
                        NewCode .= PreprocessScript(bar . LineTxt, Tree . "`n" . Script, FileList, Directives) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (ERROR)
                        Return FALSE
                }
                Else If (AhkLib[1] != "" && FileExist(AhkLib[1] . "\" . LineTxt))    ; ¿existe el archivo a incluir en la carpeta "Lib" en el directorio de instalación de AHK?
                {
                    If (!IsAlreadyIncluded(FileList, AhkLib[1] . "\" . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(AhkLib[1] . "\" . LineTxt, Tree . "`n" . Script, FileList, Directives) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (ERROR)
                        Return FALSE
                }
                Else If (AhkLib[2] != "")
                {
                    If (!IsAlreadyIncluded(FileList, AhkLib[2] . "\" . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                        NewCode .= PreprocessScript(AhkLib[2] . "\" . LineTxt, Tree . "`n" . Script, FileList, Directives) . "`n"   ; procesa el script incluido y añadimos el resultado al nuevo código
                    If (ERROR)
                        Return FALSE
                }
                Else If (!foo)    ; ¿no se debe permitir omitir archivos inexistentes?
                {
                    Util_AddLog("ERROR", "No se a encontrado el archivo a incluir", Script, A_Index, "<" . LineTxt . ">")
                    Return Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include <" . LineTxt . ">`nLínea #" . LineNum . ".", Script)
                }
                Else
                    Util_AddLog("INCLUDE", "Archivo a incluir omitido", Script, A_Index, "<" . LineTxt . ">")
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
                        Util_AddLog("ERROR", "No se ha encontrado el archivo a incluir", Script, A_Index, LineTxt)
                        Return Util_Error("Error en archivo #Include. El archivo a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . LineNum . ".", Script)
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
                LineTxt := Util_GetFullPathName(LineTxt)    ; recuperamos la ruta completa del supuesto directorio
                If (!DirExist(LineTxt))    ; ¿el directorio a incluir no existe?
                {
                    Util_AddLog("INCLUDE", "Directorio a incluir no encontrado", Script, A_Index, "<" . LineTxt . ">")
                    Return Util_Error("Error en directorio #Include. El directorio a incluir no existe.`n#Include " . LineTxt . "`nLínea #" . LineNum . ".", Script)

                }
                A_WorkingDir := LineTxt    ; cambiamos el directorio de trabajo actual
            }


            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Buscamos por el comando FileInstall
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (LineTxt ~= "i)^FileInstall")    ; ¿la línea comienza con "FileInstall"?
        {
            ; evitamos trabajar con la variable original (LineTxt) ya que debe ser añadida al script compilado
            foo := ParseFuncParams(SubStr(LineTxt, 12), Script)[1]    ; eliminamos "FileInstall" al principio de la línea y recuperamos el primer parámetro correctamente formateado
            If (DirExist(foo) || !FileExist(foo))
            {
                    Util_AddLog("ERROR", "Archivo a incluir no encontrado", Script, A_Index, foo,, "FileInstall")
                    Return Util_Error("Error en archivo FileInstall. El archivo a incluir no existe.`nLínea #" . LineNum . ".", Script)
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
        this.OldWorkingDir := A_WorkingDir
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
    WorkingDir := new TempWorkingDir(GetDirParent(Script))

    Local Data := {VerInfo: ParseVersionInfo(Script), MainIcon: ""}
        ,  foo := "" ;, bar := ""
        ,  Ext := ""

    Loop Read, Script
    {
        If (A_LoopReadLine ~= "i)^\s*;@Ahk2Exe-SetMainIcon")
        {
            If (!DirExist(foo := Trim(SubStr(LTrim(A_LoopReadLine), 22))) && FileExist(foo))
            {
                foo := Util_GetFullPathName(foo), SplitPath(foo,,, Ext)
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





DerefVar(ByRef String, Chr := "%", Script := "")
{
    String := StrReplace(String, Chr .     "A_ScriptDir" . Chr,    A_WorkingDir)
    String := StrReplace(String, Chr .       "A_AppData" . Chr,       A_AppData)
    String := StrReplace(String, Chr . "A_AppDataCommon" . Chr, A_AppDataCommon)
    String := StrReplace(String, Chr .      "A_LineFile" . Chr,          Script)
    String := StrReplace(String, Chr .       "A_Desktop" . Chr,       A_Desktop)
    String := StrReplace(String, Chr .   "A_MyDocuments" . Chr,   A_MyDocuments)
    String := StrReplace(String,  Chr . "A_ProgramFiles" . Chr,  A_ProgramFiles)
    String := StrReplace(String,  Chr .       "A_WinDir" . Chr,        A_WinDir)
    String := StrReplace(String,  Chr .         "A_Temp" . Chr,          A_Temp)

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
        Arr[prm] .= DerefVar(bar, "")

    Return Arr
}





ParseResourceStr(String, LineNum, Script)    ;@Ahk2Exe-AddResource *[int/str type/"type"] [str filename], [int/str resname]
{
    Static CommonResTypes := { bmp: 2, dib: 2              ; RT_BITMAP
                             , cur: 1                      ; RT_CURSOR
                             , ico: 3                      ; RT_ICON
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
                Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nLa sintaxis es inválida.`nLínea #" . LineNum . ".", Script)
            }
            String := LTrim(SubStr(String, foo + 1))
        }
        Else
        {
            If (!(foo := InStr(String, A_Space,, 2)) || (Obj.ResType := SubStr(String, 2, foo - 2)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis es inválida", Script, LineNum, "@Ahk2Exe-AddResource",, Obj.File)
                Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nLa sintaxis es inválida.`nLínea #" . LineNum . ".", Script)
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
        Return Util_Error("Error en la directiva @Ahk2Exe-AddResource.`nEl archivo especificado no existe.`nLínea #" . LineNum . ".", Script)
    }

    Return Obj
}
