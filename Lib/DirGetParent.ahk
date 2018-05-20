/*
    Recupera el directorio superior al directorio especificado.
    Parámetros:
        DirName:
            La cadena con la ruta de una carpeta o archivo.
    Return:
        Devuelve una cadena con la ruta al directorio superior.
    Observaciones:
        Esta función no comprueba si el directorio especificado existe o no.
        Los espacios al inicio y final de la cadena serán removidos y no se incluirán al devolver.
        Si la cadena especificada en DirName contiene el caracter "\", devuelve DirName quitando todo lo que haya despues del último caracter "\" incluido a este.
        Si se especifica un solo caracter, devuelve este caracter con el sufijo ":".
        En cualquier otro caso que no sea los 2 anteriores, devuelve DirName sin modificar.
    Ejemplos:
        MsgBox DirGetParent("X")    ; X:
        MsgBox DirGetParent("X:")    ; X:
        MsgBox DirGetParent("X:\")    ; X:
        MsgBox DirGetParent("X:\A")    ; X:
        MsgBox DirGetParent("X:\A\B\")    ; X:\A
        MsgBox DirGetParent(".")    ; .:
        MsgBox DirGetParent("XXXXXXXXX")    ; XXXXXXXXX
        MsgBox DirGetParent("123\456\789")    ; 123\456
*/
DirGetParent(DirName)
{
    If (InStr(DirName := RTrim(Trim(DirName), "\"), "\"))
        Return SubStr(DirName, 1, InStr(DirName, "\",, -1) - 1)

    If (StrLen(DirName) == 1)
        Return DirName . ":"

    Return DirName
}
