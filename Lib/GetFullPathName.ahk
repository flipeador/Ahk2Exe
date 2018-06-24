GetFullPathName(Path, WorkingDir := "")
{
    Local RestoreWD := ""
    If (DirExist(WorkingDir))
    {
        RestoreWD := A_WorkingDir
        A_WorkingDir := WorkingDir
    }

    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa364963(v=vs.85).aspx
    Local Buffer := ""
    VarSetCapacity(Buffer, 32767 * 2, 0)
    DllCall("Kernel32.dll\GetFullPathNameW", "UPtr", &Path, "UInt", 32767, "Str", Buffer, "UPtr", 0, "UInt")

    If (RestoreWD != "")
        A_WorkingDir := RestoreWD

    Return Buffer
}
