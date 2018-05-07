/*
    Ahk2Exe.exe infile.ahk                                 | compiler WorkingDir
                /in infile.ahk                             | compiler WorkingDir
                [/out outfile.exe]                         |   infile WorkingDir
                [/icon iconfile.ico]                       |   infile WorkingDir
                [/bin binfile.bin]                         | compiler WorkingDir
                [/upx]                                     | compiler WorkingDir\upx.exe
                [/mpress]                                  | compiler WorkingDir\mpress.exe
*/
ProcessCmdLine()
{
    Local           n := 1
        , Compression := Cfg.Compression
        ,     BinFile := Path(Cfg.LastBinFile).IsFile ? Cfg.LastBinFile : "Unicode " . 8*A_PtrSize . "-bit"
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
            If (!n || (n == 2 && ObjLength(A_Args) <= A_Index))
            {
                TaskDialog( ERROR_ICON, Title, ["El parámetro no es correcto.", A_Args[A_Index]] )
                Return 87
            }
        }
        Else
            AhkFile := GetFullPathName(A_Args[A_Index]), n := 1
    }

    If (AhkFile != "" && ExeFile == "")
    {
        SplitPath(AhkFile,,,, ExeFile)
        ExeFile := DirGetParent(AhkFile) . "\" . ExeFile . ".exe"
    }
    ; MsgBox "Compression: " . Compression . "`nBinFile: " . BinFile . "`nAhkFile: " . AhkFile . "`nExeFile: " . ExeFile . "`nIcoFile: " . IcoFile
    ObjRawSet(g_data, "IcoFile", IcoFile)
    Local Data := PreprocessScript(AhkFile)
    If (!Data)
        Return 774

    ObjRawSet(g_data, "Compression", Compression)
    ObjRawSet(g_data, "BinFile", BinFile)
    ObjRawSet(g_data, "AhkFile", AhkFile)
    ObjRawSet(g_data, "ExeFile", ExeFile)

    Return AhkCompile(Data) ? 0 : 774
}
