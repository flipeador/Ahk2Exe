/*
    Ahk2Exe.exe [/in] infile.ahk                           | compiler WorkingDir (/in is optional)
                [/out outfile.exe]                         |   infile WorkingDir || compiler WorkingDir
                [/icon iconfile.ico]                       |   infile WorkingDir || compiler WorkingDir
                [/bin binfile.bin]                         | compiler WorkingDir
                [/upx]                                     | compiler WorkingDir\upx.exe
                [/mpress]                                  | compiler WorkingDir\mpress.exe
                [/nocheck]                                 | no comprueba la sintaxis
                [/q] | [/quiet]                            | no muestra ningún mensaje
*/
ProcessCmdLine()  ; https://github.com/flipeador/Ahk2Exe/blob/master/README.md#compilaci%C3%B3n-por-l%C3%ADnea-de-comandos
{
    ObjRawSet(g_data, "Compression", Cfg.Compression)
    ObjRawSet(g_data, "BinFile", Util_CheckBinFile(Cfg.LastBinFile) ? Cfg.LastBinFile : "Unicode " . 8*A_PtrSize . "-bit")
    ObjRawSet(g_data, "IgnoreBinFile", FALSE)
    ObjRawSet(g_data, "IcoFile", "")
    ObjRawSet(g_data, "IgnoreSetMainIcon", FALSE)
    ObjRawSet(g_data, "ExeFile", "")
    ObjRawSet(g_data, "CreateDestFolder", FALSE)
    ObjRawSet(g_data, "AhkFile", "")
    ObjRawSet(g_data, "SyntaxCheck", TRUE)

    Local n := 1
    For g_k, g_v in A_Args    ; g_k = index | g_v = arg
    {
        If (--n)
            Continue

        If (g_v ~= "^/|-")
        {
            If (g_v ~= "i)^(/|-)in$")    ; /in infile.ahk
                ObjRawSet(g_data, "AhkFile", GetFullPathName(A_Args[g_k+1])), n := 2
            Else If (g_v ~= "i)^(/|-)out$")    ; /out outfile.exe
                ObjRawSet(g_data, "CreateDestFolder", A_Args[g_k+1] ~= "^\*")
              , ObjRawSet(g_data, "ExeFile", GetFullPathName(RegExReplace(A_Args[g_k+1], "^\*"), DirGetParent(g_data.AhkFile))), n := 2
            Else If (g_v ~= "i)^(/|-)icon$")    ; /icon iconfile.ico
                ObjRawSet(g_data, "IgnoreSetMainIcon", A_Args[g_k+1] ~= "^\*")
              , ObjRawSet(g_data, "IcoFile", GetFullPathName(RegExReplace(A_Args[g_k+1], "^\*"), DirGetParent(g_data.AhkFile))), n := 2
            Else If (g_v ~= "i)^(/|-)bin$")    ; /bin binfile.bin
                ObjRawSet(g_data, "IgnoreBinFile", A_Args[g_k+1] ~= "^\*")
              , ObjRawSet(g_data, "BinFile", RegExReplace(A_Args[g_k+1], "^\*")), n := 2
            Else If (g_v ~= "i)^(/|-)upx$")    ; /upx
                ObjRawSet(g_data, "Compression", UPX), n := 1
            Else If (g_v ~= "i)^(/|-)mpress$")    ; /mpress
                ObjRawSet(g_data, "Compression", MPRESS), n := 1
            Else If (g_v ~= "i)^(/|-)nocheck$")    ; /nocheck
                ObjRawSet(g_data, "SyntaxCheck", FALSE), n := 1
            Else If (g_v ~= "i)^(/|-)(q|quiet)$")    ; /q
                BE_QUIET := TRUE, n := 1
            If (!n || (n == 2 && ObjLength(A_Args) <= g_k))
            {
                If (!BE_QUIET)
                    TaskDialog( ERROR_ICON, Title, ["El parámetro no es correcto.", g_v] )
                Return ERROR_INVALID_PARAMETER
            }
        }
        Else
            ObjRawSet(g_data, "AhkFile", GetFullPathName(g_v)), n := 1
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

    If (!DirExist(DirGetParent(g_data.ExeFile)))
    {
        If (g_data.CreateDestFolder)    ; intentamos crear el directorio si no existe : *outfile.exe
        {
            If (!DirCreate(DirGetParent(g_data.ExeFile)))
                Return ERROR_CANNOT_CREATE_DEST_DIR
        }
        Else
            Return ERROR_DEST_DIR_NOT_FOUND
    }
    
    Local BinaryType := 0
    If (!(g_data.BinFile := Util_CheckBinFile(g_data.BinFile, BinaryType)))
        Return ERROR_BIN_FILE_NOT_FOUND
    ObjRawSet(g_data, "Compile64", BinaryType == SCS_64BIT_BINARY)
    ObjRawSet(g_data, "BinVersion", FileGetVersion(g_data.BinFile))

    Local Data := PreprocessScript(g_data.AhkFile)
    If (!Data)
        Return UNKNOWN_ERROR

    If ( AhkCompile(Data) )
    {
        OutputDebug("Successful compilation.")
        Return ERROR_SUCCESS
    }

    OutputDebug("Failed compilation.")
    Return UNKNOWN_ERROR
}





CMDLN(n, i*)
{
    Return CMDLN ? n : ObjLength(i) ? i[1] : NO_EXIT
}
