/*
    Recupera la información de versión de un archivo.
    Parámetros:
        Filename:
            El nombre del archivo a consultar.
        PropName:
            Las propiedades a consultar separadas por "|". Si la propiedad se encuentra, se incluirá en el objeto de retorno.
    Return:
        Si tuvo éxito devuelve un objeto, o cero en caso contrario.
    Ejemplo:
        For Each, Value In GetFileVersionInfo(A_ComSpec)
            Info .= Each . "`t|`t" . Value . "`n"
        MsgBox(Info)
*/
GetFileVersionInfo(Filename, PropName := "")    ; WIN_V+
{
    ; GetFileVersionInfoSizeEx function
    ; https://docs.microsoft.com/es-es/windows/desktop/api/winver/nf-winver-getfileversioninfosizeexa
    local size := DllCall("Version.dll\GetFileVersionInfoSizeExW", "UInt", 1, "UPtr", &Filename, "Ptr", 0, "UInt")    ; FILE_VER_GET_LOCALISED = 1
    if (!size)
        return FALSE
    
    ; GetFileVersionInfoEx function
    ; https://docs.microsoft.com/es-es/windows/desktop/api/winver/nf-winver-getfileversioninfoexa
    local VS_VERSIONINFO := ""
    VarSetCapacity(VS_VERSIONINFO, size)
    if (!DllCall("Version.dll\GetFileVersionInfoExW", "UInt", 1, "UPtr", &Filename, "UInt", 0, "UInt", size, "UPtr", &VS_VERSIONINFO))    ; FILE_VER_GET_LOCALISED = 1
        return FALSE
    
    ; VerQueryValue function
    ; https://docs.microsoft.com/es-es/windows/desktop/api/winver/nf-winver-verqueryvaluea
    local VERINFO := 0
    if (!DllCall("Version.dll\VerQueryValueW", "UPtr", &VS_VERSIONINFO, "Str", "\VarFileInfo\Translation", "UPtrP", VERINFO, "UIntP", 0))
        return FALSE
    
    local LangCP    := "\StringFileInfo\" . Format("{:04X}{:04X}", NumGet(VERINFO, "UShort"), NumGet(VERINFO+2, "UShort")) . "\"
    local OutputVar := {}
    
    Loop Parse, PropName == "" ? "Comments|InternalName|ProductName|CompanyName|LegalCopyright|ProductVersion|FileDescription|LegalTrademarks|PrivateBuild|FileVersion|OriginalFilename|SpecialBuild" : PropName, "|"
        if (DllCall("Version.dll\VerQueryValueW", "UPtr", &VS_VERSIONINFO, "Str", LangCP . A_LoopField, "PtrP", VERINFO, "UIntP", Size))
            OutputVar[A_LoopField] := StrGet(VERINFO, Size, "UTF-16")
    
    Return OutputVar
}
