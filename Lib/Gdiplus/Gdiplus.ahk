/*
    GDI+ Flat API
    https://msdn.microsoft.com/en-us/library/ms533969(v=vs.85).aspx

    Classes
    https://msdn.microsoft.com/en-us/library/ms533958(v=vs.85).aspx
*/
Class Gdiplus
{
    ; ===================================================================================================================
    ; CONSTRUCTOR
    ; ===================================================================================================================
    __New()
    {
        If (!(this.hModule := DllCall("Kernel32.dll\LoadLibraryW", "Str", "gdiplus.dll", "Ptr")))
            Throw Exception("Could not load gdiplus.", -1, "LoadLibraryW gdiplus.dll")

        ; GdiplusStartupInput structure
        ; https://msdn.microsoft.com/en-us/library/ms534067(v=vs.85).aspx
        Local GdiplusStartupInput := ""
        VarSetCapacity(GdiplusStartupInput, A_PtrSize == 4 ? 16 : 24, 0)
        NumPut(1, &GdiplusStartupInput, "UInt")    ; GdiplusStartupInput.GdiplusVersion (Specifies the version of GDI+. Must be 1)

        ; GdiplusStartup function
        ; https://msdn.microsoft.com/en-us/library/ms534077(v=vs.85).aspx
        Local pToken := 0
        Local Ret := DllCall("Gdiplus.dll\GdiplusStartup", "UPtrP", pToken, "UPtr", &GdiplusStartupInput, "UPtr", 0, "UInt")
        If (!pToken)
            Throw Exception("Could not start gdiplus.", -1, "GdiplusStartup returned " . Ret)
        ObjRawSet(this, "pToken", pToken)
    }


    ; ===================================================================================================================
    ; DESTRUCTOR
    ; ===================================================================================================================
    __Delete()
    {
        ; GdiplusShutdown function
        ; https://msdn.microsoft.com/en-us/library/ms534076(v=vs.85).aspx
        DllCall("Gdiplus.dll\GdiplusShutdown", "UPtr", this.pToken)
        DllCall("Kernel32.dll\FreeLibrary", "Ptr", this.hModule)
    }
}
