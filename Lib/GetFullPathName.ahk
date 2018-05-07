GetFullPathName(Path, WorkingDir := "")
{
    Local RestoreIWD := ""
    If (DirExist(WorkingDir))
    {
        RestoreIWD := A_WorkingDir
        A_WorkingDir := WorkingDir
    }

    VarSetCapacity(Buffer, 5000, 0)
    DllCall("Kernel32.dll\GetFullPathNameW", "UPtr", &Path, "UInt", 2498, "Str", Buffer, "UPtr", 0, "UInt")

    If (RestoreIWD != "")
        A_WorkingDir := RestoreIWD

    Return Buffer
}
