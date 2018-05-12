/*
    Ahk2Exe.exe [/in] infile.ahk                           | compiler WorkingDir (/in is optional)
                [/out outfile.exe]                         |   infile WorkingDir || compiler WorkingDir
                [/icon iconfile.ico]                       |   infile WorkingDir || compiler WorkingDir
                [/bin binfile.bin]                         | compiler WorkingDir
                [/upx]                                     | compiler WorkingDir\upx.exe
                [/mpress]                                  | compiler WorkingDir\mpress.exe
                [/q] | [/quiet]                            | no muestra ningún mensaje
*/
ProcessCmdLine()
{
    Local           n := 1
        , Compression := Cfg.Compression
        ,     BinFile := IS_FILE(Cfg.LastBinFile) ? Cfg.LastBinFile : "Unicode " . 8*A_PtrSize . "-bit"
        ,     AhkFile := ""
        ,     ExeFile := ""
        ,     IcoFile := ""

    Loop (ObjLength(A_Args))
    {
        If (--n)
            Continue

        If (A_Args[A_Index] ~= "^/|-")
        {
            If (A_Args[A_Index] ~= "i)(/|-)in")
                AhkFile := GetFullPathName(A_Args[A_Index+1]), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)out")
                ExeFile := GetFullPathName(A_Args[A_Index+1], DirGetParent(AhkFile)), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)icon")
                IcoFile := GetFullPathName(A_Args[A_Index+1], DirGetParent(AhkFile)), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)bin")
                BinFile := GetFullPathName(A_Args[A_Index+1]), n := 2
            Else If (A_Args[A_Index] ~= "i)(/|-)upx")
                Compression := UPX, n := 1
            Else If (A_Args[A_Index] ~= "i)(/|-)mpress")
                Compression := MPRESS, n := 1
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
            AhkFile := GetFullPathName(A_Args[A_Index]), n := 1
    }

    If (AhkFile == "")
        Return ERROR_SOURCE_NO_SPECIFIED

    If (!IS_FILE(AhkFile))
        Return ERROR_SOURCE_NOT_FOUND

    If (!FileOpen(AhkFile, "r"))
        Return ERROR_CANNOT_OPEN_SCRIPT

    If (ExeFile == "")
        ExeFile := DirGetParent(AhkFile) . "\" . Path(AhkFile).FNNE . ".exe"
    
    ObjRawSet(g_data, "IcoFile", IcoFile)
    Local Data := PreprocessScript(AhkFile)
    If (!Data)
        Return UNKNOWN_ERROR

    ObjRawSet(g_data, "Compression", Compression)
    ObjRawSet(g_data, "BinFile", BinFile)
    ObjRawSet(g_data, "AhkFile", AhkFile)
    ObjRawSet(g_data, "ExeFile", ExeFile)
    Return AhkCompile(Data) ? ERROR_SUCCESS : UNKNOWN_ERROR
}
