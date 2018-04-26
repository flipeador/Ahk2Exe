
;CB  := (Gui:=GuiCreate()).AddComboBox("x0 y0 w200", "Item AB|Item AC|Item AD"), Gui.Show(), Gui.OnEvent("Close", "ExitApp")





/*
    Encuentra el primer elemento que coincide con la cadena especificada.
    Parámetros:
        String:
            La cadena a buscar.
        Item:
            El índice basado en cero del elemento que precede al primer elemento que se buscará.
            Cuando la búsqueda llega al final, continúa desde la parte superior hasta el elemento especificado.
            Si especifica -1, se busca desde el principio.
        Mode:
            Determina el comportamiento de la búsqueda. Debe especificar uno de los siguientes valores.
                0 = Busca el elemento cuyo texto comience por la cadena especificada. Este es el modo por defecto. No distingue entre mayúsculas y minúsculas.
                1 = Busca el elemento cuyo texto coincide exactamente con la cadena especificada. No distingue entre mayúsculas y minúsculas.
                2 = Busca el elemento cuyo texto coincida de forma parcial con la cadena especificada. No distingue entre mayúsculas y minúsculas.
                3 = Igual al modo #2, pero la búsqueda distingue entre mayúsculas y minúsculas.
        Return:
            El valor de retorno es el índice basado en cero del elemento coincidente. -1 si la búsqueda no ha tenido éxito.
*/
CB_FindString(CB, String, Item := -1, Mode := 0)
{
    If (Mode > 1)
    {
        Loop (CB_GetCount(CB))
            If ((Item == -1 || A_Index-2 > Item) && InStr(CB_GetText(CB, A_Index-1), String, Mode == 3))
                Return A_Index-1
        Return -1
    }

    ; CB_FINDSTRING message | CB_FINDSTRINGEXACT message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775835(v=vs.85).aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775837(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", Mode ? 0x158 : 0x14C, "Ptr", Item, "UPtr", &String, "Ptr")
}





/*
    Recupera la cantidad de elementos.
*/
CB_GetCount(CB)
{
    ; CB_GETCOUNT message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775841(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0146, "Ptr", 0, "Ptr", 0, "Ptr")
}





/*
    Recupera el texto del elemento especificado.
    Return:
        Si tuvo éxito devuelve el texto del elemento, caso contrario devuelve una cadena vacía.
    ErrorLevel:
        Se establece un TRUE si hubo un error (el elemento no existe). FALSE si tuvo éxito.
*/
CB_GetText(CB, Item := -1)
{
    If (Item == -1)
        Return ControlGetText(, "ahk_id" . CB_GetInfo(CB).Edit)

    ; CB_GETLBTEXTLEN message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775864(v=vs.85).aspx
    Local Length := DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0149, "Ptr", Item, "Ptr", 0, "Ptr")
    If (Length == -1 && (ErrorLevel := TRUE))    ; -1 = CB_ERR
        Return ""

    ; CB_GETLBTEXT message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775862(v=vs.85).aspx
    VarSetCapacity(Buffer, Length + 2, 0)    ; 2 = '\0'
    DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0148, "Ptr", Item, "UPtr", &Buffer, "Ptr")

    ErrorLevel := FALSE
    Return StrGet(&Buffer, "UTF-16")
}





/*
    Establece el texto actual o cambia el texto del elemento especificado.
    Parámetros:
        String:
            La cadena a establecer.
        Item:
            El índice basado en cero del elemento para cambiar el texto. Tenga en cuenta que no se puede modificar un elemento, la función elimina e inserta un nuevo elemento con el texto especificado.
            Si este parámetro es -1, la función no modifica ningún elemento, sino que solo establece el texto especificado en el control de edición.
    Return:
        Si Item es -1 la función devuelve 1 si tuvo éxito, cero en caso contrario.
        Si Item no es -1, la función devuelve la posición del elemento modificado, -1 si hubo un error.
*/
CB_SetText(CB, String, Item := -1)
{
    If (Item == -1)
        Return DllCall("User32.dll\SetWindowTextW", "Ptr", CB.Hwnd, "UPtr", &String)
    Local Selection := CB_GetSelection(CB)
    If (CB_Delete(CB, Item) == -1)
        Return -1
    If ((Item := CB_Insert(CB, String, Item)) < 0)
        Return -1
    If (Selection == Item)
        DllCall("User32.dll\SetWindowTextW", "Ptr", CB.Hwnd, "UPtr", &String)
    Return Item
}





