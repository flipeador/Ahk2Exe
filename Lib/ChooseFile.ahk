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
            Para especificar el filtro seleccionado por defecto, agrege el caracter "`n" al valor de la clave. Por defecto se selecciona el primer filtro.
            Para especificar la extensión predeterminada que se agregará a los nombres de archivo, especifique el caracter "`r" junto a la extensión.
            El caracter predeterminado para separar las extensiónes es ";". Los espacios son omitidos del valor.
        CustomPlaces:
            Especifica un Array con los directorios personalizados que se mostrarán en el panel izquierdo. Los directorios inexistentes serán omitidos.
            Para especificar la hubicación en la lista, especifique un Array con el directorio y la hubicación de este (0 = Inferior, 1 = Superior).
            Generalmente se suelte utilizar con la opción FOS_HIDEPINNEDPLACES.
        Options:
            Determina el comportamiento del diálogo. Este parámetro debe ser uno o más de los siguientes valores.
                0x00000200 (FOS_ALLOWMULTISELECT) = Permite seleccionar más de un archivo.
                0x00001000    (FOS_FILEMUSTEXIST) = El archivo devuelto debe existir. Este es el valor por defecto.
                0x00040000 (FOS_HIDEPINNEDPLACES) = Ocultar elementos que se muestran de forma predeterminada en el panel de navegación de la vista.
                0x02000000  (FOS_DONTADDTORECENT) = No agregue el elemento que se abre o guarda en la lista de documentos recientes (function SHAddToRecentDocs).
                0x10000000  (FOS_FORCESHOWHIDDEN) = Incluye elementos ocultos y del sistema.
            Puede consultar todos los valores disponibles en https://msdn.microsoft.com/en-us/library/windows/desktop/dn457282(v=vs.85).aspx.
    Return:
        Devuelve 0 si el usuario canceló el diálogo, en caso contrario devuelve el archivo seleccionado.
        Si especificó la opción FOS_ALLOWMULTISELECT y la función tuvo éxito, devuelve un Array con los archivos seleccionados.
        Si tuvo éxito, ErrorLevel se establece en un objeto con las claves descritas a continuación.
            FileName      = El texto actualmente ingresado en el cuadro de edición de nombre de archivo del diálogo.
            FileTypeIndex = El índice en la lista dezplegable del tipo de archivo actualmente seleccionado (filtro).
    Ejemplo:
        Result := ChooseFile( [0, "Título del diálogo - Seleccionar archivo.."]
                            , A_ComSpec
                            , {Todos: "`n*.*", Música: "*.mp3", Imágenes: "*.jpg;*.png", Videos: "*.avi;*.mp4;*.mkv;*.wmp", Documentos: "*.txt"}
                            , [A_WinDir,A_Desktop,A_Temp,A_Startup,A_ProgramFiles]
                            , 0x10000000 | 0x02000000 | 0x00000200 | 0x00001000 )
        If ((List := "") == "" && Result != FALSE)
            For Each, File in Result
                List .= File . "`n"
        MsgBox List
