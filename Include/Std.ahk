/*
    Determina si el archivo especificado existe o no.
    Return:
        Si existe devuelve sus atributos, si no existe devuelve cero.
*/
IS_FILE(Path)
{
    Local Att := FileExist(Path)
    Return Att == "" || InStr(Att, "D") ? FALSE : Att
}





PATH(Path, ByRef FN := "", ByRef Dir := "", ByRef Ext := "", ByRef FNNE := "", ByRef Drive := "", ByRef Attrib := "")
{
    SplitPath(Path, FN, Dir, Ext, FNNE, Drive), Attrib := FileExist(Path)
    Return {Path: Path, FN: FN, Dir: Dir, Ext: Ext, FNNE: FNNE, Drive: Drive, IsDir: InStr(Attrib, "D")?Attrib:0, IsFile: Attrib!=""&&Attrib&&!InStr(Attrib, "D")?Attrib:0, Exist: Attrib!=""&&Attrib}
}
