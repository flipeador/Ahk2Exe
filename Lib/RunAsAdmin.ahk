/*
    Ejecuta el Script actual como Administrador.
    Return:
        0 = No se ha podido ejecutar como Administrador.
        1 = El Script ya tiene permisos de Administrador.
        2 = El Script se ha ejecutado como Administrador con éxito.
*/
RunAsAdmin()
{
    If (A_IsAdmin)
    {
        Local Ret := 1
        If (ObjLength(A_Args) && A_Args[1] == A_ThisFunc)
            ObjDelete(A_Args, 1), Ret := 2
        Return Ret
    }

    If (ObjLength(A_Args) && A_Args[1] == A_ThisFunc)
        Return FALSE

    Local Params := A_Space
    Loop (ObjLength(A_Args))
        Params .= "`"" . A_Args[A_Index] . "`"" . A_Space

    If (A_IsCompiled)
        Run("*RunAs `"" . A_ScriptFullPath . "`" " . A_ThisFunc . Params)
    Else
        Run("*RunAs `"" . A_AhkPath . "`" `"" . A_ScriptFullPath . "`" " . A_ThisFunc . Params)
    ExitApp
}