*/
ChooseFile(Owner, FileName := "", Filter := "", CustomPlaces := "", Options := 0x1000)
{
    ; IFileOpenDialog interface
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775834(v=vs.85).aspx
    local IFileOpenDialog := ComObjCreate("{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}", "{D57C7288-D4AD-4768-BE02-9D969532D960}")
        ,           Title := IsObject(Owner) ? Owner[2] . "" : ""
        ,           Flags := Options     ; FILEOPENDIALOGOPTIONS enumeration (https://msdn.microsoft.com/en-us/library/windows/desktop/dn457282(v=vs.85).aspx)
        ,      IShellItem := PIDL := 0   ; PIDL recibe la dirección de memoria a la estructura ITEMIDLIST que debe ser liberada con la función CoTaskMemFree
        ,             Obj := {COMDLG_FILTERSPEC: ""}, foo := "", bar := ""
        ,       Directory := FileName
    Owner := IsObject(Owner) ? Owner[1] : (WinExist("ahk_id" . Owner) ? Owner : 0)
    Filter := IsObject(Filter) ? Filter : {"All files": "*.*"}


    if ( FileName != "" )
    {
        if ( InStr(FileName, "\") )
        {
            if !( FileName ~= "\\$" )    ; si «FileName» termina con "\" se trata de una carpeta
            {
                local File := ""
                SplitPath(FileName, File, Directory)
                ; IFileDialog::SetFileName
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775974(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileOpenDialog)+15*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", &File)
            }
            
            while ( InStr(Directory,"\") && !DirExist(Directory) )                   ; si el directorio no existe buscamos directorios superiores
                Directory := SubStr(Directory, 1, InStr(Directory, "\",, -1) - 1)    ; recupera el directorio superior
            if ( DirExist(Directory) )
            {
                DllCall("Shell32.dll\SHParseDisplayName", "UPtr", &Directory, "Ptr", 0, "UPtrP", PIDL, "UInt", 0, "UInt", 0)
                DllCall("Shell32.dll\SHCreateShellItem", "Ptr", 0, "Ptr", 0, "UPtr", PIDL, "UPtrP", IShellItem)
                ObjRawSet(Obj, IShellItem, PIDL)
                ; IFileDialog::SetFolder method
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761828(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileOpenDialog)+12*A_PtrSize), "Ptr", IFileOpenDialog, "UPtr", IShellItem)
            }
        }
        else    ; si «FileName» es únicamente el nombre de un archivo
            DllCall(NumGet(NumGet(IFileOpenDialog)+15*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", &FileName)
    }
    

    ; COMDLG_FILTERSPEC structure
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb773221(v=vs.85).aspx
    local Description := "", FileTypes := "", FileTypeIndex := 1
    ObjSetCapacity(Obj, "COMDLG_FILTERSPEC", 2*Filter.Count() * A_PtrSize)
    for Description, FileTypes in Filter
    {
        loop parse, FileTypes, ";"            ; itera por todas las extensiones separadas por ";"
            if ( InStr(A_LoopField, "`r") )   ; si se especificó el caracter "`r" en la extensión actual
                ; IFileDialog::SetDefaultExtension method
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775970(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileSaveDialog)+22*A_PtrSize), "UPtr", IFileSaveDialog, "Str", RegExReplace(A_LoopField,"\s*`n*`r*\**\.*"))
        FileTypeIndex := InStr(FileTypes,"`n") ? A_Index : FileTypeIndex
        ObjRawSet(Obj, "#" . A_Index, Trim(Description)), ObjRawSet(Obj, "@" . A_Index, RegExReplace(FileTypes,"\s*`n*`r*"))
        NumPut(ObjGetAddress(Obj,"#" . A_Index), ObjGetAddress(Obj,"COMDLG_FILTERSPEC") + A_PtrSize * 2*(A_Index-1))        ; COMDLG_FILTERSPEC.pszName
        NumPut(ObjGetAddress(Obj,"@" . A_Index), ObjGetAddress(Obj,"COMDLG_FILTERSPEC") + A_PtrSize * (2*(A_Index-1)+1))    ; COMDLG_FILTERSPEC.pszSpec
    }

    ; IFileDialog::SetFileTypes method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775980(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+4*A_PtrSize), "UPtr", IFileOpenDialog, "UInt", Filter.Count(), "UPtr", ObjGetAddress(Obj,"COMDLG_FILTERSPEC"))

    ; IFileDialog::SetFileTypeIndex method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775978(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+5*A_PtrSize), "UPtr", IFileOpenDialog, "UInt", FileTypeIndex)

    
    if ( IsObject(CustomPlaces := IsObject(CustomPlaces) || CustomPlaces == "" ? CustomPlaces : [CustomPlaces]) )
    {
        local Directory := ""
        for foo, Directory in CustomPlaces    ; foo = index
        {
            foo := IsObject(Directory) ? Directory[2] : 0    ; FDAP enumeration (https://msdn.microsoft.com/en-us/library/windows/desktop/bb762502(v=vs.85).aspx)
            if ( DirExist(Directory := IsObject(Directory) ? Directory[1] : Directory) )
            {
                DllCall("Shell32.dll\SHParseDisplayName", "UPtr", &Directory, "Ptr", 0, "UPtrP", PIDL, "UInt", 0, "UInt", 0)
                DllCall("Shell32.dll\SHCreateShellItem", "Ptr", 0, "Ptr", 0, "UPtr", PIDL, "UPtrP", IShellItem)
                ObjRawSet(Obj, IShellItem, PIDL)
                ; IFileDialog::AddPlace method
                ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775946(v=vs.85).aspx
                DllCall(NumGet(NumGet(IFileOpenDialog)+21*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", IShellItem, "UInt", foo)
            }
        }
    }


    ; IFileDialog::SetTitle method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761834(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+17*A_PtrSize), "UPtr", IFileOpenDialog, "UPtr", Title == "" ? 0 : &Title)

    ; IFileDialog::SetOptions method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761832(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileOpenDialog)+9*A_PtrSize), "UPtr", IFileOpenDialog, "UInt", Flags)


    ; IModalWindow::Show method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761688(v=vs.85).aspx
    local Result := []
    if ( !DllCall(NumGet(NumGet(IFileOpenDialog)+3*A_PtrSize), "UPtr", IFileOpenDialog, "Ptr", Owner, "UInt") )
    {
        ; IFileDialog::GetFileTypeIndex method
        ; https://msdn.microsoft.com/es-es/bb775958
        DllCall(NumGet(NumGet(IFileOpenDialog+0)+6*A_PtrSize), "UPtr", IFileOpenDialog, "UIntP", FileTypeIndex)

        ; IFileDialog::GetFileName method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775956(v=vs.85).aspx
        DllCall(NumGet(NumGet(IFileOpenDialog+0)+16*A_PtrSize), "UPtr", IFileOpenDialog, "UIntP", foo)
        ErrorLevel := { FileTypeIndex: FileTypeIndex, FileName: StrGet(foo, "UTF-16") }
        DllCall("Ole32.dll\CoTaskMemFree", "UPtr", foo)

        ; IFileOpenDialog::GetResults method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775831(v=vs.85).aspx
        local IShellItemArray := 0    ; IShellItemArray interface (https://msdn.microsoft.com/en-us/library/windows/desktop/bb761106(v=vs.85).aspx)
        DllCall(NumGet(NumGet(IFileOpenDialog)+27*A_PtrSize), "UPtr", IFileOpenDialog, "UPtrP", IShellItemArray)

        ; IShellItemArray::GetCount method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761098(v=vs.85).aspx
        local Count := 0    ; pdwNumItems
        DllCall(NumGet(NumGet(IShellItemArray)+7*A_PtrSize), "UPtr", IShellItemArray, "UIntP", Count, "UInt")

        local Buffer := ""
        loop ( 0*VarSetCapacity(Buffer, 32767 * 2) + Count )
        {
            ; IShellItemArray::GetItemAt method
            ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761100(v=vs.85).aspx
            DllCall(NumGet(NumGet(IShellItemArray)+8*A_PtrSize), "UPtr", IShellItemArray, "UInt", A_Index-1, "UPtrP", IShellItem)
            DllCall("Shell32.dll\SHGetIDListFromObject", "UPtr", IShellItem, "UPtrP", PIDL)
            DllCall("Shell32.dll\SHGetPathFromIDListEx", "UPtr", PIDL, "Str", Buffer, "UInt", 32767, "UInt", 0)
            ObjRawSet(Obj, IShellItem, PIDL), ObjPush(Result, Buffer)
        }

        ObjRelease(IShellItemArray)
    }


    for foo, bar in Obj    ; foo = IShellItem interface (ptr)  |  bar = PIDL structure (ptr)
        if ( foo is "integer" )    ; IShellItem?
            ObjRelease(foo), DllCall("Ole32.dll\CoTaskMemFree", "UPtr", bar)
    ObjRelease(IFileOpenDialog)

    return ObjLength(Result) ? (Options & 0x200 ? Result : Result[1]) : FALSE
}
