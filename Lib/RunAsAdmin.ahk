/*
    Ejecuta el Script actual como Administrador.
    Return:
        0 = No se ha podido ejecutar como Administrador.
        1 = El Script ya tiene permisos de Administrador.
        2 = El Script se ha ejecutado como Administrador con éxito.
*/
RunAsAdmin()
{
    If (ObjLength(A_Args) && A_Args[1] == A_ThisFunc && ObjRemoveAt(A_Args, 1))
        Return A_IsAdmin ? 2 : FALSE

    If (A_IsAdmin)
        Return TRUE

    Local Params := ""
    Loop (ObjLength(A_Args))
        Params .= " `"" . A_Args[A_Index] . "`""

    If (A_IsCompiled)
        Run("*RunAs `"" . A_ScriptFullPath . "`" " . A_ThisFunc . Params)
    Else
        Run("*RunAs `"" . A_AhkPath . "`" `"" . A_ScriptFullPath . "`" " . A_ThisFunc . Params)
    ExitApp
}
