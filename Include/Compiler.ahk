AhkCompile(Data)
{
    Util_AddLog("INFO", "Se ha iniciado la compilación", Data.Script)

    Local foo := "", bar := ""    ; variables temporales


    ; ======================================================================================================================================================
    ; Comprobar archivos
    ; ======================================================================================================================================================
    Local BinFile := Util_CheckBinFile(CB_GetText(Gui.Control["ddlbin"]))
    If (!BinFile)    ; ¿el archivo BIN no existe?
    {
        Util_AddLog("ERROR", "El archivo BIN no se ha encontrado", BinFile,, Data.Script)
        Return Util_Error("El archivo BIN no existe.", BinFile)
    }

    Local ExeFile := Gui.Control["edest"].Text
    If (ExeFile == "")    ; si no se a especificado un archivo destino, utiliza la misma carpeta y nombre que el archivo fuente
    {
        Local SrcDir := "", SrcName := ""
        SplitPath(Data.Script,, SrcDir,, SrcName)
        ExeFile := SrcDir . "\" . SrcName . ".exe"
    }

    If (!DirExist(GetDirParent(ExeFile)))    ; ¿el directorio del archivo EXE resultante no existe?
    {
        Util_AddLog("ERROR", "El directorio del archivo destino no existe", ExeFile,, Data.Script)
        Return Util_Error("El directorio del archivo resultante EXE no existe.", ExeFile)
    }

    Local IconFile := CB_GetText(Gui.Control["ddlico"])
    If (IconFile != "" && (DirExist(IconFile) || !FileExist(IconFile)))
    {
        Util_AddLog("ERROR", "No se ha encontrado el icono principal", IconFile,, Data.Script)
        Return Util_Error("El icono principal a establecer no existe.", IconFile)
    }

    Local hIconFile := 0
    If (IconFile != "" && !(hIconFile := FileOpen(IconFile, "r")))
    {
        Util_AddLog("ERROR", "No se ha podido abrir el icono principal para lectura", IconFile,, Data.Script)
        Return Util_Error("No se ha podido abrir el icono principar para lectura.", IconFile)
    }

    ; comprobamos que el archivo icono principal sea un icono válido comprobando algunos datos del encabezado (ICONDIR structure)
    If (hIconFile && (hIconFile.ReadUShort() != 0 || hIconFile.ReadUShort() != 1))
    {
        Util_AddLog("ERROR", "El archivo icono principal no es un icono válido", IconFile,, Data.Script)
        Return Util_Error("El archivo icono principal no es un icono válido.", IconFile)
    }

    FileSetAttrib("N", ExeFile)
    If (!FileCopy(BinFile, ExeFile, TRUE))    ; ¿no se pudo copiar el archivo BIN al destino?
    {
        Util_AddLog("ERROR", "No ha sido posible copiar el arcivo BIN al destino", ExeFile,, Data.Script)
        Return Util_Error("No se ha podido copiar el archivo BIN al destino.`n" . BinFile, ExeFile)
    }


    ; ======================================================================================================================================================
    ; Iniciar compilación
    ; ======================================================================================================================================================
    ; abrimos el archivo destino para escribir/añadir los recursos en él
    Local hUpdate := DllCall("Kernel32.dll\BeginUpdateResourceW", "UPtr", &ExeFile, "Int", FALSE, "Ptr")
    If (!hUpdate)
    {
        FileDelete(ExeFile)    ; eliminamos el archivo destino, la compilación no ha terminado correctamente
        Util_AddLog("ERROR", "No se ha podido abrir el archivo destino para su edición", ExeFile,, Data.Script, A_LastError)
        Return Util_Error("Ha ocurrido un error al abrir el archivo destino.`nError #" . A_LastError . ".", ExeFile)
    }

    FileSetAttrib("H", ExeFile)    ; ocultamos el archivo para evitar que sea "tocado" por el usuario durante la compilación

    ; cargamos el archivo destino para lectura
    ; todas las funciones ejecutadas a continuación asumimos que no fallarán, debido a que tuvo éxito la función BeginUpdateResource, y que además es raro (¿lo és?)
    Local hExe := DllCall("Kernel32.dll\LoadLibraryExW", "UPtr", &ExeFile, "UInt", 0, "UInt", 0x2, "Ptr")

    ; incluir el archivo fuente
    Local Size := StrPut(Data.Code, "UTF-8") - 1, Buffer := ""
    VarSetCapacity(Buffer, Size), StrPut(Data.Code, &Buffer, Size, "UTF-8")
    DllCall("Kernel32.dll\UpdateResourceW", "Ptr", hUpdate, "Int", 10, "Str", ">AUTOHOTKEY SCRIPT<", "UShort", SUBLANG_ENGLISH_US, "UPtr", &Buffer, "UInt", Size)
    VarSetCapacity(Buffer, 0)

    ; incluir el archivo icono principal
    Local GROUP_ICON := "", ICONS := "", IconGroupID := 0, IconID := 1
    If (hIconFile)
    {
        ; eliminamos todos grupos de iconos
        For Each, Resource in EnumResourceNames(hExe, RT_GROUP_ICON)
        {
            ; eliminamos todos los iconos en el grupo actual
            For i, IconResName in EnumResourceIcons(hExe, Resource.Name)
                DeleteResource(hUpdate, RT_ICON, IconResName)
            DeleteResource(hUpdate, Resource.Type, Resource.Name, Resource.LangID)
        }
        ; procesamos y añadimos el icono
        ProcessIcon(hIconFile, IconID, GROUP_ICON, ICONS)
        AddResource(hUpdate, RT_GROUP_ICON, ++IconGroupID, ObjGetAddress(GROUP_ICON, "Buffer"), GROUP_ICON.Size)
        Loop (ObjLength(ICONS))
            AddResource(hUpdate, RT_ICON, IconID++, ObjGetAddress(ICONS[A_Index], "Buffer"), ICONS[A_Index].Size)
        GROUP_ICON := "", ICONS := ""
    }
    hIconFile.Close()    ; cerramos el archivo icono principal

    ; incluimos los recursos
    Loop (ObjLength(Data.Directives.Resources))
    {
        foo := Data.Directives.Resources[A_Index]

        If (foo.ResType == RT_RCDATA)
        {
            VarSetCapacity(Buffer, Size := FileGetSize(foo.File)), FileOpen(foo.File, "r").RawRead(&Buffer, Size)
            AddResource(hUpdate, RT_RCDATA, foo.Name, &Buffer, Size, Data.ResourceLang)
        }

        Else If (foo.ResType == RT_GROUP_ICON || foo.ResType == RT_ICON)
        {
            If (hIconFile := FileOpen(foo.File, "r"))
            {
                ProcessIcon(hIconFile, IconID, GROUP_ICON, ICONS)
                AddResource(hUpdate, RT_GROUP_ICON, ++IconGroupID, ObjGetAddress(GROUP_ICON, "Buffer"), GROUP_ICON.Size)
                Loop (ObjLength(ICONS))
                    AddResource(hUpdate, RT_ICON, IconID++, ObjGetAddress(ICONS[A_Index], "Buffer"), ICONS[A_Index].Size)
                hIconFile.Close(), GROUP_ICON := "", ICONS := ""
            }
            Else
                Util_AddLog("ADVERTENCIA", "No se ha podido abrir el icono especificado para lectura", Data.Script,, "@Ahk2Exe-AddResource",, obj.File)
        }

        VarSetCapacity(Buffer, 0)
    }
    
    ; establecemos la información de la versión
    ; ...

    ; cerramos el archivo destino
    DllCall("Kernel32.dll\FreeLibrary", "Ptr", hExe, "Ptr")
    DllCall("Kernel32.dll\EndUpdateResourceW", "Ptr", hUpdate, "Int", FALSE)
    FileSetAttrib("N", ExeFile)    ; ya podemos hacer visible el archivo destino


    ; ======================================================================================================================================================
    ; Iniciar compresión
    ; ======================================================================================================================================================
    Local CompressionMode := CB_GetSelection(Gui.Control["ddlcomp"])
    If (CompressionMode == UPX)
    {
        Util_AddLog("INFO", "Iniciando compresión del archivo destino", ExeFile)
        If (Util_CheckCompressionFile("upx.exe"))
        {
            RunWait A_ComSpec . " /c upx.exe -f --ultra-brute --8086 --8mib-ram `"" . ExeFile . "`""
            Util_AddLog("INFO", "Compresión con UPX finalizada", ExeFile)
        }
        Else
            TaskDialog(WARNING_ICON, [Gui.Title,"Compresión.."], "No se ha encontrado UPX."), Util_AddLog("ADVERTENCIA", "No se ha encontrado UPX")
    }
    Else If (CompressionMode == MPRESS)
    {
        Util_AddLog("INFO", "Iniciando compresión del archivo destino", ExeFile)
        If (Util_CheckCompressionFile("mpress.exe"))
        {
            RunWait A_ComSpec . " /c mpress.exe -s `"" . ExeFile . "`""
            Util_AddLog("INFO", "Compresión con MPRESS finalizada", ExeFile)
        }
        Else
            TaskDialog(WARNING_ICON, [Gui.Title,"Compresión.."], "No se ha encontrado MPRESS."), Util_AddLog("ADVERTENCIA", "No se ha encontrado MPRESS")
    }
    Else
        Util_AddLog("INFO", "No se ha seleccionado ningún método de compresión", ExeFile)


    ; ======================================================================================================================================================
    ; ÉXITO!
    ; ======================================================================================================================================================
    TaskDialog(INFO_ICON, [Gui.Title,"Compilación.."], ["La compilación a finalizado con éxito!",ExeFile])

    Return TRUE
}
