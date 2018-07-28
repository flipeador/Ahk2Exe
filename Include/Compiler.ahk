AhkCompile(Data)
{
    Util_AddLog("INFO", "Se ha iniciado la compilación", Data.Script)

    Local foo := "" ;, bar := ""    ; variables temporales


    ; ======================================================================================================================================================
    ; Comprobar archivos
    ; ======================================================================================================================================================
    Util_Status("Compilando.. Comprobando archivos.")

    If (!Util_CheckBinFile(g_data.BinFile))
    {
        Util_AddLog("ERROR", "El archivo BIN no se ha encontrado", g_data.BinFile)
        Return Util_Error("El archivo BIN no existe.", g_data.BinFile, CMDLN(ERROR_BIN_FILE_NOT_FOUND))
    }

    If (!FileOpen(g_data.BinFile, "r"))
    {
        Util_AddLog("ERROR", "El archivo BIN no se ha podido abrir para lectura", g_data.BinFile)
        Return Util_Error("El archivo BIN no se ha podido abrir para lectura.", g_data.BinFile, CMDLN(ERROR_BIN_FILE_CANNOT_OPEN))
    }

    Local ExeFile := CMDLN ? g_data.ExeFile : GetFullPathName(g_data.Gui.EDDst.Text, DirGetParent(Data.Script))
    If (ExeFile == "")    ; si no se a especificado un archivo destino, utiliza la misma carpeta y nombre que el archivo fuente
    {
        Local SrcDir := "", SrcName := ""
        SplitPath(Data.Script,, SrcDir,, SrcName)
        ExeFile := SrcDir . "\" . SrcName . ".exe"
    }

    If (!DirExist(DirGetParent(ExeFile)))    ; ¿el directorio del archivo EXE resultante no existe?
    {
        Util_AddLog("ERROR", "El directorio del archivo destino no existe", ExeFile)
        Return Util_Error("El directorio del archivo resultante EXE no existe.", ExeFile, CMDLN(ERROR_DEST_DIR_NOT_FOUND))
    }

    Local IconFile := Data.Directives.MainIcon
    If (IconFile != "" && !IS_FILE(IconFile))
    {
        Util_AddLog("ERROR", "El icono principal no se ha encontrado", IconFile)
        Return Util_Error("El icono principal no se ha encontrado.", IconFile, CMDLN(ERROR_MAIN_ICON_NOT_FOUND))
    }

    Local hIconFile := 0
    If (IconFile != "" && !(hIconFile := FileOpen(IconFile, "r")))
    {
        Util_AddLog("ERROR", "El icono principal no se ha podido abrir para lectura", IconFile)
        Return Util_Error("El icono principal no se ha podido abrir para lectura.", IconFile, CMDLN(ERROR_MAIN_ICON_CANNOT_OPEN))
    }

    ; comprobamos que el archivo icono principal sea un icono válido comprobando algunos datos del encabezado (ICONDIR structure) (esto no asegura nada)
    If (hIconFile && (hIconFile.ReadUShort() != 0 || hIconFile.ReadUShort() != 1))
    {
        hIconFile.Close()
        Util_AddLog("ERROR", "El icono principal no es un icono válido", IconFile)
        Return Util_Error("El icono principal no es un icono válido.", IconFile, CMDLN(ERROR_INVALID_MAIN_ICON))
    }

    FileSetAttrib("N", ExeFile)    ; evita errores bajo ciertas condiciones
    If (!FileCopy(g_data.BinFile, ExeFile, TRUE))    ; ¿no se pudo copiar el archivo BIN al destino?
    {
        Util_AddLog("ERROR", "No se ha podido copiar el archivo BIN al destino", ExeFile)
        Return Util_Error("No se ha podido copiar el archivo BIN al destino.`n" . g_data.BinFile, ExeFile, CMDLN(ERROR_CANNOT_COPY_BIN_FILE))
    }


    ; ======================================================================================================================================================
    ; Iniciar compilación
    ; ======================================================================================================================================================
    Util_Status("Compilando.. Añadiendo recursos.")

    ; abrimos el archivo destino para eliminar/añadir/modificar los recursos en él
    Local hUpdate := BeginUpdateResource(ExeFile)
    If (!hUpdate)
    {
        FileDelete(ExeFile)    ; eliminamos el archivo destino, la compilación no ha terminado correctamente
        Util_AddLog("ERROR", "No se ha podido abrir el archivo destino para su edición", ExeFile)
        Return Util_Error("No se ha podido abrir el archivo destino para su edición.`nError #" . A_LastError . ".", ExeFile, CMDLN(ERROR_CANNOT_OPEN_EXE_FILE))
    }

    FileSetAttrib("H", ExeFile)    ; ocultamos el archivo para evitar que sea "tocado" por el usuario durante la compilación

    ; cargamos el archivo destino para lectura
    ; todas las funciones ejecutadas a continuación asumimos que no fallarán, debido a que tuvo éxito la función BeginUpdateResource, y que además es raro (¿lo és?)
    Local hExe := LoadLibrary(ExeFile, 2)


    ; incluir el archivo fuente
    ; se incluye como texto, con el nombre ">AUTOHOTKEY SCRIPT<" que AHK (archivo bin) reconocerá para proceder a ejecutar el Script
    Local Size := 0, Buffer := ""
    UpdateResource(hUpdate, RT_RCDATA, hIconFile ? ">AHK WITH ICON<" : ">AUTOHOTKEY SCRIPT<",, StrPutVar(Data.Code, Buffer, Size), Size-1)    ; -1 = '\0'


    ; incluir el archivo icono principal
    ; el primer icono (grupo #1) es el que tomará Windows como el icono principal del archivo
    ; antes de añadir un icono, debemos eliminar los iconos actuales por defecto de AHK
    Local    GROUP_ICON := "",    ICONS := ""
        ,  GROUP_CURSOR := "",  CURSORS := ""
        ,        IconID :=  1, CursorID :=  1
    If (hIconFile)
    {
        If (TRUE)
        {
            ; eliminamos todos los grupos de iconos
            For g_k, g_v in EnumResourceNames(hExe, RT_GROUP_ICON)    ; g_v = [obj] Resource
            {
                ; eliminamos todos los iconos en el grupo actual
                For g_k, g_v in EnumResourceIcons(hExe, g_v.Name)    ; g_v = IconResName
                    UpdateResource(hUpdate, RT_ICON, g_v)
                UpdateResource(hUpdate, g_v.Type, g_v.Name)
            }
        }
        ; procesamos y añadimos el icono
        ProcessIcon(hIconFile, IconID, GROUP_ICON, ICONS)
        UpdateResource(hUpdate, RT_GROUP_ICON, 159,, ObjGetAddress(GROUP_ICON, "Buffer"), GROUP_ICON.Size)
        Loop (ObjLength(ICONS))
            UpdateResource(hUpdate, RT_ICON, IconID++,, ObjGetAddress(ICONS[A_Index], "Buffer"), ICONS[A_Index].Size)
        GROUP_ICON := "", ICONS := ""
        
        hIconFile.Close()    ; cerramos el archivo icono principal
    }


    ; incluimos los recursos
    For g_k, g_v in Data.Directives.Resources    ; g_k = index | g_v = res obj info
    {
        ObjRawSet(g_v, "ResType", RES_CTYPE(g_v.ResType))
        ObjRawSet(g_v, "ResName", RES_CTYPE(g_v.ResName))
        ObjRawSet(g_v, "LangID", g_v.LangID == "" ? Data.Directives.ResourceLang : g_v.LangID)

        ; añadimos un icono ICO
        ; un archivo icono normalmente contiene varias imágenes con distintos tamaños, por ello debemos primero crear un grupo de iconos, este grupo especifica información
        ;   de las imágenes y los identificadores de cada imagen en RT_ICON
        If (g_v.ResType == RT_GROUP_ICON)
        {
            If (hIconFile := ResFileOpen(Data, g_v.FileName))
            {
                ProcessIcon(hIconFile, IconID, GROUP_ICON, ICONS)
                UpdateResource(hUpdate, RT_GROUP_ICON, g_v.ResName, g_v.LangID, ObjGetAddress(GROUP_ICON, "Buffer"), GROUP_ICON.Size)
                Loop (ObjLength(ICONS))
                    UpdateResource(hUpdate, RT_ICON, IconID++, g_v.LangID, ObjGetAddress(ICONS[A_Index], "Buffer"), ICONS[A_Index].Size)
                GROUP_ICON := "", ICONS := "", hIconFile.Close()
            }
        }

        ; añadimos un cursor CUR
        ; se aplica la misma lógica que para archivos ICO
        Else If (g_v.ResType == RT_GROUP_CURSOR)
        {
            If (hIconFile := ResFileOpen(Data, g_v.FileName))
            {
                ProcessIcon(hIconFile, CursorID, GROUP_CURSOR, CURSORS)
                UpdateResource(hUpdate, RT_GROUP_CURSOR, g_v.ResName, g_v.LangID, ObjGetAddress(GROUP_CURSOR, "Buffer"), GROUP_CURSOR.Size)
                Loop (ObjLength(CURSORS))
                    UpdateResource(hUpdate, RT_CURSOR, CursorID++, g_v.LangID, ObjGetAddress(CURSORS[A_Index], "Buffer"), CURSORS[A_Index].Size)
                GROUP_CURSOR := "", CURSORS := "", hIconFile.Close()
            }
        }

        ; añadimos imagen PNG
        Else If (g_v.ResType == ".PNG")
        {
            If (ResFileOpen(Data, g_v.FileName, Buffer, Size))
                UpdateResource(hUpdate, RT_ICON, g_v.ResName, g_v.LangID, &Buffer, Size)
        }

        ; añadimos una imagen BITMAP (.bmp)
        ; debemos excluir la cabecera BITMAPFILEHEADER al momento de añadir el archivo como un recurso RT_BITMAP
        Else If (g_v.ResType == RT_BITMAP)
        {
            If (ResFileOpen(Data, g_v.FileName, Buffer, Size))
                UpdateResource(hUpdate, RT_BITMAP, g_v.ResName, g_v.LangID, &Buffer + 14, Size - 14)    ; 14 = sizeof BITMAPFILEHEADER
        }

        ; añadimos cualquier otro tipo de recurso no reconocido, no soportado o cualquier otro archivo que no requiera modificaciones
        Else
        {
            If (ResFileOpen(Data, g_v.FileName, Buffer, Size))
                UpdateResource(hUpdate, g_v.ResType, g_v.ResName, g_v.LangID, &Buffer, Size)
        }
    }
    

    ; establecemos la información de la versión
    Local  VerRes := new VersionRes( LoadResource3(hExe, RT_VERSION, 1) )    ; LoadResource3 devuelve un puntero a la estructura VS_VERSIONINFO
        ,   StrFI := VerRes.GetChild("StringFileInfo")                       ; recupera un puntero a la estructura StringFileInfo

    local LangID := StrFI.DeleteAll(), VerInfo := ""
    for LangID, g_v in Data.Directives.VersionInfo    ; g_v = {PropName: Value, ..}
    {
        if ( !(VerInfo := StrFI.GetChild(LangID)) )    ; recupera y comprueba si existe la estructura StringTable con el idioma especificado
            VerInfo := StrFI.AddChild( new VersionRes(LangID) )    ; si no existe la crea
        for g_k, g_v in g_v    ; g_k = PropName | g_v = Value
            VerInfo.AddChild( new VersionRes(g_k,g_v) )    ; añade la propiedad
    }

    ; establecemos la versión binaria del archivo
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646997(v=vs.85).aspx
    NumPut(MAKELONG(Data.Directives.FileVersion[2], Data.Directives.FileVersion[1]), VerRes.GetValue(8), "UInt")     ; VS_FIXEDFILEINFO.dwFileVersionMS
    NumPut(MAKELONG(Data.Directives.FileVersion[4], Data.Directives.FileVersion[3]), VerRes.GetValue(12), "UInt")    ; VS_FIXEDFILEINFO.dwFileVersionLS

    ; establecemos la versión binaria del producto
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646997(v=vs.85).aspx
    NumPut(MAKELONG(Data.Directives.ProductVersion[2], Data.Directives.ProductVersion[1]), VerRes.GetValue(16), "UInt")    ; VS_FIXEDFILEINFO.dwProductVersionMS
    NumPut(MAKELONG(Data.Directives.ProductVersion[4], Data.Directives.ProductVersion[3]), VerRes.GetValue(20), "UInt")    ; VS_FIXEDFILEINFO.dwProductVersionLS

    ; guardamos la nueva estructura
    UpdateResource(hUpdate, RT_VERSION, 1, Data.Directives.ResourceLang, VerRes.Alloc(Size), Size)    ; escribimos el nuevo recurso de versión reemplazando el actual
    LangID := "", VerInfo := "", StrFI := "", VerRes := ""


    ; verificamos si debemos hacer cambios en el archivo .manifest
    ; https://msdn.microsoft.com/en-us/library/6ad1fshk.aspx
    If (Data.Directives.RequireAdmin)
    {
        foo := StrGet(LoadResource3(hExe, RT_MANIFEST, 1, Size), Size, "UTF-8")   ; recupera el contenido del archivo manifest actual
        foo := StrReplace(foo, "asInvoker", "requireAdministrator")               ; security requestedPrivileges requestedExecutionLevel level
        UpdateResource(hUpdate, RT_MANIFEST, 1,, StrPutVar(foo, Buffer, Size), Size-1)
    }


    ; cerramos el archivo destino
    FreeLibrary(hExe)
    EndUpdateResource(hUpdate)   ; cerramos el archivo y escribimos los datos


    ; establecemos el subsistema requerido para ejecutar el archivo destino
    ; PE File Format: https://blog.kowalczyk.info/articles/pefileformat.html
    If (Data.Directives.Subsystem != IMAGE_SUBSYSTEM_WINDOWS_GUI)
    {
        hExeFile := FileOpen(ExeFile, "rw")    ; asumimos que no fallará debido a que recien estuvimos trabajando con el archivo
        hExeFile.Seek(60)    ; IMAGE_DOS_HEADER.e_lfanew (File address of PE header)
        hExeFile.Seek(hExeFile.ReadUInt() + 20 + 72)    ; IMAGE_OPTIONAL_HEADER.Subsystem | 20 = sizeof IMAGE_FILE_HEADERs
        hExeFile.WriteUShort(Data.Directives.Subsystem)
        hExeFile.Close()
    }


    ; añadimos streams
    For g_k, g_v in Data.Directives.Streams    ; g_k = Index | g_v = {Name,Value,Mode,Encoding}
    {
        If (g_v.Mode == 0)    ; plain text
            FileOpen(ExeFile . ":" . g_v.Name, "w", g_v.Encoding).Write(g_v.Value)
          , Util_AddLog("INFO", "Se ha añadido el stream `"" . g_v.Name . "`"", ExeFile)
        Else If (g_v.Mode == 1)    ; plain text file
        {
            If (foo := FileOpen(g_v.Value, "r", g_v.Encoding))
            {
                foo := FileOpen(ExeFile . ":" . g_v.Name, "w", g_v.Encoding).Write(foo.Read())
                Util_AddLog("INFO", "Se ha añadido el stream `"" . g_v.Name . "`"", ExeFile)
            }
            Else
                Util_AddLog("ADVERTENCIA", "No se ha podido abrir el archivo para añadir al stream `"" . g_v.Name . "`"", g_v.Value)
        }
        Else If (g_v.Mode == 2)    ; binary file
        {
            If (foo := FileOpen(g_v.Value, "r"))
            {
                VarSetCapacity(Buffer, Size := foo.Length)
                foo.Seek(0), foo.RawRead(&Buffer, Size)
                foo := FileOpen(ExeFile . ":" . g_v.Name, "w")
                foo.Seek(0), foo.RawWrite(&Buffer, Size), foo.Close()
                Util_AddLog("INFO", "Se ha añadido el stream `"" . g_v.Name . "`"", g_v.Value)
            }
            Else
                Util_AddLog("ADVERTENCIA", "No se ha podido abrir el archivo para añadir al stream `"" . g_v.Name . "`"", g_v.Value)
        }
    }


    ; ======================================================================================================================================================
    ; Iniciar compresión
    ; ======================================================================================================================================================
    Local CompressionMode := CMDLN ? g_data.Compression : g_data.Gui.CBCmp.Selected

    If (CompressionMode != NO_COMPRESSION)
    {
        Util_Status("Comprimiendo ..")
        Util_AddLog("INFO", "Iniciando compresión del archivo destino", ExeFile)
    }
    Else
        Util_AddLog("INFO", "No se ha seleccionado ningún método de compresión", ExeFile)

    If (CompressionMode == UPX)
    {
        If (IS_FILE("upx.exe"))
        {
            RunWait("upx.exe -f --ultra-brute --8086 --8mib-ram `"" . ExeFile . "`"",, BE_QUIET ? "Hide" : "")
            Util_AddLog("INFO", "Compresión con UPX finalizada", ExeFile)
        }
        Else
        {
            Util_AddLog("ADVERTENCIA", "No se ha encontrado UPX")
            If (!BE_QUIET)
                TaskDialog(WARNING_ICON, [Gui.Title,"Compresión.."], "No se ha encontrado UPX.")
        }
    }
    
    If (CompressionMode == MPRESS)
    {
        If (IS_FILE("mpress.exe"))
        {
            RunWait("mpress.exe -s `"" . ExeFile . "`"",, BE_QUIET ? "Hide" : "")
            Util_AddLog("INFO", "Compresión con MPRESS finalizada", ExeFile)
        }
        Else
        {
            Util_AddLog("ADVERTENCIA", "No se ha encontrado MPRESS")
            If (!BE_QUIET)
                TaskDialog(WARNING_ICON, [Gui.Title,"Compresión.."], "No se ha encontrado MPRESS.")
        }
    }


    ; ======================================================================================================================================================
    ; Finalizar
    ; ======================================================================================================================================================
    Util_Status("La compilación a finalizado.")
    If (Data.Directives.PostExec)
    {
        Util_AddLog("INFO", "Se ha especificado un comando de post-ejecución", Data.Directives.PostExec.Target)
        If (!DirExist(Data.Directives.PostExec.WorkingDir))
            Data.Directives.PostExec.WorkingDir := DirGetParent(ExeFile)
        If (Data.Directives.PostExec.Options == "*")    ; AHK code
        {
            try    ; try Subprocess
            {
                ExecScript(Data.Directives.PostExec.Target, Data.Directives.PostExec.WorkingDir, 0)    ; nuevo proceso
                Util_AddLog("INFO", "El comando de post-ejecución se ha ejecutado en un nuevo proceso", Data.Directives.PostExec.Target)
            }
            catch    ; error
                Util_AddLog("ADVERTENCIA", "Ha ocurrido un error al ejecutar el comando de post-ejecución", Data.Directives.PostExec.Target)
                
        }
        Else    ; Run Function
        {
            try    ; try Subprocess
            {
                ExecScript("Run '" . Data.Directives.PostExec.Target . "','" . Data.Directives.PostExec.WorkingDir . "','" . Data.Directives.PostExec.Options . "'", Data.Directives.PostExec.WorkingDir, 0)    ; intentamos en un nuevo proceso
                Util_AddLog("INFO", "El comando de post-ejecución se ha ejecutado en un nuevo proceso", A_ScriptFullPath)
            }
            catch    ; error
            {
                try    ; try Run
                {
                    Run(Data.Directives.PostExec.Target, Data.Directives.PostExec.WorkingDir, Data.Directives.PostExec.Options)
                    Util_AddLog("INFO", "El comando de post-ejecución se ha ejecutado por el compilador", A_ScriptFullPath)
                } 
                catch    ; error
                    Util_AddLog("ADVERTENCIA", "Ha ocurrido un error de sintaxis en el comando de post-ejecución", Data.Directives.PostExec.Target)
            }
        }
    }

    
    ; ======================================================================================================================================================
    ; ÉXITO! | TERMINAMOS
    ; ======================================================================================================================================================
    FileSetAttrib("N", ExeFile)    ; ya podemos hacer visible el archivo destino
    If (!BE_QUIET)
        TaskDialog(INFO_ICON, [Title,"Compilación.."], ["La compilación a finalizado con éxito!",ExeFile])

    Return TRUE
}





ResFileOpen(Data, FileName, ByRef Buffer := "", ByRef Size := 0)
{
    Local f := FileOpen(FileName, "r")
    If (f)
    {
        f.Seek(0)
        If (IsByRef(Buffer))
        {
            VarSetCapacity(Buffer, Size := f.Length)
            Return f.RawRead(&Buffer, Size)
        }
        Return f
    }

    Util_AddLog("ADVERTENCIA", "No se ha podido abrir el archivo especificado en @Ahk2Exe-AddResource", Data.Script)
    Return FALSE
}
