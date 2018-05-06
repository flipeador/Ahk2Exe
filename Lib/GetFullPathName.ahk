GetFullPathName(Path, WorkingDir := "")
{
    Local RestoreIWD := FALSE
    If (DirExist(WorkingDir))
    {
        RestoreIWD := TRUE
        A_WorkingDir := WorkingDir
    }

    ;If (!InStr(Path, ".."))
    ;    Return InStr(Path, ":") ? Path : A_WorkingDir . "\" . Path

    VarSetCapacity(Buffer, 5000, 0)
    DllCall("Kernel32.dll\GetFullPathNameW", "UPtr", &Path, "UInt", 2498, "Str", Buffer, "UPtr", 0, "UInt")

    If (RestoreIWD)
        A_WorkingDir := A_InitialWorkingDir

    Return Buffer
}
