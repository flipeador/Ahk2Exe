Class VersionRes
{
    ; ===================================================================================================================
    ; INSTANCE VARIABLES
    ; ===================================================================================================================
         Length := 0     ; WORD wLength
    ValueLength := 0     ; wORD wValueLength
           Type := 0     ; WORD wType
            Key := ""    ; WCHAR szKey
          Value := ""    ; VS_FIXEDFILEINFO|WORD Value
       Children := []    ; StringFileInfo|StringTable|String|VarFileInfo|Var Children
    

    ; ===================================================================================================================
    ; CONSTRUCTOR
    ; ===================================================================================================================
    __New(Ptr := 0)
    {
        If (!Ptr)
            Return this
        
        ObjRawSet( this,      "Length", NumGet(Ptr += 0, "UShort") )
        Local Limit := Ptr + this.Length
        ObjRawSet( this, "ValueLength", NumGet(Ptr += 2, "UShort") )
        ObjRawSet( this,        "Type", NumGet(Ptr += 2, "UShort") )    ; 0 = Binary | 1 = Text
        ObjRawSet( this,         "Key", StrGet(Ptr += 2, "UTF-16") )

        Ptr += 2 * ( StrLen(this.Key) + 1 )
        Ptr := (Ptr + 3) & ~3    ; Padding

        Local Size := this.ValueLength * (this.Type + 1)
        ObjSetCapacity(this, "Value", Size)

        DllCall("msvcrt.dll\memcpy", "UPtr", ObjGetAddress(this, "Value"), "UPtr", Ptr, "UPtr", Size, "Cdecl")

        Ptr += Size
        Ptr := (Ptr + 3) & ~3    ; Padding

        While (Ptr < Limit)
        {
            Size := (NumGet(Ptr, "UShort") + 3) & ~3
            ObjPush(this.Children, new VersionRes(Ptr))
            Ptr += Size
        }
    }
    

    ; ===================================================================================================================
    ; PUBLIC METHODS
    ; ===================================================================================================================
    /*
        Crea una estructura miembro válida. Devuelve un objeto VersionRes.
        Parámetros:
            Type:
                El tipo de datos en Data. 0 para datos binarios. 1 para texto.
            Key:
                El nombre para este nuevo miembro. Este valor no puede ser una cadena vacía.
            Data:
                Los datos. Este valor depende del tipo de datos o el tipo de valor pasado.
                Si va a incluir datos binarios, debe especificar un puntero. Debe especificar el tamaño en ValueLength.
                Si va a incluir texto, debe especificar una cadena.
            ValueLength:
                El tamaño de Data. Obligatorio si Data es un puntero y Type es 0.
    */
    CreateChild(Type, Key, Data := "", ValueLength := 0)
    {
        If (Key == "")
            Return FALSE
        ValueLength := Type ? StrLen(Data) + 1 : ValueLength
        Local   Size := ((6 + 2*StrLen(Key)+2 + 3) & ~3) + ((ValueLength * (Type + 1) + 3) & ~3)
            , VerRes := new VersionRes()
        ObjRawSet( VerRes,      "Length",        Size )
        ObjRawSet( VerRes, "ValueLength", ValueLength )
        ObjRawSet( VerRes,        "Type",        Type )
        ObjRawSet( VerRes,         "Key", String(Key) )
        If (Type)
            ObjRawSet( VerRes, "Value", ValueLength ? SubStr(Data, 1, ValueLength) : String(Data) )
        Else
            ObjSetCapacity( VerRes, "Value", ValueLength )
          , DllCall("msvcrt.dll\memcpy", "UPtr", ObjGetAddress(VerRes, "Value"), "UPtr", Data, "UPtr", ValueLength, "Cdecl")
        Return VerRes 
    }

    /*
        Añade un miembro en la estructura actual.
        Parámetros:
            Node:
                Un objeto VersionRes o un puntero a la estructura miembro.
    */
    AddChild(Node)
    {
        ObjPush(this.Children, IsObject(Node) ? Node : Node := new VersionRes(Node))
        Return Node
    }
    
    /*
        Recupera el miembro con el nombre especificado en la estructura actual.
    */
    GetChild(Key, CaseSensitive := FALSE)
    {
        Loop (ObjLength(this.Children))
            If ((CaseSensitive && this.Children[A_Index].Key == Key) || (!CaseSensitive && this.Children[A_Index].Key = Key))
                Return this.Children[A_Index]
        Return FALSE
    }

    /*
        Elimina el miembro con el nombre especificado en la estructura actual.
    */
    DeleteChild(Key, CaseSensitive := FALSE)
    {
        Loop (ObjLength(this.Children))
            If ((CaseSensitive && this.Children[A_Index].Key == Key) || (!CaseSensitive && this.Children[A_Index].Key = Key))
                Return ObjRemoveAt(this.Children, A_Index)
        Return FALSE
    }
    
    /*
        Elimina todos los miembros de la estructura actual.
    */
    DeleteAll()
    {
        ObjRawSet(this, "Children", [])
    }

    /*
        Cambia el valor de la estructura actual por el texto especificado.
    */
    SetText(Text)
    {
        ObjRawSet(this, "Value", String(Text))
        ObjRawSet(this, "Type", 1)
        ObjRawSet(this, "ValueLength", StrLen(Text) + 1)
    }

    /*
        Recupera el tamaño total de la estructura actual junto con todos sus miembros.
    */
    GetSize()
    {
        Local Size := ((6 + 2*StrLen(this.Key)+2 + 3) & ~3) + ((this.ValueLength * (this.Type + 1) + 3) & ~3)
        Loop (ObjLength(this.Children))
            Size += this.Children[A_Index].GetSize()
        Return Size
    }

    /*
        Escribe esta estructura junto con todos sus miembros en la dirección de memoria especificada y devuelve el tamaño total.
    */
    Save(Ptr)
    {
        Local PtrO := Ptr

        NumPut(this.ValueLength, Ptr += 2, "UShort")
        NumPut(this.Type, Ptr += 2, "UShort")

        Ptr += 2 * StrPut(this.Key, Ptr += 2, "UTF-16")
        Ptr := (Ptr + 3) & ~3    ; Padding

        Local Size := this.ValueLength * (this.Type + 1)
        DllCall("msvcrt.dll\memcpy", "UPtr", Ptr, "UPtr", ObjGetAddress(this, "Value"), "UPtr", Size, "Cdecl")

        Ptr += Size
        Ptr := (Ptr + 3) & ~3    ; Padding

        Loop (ObjLength(this.Children))
            Ptr += this.Children[A_Index].Save(Ptr)

        NumPut(Size := Ptr - PtrO, PtrO, "UShort")
        Return Size
    }
}
