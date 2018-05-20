AhkCompile(Data)
{
    Util_AddLog("INFO", "Se ha iniciado la compilación", Data.Script)

    Local foo := "", bar := ""    ; variables temporales


    ; ======================================================================================================================================================
    ; Comprobar archivos
    ; ======================================================================================================================================================
    Util_Status("Compilando.. Comprobando archivos.")

    If (!Util_CheckBinFile(g_data.BinFile))
    {
        Util_AddLog("ERROR", "El archivo BIN no se ha encontrado", g_data.BinFile)
        Return Util_Error("El archivo BIN no existe.", g_data.BinFile, CMDLN ? ERROR_BIN_FILE_NOT_FOUND : NO_EXIT)
    }

    If (!FileOpen(g_data.BinFile, "r"))
    {
        Util_AddLog("ERROR", "El archivo BIN no se ha podido abrir para lectura", g_data.BinFile)
        Return Util_Error("El archivo BIN no se ha podido abrir para lectura.", g_data.BinFile, CMDLN ? ERROR_BIN_FILE_CANNOT_OPEN : NO_EXIT)
    }

    Local ExeFile := CMDLN ? g_data.ExeFile : Gui.Control["edest"].Text
    If (ExeFile == "")    ; si no se a especificado un archivo destino, utiliza la misma carpeta y nombre que el archivo fuente
    {
        Local SrcDir := "", SrcName := ""
        SplitPath(Data.Script,, SrcDir,, SrcName)
        ExeFile := SrcDir . "\" . SrcName . ".exe"
    }

    If (!DirExist(DirGetParent(ExeFile)))    ; ¿el directorio del archivo EXE resultante no existe?
    {
        Util_AddLog("ERROR", "El directorio del archivo destino no existe", ExeFile)
        Return Util_Error("El directorio del archivo resultante EXE no existe.", ExeFile)
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
    ; se incluye como texto simple, con el nombre ">AUTOHOTKEY SCRIPT<" que AHK (archivo bin) reconocerá para proceder a ejecutar el Script
    Local Size := StrPut(Data.Code, "UTF-8") - 1, Buffer := ""
    VarSetCapacity(Buffer, Size), StrPut(Data.Code, &Buffer, Size, "UTF-8")
    UpdateResource(hUpdate, RT_RCDATA, ">AUTOHOTKEY SCRIPT<",, &Buffer, Size)
    VarSetCapacity(Buffer, 0)

    ; incluir el archivo icono principal
    ; el primer icono (grupo #1) es el que tomará Windows como el icono principal del archivo
    ; antes de añadir un icono, debemos eliminar los iconos actuales por defecto de AHK
    Local    GROUP_ICON := "",    ICONS := ""
        ,  GROUP_CURSOR := "",  CURSORS := ""
        ,        IconID :=  1, CursorID :=  1
    If (hIconFile)
    {
        ; eliminamos todos los grupos de iconos
        For Each, Resource in EnumResourceNames(hExe, RT_GROUP_ICON)
        {
            ; eliminamos todos los iconos en el grupo actual
            For i, IconResName in EnumResourceIcons(hExe, Resource.Name)
                UpdateResource(hUpdate, RT_ICON, IconResName)
            UpdateResource(hUpdate, Resource.Type, Resource.Name)
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
    Loop (ObjLength(Data.Directives.Resources))
    {
        foo := Data.Directives.Resources[A_Index]
        ObjRawSet(foo, "ResType", RES_CTYPE(foo.ResType))
        ObjRawSet(foo, "ResName", RES_CTYPE(foo.ResName))
        ObjRawSet(foo, "LangID", foo.LangID == "" ? Data.Directives.ResourceLang : foo.LangID)

        ; añadimos un icono ICO
        ; un archivo icono normalmente contiene varias imágenes con distintos tamaños, por ello debemos primero crear un grupo de iconos, este grupo especifica información
        ;   de las imágenes y los identificadores de cada imagen en RT_ICON
        If (foo.ResType == RT_ICON)
        {
            If (hIconFile := ResFileOpen(Data, foo.FileName))
            {
                ProcessIcon(hIconFile, IconID, GROUP_ICON, ICONS)
                UpdateResource(hUpdate, RT_GROUP_ICON, foo.ResName, foo.LangID, ObjGetAddress(GROUP_ICON, "Buffer"), GROUP_ICON.Size)
                Loop (ObjLength(ICONS))
                    UpdateResource(hUpdate, RT_ICON, IconID++, foo.LangID, ObjGetAddress(ICONS[A_Index], "Buffer"), ICONS[A_Index].Size)
                GROUP_ICON := "", ICONS := ""
            }
        }

        ; añadimos un cursor CUR
        ; se aplica la misma lógica que para archivos ICO
        Else If (foo.ResType == RT_CURSOR)
        {
            If (hIconFile := ResFileOpen(Data, foo.FileName))
            {
                ProcessIcon(hIconFile, CursorID, GROUP_CURSOR, CURSORS)
                UpdateResource(hUpdate, RT_GROUP_CURSOR, foo.ResName, foo.LangID, ObjGetAddress(GROUP_CURSOR, "Buffer"), GROUP_CURSOR.Size)
                Loop (ObjLength(CURSORS))
                    UpdateResource(hUpdate, RT_CURSOR, CursorID++, foo.LangID, ObjGetAddress(CURSORS[A_Index], "Buffer"), CURSORS[A_Index].Size)
                GROUP_CURSOR := "", CURSORS := ""
            }
        }

        ; añadimos imagen PNG
        Else If (foo.ResType == ".PNG")
        {
            If (ResFileOpen(Data, foo.FileName, Buffer, Size))
                UpdateResource(hUpdate, RT_ICON, foo.ResName, foo.LangID, &Buffer, Size)
        }

        ; añadimos una imagen BITMAP (.bmp)
        ; debemos excluir la cabecera BITMAPFILEHEADER al momento de añadir el archivo como un recurso RT_BITMAP
        Else If (foo.ResType == RT_BITMAP)
        {
            If (ResFileOpen(Data, foo.FileName, Buffer, Size))
                UpdateResource(hUpdate, RT_BITMAP, foo.ResName, foo.LangID, &Buffer + 14, Size - 14)    ; 14 = sizeof BITMAPFILEHEADER
        }

        ; añadimos cualquier otro tipo de recurso no reconocido, no soportado o cualquier otro archivo que no requiera modificaciones
        Else
        {
            If (ResFileOpen(Data, foo.FileName, Buffer, Size))
                UpdateResource(hUpdate, foo.ResType, RES_CTYPE(foo.ResName), foo.LangID, &Buffer, Size)
        }

        hIconFile := 0, Buffer := "", VarSetCapacity(Buffer, 0)
    }
    

    ; establecemos la información de la versión
    Local pVS_VERSIONINFO := LoadResource3(hExe, RT_VERSION, 1)
        ,          VerRes := new VersionRes(pVS_VERSIONINFO)
        ,         VerInfo := VerRes.GetChild("StringFileInfo").GetChild("040904B0")
    
    VerInfo.DeleteAll()    ; eliminamos todas las propiedades
    For g_k, g_v in Data.Directives.VersionInfo    ; añadimos las nuevas propiedades
        VerInfo.AddChild( new VersionRes(g_k, g_v) )    ; g_k = Prop | g_v = Value

    ; establecemos la versión del archivo
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646997(v=vs.85).aspx
    Local FileVersion := StrSplit(Data.Directives.VersionInfo.FileVersion, ".")
    NumPut(MAKELONG(FileVersion[2] is "Integer" ? FileVersion[2] : 0, FileVersion[1] is "Integer" ? FileVersion[1] : 0), ObjGetAddress(VerRes, "Value")+8, "UInt")    ; VS_FIXEDFILEINFO.dwFileVersionMS
    NumPut(MAKELONG(FileVersion[4] is "Integer" ? FileVersion[4] : 0, FileVersion[3] is "Integer" ? FileVersion[3] : 0), ObjGetAddress(VerRes, "Value")+12, "UInt")    ; VS_FIXEDFILEINFO.dwFileVersionLS

    ; establecemos la versión del producto
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646997(v=vs.85).aspx
    Local ProductVersion := StrSplit(Data.Directives.VersionInfo.ProductVersion, ".")
    NumPut(MAKELONG(ProductVersion[2] is "Integer" ? ProductVersion[2] : 0, ProductVersion[1] is "Integer" ? ProductVersion[1] : 0), ObjGetAddress(VerRes, "Value")+16, "UInt")    ; VS_FIXEDFILEINFO.dwProductVersionMS
    NumPut(MAKELONG(ProductVersion[4] is "Integer" ? ProductVersion[4] : 0, ProductVersion[3] is "Integer" ? ProductVersion[3] : 0), ObjGetAddress(VerRes, "Value")+20, "UInt")    ; VS_FIXEDFILEINFO.dwProductVersionLS

    ; guardamos la nueva estructura
    VarSetCapacity(Buffer, VerRes.GetSize())    ; Buffer es la nueva estructura VS_VERSIONINFO
    UpdateResource(hUpdate, RT_VERSION, 1)    ; eliminamos el recurso de versión actual
    UpdateResource(hUpdate, RT_VERSION, 1, Data.Directives.ResourceLang, &Buffer, VerRes.Save(&Buffer))    ; escribimos el nuevo recurso de versión
    Buffer := VerRes := VerInfo := "", VarSetCapacity(Buffer, 0)


    ; cerramos el archivo destino
    FreeLibrary(hExe), EndUpdateResource(hUpdate)

    ; establecemos el subsistema requerido para ejecutar el archivo destino
    ; PE File Format: https://blog.kowalczyk.info/articles/pefileformat.html
    hExeFile := FileOpen(ExeFile, "rw")    ; asumimos que no fallará debido a que recien estuvimos trabajando con el archivo
    hExeFile.Seek(60)    ; IMAGE_DOS_HEADER.e_lfanew (File address of PE header)
    hExeFile.Seek(hExeFile.ReadUInt() + 20 + 72)    ; IMAGE_OPTIONAL_HEADER.Subsystem | 20 = sizeof IMAGE_FILE_HEADERs
    hExeFile.WriteUShort(Data.Directives.Subsystem)
    hExeFile.Close()


    ; ======================================================================================================================================================
    ; Iniciar compresión
    ; ======================================================================================================================================================
    Local CompressionMode := CMDLN ? g_data.Compression : CB_GetSelection(Gui.Control["ddlcomp"])

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
    If (Data.Directives.PostExec != "")
    {
        Util_AddLog("INFO", "Se ha especificado un comando de post-ejecución", Data.Directives.PostExec)
        Run(Data.Directives.PostExec)
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
        If (IsByRef(Buffer))
        {
            VarSetCapacity(Buffer, Size := f.Length)
            f.RawRead(&Buffer, Size), f.Close()
            Return TRUE
        }
        Return f
    }

    Util_AddLog("ADVERTENCIA", "No se ha podido abrir el archivo especificado en @Ahk2Exe-AddResource", Data.Script)
    Return FALSE
}
