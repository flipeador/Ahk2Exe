/*
    Ahk2Exe.exe [/in] infile.ahk                           | compiler WorkingDir (/in is optional)
                [/out outfile.exe]                         |   infile WorkingDir || compiler WorkingDir
                [/icon iconfile.ico]                       |   infile WorkingDir || compiler WorkingDir
                [/bin binfile.bin]                         | compiler WorkingDir
                [/upx]                                     | compiler WorkingDir\upx.exe
                [/mpress]                                  | compiler WorkingDir\mpress.exe
                [/q] | [/quiet]                            | no muestra ningún mensaje
    Ejemplos:
        Compila el archivo "Script.ahk" en el mismo directorio que el compilador, suprime mensajes y el archivo destino es d:\Script.exe.
            Ahk2Exe.exe Script.ahk /out d: /q
        Compila el archivo "C:\Script.ahk", suprime mensajes, establece el icono "ICO.ico" y el archivo destino es "D:\ScriptC.exe"
            Ahk2Exe.exe C:\Script.ahk /q /icon ICO.ico /out D:\ScriptC
        Compila el archivo "Script.ahk" y el archivo destino es "XXX.bin"
            Ahk2Exe.exe Script.ahk /out XXX.bin
        Compila el archivo "Script.ahk" y el archivo destino es "Script.exe" comprimido con MPRESS
            Ahk2Exe.exe Script.ahk /mpress
*/
ProcessCmdLine()
{
    ObjRawSet(g_data, "Compression", Cfg.Compression)
    ObjRawSet(g_data, "BinFile", Util_CheckBinFile(Cfg.LastBinFile) ? Cfg.LastBinFile : "Unicode " . 8*A_PtrSize . "-bit")
    ObjRawSet(g_data, "IgnoreSetMainIcon", FALSE)
    ObjRawSet(g_data, "IcoFile", "")
    ObjRawSet(g_data, "ExeFile", "")
    ObjRawSet(g_data, "AhkFile", "")

    Local n := 1
    Loop ( ObjLength(A_Args) )
    {
        If (--n)
            Continue

        If (A_Args[A_Index] ~= "^/|-")
        {
            If (A_Args[A_Index] ~= "i)(/|-)in")
                ObjRawSet(g_data, "AhkFile", GetFullPathName(A_Args[A_Index+1])), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)out")
                ObjRawSet(g_data, "ExeFile", GetFullPathName(A_Args[A_Index+1], DirGetParent(g_data.AhkFile))), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)icon")
                ObjRawSet(g_data, "IgnoreSetMainIcon", A_Args[A_Index+1] ~= "^\*")
              , ObjRawSet(g_data, "IcoFile", GetFullPathName(RegExReplace(A_Args[A_Index+1], "^\*"), DirGetParent(g_data.AhkFile))), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)bin")
                ObjRawSet(g_data, "IgnoreBinFile", A_Args[A_Index+1] ~= "^\*")
              , ObjRawSet(g_data, "BinFile", RegExReplace(A_Args[A_Index+1], "^\*")), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)upx")
                ObjRawSet(g_data, "Compression", UPX), n := 1
            Else If (A_Args[A_Index] ~= "i)(/|-)mpress")
                ObjRawSet(g_data, "Compression", MPRESS), n := 1
            Else If (A_Args[A_Index] ~= "i)(/|-)q")
                BE_QUIET := TRUE, n := 1
            If (!n || (n == 2 && ObjLength(A_Args) <= A_Index))
            {
                If (!BE_QUIET)
                    TaskDialog( ERROR_ICON, Title, ["El parámetro no es correcto.", A_Args[A_Index]] )
                Return ERROR_INVALID_PARAMETER
            }
        }
        Else
            ObjRawSet(g_data, "AhkFile", GetFullPathName(A_Args[A_Index])), n := 1
    }

    If (g_data.AhkFile == "")
        Return ERROR_SOURCE_NO_SPECIFIED

    If (!IS_FILE(g_data.AhkFile))
        Return ERROR_SOURCE_NOT_FOUND

    If (!FileOpen(g_data.AhkFile, "r"))
        Return ERROR_CANNOT_OPEN_SCRIPT

    If (g_data.ExeFile == "")
        ObjRawSet(g_data, "ExeFile", DirGetParent(g_data.AhkFile) . "\" . PATH(g_data.AhkFile).FNNE . ".exe")
    Else If (DirExist(g_data.ExeFile))
        ObjRawSet(g_data, "ExeFile", RTrim(g_data.ExeFile, "\") . "\" . PATH(g_data.AhkFile).FNNE . ".exe")
    Else If (PATH(g_data.ExeFile).Ext == "")
        g_data.ExeFile .= ".exe"
    
    Local BinaryType := 0
    If (!(g_data.BinFile := Util_CheckBinFile(g_data.BinFile, BinaryType)))
        Return ERROR_BIN_FILE_NOT_FOUND
    ObjRawSet(g_data, "Compile64", BinaryType == SCS_64BIT_BINARY)
    ObjRawSet(g_data, "BinVersion", FileGetVersion(g_data.BinFile))

    Local Data := PreprocessScript(g_data.AhkFile)
    If (!Data)
        Return UNKNOWN_ERROR

    Return AhkCompile(Data) ? ERROR_SUCCESS : UNKNOWN_ERROR
}





CMDLN(n)
{
    Return CMDLN ? n : NO_EXIT
}