/*
    Recupera el elemento seleccionado.
    Return:
        Si no hay ningún elemento seleccionado devuelve -1, caso contrario devuelve el índice basado en cero del elemento seleccionado.
*/
CB_GetSelection(CB)
{
    ; CB_GETCURSEL message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775845(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0147, "Ptr", 0, "Ptr", 0, "Ptr")
}





/*
    Establece la selección en el elemento especificado.
    Return:
        Si tuvo éxito devuelve el índice basado en cero del elemento seleccionado, caso contrario devuelve -1.
*/
CB_SetSelection(CB, Item)
{
    ; CB_SETCURSEL message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775899(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x014E, "Ptr", Item, "Ptr", 0, "Ptr")
}





/*
    Recupera las posiciones de carácter inicial y final de la selección actual en el control de edición.
    Return:
        Devuelve un objeto con las claves Start y End indicando el carácter inicial y final respectivamente.
*/
CB_GetEditSel(CB)
{
    ; CB_GETEDITSEL message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775853(v=vs.85).aspx
    Local StartingPos := EndingPos := 0
    DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0140, "UIntP", StartingPos, "UIntP", EndingPos, "Ptr")
    Return {Start: StartingPos, End: EndingPos}
}





/*
    Selecciona carácteres en el control de edición.
    Parámetros:
        StartingPos:
            La posición basada en cero del caracter que indica el comienzo de la selección. Si este parámetro es -1 se remueve la selección actual, si la hay.
        EndingPos:
            La posición basada en cero del caracter que indica el final de la selección. Si este parámetro es -1 se seleccionan todos los caracteres a partir de StartingPos.
    Return:
        Si se envia a un control ComboBox devuelve TRUE, si se envía a un control DropDownList devuelve -1 (CB_ERR).
*/
CB_SetEditSel(CB, StartingPos, EndingPos)
{
    ; CB_SETEDITSEL message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775903(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0142, "Ptr", 0, "Int", (StartingPos & 0xFFFF) | (EndingPos & 0xFFFF) << 16, "Ptr")
}





/*
    Elimina el elemento especificado o todos los elementos.
    Return:
        Si Item es -1, devuelve siempre 0 (CB_OKAY).
        Si Item no es -1, devuelve la cantidad de elementos aún en la lista, o -1 si el elemento es inválido.
*/
CB_Delete(CB, Item := -1)
{
    ; CB_RESETCONTENT message | CB_DELETESTRING message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775878(v=vs.85).aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775830(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", Item == -1 ? 0x014B : 0x0144, "Ptr", Item, "Ptr", 0)
}





/*
    Añade un elemento en la posición especificada.
    Parámetros:
        String:
            El nombre del elemento. Puede especificar un Array para añadir varios elementos.
        Item:
            El índice basado en cero de la posición en la que insertar el elemento. Si este parámetro es -1, el elemento se agrega al final de la lista.
        Flag:
            Si se establece, especifica el valor del parámetro «Mode» de la función CB_FindString, el elemento no se añadirá si ya existe un elemento con el mismo texto.
    Return:
        Si tuvo éxito devuelve la posición basada en cero del nuevo elemento.
        Si hubo un error devuelve -1 (CB_ERR).
        Si no hay más espacio para insertar la cadena devuelve -2 (CB_ERRSPACE).
        Si se especificó Flags y ya hay un elemento con el mismo texto, devuelve -3. No es válido si String es un Array.
        Si se especificó un Array en String, devuelve la posición basada en cero del primer elemento añadido.
*/
CB_Insert(CB, String, Item := -1, Flag := -1)
{
    If (IsObject(String))
    {
        Loop (ObjLength(String))
            If (Flag == -1 || CB_FindString(CB, String, Flag) == -1)
                Item := DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x014A, "Ptr", Item, "UPtr", &String[A_Index], "Ptr")
        Return Item - ObjLength(String) + 3
    }

    ; CB_INSERTSTRING message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775875(v=vs.85).aspx
    Return Flag == -1 || CB_FindString(CB, String, Flag) == -1 ? DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x014A, "Ptr", Item, "UPtr", &String, "Ptr") : -3
}





