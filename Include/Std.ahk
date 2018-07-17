/*
    expr := InputBox("Enter an expression to evaluate as a new script.",,, "Ord('*')")
    result := ExecScript("FileAppend " .  expr . ", '*'")
    MsgBox "Result: " . result
*/
ExecScript(Script, WorkingDir := "", Wait := TRUE)
{
    If (g_ahkpath == "")
        Throw Exception("ExecScript", -1, "AutoHotkey.exe not found")

    Local ahk := new Subprocess("`"" . g_ahkpath . "`" /ErrorStdOut *",, 0)    ; thanks «coffee»
    If (!ahk)    ; puede requerir permisos Administrativos
        Throw Exception("ExecScript", -1, "Process couldn't be created")

    ahk.StdIn.Encoding := ""
    ahk.StdIn.Write( "#NoTrayIcon"
                   . "`nListLines 0"
                   . "`n#KeyHistory 0"
                   . "`n#Warn"
                   . "`nA_RegView:=64"
                   . "`nA_DetectHiddenWIndows:=1"
                   . "`nA_WorkingDir:='" . (DirExist(WorkingDir) ? WorkingDir : A_WorkingDir) . "'"
                   . "`n" . Script
                   . "`nExitApp")
    ahk.StdIn.Close()    ; Close StdIn so it can run

    Return Wait ? ahk.StdOut.ReadAll() : ""
}





SetFileExt(File, Ext := "")
{
    if ((File:=Trim(File)) == "")
        return ""
    local c_ext := ""
    SplitPath(File,,, c_ext)
    return c_ext == "" && SubStr(File, -1) != "." ? File . (Ext == "" ? "" : "." . Ext) : RegExReplace(File, "\..*$", Ext == "" ? "" : "." . Ext)
}





_CONTAINS(Var, Data, CaseSensitive := FALSE, Delimiter := "|", OmitCars := "")
{
    Local Key := "", Value := ""
    If (IsObject(Data))
    {
        For Key, Value in Data
            If (InStr(Var, Value, CaseSensitive))
                Return TRUE
    }
    Else
        Loop Parse, Data, Delimiter, OmitCars
            If (InStr(Var, A_LoopField, CaseSensitive))
                Return TRUE
    Return FALSE
}





_IN(Var, Data, CaseSensitive := FALSE, Delimiter := "|", OmitCars := "")
{
    Local Key := "", Value := ""
    If (IsObject(Data))
    {
        For Key, Value in Data
            If ( (CaseSensitive && Value == Var) || (!CaseSensitive && Value = Var) )
                Return TRUE
    }
    Else
        Loop Parse, Data, Delimiter, OmitCars
            If ( (CaseSensitive && A_LoopField == Var) || (!CaseSensitive && A_LoopField = Var) )
                Return TRUE
    Return FALSE
}





IS_FILE(Path)
{
    Local Att := FileExist(Path)
    Return Att == "" || InStr(Att, "D") ? FALSE : Att
}





PATH(Path, ByRef FN := "", ByRef Dir := "", ByRef Ext := "", ByRef FNNE := "", ByRef Drive := "", ByRef Attrib := "")
{
    SplitPath(Path, FN, Dir, Ext, FNNE, Drive), Attrib := FileExist(Path)
    Return {Path:Path,FN:FN,Dir:Dir,Ext:Ext,FNNE:FNNE,Drive:Drive,IsDir:InStr(Attrib,"D")?Attrib:0,IsFile:Attrib!=""&&Attrib&&!InStr(Attrib,"D")?Attrib:0,Exist:Attrib!=""&&Attrib}
}





; MsgBox (i:=ObjModify([1,2,3],(n)=>n*2,-4,8))[1] i[2] i[3] i[4]    ; test 2468
ObjModify(Obj, Fnc, Limit := 0, Default := "")
{
    Local k := "", v := ""
    For k, v in Obj    ; [] | {}
        If (A_Index == Limit)
            Break
        Else
            Obj[k] := Fnc.MaxParams == 1 ? Fnc.Call(v) : Fnc.MaxParams == 2 ? Fnc.Call(k,v) : Fnc.Call(A_Index,k,v)
    Loop (Limit < 0 ? Abs(Limit)-ObjLength(Obj) : 0)    ; array
        ObjPush(Obj, Default)
    Return Obj
}





