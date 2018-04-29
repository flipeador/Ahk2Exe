/*
    Muestra un diálogo para seleccionar un archivo.
    Parámetros:
        Owner / Title:
            El identificador de la ventana propietaria de este diálogo. Este valor puede ser cero.
            Un Array con el identificador de la ventana propietaria y el título. Si el título es una cadena vacía se establece al por defecto "Abrir".
        FileName:
            La ruta al archivo o directorio seleccioado por defecto. Si especifica un directorio, éste debe terminar con una barra invertida.
        Filter:
            Especifica un filtro de archivos. Debe especificar un objeto, cada clave representa la descripción y el valor los tipos de archivos.
            Para especificar el filtro seleccionado por defecto, agrege el caracter "#" al valor de la clave.
        CustomPlaces:
            Especifica un Array con los directorios personalizados que se mostrarán en el panel izquierdo. Los directorios inexistentes serán omitidos.
            Para especificar la hubicación en la lista, especifique un Array con el directorio y la hubicación de este (0 = Inferior, 1 = Superior).
            Generalmente se suelte utilizar con la opción FOS_HIDEPINNEDPLACES.
        Options:
            Determina el comportamiento del diálogo. Este parámetro debe ser uno o más de los siguientes valores.
                0x00000200 (FOS_ALLOWMULTISELECT) = Permite seleccionar más de un archivo.
                0x00001000    (FOS_FILEMUSTEXIST) = El archivo devuelto debe existir. Este es el valor por defecto.
                0x00040000 (FOS_HIDEPINNEDPLACES) = Ocultar elementos que se muestran de forma predeterminada en el panel de navegación de la vista.
                0x02000000  (FOS_DONTADDTORECENT) = No agregue el elemento que se abre o guarda en la lista de documentos recientes (SHAddToRecentDocs function).
                0x10000000  (FOS_FORCESHOWHIDDEN) = Incluye elementos ocultos y del sistema.
            Puede consultar todos los valores disponibles en https://msdn.microsoft.com/en-us/library/windows/desktop/dn457282(v=vs.85).aspx.
    Return:
        Devuelve 0 si el usuario canceló el diálogo, caso contrario devuelve la ruta del archivo seleccionado.
        Si especificó la opción FOS_ALLOWMULTISELECT y la función tuvo éxito, devuelve un Array con la ruta de los archivos seleccionados.
    Ejemplo:
        Result := ChooseFile( [0, "Título del diálogo - Guardar como.."]
                            , A_ComSpec
                            , {Todos: "#*.*", Música: "*.mp3", Imágenes: "*.jpg;*.png", Videos: "*.avi;*.mp4;*.mkv;*.wmp", Documentos: "*.txt"}    ; # = Default
                            , [A_WinDir,A_Desktop,A_Temp,A_Startup,A_ProgramFiles]
                            , 0x10000000|0x02000000|0x00000200|0x00001000 )
        If ((List := "") == "" && Result != FALSE)
            For Each, File in Result
                List .= File . "`n"
        MsgBox List
*/
ChooseFile(Owner, FileName := "", Filter := "", CustomPlaces := "", Options := 0x1000)
{
    ; IFileOpenDialog interface
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775834(v=vs.85).aspx
    Local IFileOpenDialog := ComObjCreate("{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}", "{D57C7288-D4AD-4768-BE02-9D969532D960}")
        ,           Title := IsObject(Owner) ? Owner[2] . "" : ""
        ,           Flags := Options    ; FILEOPENDIALOGOPTIONS enumeration (https://msdn.microsoft.com/en-us/library/windows/desktop/dn457282(v=vs.85).aspx)
        ,      IShellItem := PIDL := i := 0    ; PIDL recibe la dirección de memoria a la estructura ITEMIDLIST que debe ser liberada con la función CoTaskMemFree
        ,             Obj := {}
        ,       Directory := FileName
    Owner := IsObject(Owner) ? Owner[1] : (WinExist("ahk_id" . Owner) ? Owner : 0)
    Filter := IsObject(Filter) ? Filter : {"All files": "*.*"}
    CustomPlaces := IsObject(CustomPlaces) || CustomPlaces == "" ? CustomPlaces : [CustomPlaces]


    If (FileName != "")    ; ¿se especificó un nombre de archivo y/o directorio?
    {
        If (InStr(FileName, "\"))    ; ¿se especificó un directorio?
        {
            If (SubStr(FileName, -1) != "\")    ; ¿se especificó un archivo?
            {
                Local File := ""
                SplitPath(FileName, File, Directory)
                ; IFileDialog::SetFileName
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775974(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileOpenDialog)+15*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", &File)
            }
            
            While (StrLen(Directory) > 3 && !DirExist(Directory))    ; si el directorio no existe buscamos directorios superiores
                Directory := SubStr(Directory, 1, InStr(RTrim(Directory, "\"), "\",, -1) - 1)
            If (DirExist(Directory))
            {
                DllCall("Shell32.dll\SHParseDisplayName", "UPtr", &Directory, "Ptr", 0, "UPtrP", PIDL, "UInt", 0, "UInt", 0)
                DllCall("Shell32.dll\SHCreateShellItem", "Ptr", 0, "Ptr", 0, "UPtr", PIDL, "UPtrP", IShellItem)
                DllCall("Ole32.dll\CoTaskMemFree", "UPtr", PIDL), ObjRawSet(Obj, IShellItem, 0)
                ; IFileDialog::SetFolder method
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761828(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileOpenDialog)+12*A_PtrSize), "Ptr", IFileOpenDialog, "Ptr", IShellItem, "UInt") ;Set Directory
            }
        }
        Else    ; solo se especificó un nombre de archivo
            DllCall(NumGet(NumGet(IFileOpenDialog)+15*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", &FileName, "UInt")
    }


    ; COMDLG_FILTERSPEC structure
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb773221(v=vs.85).aspx
    Local TotalFilters := 0, Description := "", FileTypes := "", FileTypeIndex := 1
    For Description, FileTypes in Filter
        ++TotalFilters
    Local COMDLG_FILTERSPEC := ""
    VarSetCapacity(COMDLG_FILTERSPEC, 2*TotalFilters * A_PtrSize, i:=0)
        
    For Description, FileTypes in Filter
    {
        FileTypeIndex := InStr(FileTypes, "#") ? A_Index : FileTypeIndex
        ObjRawSet(Obj, "#" . A_Index, Trim(Description)), ObjRawSet(Obj, "@" . A_Index, Trim(StrReplace(FileTypes, "#")))
        NumPut(ObjGetAddress(Obj, "#" . A_Index), &COMDLG_FILTERSPEC + A_PtrSize * i++)    ; COMDLG_FILTERSPEC.pszName
        NumPut(ObjGetAddress(Obj, "@" . A_Index), &COMDLG_FILTERSPEC + A_PtrSize * i++)    ; COMDLG_FILTERSPEC.pszSpec
    }
    
    ; IFileDialog::SetFileTypes method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775980(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+4*A_PtrSize), "UPtr", IFileOpenDialog, "UInt", TotalFilters, "UPtr", &COMDLG_FILTERSPEC, "UInt")

    ; IFileDialog::SetFileTypeIndex method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775978(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+5*A_PtrSize), "UPtr", IFileOpenDialog, "UInt", FileTypeIndex, "UInt")

    
    If (IsObject(CustomPlaces))
    {
        Local Directory := ""
        For i, Directory in CustomPlaces
        {
            i := IsObject(Directory) ? Directory[2] : 0    ; FDAP enumeration (https://msdn.microsoft.com/en-us/library/windows/desktop/bb762502(v=vs.85).aspx)
            Directory := IsObject(Directory) ? Directory[1] : Directory
            If (DirExist(Directory))
            {
                DllCall("Shell32.dll\SHParseDisplayName", "UPtr", &Directory, "Ptr", 0, "UPtrP", PIDL, "UInt", 0, "UInt", 0)
                DllCall("Shell32.dll\SHCreateShellItem", "Ptr", 0, "Ptr", 0, "UPtr", PIDL, "UPtrP", IShellItem)
                DllCall("Ole32.dll\CoTaskMemFree", "UPtr", PIDL), ObjRawSet(Obj, IShellItem, 0)
                ; IFileDialog::AddPlace method
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775946(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileOpenDialog)+21*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", IShellItem, "UInt", i, "UInt")
            }
        }
    }


    ; IFileDialog::SetTitle method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761834(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+17*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", Title == "" ? 0 : &Title, "UInt")

    ; IFileDialog::SetOptions method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761832(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+9*A_PtrSize), "UPtr", IFileOpenDialog, "UInt", Flags, "UInt")


    ; IModalWindow::Show method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761688(v=vs.85).aspx
    Local Result := []
    If (!DllCall(NumGet(NumGet(IFileOpenDialog)+3*A_PtrSize), "UPtr", IFileOpenDialog, "Ptr", Owner, "UInt"))
    {
        ; IFileOpenDialog::GetResults method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775831(v=vs.85).aspx
        Local IShellItemArray := 0    ; IShellItemArray interface (https://msdn.microsoft.com/en-us/library/windows/desktop/bb761106(v=vs.85).aspx)
        DllCall(NumGet(NumGet(IFileOpenDialog)+27*A_PtrSize), "UPtr", IFileOpenDialog, "UPtrP", IShellItemArray, "UInt")

        ; IShellItemArray::GetCount method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761098(v=vs.85).aspx
        Local Count := 0    ; pdwNumItems
        DllCall(NumGet(NumGet(IShellItemArray)+7*A_PtrSize), "UPtr", IShellItemArray, "UIntP", Count, "UInt")

        Local Buffer := ""
        VarSetCapacity(Buffer, 32767 * 2)
        Loop (Count)
        {
            ; IShellItemArray::GetItemAt method
            ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761100(v=vs.85).aspx
            DllCall(NumGet(NumGet(IShellItemArray)+8*A_PtrSize), "UPtr", IShellItemArray, "UInt", A_Index-1, "UPtrP", IShellItem)
            DllCall("Shell32.dll\SHGetIDListFromObject", "UPtr", IShellItem, "UPtrP", PIDL)
            DllCall("Shell32.dll\SHGetPathFromIDListEx", "UPtr", PIDL, "Str", Buffer, "UInt", 32767, "UInt", 0)
            DllCall("Ole32.dll\CoTaskMemFree", "UPtr", PIDL), ObjPush(Result, Buffer), ObjRelease(IShellItem)
        }

        ObjRelease(IShellItemArray)
    }


    For i in Obj
        If (Type(i) == "Integer")    ; IShellItem?
            ObjRelease(i)
    ObjRelease(IFileOpenDialog)

    Return ObjLength(Result) ? (Options&0x200 ? Result : Result[1]) : FALSE
}