/*
    Establece el alto de los elementos de la lista o el campo de selección.
    Parámetros:
        Height:
            Especifica la altura, en píxeles.
        Component:
            Este parámetro debe ser -1 para establecer la altura del campo de selección.
            Debe ser cero para establecer la altura de los elementos de la lista, a menos que el control tenga el estilo CBS_OWNERDRAWVARIABLE
            En ese caso, el parámetro es el índice basado en cero de un elemento de lista específico.
    Return:
        Devuelve -1 (CB_ERR) si hubo un error.
*/
CB_SetItemHeight(CB, Height, Component := 0)
{
    ; CB_SETITEMHEIGHT message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775911(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0153, "Ptr", Component, "Ptr", Height, "Ptr")
}





CB_GetItemData(CB, Data, Item)
{
    ; CB_GETITEMDATA message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775859(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0150, "Ptr", Item, "Ptr", 0, "Ptr")
}





CB_SetItemData(CB, Data, Item)
{
    ; CB_SETITEMDATA message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775909(v=vs.85).aspx
    Return DllCall("User32.dll\SendMessageW", "Ptr", CB.Hwnd, "UInt", 0x0151, "Ptr", Item, "Ptr", Data, "Ptr")
}





/*
    Recupera información del control.
    Return:
        Devuelve un objeto con las siguientes claves o cero si hubo un error.
            Rect       : Un objecto con las siguientes claves.
                Edit  : Un objeto con las claves Left, Top, Right y Bottom con las coordenadas de la caja de edición.
                Button: Un objeto con las claves Left, Top, Right y Bottom con las coordenadas del botón que contiene la flecha desplegable.
            ButtonState: El estado del botón del ComboBox. Este parámetro puede ser uno de los siguientes valores.
                0                                   = El botón existe y no está presionado.
                0x00008000 (STATE_SYSTEM_INVISIBLE) = No hay botón.
                0x00000008 (STATE_SYSTEM_PRESSED)   = El botón está presionado.
            CB         : El identificador del control ComboBox.
            Edit       : El identificador del control de edición (Edit).
            DDL        : El identificador de la lista desplegable.
*/
CB_GetInfo(CB)
{
    ; COMBOBOXINFO structure
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775798(v=vs.85).aspx
    Local COMBOBOXINFO := ""
    NumPut(VarSetCapacity(COMBOBOXINFO, 4 + 16 + 16 + 4 + A_PtrSize*3, 0), &COMBOBOXINFO, "UInt")

    ; GetComboBoxInfo function
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775939(v=vs.85).aspx
    If (!DllCall("User32.dll\GetComboBoxInfo", "Ptr", CB.Hwnd, "UPtr", &COMBOBOXINFO))
        Return FALSE

    Return { Rect: {   Edit: {   Left: NumGet(&COMBOBOXINFO +  4, "Int")
                             ,    Top: NumGet(&COMBOBOXINFO +  8, "Int")
                             ,  Right: NumGet(&COMBOBOXINFO + 12, "Int")
                             , Bottom: NumGet(&COMBOBOXINFO + 16, "Int") }
                   , Button: {   Left: NumGet(&COMBOBOXINFO + 20, "Int")
                             ,    Top: NumGet(&COMBOBOXINFO + 24, "Int")
                             ,  Right: NumGet(&COMBOBOXINFO + 28, "Int")
                             , Bottom: NumGet(&COMBOBOXINFO + 32, "Int") } }
           , ButtonState: NumGet(&COMBOBOXINFO + 36, "UInt")
           ,   CB: NumGet(&COMBOBOXINFO + 40              , "Ptr")
           , Edit: NumGet(&COMBOBOXINFO + 40 + A_PtrSize  , "Ptr")
           ,  DDL: NumGet(&COMBOBOXINFO + 40 + A_PtrSize*2, "Ptr") }
}
