/*
    Referencias:
        VS_VERSIONINFO structure
        https://msdn.microsoft.com/en-us/library/windows/desktop/ms647001(v=vs.85).aspx

        StringFileInfo structure
        https://msdn.microsoft.com/en-us/library/windows/desktop/ms646989(v=vs.85).aspx

        StringTable structure
        https://msdn.microsoft.com/en-us/library/windows/desktop/ms646992(v=vs.85).aspx

        String structure
        https://msdn.microsoft.com/en-us/library/windows/desktop/ms646987(v=vs.85).aspx

        VarFileInfo structure
        https://msdn.microsoft.com/en-us/library/windows/desktop/ms646995(v=vs.85).aspx

        Var structure
        https://msdn.microsoft.com/en-us/library/windows/desktop/ms646994(v=vs.85).aspx

    Thanks to:
        fincs : https://autohotkey.com/boards/viewtopic.php?f=24&t=521
*/
Class VersionRes    ;// updated on 2018-05-25 | Flipeador
{
    ; ===================================================================================================================
    ; INSTANCE VARIABLES
    ; ===================================================================================================================
    ValueLength := 0     ; WORD wValueLength
           Type := 0     ; WORD wType
            Key := ""    ; WCHAR szKey
          Value := ""    ; VS_FIXEDFILEINFO|WORD Value
       Children := []    ; VS_VERSIONINFO|StringFileInfo|StringTable|String|VarFileInfo|Var Children
    

    ; ===================================================================================================================
    ; CONSTRUCTOR
    ; ===================================================================================================================
    __New(Ptr, Data := "", Length := "")
    {
        If (Type(Ptr) == "String")
        {
            this[Type(Data) == "Integer" ? "SetBinary" : "SetText"](Data, Length)
            Return this.SetKey(Ptr)
        }
        
        If (Type(Ptr) != "Integer" || Ptr < 0x10000)
            Throw Exception("Class VersionRes invalid parameter #1", -1, "Invalid address")

        Local Limit := Ptr + NumGet(Ptr, "UShort")
        ObjRawSet( this, "ValueLength", NumGet(Ptr += 2, "UShort") )
        ObjRawSet( this,        "Type", NumGet(Ptr += 2, "UShort") )    ; 0 = Binary | 1 = Text
        ObjRawSet( this,         "Key", StrGet(Ptr += 2, "UTF-16") )

        Ptr := (Ptr + 2 * ( StrLen(this.Key) + 1 ) + 3) & ~3

        Local Size := this.ValueLength * (this.Type + 1)
        ObjSetCapacity(this, "Value", Size)

        DllCall("msvcrt.dll\memcpy", "UPtr", ObjGetAddress(this, "Value"), "UPtr", Ptr, "UPtr", Size, "Cdecl")

        Ptr := (Ptr + Size + 3) & ~3

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
    AddChild(Node)
    {
        If (!IsObject(Node) || Node.__Class != "VersionRes")
            Throw Exception("Class VersionRes::AddChild invalid parameter #1", -1)
        ObjPush(this.Children, Node)
        Return Node
    }
    
    GetChild(Key, CaseSensitive := FALSE)
    {
        Loop (ObjLength(this.Children))
            If ((CaseSensitive && this.Children[A_Index].Key == Key) || (!CaseSensitive && this.Children[A_Index].Key = Key))
                Return this.Children[A_Index]
        Return FALSE
    }

    DeleteChild(Key, CaseSensitive := FALSE)
    {
        Loop (ObjLength(this.Children))
            If ((CaseSensitive && this.Children[A_Index].Key == Key) || (!CaseSensitive && this.Children[A_Index].Key = Key))
                Return ObjRemoveAt(this.Children, A_Index)
        Return FALSE
    }
    
    DeleteAll()
    {
        ObjRawSet(this, "Children", [])
        Return this
    }

    SetKey(Key)
    {
        ObjRawSet(this, "Key", String(Key))
        Return this
    }

    SetText(Text, Length := "")
    {
        Text := Length == "" ? String(Text) : SubStr(Text, 1, Length)
        ObjRawSet(this, "ValueLength", StrLen(Text) + 1)
        ObjRawSet(this, "Value", Text)
        ObjRawSet(this, "Type", 1)
        Return this.ValueLength
    }
    
    SetBinary(Address, Length)
    {
        If (Type(Address) != "Integer" || Address < 0x10000)
            Throw Exception("Class VersionRes::SetBinary invalid parameter #1", -1, "Invalid address")

        If (Type(Length) != "Integer" || Length < 0)
            Throw Exception("Class VersionRes::SetBinary invalid parameter #2", -1, "Invalid data size")

        ObjRawSet(this, "ValueLength", Length)
        ObjSetCapacity(this, "Value", Length)
        DllCall("msvcrt.dll\memcpy", "UPtr", ObjGetAddress(this, "Value"), "UPtr", Address, "UPtr", Length, "Cdecl")
        ObjRawSet(this, "Type", 0)
        Return Length
    }

    GetKey()
    {
        Return this.Key
    }

    GetValue(Offset := 0)
    {
        Return this.Type ? this.Value : ObjGetAddress(this, "Value") + Offset
    }

    GetType()
    {
        Return this.Type
    }

    GetSize()
    {
        Local Size := ((6 + 2*StrLen(this.Key)+2 + 3) & ~3) + ((this.ValueLength * (this.Type + 1) + 3) & ~3)
        Loop (ObjLength(this.Children))
            Size += this.Children[A_Index].GetSize()
        Return Size
    }

    Alloc(ByRef Size)
    {
        ObjRawSet(this, "Buffer", "")
        ObjSetCapacity(this, "Buffer", this.GetSize())
        Size := this.Save(ObjGetAddress(this, "Buffer"))
        Return ObjGetAddress(this, "Buffer")
    }

    Save(Address)
    {
        Local Address2 := Address
        NumPut(this.ValueLength, Address += 2, "UShort")
        NumPut(this.Type, Address += 2, "UShort")

        Address := ( Address + 2 * StrPut(this.Key, Address += 2, "UTF-16") + 3 ) & ~3

        Local Size := this.ValueLength * (this.Type + 1)
        DllCall("msvcrt.dll\memcpy", "UPtr", Address, "UPtr", ObjGetAddress(this, "Value"), "UPtr", Size, "Cdecl")

        Address := ( Address + Size + 3 ) & ~3
        
        Loop (ObjLength(this.Children))
            Address += this.Children[A_Index].Save(Address)

        NumPut(Size := Address - Address2, Address2, "UShort")
        Return Size
    }
}
