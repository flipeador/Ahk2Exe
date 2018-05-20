BeginUpdateResource(FileName, DeleteExistingResources := FALSE)
{
    Return DllCall("Kernel32.dll\BeginUpdateResourceW", "UPtr", &FileName, "Int", DeleteExistingResources, "Ptr")
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648030(v=vs.85).aspx





EndUpdateResource(hUpdate, Discard := FALSE)
{
    Return DllCall("Kernel32.dll\EndUpdateResourceW", "Ptr", hUpdate, "Int", Discard)
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648032(v=vs.85).aspx





EnumResourceNames(hExe, ResType, Flags := 0, LangID := 0x0409)
{
    Local EnumResNameProc := CallbackCreate("EnumResNameProc", "&", 4)
        ,           Data  := []

    DllCall("Kernel32.dll\EnumResourceNamesExW", "Ptr", hExe, "UPtr", RES_TYPE(ResType), "UPtr", EnumResNameProc, "UPtr", 0, "UInt", Flags, "UShort", LangID)
    CallbackFree(EnumResNameProc)
    Return Data


    EnumResNameProc(Address)    ; EnumResNameProc(HMODULE hModule, LPCTSTR lpszType, LPTSTR lpszName, LONG_PTR lParam)
    {
        Local  hModule := NumGet(Address)
            , lpszType := NumGet(Address + A_PtrSize)
            , lpszName := NumGet(Address + A_PtrSize*2)

        ObjPush(Data, {  hModule: hModule
                      ,     Type: IS_INTRESOURCE(lpszType) ? lpszType : StrGet(lpszType, "UTF-16")
                      ,     Name: IS_INTRESOURCE(lpszName) ? lpszName : StrGet(lpszName, "UTF-16")
                      ,   LangID: LangID })

        Return TRUE    ; continuar enumeración
    } ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648034(v=vs.85).aspx
}





UpdateResource(hUpdate, ResType, ResName, LangID := 0x0409, pData := 0, Size := 0)
{
    If (Type(pData) != "Integer" || (pData && pData < 0x10000))
        Throw Exception("Function UpdateResource invalid parameter #5", -1, "Invalid address")
    If (Type(Size) != "Integer" || Size < 0)
        Throw Exception("Function UpdateResource invalid parameter #6", -1, "Invalid size")

    Return DllCall("Kernel32.dll\UpdateResourceW", "Ptr", hUpdate, "Ptr", RES_TYPE(ResType), "UPtr", RES_NAME(ResName), "UShort", LangID, "UPtr", pData, "UInt", Size)
}





FindResource(hExe, ResType, ResName, LangID := 0x0409)
{
    Return DllCall("Kernel32.dll\FindResourceExW", "Ptr", hExe, "Ptr", RES_TYPE(ResType), "UPtr", RES_NAME(ResName), "UShort", LangID, "Ptr")
}





LockResource(hResData)
{
    Return DllCall("Kernel32.dll\LockResource", "Ptr", hResData, "UPtr")
}





LoadResource(hExe, hResInfo)
{
    Return DllCall("Kernel32.dll\LoadResource", "Ptr", hExe, "Ptr", hResInfo, "Ptr")
}

LoadResource2(hExe, hResInfo)
{
    Return LockResource(LoadResource(hExe, hResInfo))
}

LoadResource3(hExe, ResType, ResName, ByRef Size := "", LangID := 0x0409)
{
    Local hResInfo := FindResource(hExe, ResType, ResName, LangID)
    Size := SizeofResource(hExe, hResInfo)
    Return LoadResource2(hExe, hResInfo)    
}





SizeofResource(hExe, hResInfo)
{
    Return DllCall("Kernel32.dll\SizeofResource", "Ptr", hExe, "Ptr", hResInfo, "UInt")
}





FreeLibrary(hModule)
{
    Return hModule ? DllCall("Kernel32.dll\FreeLibrary", "Ptr", hModule) : 0
} ; https://msdn.microsoft.com/es-es/library/windows/desktop/ms683152(v=vs.85).aspx





LoadLibrary(DllName, Flags := 0)
{
    Return DllCall("Kernel32.dll\LoadLibraryEx", "UPtr", &DllName, "UInt", 0, "UInt", Flags, "Ptr")
}





LoadImage(hInstance, Name, Type := 0, W := 0, H := 0, Flags := "")
{
    Local hExe := 0
    If (hInstance == -1)
        hInstance := A_IsCompiled ? hExe := LoadLibrary(A_ScriptFullPath, 2) : 0
    Flags := Flags == "" ? (hInstance ? 0 : 0x10) : Flags
    Local hImage := DllCall("User32.dll\LoadImageW", "Ptr", hInstance, "UPtr", Type(Name) == "Integer" ? Name : &Name, "UInt", Type, "Int", W, "Int", H, "UInt", Flags, "Ptr")
    FreeLibrary(hExe)
    Return hImage
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648045(v=vs.85).aspx






EnumResourceIcons(hExe, IconGroupName, LangId := 0x0409)
{
    Local hResInfo := FindResource(hExe, 14, IconGroupName, LangId)    ; 14 = RT_GROUP_ICON
    If (!hResInfo)
        Return FALSE

    Local hResData := LoadResource(hExe, hResInfo)
        , hResLock := LockResource(hResData)
        ,    Icons := []
    Loop (NumGet(hResLock + 4, "UShort"))
        Icons[A_Index] := NumGet(hResLock + 6 + (A_Index-1)*14 + 12, "UShort")

    Return Icons
}





/*
    ICONDIR structure
    Offset#   Size (in bytes)   Purpose
    0         2                 Reserved. Must always be 0.
    2         2                 Specifies image type: 1 for icon (.ICO) image, 2 for cursor (.CUR) image. Other values are invalid.
    4         2                 Specifies number of images in the file.

    Structure of image directory
    Image #1    Entry for the first image
    Image #2    Entry for the second image
    ... 
    Image #n    Entry for the last image
    
    Image entry
    ICONDIRENTRY structure
    Offset#   Size (in bytes)   Purpose
    0         1                 Specifies image width in pixels. Can be any number between 0 and 255. Value 0 means image width is 256 pixels.
    1         1                 Specifies image height in pixels. Can be any number between 0 and 255. Value 0 means image height is 256 pixels.
    2         1                 Specifies number of colors in the color palette. Should be 0 if the image does not use a color palette.
    3         1                 Reserved. Should be 0.[Notes 2]
    4         2                 In ICO format: Specifies color planes. Should be 0 or 1.[Notes 3] | In CUR format: Specifies the horizontal coordinates of the hotspot in number of pixels from the left.
    6         2                 In ICO format: Specifies bits per pixel. [Notes 4] | In CUR format: Specifies the vertical coordinates of the hotspot in number of pixels from the top.
    8         4                 Specifies the size of the image's data in bytes
    12        4                 Specifies the offset of BMP or PNG data from the beginning of the ICO/CUR file

          RT_ICON = sizeof image's data
    RT_GROUP_ICON = sizeof ICONDIR + number of images * (12 + sizeof UShort)    | 12 = ICONDIRENTRY Offset#0-Offset#8 | UShort = IconID
*/
ProcessIcon(hIconFile, IconIDs, ByRef GROUP_ICON, ByRef ICONS)
{
    hIconFile.Seek(2), GROUP_ICON := {Buffer: "", Size: 0}, ICONS := []
    Local   Type := hIconFile.ReadUShort()    ; 1 = ICO | 2 = CUR
        , Images := hIconFile.ReadUShort()    ; número de imágenes en el archivo

    ObjRawSet(GROUP_ICON, "Size", 6 + Images * (12 + 2))
    ObjSetCapacity(GROUP_ICON, "Buffer", GROUP_ICON.Size)
    NumPut(0x0000, ObjGetAddress(GROUP_ICON, "Buffer") + 0, "UShort")    ; siempre debe ser cero
    NumPut(Type  , ObjGetAddress(GROUP_ICON, "Buffer") + 2, "UShort")
    NumPut(Images, ObjGetAddress(GROUP_ICON, "Buffer") + 4, "UShort")

    Local pGROUP_ICON := ObjGetAddress(GROUP_ICON, "Buffer") + 6, ImageOffset := 0, Offset := 0
    Loop (Images)
    {
        hIconFile.RawRead(pGROUP_ICON, 12)    ; ICONDIRENTRY Offset#0-Offset#8
        pGROUP_ICON := NumPut(IsObject(IconIDs) ? IconIDs[A_Index] : IconIDs++, pGROUP_ICON + 12, "UShort")

        ImageOffset := hIconFile.ReadUInt()    ; the offset of image's data
        Offset := hIconFile.Pos
        hIconFile.Seek(ImageOffset)

        ObjPush(ICONS, {Buffer: "", Size: 0})
        ObjRawSet(ICONS[A_Index], "Size", NumGet(pGROUP_ICON - 2 - 4, "UInt") + (Type == 2 ? 4 : 0))    ; por algún motivo que desconozco, la imagen cursor debe empezar con unos 4 bytes adicionales
        ObjSetCapacity(ICONS[A_Index], "Buffer", ICONS[A_Index].Size)
        hIconFile.RawRead(ObjGetAddress(ICONS[A_Index], "Buffer") + (Type == 2 ? 4 : 0), ICONS[A_Index].Size - (Type == 2 ? 4 : 0))
        hIconFile.Seek(Offset)
    }
}





; devuelve TRUE si «r» es una dirección de memoria, o cero si es un número entero válido como nombre de recurso
; el nombre de un recurso no puede ser mayor o igual a 65536, de lo contrario la función lo interpreta como una dirección de memoria
; devuelve un ERROR si «r» no es un número válido
IS_INTRESOURCE(ByRef r)    ; IS_INTRESOURCE(_r) ((((ULONG_PTR)(_r)) >> 16) == 0)
{
    Return (r:=Integer(r)) >> 16 == 0    ; r < 0x10000
}

; si se especifica un entero comprendido entre 0 y 65535 inclusive, devuelve el mismo número; caso contrario devuelve un puntero a una cadena.
RES_NAME(ByRef s)
{
    Return Type(s) == "Integer" && s >= 0 && s < 0x10000 ? s : &(s := Format("{:U}", s))
}

; si se especifica un entero comprendido entre 0 y 65535 inclusive, devuelve el mismo número; caso contrario devuelve un puntero a una cadena.
RES_TYPE(ByRef s)
{
    Return Type(s) == "Integer" && s >= 0 && s < 0x10000 ? s : &(s := Format("{:U}", s))
}

; corrige el tipo de datos dependiendo del valor especificado
RES_CTYPE(s)
{
    Return s is "Float" || !(s is "Integer") || StrLen(s) > 7 || s >= 0x10000 || s < 0 ? String(s) : Integer(s)
}
