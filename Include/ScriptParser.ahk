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
                      ,         PostExec: FALSE
                      ,      VersionInfo: {      FileVersion: g_data.BinVersion    ; estos son los valores por defecto de la información de versión
                                          ,   ProductVersion: g_data.BinVersion
                                          , OriginalFilename: PATH(Script).FN
                                          ,         Comments: "Compiled with https://github.com/flipeador/Ahk2Exe" }
                      ,      FileVersion: StrSplit(g_data.BinVersion, ".")    ; versión binaria del archivo
                      ,   ProductVersion: StrSplit(g_data.BinVersion, ".")    ; versión binaria del producto
                      ,        Resources: []
                      ,     RequireAdmin: FALSE
                      ,          Streams: [] }
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
        ,          _If := FALSE    ; http://www.cplusplus.com/doc/tutorial/preprocessor/

    VarSetCapacity(NewCode, FileGetSize(Script))    ; establecemos la capacidad de la variable que amlacenará el nuevo código, para mejorar el rendimiento
    VarSetCapacity(LineTxt, 65534 * 2)    ; capacidad de la variable que almacenará el texto de la línea actual

    ; caracteres especiales regex \.*?+[{|()^$
    Loop Read, Script    ; abrimos el archivo para lectura y leemos línea por línea
    {
        LineTxt := A_LoopReadLine


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos secciones de continuación (cadenas)
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (ContSection)
        {
            If ( !(LineTxt ~= "^\s*\)(`"|')") )    ; ¿no termina la sección?    )" | )'
            {
                If (!InStr(ContSection.Options, "LTrim0"))
                    LineTxt := LTrim(LineTxt)

                If (!InStr(ContSection.Options, "RTrim0"))
                    LineTxt := RTrim(LineTxt)

                NewCode .= ( InStr(ContSection.Options, "C") ? RegExReplace(LineTxt, "\s+;.*") : LineTxt ) . "`n"    ; C = Comments (si se permite comentarios los quitamos con regex)
                Continue
            }
            NewCode .= ProcessLine(Trim(RegExReplace(LineTxt, "\s+;.*"))) . "`n"
            ContSection := FALSE
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Eliminamos comentarios en línea, espacios en blanco al inicio/final y omitimos líneas en blanco
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        LineTxt := Trim(LineTxt)
        If (LineTxt ~= "^\s*$")    ; ignoramos líneas en blanco | ignore blank lines
            Continue


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detercamos comentarios
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (InComment)    ; ¿comentario en bloque multilínea?
        {
            InComment := !(LineTxt ~= "\*/$")    ; fix 20180614 | thanks «coffee»
            If (!InComment || !Keep)
                Continue
        }

        If (IgnoreBegin)    ; ignorar líneas especificadas entre @Ahk2Exe-IgnoreBegin[32/64] y @Ahk2Exe-IgnoreEnd[32/64]
        {
            If (LineTxt ~= "i)^;@Ahk2Exe-IgnoreEnd" . IgnoreBegin.Bits)
                IgnoreBegin := FALSE

            Else If (!(LineTxt ~= "^;") && IgnoreBegin.Lines != "" && !--IgnoreBegin.Lines)
                IgnoreBegin := FALSE

            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos @Ahk2Exe-ifdef/ifndef/elif/else/endif
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (_If)
        {
            If (LineTxt ~= "i)^;@Ahk2Exe-EndIf\s*")
            {
                _If := FALSE
                Continue
            }

            If (LineTxt ~= "i)^;@Ahk2Exe-(ifn?def|if|else|elif)")    ; nested ifs - is it really important?
            {
                Util_AddLog("ERROR", "@Ahk2Exe-If no soportado dentro de otros ifs", Script, A_Index)
                Return Util_Error("@Ahk2Exe-If no soportado dentro de otros ifs.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_NOT_SUPPORTED))
            }

            If ( _If.Type = "ifdef" && !ObjHasKey(g_data.define, _If.Def[1]) )
                Continue
            
            If ( _If.Type = "ifndef" && ObjHasKey(g_data.define, _If.Def[1]) )
                Continue

            If (_If.Type = "if")
            {
                foo := _If.Def
                For g_k, g_v in g_data.define    ; g_k = Identifier | g_v = Replacement
                    foo := RegExReplace(foo, "\b" . g_k . "\b", g_v)
                If ( !Eval(foo) )    ; eval expr | ExecScript("FileAppend " .  foo . ", '*'")
                    Continue
            } 
        }

        
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos comentarios en bloque
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (LineTxt ~= "^/\*")
        {
            InComment := !(LineTxt ~= "\*/\s*$")    ; ¿el comentario en bloque termina en la misma línea o no? (/* comentario */)
            Keep := LineTxt ~= "i)^/\*@Ahk2Exe-Keep"
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Detectamos secciones de continuación var:="`n(`n)"
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (LineTxt ~= "^\(((?!\)).)*$")    ; ¿la línea empieza por "(" y no contiene ningún ")" en ella?
            ContSection := { Options: Trim(SubStr(LineTxt, 2)) }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Directivas específicas del compilador
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If (LineTxt ~= "i)^;@Ahk2Exe-")
        {
            LineTxt := SubStr(LineTxt, 11)    ; eliminamos ";@Ahk2Exe-" al principio
            foo := (bar := InStr(LineTxt, A_Space)) ? SubStr(LineTxt, 1, bar - 1) : LineTxt    ; recuperamos el nombre del comando
            bar := bar ? RegExReplace(LTrim(SubStr(LineTxt, bar)), "\s+;.*") : ""    ; recupera el valor

            ; ##############################################################################################################################################
            ; Directivas que controlan los metadatos ejecutables que se añadirán al archivo EXE resultante
            ; ##############################################################################################################################################
            If (foo = "ConsoleApp")    ; ConsoleApp
            {
                If (bar != "")    ; esta directiva no admite parámetros
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-ConsoleApp", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-ConsoleApp.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(Directives, "Subsystem", IMAGE_SUBSYSTEM_WINDOWS_CUI)
            }

            Else If (foo = "UseResourceLang")    ; UseResourceLang LangID
            {
                If (bar == "")    ; el primer parámetro es requerido
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-UseResourceLang", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-UseResourceLang.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else If (!(bar is "Integer") || !LCIDToLocaleName(bar))    ; comprueba el código de idioma
                    Util_AddLog("ERROR", "El valor de idioma en @Ahk2Exe-UseResourceLang es inválido", Script, A_Index)
                  , Util_Error("El valor de idioma en @Ahk2Exe-UseResourceLang es inválido.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(Directives, "ResourceLang", Integer(bar))
            }

            Else If (foo = "PostExec")    ; PostExec Command [, WorkingDir] [, Options]
            {
                bar := ParseParams(bar,, 3)
                If (bar[1] == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-PostExec", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-PostExec.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(Directives, "PostExec", {Target: bar[1], WorkingDir: bar[2], Options: bar[3]})
            }

            Else If (foo = "AddResource")    ; AddResource [*Type] FileName [, ResName] [, LangID]
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-AddResource", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-AddResource.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjPush(Directives.Resources, ParseResourceStr(bar, Script, A_Index))
            }

            Else If (foo = "SetMainIcon")    ; SetMainIcon IconFile
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

            Else If (foo ~= "i)^Set")    ; SetProp [Value]
            {
                If ( StrLen(foo) < 4 )
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-Set", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-Set.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))

                Else
                {
                    If (foo = "SetFileVersion" || foo = "SetProductVersion" || foo = "SetVersion")
                    {
                        bar := [foo, bar]
                        foo := ObjModify(StrSplit(bar[2], "."), (n) => n is "Integer" ? Integer(n) : 0, -4, 0)
                        If (bar[1] = "SetFileVersion" || bar[1] = "SetVersion")
                            ObjRawSet(Directives, "FileVersion", foo)
                          , ObjRawSet(Directives.VersionInfo, "FileVersion", bar[2])
                        If (bar[1] = "SetProductVersion" || bar[1] = "SetVersion")
                            ObjRawSet(Directives, "ProductVersion", foo)
                          , ObjRawSet(Directives.VersionInfo, "ProductVersion", bar[2])
                    }
                    Else If (foo = "SetName")
                    {
                        ObjRawSet(Directives.VersionInfo, "InternalName", bar)
                        ObjRawSet(Directives.VersionInfo, "ProductName", bar)
                    }
                    Else If (foo = "SetDescription")
                        ObjRawSet(Directives.VersionInfo, "FileDescription", bar)
                    Else If (foo = "SetCopyright")
                        ObjRawSet(Directives.VersionInfo, "LegalCopyright", bar)
                    Else If (foo = "SetOrigFilename")
                        ObjRawSet(Directives.VersionInfo, "OriginalFilename", bar)
                    Else
                        ObjRawSet(Directives.VersionInfo, SubStr(foo, 4), bar)    ; SetXXX
                }
            }

            Else If (foo = "VerInfo")    ; VerInfo Prop [, Value] [, Delete?]
            {
                bar := ParseParams(bar,, 3)
                If ( (bar[1] == "" && bar[3] != 2) || (bar[3] != "" && bar[3] != 1 && bar[3] != 2 ) )
                    Util_AddLog("ERROR", "La sintaxis en la directiva @Ahk2Exe-VerInfo no es correcta", Script, A_Index)
                  , Util_Error("La sintaxis en la directiva @Ahk2Exe-VerInfo no es correctao.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))

                Else If (bar[3] == "")    ; añade/modifica la propiedad especificada
                    ObjRawSet(Directives.VersionInfo, bar[1], bar[2])
                Else If (bar[3] == 1)    ; elimina la propiedad especificada
                    ObjDelete(Directives.VersionInfo, bar[1])
                Else ;If (bar[3] == 2)    ; elimina todas las propiedades
                    ObjRawSet(Directives, "VersionInfo", {})
            }

            Else If (foo = "FileVersion" || bar = "ProductVersion")    ; FileVersion 0.0.0.0  |  ProductVersion 0.0.0.0
            {
                If ( !RegExMatch(bar, "^\d+\.\d+\.\d+\.\d+$") )    ; 0.0.0.0
                    Util_AddLog("ERROR", "El valor especificado en @Ahk2Exe-" . foo . " es inválido", Script, A_Index)
                  , Util_Error("El valor especificado en @Ahk2Exe-" . foo . " es inválido.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(Directives, foo, ObjModify(StrSplit(bar, "."), (n) => Integer(n)))
            }

            Else If (foo = "RequireAdmin")    ; RequireAdmin
                ObjRawSet(Directives, "RequireAdmin", TRUE)

            Else If (foo = "AddStream")    ; AddStream Name [, Value] [, IsText?]
            {
                bar := ParseParams(bar,, 3)
                If (Contains2(bar[1], "<>:`"/\|?*`t") || (bar[3] != 1 && bar[3] != ""))
                    Util_AddLog("ERROR", "La sintaxis en la directiva @Ahk2Exe-AddStream no es correcta", Script, A_Index)
                  , Util_Error("La sintaxis en la directiva @Ahk2Exe-AddStream no es correcta.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjPush(Directives.Streams, {Name: bar[1], Value: bar[2], IsText: bar[3] == 1})
            }


            ; ##############################################################################################################################################
            ; Directivas que controlan el comportamiento del script
            ; ##############################################################################################################################################
            Else If (foo ~= "i)^IgnoreBegin(32|64)?$")    ; IgnoreBegin[32|64] [Lines]
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

            Else If (foo ~= "i)^IgnoreEnd(32|64)?$")    ; IgnoreEnd[32|64]
                Continue

            Else If (foo ~= "i)^Keep(32|64)?$")    ; Keep[32|64] Code
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-Keep", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-Keep.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))

                Else If (foo = "Keep")
                    NewCode .= bar . "`n"
                Else If (foo = "Keep32" && !g_data.Compile64)
                    NewCode .= bar . "`n"
                Else If (foo = "Keep64" && g_data.Compile64)
                    NewCode .= bar . "`n"
            }

            Else If (foo = "Bin")    ; Bin BinFile
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

            Else If (foo = "define")   ; Define A [B ..]
            {
                bar := ParseParams(bar, "\s", 2)    ; bar := [A,B]
                If (bar[1] == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-Define", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-Define.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjRawSet(g_data.define, bar[1], bar[2])
            }

            Else If (foo = "undef")
            {
                If ( !ObjHasKey(g_data.define, bar) )
                    Util_AddLog("ERROR", "@Ahk2Exe-UnDef El identificador no estaba definido", Script, A_Index)
                  , Util_Error("@Ahk2Exe-UnDef El identificador no estaba definido.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    ObjDelete(g_data.define, bar)
            }

            Else If (foo ~= "i)^ifn?def$")    ; if[n]def A [B ..]
            {
                bar := ParseParams(bar, "\s", 2)    ; bar := [A,B]
                If (bar[1] == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-" . foo, Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-" . foo . ".`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    _If := { Type: foo, Def: bar }
            }

            Else If (foo = "if")
            {
                If (bar == "")
                    Util_AddLog("ERROR", "Uso inválido de la directiva @Ahk2Exe-If", Script, A_Index)
                  , Util_Error("Uso inválido de la directiva @Ahk2Exe-If.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_INVALID_DIRECTIVE_SYNTAX))
                Else
                    _If := { Type: foo, Def: bar }
            }

            Else
                Util_AddLog("ERROR", "El comando de directiva @Ahk2Exe especificado es inválido", Script, A_Index)
              , Util_Error("El comando de directiva @Ahk2Exe especificado es inválido.`nLínea #" . A_Index . ".", Script, CMDLN(ERROR_UNKNOWN_DIRECTIVE_COMMAND))


            If (ERROR)
                Return FALSE
            Continue
        }


        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        ; Eliminamos comentarios en línea y optimizamos la línea
        ; ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
        If ( (LineTxt := RegExReplace(LineTxt, "\s+;.*")) == "" )
            Continue
        LineTxt := ProcessLine(LineTxt)


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
            If (LineTxt ~= "^<")    ; ¿el archivo a incluir debe buscarse en la carpeta "Lib"?
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
                For g_k, g_v in [ DirGetParent(FileList[1]) . "\Lib\"
                                ; Biblioteca de usuario
                                , A_MyDocuments . "\AutoHotkey\Lib\"
                                ; Biblioteca local
                                , g_ahkpath == "" ? "" : DirGetParent(g_ahkpath) . "\Lib\" ]
                {
                    If (g_v != "" && IS_FILE(g_v . LineTxt))
                    {
                        If (!IsAlreadyIncluded(FileList, g_v . LineTxt, IncludeAgain))    ; ¿el archivo aún no se ha incluido?
                            NewCode .= PreprocessScript(g_v . LineTxt, Tree . "`n" . Script, FileList, Directives) . "`n"    ; procesa el script incluido y añadimos el resultado al nuevo código
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
    {
        ; Thanks «coffee» : https://autohotkey.com/boards/viewtopic.php?f=44&t=48953#p223878
        If (g_data.SyntaxCheck)    ; comprobación de sintaxis y autoinclución de bibliotecas
        {
            Util_AddLog("INFO", "La comprobación de sintaxis está habilitada", Script)
            If (g_ahkpath == "")
            {
                Util_AddLog("ADVERTENCIA", "No se ha podido realizar la comprobación de sintaxis porque no se ha encontrado AutoHotkey.exe", Script)
                OutputDebug("Syntax check unsuccessful. Can't find AutoHotkey.exe.")
            }
            Else
            {
                Local ahk := {}
                Loop 2
                ; en la primera iteración comprueba la sintaxis y luego se añaden las librerias faltantes (si las hay)
                ; en la segunda iteración -si es necesaria- se comprueba la sintaxis con las librerías ya añadidas
                {
                    If (!(ahk.prc := new SubProcess("`"" . g_ahkpath . "`"" . " /iLib * /ErrorStdOut *")))
                    {
                        Util_AddLog("ADVERTENCIA", "No se ha podido realizar la comprobación de sintaxis porque no se ha podido ejecutar un nuevo proceso de AutoHotkey.exe", Script)
                        OutputDebug("Syntax check unsuccessful. Can't execute new AutoHotkey.exe Subprocess.")
                        Break
                    }
                    ahk.prc.StdIn.Write(NewCode)
                    ahk.prc.StdIn.Close()

                    if ((ahk.stderr := ahk.prc.StdErr.ReadAll()) != "")    ; comprueba por errores de sintaxis
                    {
                        Util_AddLog("ERROR", "El script contiene errores de sintaxis", Script)
                        Return Util_Error("El script contiene errores de sintaxis.", ahk.stderr, CMDLN(ERROR_INVALID_SYNTAX))
                    }

                    If ((ahk.stdout := ahk.prc.StdOut.ReadAll()) != "")    ; comprueba por librerías faltantes
                    {
                        Loop Parse, ahk.stdout, "`n", "`r"
                        {
                            If (A_LoopField ~= "^#IncludeAgain")
                            {
                                NewCode .= PreprocessScript(SubStr(A_LoopField, 15), Tree . "`n" . Script, FileList, Directives) . "`n"
                                If (ERROR)
                                    Return FALSE
                                Util_AddLog("INFO", "Se ha autoincluido una biblioteca", SubStr(A_LoopField, 15))
                            }
                        }
                    }
                    Else If (A_Index == 1)
                    {
                        Util_AddLog("INFO", "No se han encontrado bibliotecas para autoincluir", Script)
                        Break
                    }

                    ahk := {}
                }
            }
        }

        Return {       Code: "; <COMPILER: v" . A_AhkVersion . ">`n" . Trim(NewCode, "`t`s`r`n")
               , Directives: Directives
               ,     Script: Script }
    }

    Return Trim(NewCode, "`t`s`r`n")
}





ProcessLine(Code) ; \.*?+[{|()^$
{
    Code := StrSplit(Code)
    Local   Escape := 0
        ,  EscSequ := ";:nrbtsvaf'{}^!+#```""
        ,     Last := ""
        ,        i := 1    ; Index

    While (i <= ObjLength(Code))
    {
        ; procesamos las cadenas de caracteres
        If (Last ~= "`"|'")
        {
            If (!Escape && Code[i] == Last)
                ++i, Last := ""
            Else
            {
                Escape := !Escape && Code[i] == "``"
                If (Escape)
                {
                    If (InStr(EscSequ, Code[i+1], TRUE))    ; caracter especial?
                    {
                        If (Code[i+1] == "s")
                            ObjRemoveAt(Code, i+1), Code[i] := A_Space  ; `s = A_Space
                        Else If (Code[i+1] == "t")
                            ObjRemoveAt(Code, i+1), Code[i] := A_Tab    ; `t = A_Tab
                        ++i
                    }
                    Else
                        ObjRemoveAt(Code, i)    ; quita `
                }
                Else
                    ++i
            }
            Continue
        }
        
        If (Code[i] ~= "\s")
        {
            If (Code[i+1] ~= "\s")    ; quita espacios de más
            {
                ObjRemoveAt(Code, i)
                Continue
            }

            If (Code[i+1] == "." && Code[i+2] ~= "\s")    ; " . " = " "
            {
                ObjRemoveAt(Code, i+1, 2)
                Continue
            }
        }
        
        If (Code[i-1] == "" || Code[i-1] ~= "\s|\(|~|\-|\+|/|&|,|\*|!|<|>|\||=|\?|:|\[|\{|\^")
        {
            If (ArrSubStr(i,12) = "A_IsCompiled")
                ObjRemoveAt(Code, i+1, 11), Code[i] := 1
            Else If (ArrSubStr(i,9) = "A_PtrSize")
                ObjRemoveAt(Code, i+1, 8), Code[i] := g_data.Compile64 ? 8 : 4
        }

        Last := Code[i++]
    }

    Local NewCode := ""
    VarSetCapacity(NewCode, ObjLength(Code) * 2)
    For i, Last in Code
        NewCode .= Last
    Return NewCode

    ArrSubStr(start, length)
    {
        Local sub_str := ""
        Loop (length)
            sub_str .= Code[start+A_Index-1]
        Return sub_str
    }
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
        ,    Data :=  { Script: Script, MainIcon: "", BinFile: "" }
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





ParseFuncParams(Params, Script)    ; FileInstall Source, Dest | support for fileinstall function - very limited | need rewrite
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
    Static ResTypes := { bmp: 2, dib: 2              ; RT_BITMAP
                       , cur: 12                     ; RT_GROUP_CURSOR
                       , ico: 14                     ; RT_GROUP_ICON
                       , htm: 23, html: 23, mht: 23  ; RT_HTML
                       , manifest: 24                ; RT_MANIFEST
                       ; otros
                       , png: ".PNG" }

    Local Data := { ResType: "", FileName: "", ResName: "", LangID: "" }
        ,  foo := ""

    If (String ~= "^\*")
    {
        If (String ~= "^\*`"")
        {
            If (!(foo := InStr(String, "`"",, 3)) || (Data.ResType := SubStr(String, 3, foo - 3)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis en @Ahk2Exe-AddResource no es correcta", Script, Line)
                Return Util_Error("La sintaxis en @Ahk2Exe-AddResource no es correcta.`nLínea: " . Line ".", Script)
            }
        }
        Else
        {
            If (!(foo := InStr(String, A_Space,, 2)) || (Data.ResType := SubStr(String, 2, foo - 2)) == "")
            {
                Util_AddLog("ERROR", "La sintaxis en @Ahk2Exe-AddResource no es correcta", Script, Line)
                Return Util_Error("La sintaxis en @Ahk2Exe-AddResource no es correcta.`nLínea: " . Line ".", Script)
            }
        }
        String := LTrim(SubStr(String, foo + 1))
    }

    foo := ParseParams(String,, 3)
    For g_k, g_v in ["FileName","ResName","LangID"]
        ObjRawSet(Data, g_v, foo[g_k])

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





;MsgBox ParseParams("a,b,c")[2]    ; b
;MsgBox ParseParams(".1 2 3.","\s")[3]    ; 3.
ParseParams(String, Delimiter := ",", Max := 0, Default := "", Trim := TRUE)
{
    Local Data := [], Len := StrLen(String)
        , Skip := 0, Pos := 1

    Loop Parse, String
    {
        If (Skip-- > 0)
            Continue
        Else If (Pos == Max)
        {
            Data[Pos] := SubStr(String, A_Index)
            Break
        }
        Else If (A_LoopField ~= Delimiter)
            ++Pos
        Else If (A_LoopField == "``")
            Skip := 1, Data[Pos] .= SubStr(String, A_Index+1, 1)
        Else
            Data[Pos] .= A_LoopField
    }

    Loop (Trim ? ObjLength(Data) : 0)
        Data[A_Index] := Trim( Data[A_Index] )

    Loop ( Max - ObjLength(Data) )
        ObjPush(Data, Default)

    Return Data
}
