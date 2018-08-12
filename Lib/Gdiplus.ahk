/*
    GDI+ Flat API
        https://docs.microsoft.com/es-es/windows/desktop/gdiplus/-gdiplus-flatapi-flat

    Classes
        https://docs.microsoft.com/es-es/windows/desktop/gdiplus/-gdiplus-class-classes

    Status Enumeration (error codes)
        https://docs.microsoft.com/en-us/windows/desktop/api/Gdiplustypes/ne-gdiplustypes-status

    You can find the complete library in the following link
        https://github.com/flipeador/AutoHotkey/tree/master/Lib/gdiplus

    Thanks to
        tariqporter (TIC) - https://github.com/tariqporter/Gdip/blob/master/Gdip.ahk
*/
class Gdiplus
{
    ; ===================================================================================================================
    ; STATIC/CLASS VARIABLES
    ; ===================================================================================================================
    static hModule             := 0
    static pToken              := 0
    static GdiplusStartupInput := ""     ; https://docs.microsoft.com/es-es/windows/desktop/api/gdiplusinit/ns-gdiplusinit-gdiplusstartupinput
    static LastError           := 0      ; almacena el último código de error de la enumeración Status


    ; ===================================================================================================================
    ; PUBLIC METHODS
    ; ===================================================================================================================
    Startup()
    {
        if ( !Gdiplus.pToken )
        {
            if !( Gdiplus.hModule := DllCall("Kernel32.dll\LoadLibraryW", "Str", "gdiplus.dll", "Ptr") )
                throw Exception("Could not load gdiplus", -1, "Error " . A_LastError)

            ; GdiplusStartupInput structure
            ; https://docs.microsoft.com/es-es/windows/desktop/api/gdiplusinit/ns-gdiplusinit-gdiplusstartupinput
            Gdiplus.SetCapacity("GdiplusStartupInput", A_PtrSize == 4 ? 16 : 24)
            DllCall("NtDll.dll\RtlFillMemory", "UPtr", Gdiplus.GetAddress("GdiplusStartupInput"), "UPtr", A_PtrSize == 4 ? 16 : 24, "UChar", 0)
            NumPut(1, Gdiplus.GetAddress("GdiplusStartupInput"), "UInt")    ; GdiplusStartupInput.GdiplusVersion (Specifies the version of GDI+. Must be 1)

            ; GdiplusStartup function
            ; https://docs.microsoft.com/es-es/windows/desktop/api/gdiplusinit/nf-gdiplusinit-gdiplusstartup
            local pToken := 0
            Gdiplus.LastError := DllCall("Gdiplus.dll\GdiplusStartup", "UPtrP", pToken, "UPtr", Gdiplus.GetAddress("GdiplusStartupInput"), "UPtr", 0, "UInt")
            if !( Gdiplus.pToken := pToken )
            {
                DllCall("Kernel32.dll\FreeLibrary", "Ptr", Gdiplus.hModule)
                throw Exception("Could not start gdiplus", -1, "Error " . Gdiplus.LastError)
            }
        }
    }

    Shutdown()
    {
        if ( Gdiplus.pToken )
        {
            ; GdiplusShutdown function
            ; https://docs.microsoft.com/es-es/windows/desktop/api/gdiplusinit/nf-gdiplusinit-gdiplusshutdown
            DllCall("Gdiplus.dll\GdiplusShutdown", "UPtr", Gdiplus.pToken)
            DllCall("Kernel32.dll\FreeLibrary", "Ptr", Gdiplus.hModule)
            Gdiplus.pToken := 0
        }
    }
}
