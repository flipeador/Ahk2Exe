AhkCompile(Code)
{
    ; ======================================================================================================================================================
    ; Comprobar archivos
    ; ======================================================================================================================================================
    Local BinTxt := CB_GetText(Gui.Control["ddlbin"], CB_GetSelection(Gui.Control["ddlbin"]))
        , BinFile := Util_CheckBinFile(BinTxt)
    If (!BinFile)    ; ¿el archivo BIN no existe?
    {
        Util_Error("El archivo BIN no existe.", BinTxt)
        Log .= "No se ha encontrado el archivo BIN [" . BinTxt . "]`n"
        Return FALSE
    }

    Local SrcFile := CB_GetText(Gui.Control["ddlsrc"], CB_GetSelection(Gui.Control["ddlsrc"]))

    Local ExeFile := CB_GetText(Gui.Control["edest"], CB_GetSelection(Gui.Control["edest"]))
    If (ExeFile == "")
    {
        SplitPath(SrcFile,, SrcDir,, SrcName)
        ExeFile := SrcDir . "\" . SrcName . ".exe"
    }
    If (!FileCopy(BinFile, ExeFile, 1))
    {
        Util_Error("No se ha podido compiar el archivo BIN al destino.", ExeFile)
        Log .= "Error al copiar el archivo a destino [" . ExeFile . "]`n"
        Return FALSE
    }


    ; ======================================================================================================================================================
    ; Iniciar compilación
    ; ======================================================================================================================================================
    Local hUpdate := 0, Size := 0, Buffer := ""
    hUpdate := DllCall("Kernel32.dll\BeginUpdateResourceW", "UPtr", &ExeFile, "Int", FALSE, "Ptr")
    Size := StrPut(Code, "UTF-8") - 1
    VarSetCapacity(Buffer, Size)
    StrPut(Code, &Buffer, Size, "UTF-8")
    DllCall("Kernel32.dll\UpdateResourceW", "Ptr", hUpdate, "Int", 10, "Str", ">AUTOHOTKEY SCRIPT<", "UShort", 0x0409, "UPtr", &Buffer, "UInt", Size)
    DllCall("Kernel32.dll\EndUpdateResourceW", "Ptr", hUpdate, "Int", FALSE)


    ; ======================================================================================================================================================
    ; Iniciar compresión
    ; ======================================================================================================================================================
    Local  CompTxt := CB_GetText(Gui.Control["ddlcomp"], CB_GetSelection(Gui.Control["ddlcomp"]))
        , CompFile := Util_CheckCompress(CompTxt)
    If (CompFile && InStr(CompTxt, "UPX"))    ; ¿comprimir con UPX?
        RunWait A_ComSpec . " /c upx.exe -f --ultra-brute --8086 --8mib-ram `"" . ExeFile . "`""
    Else If (CompFile && InStr(CompTxt, "MPRESS"))    ; ¿comprimir con MPRESS?
        RunWait A_ComSpec . " /c mpress.exe -s `"" . ExeFile . "`""


    ; ======================================================================================================================================================
    ; ÉXITO!
    ; ======================================================================================================================================================
    TaskDialog([Gui.Hwnd,0xFFFD], [Gui.Title,"Compilación.."], ["La compilación a finalizado con éxito!",ExeFile])
    Return TRUE
}
