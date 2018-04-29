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

    ; incluir el archivo fuente
    Local Size := StrPut(Data.Code, "UTF-8") - 1, Buffer := ""
    VarSetCapacity(Buffer, Size), StrPut(Data.Code, &Buffer, Size, "UTF-8")
    DllCall("Kernel32.dll\UpdateResourceW", "Ptr", hUpdate, "Int", 10, "Str", ">AUTOHOTKEY SCRIPT<", "UShort", SUBLANG_ENGLISH_US, "UPtr", &Buffer, "UInt", Size)
    VarSetCapacity(Buffer, 0)

    ; incluimos los recursos
    Loop (ObjLength(Data.Directives.Resources))
    {
        foo := Data.Directives.Resources[A_Index]

        If (foo.ResType == RT_RCDATA)
        {
            VarSetCapacity(Buffer, Size := FileGetSize(foo.File)), FileOpen(foo.File, "r").RawRead(&Buffer, Size)
            DllCall("Kernel32.dll\UpdateResourceW", "Ptr", hUpdate, "Int", RT_RCDATA, "UPtr", foo.Name, "UShort", Data.ResourceLang, "UPtr", &Buffer, "UInt", Size)
        }

        VarSetCapacity(Buffer, 0)
    }
    
    ; establecemos la información de la versión
    ; ...

    ; cerramos el archivo destino
    DllCall("Kernel32.dll\EndUpdateResourceW", "Ptr", hUpdate, "Int", FALSE)


    ; ======================================================================================================================================================
    ; Iniciar compresión
    ; ======================================================================================================================================================
    Local CompressionMode := CB_GetSelection(Gui.Control["ddlcomp"])
    If (CompressionMode == UPX)
    {
        If (Util_CheckCompressionFile("upx.exe"))
            RunWait A_ComSpec . " /c upx.exe -f --ultra-brute --8086 --8mib-ram `"" . ExeFile . "`""
        Else
            TaskDialog(WARNING_ICON, [Gui.Title,"Compresión.."], "No se ha encontrado UPX.")
    }
    Else If (CompressionMode == MPRESS)
    {
        If (Util_CheckCompressionFile("mpress.exe"))
            RunWait A_ComSpec . " /c mpress.exe -s `"" . ExeFile . "`""
        Else
            TaskDialog(WARNING_ICON, [Gui.Title,"Compresión.."], "No se ha encontrado MPRESS.")
    }


    ; ======================================================================================================================================================
    ; ÉXITO!
    ; ======================================================================================================================================================
    TaskDialog(INFO_ICON, [Gui.Title,"Compilación.."], ["La compilación a finalizado con éxito!",ExeFile])

    Return TRUE
}