; MsgBox "ptr:" . StrPutVar("Hola Mundo!", Buffer, Size) . "`nsize:" . Size . "`nstr:" . StrGet(&Buffer, "UTF-8")
; MsgBox StrPutVar("•", Buffer, Size) . " | " . Size . " | " . StrGet(&Buffer, "UTF-8")
; MsgBox StrPutVar("•", Buffer, Size, "UTF-16") . " | " . Size . " | " . StrGet(&Buffer, "UTF-16")
StrPutVar(String, ByRef Buffer, ByRef Size := "", Encoding := "UTF-8")
{
    VarSetCapacity(Buffer, (Size := StrPut(String, Encoding) - VarSetCapacity(Buffer, 0)*0) * ((Encoding = "UTF-16") + 1))
    Return IsByRef(Size) ? StrPut(String, &Buffer, Size, Encoding) * 0 + &Buffer : StrPut(String, &Buffer, Size, Encoding)
} ; AutoHotkey Documentation




/*
DPI(n, dpi := 1, m := 1)
{
    return m > 0 ? n * ((dpi ? g_dpiy : g_dpix) / 96) * m : n / ((dpi ? g_dpiy : g_dpix) / 96) * (m ? m : 1)
}
*/




/*
    #define MAKEWORD(a, b)      ((WORD)(((BYTE)(((DWORD_PTR)(a)) & 0xff)) | ((WORD)((BYTE)(((DWORD_PTR)(b)) & 0xff))) << 8))
    n := MAKEWORD(0, 255), MsgBox("WORD " . n . "; LOBYTE " . LOBYTE(n) . "; HIBYTE " . HIBYTE(n))
*/
MAKEWORD(byte_low, byte_high := 0)
{
    Return (byte_low & 0xFF) | ((byte_high & 0xFF) << 8)
} ; https://msdn.microsoft.com/es-es/library/windows/desktop/ms632663(v=vs.85).aspx

/*
    #define MAKELONG(a, b)      ((LONG)(((WORD)(((DWORD_PTR)(a)) & 0xffff)) | ((DWORD)((WORD)(((DWORD_PTR)(b)) & 0xffff))) << 16))
    n := MAKELONG(0, 65535), MsgBox("LONG " . n . "; LOWORD " . LOWORD(n) . "; HIWORD " . HIWORD(n))
*/
MAKELONG(short_low, short_high := 0)
{
    Return (short_low & 0xFFFF) | ((short_high & 0xFFFF) << 16)
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms632660(v=vs.85).aspx

/*
    #define MAKELONG64(hi, lo)    ((LONGLONG(DWORD(hi) & 0xffffffff) << 32 ) | LONGLONG(DWORD(lo) & 0xffffffff))
    n := MAKELONG64(0, 4294967295), MsgBox("LONG64 " . n . "; LOLONG " . LOLONG(n) . "; HILONG " . HILONG(n))
*/
MAKELONG64(long_low, long_high := 0)
{
    Return (long_low & 0xFFFFFFFF) | ((long_high & 0xFFFFFFFF) << 32)  
}

LOWORD(l)
{
    Return l & 0xFFFF
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms632659(v=vs.85).aspx

HIWORD(l)
{
    Return (l >> 16) & 0xFFFF
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms632657(v=vs.85).aspx

LOBYTE(w)
{
    Return w & 0xFF
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms632658(v=vs.85).aspx

HIBYTE(w)
{
    Return (w >> 8) & 0xFF
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms632656(v=vs.85).aspx

LOLONG(ll)
{
    Return ll & 0xFFFFFFFF
}

HILONG(ll)
{
    Return (ll >> 32) & 0xFFFFFFFF
}
