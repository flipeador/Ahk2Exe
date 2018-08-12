/*
    Muestra un diálogo para guardar uno archivo.
    Parámetros:
        Owner / Title:
            El identificador de la ventana propietaria de este diálogo. Este valor puede ser cero.
            Un Array con el identificador de la ventana propietaria y el título. Si el título es una cadena vacía se establece al por defecto "Guardar como".
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
                0x00000002  (FOS_OVERWRITEPROMPT) = Ppreguntar antes de sobrescribir un archivo existente con el mismo nombre.
                0x00000004  (FOS_STRICTFILETYPES) = Solo permite al usuario elegir un archivo que tenga una de las extensiones de nombre de archivo especificadas a través del filtro.
                0x00040000 (FOS_HIDEPINNEDPLACES) = Ocultar elementos que se muestran de forma predeterminada en el panel de navegación de la vista.
                0x10000000  (FOS_FORCESHOWHIDDEN) = Incluye elementos ocultos y del sistema.
                0x02000000  (FOS_DONTADDTORECENT) = No agregue el elemento que se abre o guarda en la lista de documentos recientes (function SHAddToRecentDocs).
            Puede consultar todos los valores disponibles en https://msdn.microsoft.com/en-us/library/windows/desktop/dn457282(v=vs.85).aspx.
            Los valores por defecto son FOS_OVERWRITEPROMPT y FOS_STRICTFILETYPES.
    Return:
        Devuelve 0 si el usuario canceló el diálogo, en caso contrario devuelve la ruta del archivo seleccionado.
        Si tuvo éxito, ErrorLevel se establece en un objeto con las claves descritas a continuación.
            FileName      = El texto actualmente ingresado en el cuadro de edición de nombre de archivo del diálogo.
            FileTypeIndex = El índice en la lista dezplegable del tipo de archivo actualmente seleccionado (filtro).
    Ejemplo:
        MsgBox SaveFile( [0, "Título del diálogo - Guardar como.."]
                       , A_ComSpec
                       , {Música: "*.mp3", Imágenes: "`n*.jpg;*.png", Videos: "*.avi;*.mp4;*.mkv;*.wmp", Documentos: "*.txt"}
                       , [A_WinDir,A_Desktop,A_Temp,A_Startup,A_ProgramFiles]
                       , 0x00000002 | 0x00000004 | 0x10000000 | 0x02000000 )
*/
SaveFile(Owner, FileName := "", Filter := "", CustomPlaces := "", Options := 0x6)
{
    ; IFileSaveDialog interface
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775688(v=vs.85).aspx
    local IFileSaveDialog := ComObjCreate("{C0B4E2F3-BA21-4773-8DBA-335EC946EB8B}", "{84BCCD23-5FDE-4CDB-AEA4-AF64B83D78AB}")
        ,           Title := IsObject(Owner) ? Owner[2] . "" : ""
        ,           Flags := Options     ; FILEOPENDIALOGOPTIONS enumeration (https://msdn.microsoft.com/en-us/library/windows/desktop/dn457282(v=vs.85).aspx)
        ,      IShellItem := PIDL := 0   ; PIDL recibe la dirección de memoria a la estructura ITEMIDLIST que debe ser liberada con la función CoTaskMemFree
        ,             Obj := {}, foo := "", bar := ""
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
                DllCall(NumGet(NumGet(IFileSaveDialog)+15*A_PtrSize), "UPtr", IFileSaveDialog, "UPtr", &File)
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
                DllCall(NumGet(NumGet(IFileSaveDialog)+12*A_PtrSize), "Ptr", IFileSaveDialog, "UPtr", IShellItem)
            }
        }
        else    ; si «FileName» es únicamente el nombre de un archivo
            DllCall(NumGet(NumGet(IFileSaveDialog)+15*A_PtrSize), "UPtr", IFileSaveDialog, "UPtr", &FileName)
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
    DllCall(NumGet(NumGet(IFileSaveDialog)+4*A_PtrSize), "UPtr", IFileSaveDialog, "UInt", Filter.Count(), "UPtr", ObjGetAddress(Obj,"COMDLG_FILTERSPEC"))

    ; IFileDialog::SetFileTypeIndex method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775978(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileSaveDialog)+5*A_PtrSize), "UPtr", IFileSaveDialog, "UInt", FileTypeIndex)


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
                DllCall(NumGet(NumGet(IFileSaveDialog)+21*A_PtrSize), "UPtr", IFileSaveDialog, "UPtr", IShellItem, "UInt", foo)
            }
        }
    }


    ; IFileDialog::SetTitle method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761834(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileSaveDialog)+17*A_PtrSize), "UPtr", IFileSaveDialog, "UPtr", Title == "" ? 0 : &Title)

    ; IFileDialog::SetOptions method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761832(v=vs.85).aspx
    DllCall(NumGet(NumGet(IFileSaveDialog)+9*A_PtrSize), "UPtr", IFileSaveDialog, "UInt", Flags)


    ; IModalWindow::Show method
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb761688(v=vs.85).aspx
    local Result := FALSE
    if ( !DllCall(NumGet(NumGet(IFileSaveDialog)+3*A_PtrSize), "UPtr", IFileSaveDialog, "Ptr", Owner, "UInt") )
    {
        ; IFileDialog::GetFileTypeIndex method
        ; https://msdn.microsoft.com/es-es/bb775958
        DllCall(NumGet(NumGet(IFileSaveDialog+0)+6*A_PtrSize), "UPtr", IFileSaveDialog, "UIntP", FileTypeIndex)

        ; IFileDialog::GetFileName method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775956(v=vs.85).aspx
        DllCall(NumGet(NumGet(IFileSaveDialog+0)+16*A_PtrSize), "UPtr", IFileSaveDialog, "UIntP", foo)
        ErrorLevel := { FileTypeIndex: FileTypeIndex, FileName: StrGet(foo, "UTF-16") }
        DllCall("Ole32.dll\CoTaskMemFree", "UPtr", foo)

        ; IFileDialog::GetResult method
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775964(v=vs.85).aspx
        if ( !DllCall(NumGet(NumGet(IFileSaveDialog)+20*A_PtrSize), "UPtr", IFileSaveDialog, "UPtrP", IShellItem) )
        {
            DllCall("Shell32.dll\SHGetIDListFromObject", "UPtr", 0*VarSetCapacity(Result,32767*2, 0)+IShellItem, "UPtrP", PIDL)
            DllCall("Shell32.dll\SHGetPathFromIDListEx", "UPtr", PIDL, "Str", Result, "UInt", 32767, "UInt", 0)
            ObjRawSet(Obj, IShellItem, PIDL)
        }
    }


    for foo, bar in Obj    ; foo = IShellItem interface (ptr)  |  bar = PIDL structure (ptr)
        if ( foo is "integer" )    ; IShellItem?
            ObjRelease(foo), DllCall("Ole32.dll\CoTaskMemFree", "UPtr", bar)
    ObjRelease(IFileSaveDialog)

    return Result
}
