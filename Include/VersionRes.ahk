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
    __New(Ptr, Data := "", Length := "")
    {
        If (Type(Ptr) == "String")
        {
            this[Type(Data) == "Integer" ? "SetBinary" : "SetText"](Data, Length)
            Return this.SetKey(Ptr)
        }
        
        If (Type(Ptr) != "Integer" || Ptr < 0x10000)
            Throw Exception("Class VersionRes invalid parameter #1", -1, "Invalid address")

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
    AddChild(Node)
    {
        ObjPush(this.Children, IsObject(Node) ? Node : Node := new VersionRes(Node))
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

    GetSize()
    {
        Local Size := ((6 + 2*StrLen(this.Key)+2 + 3) & ~3) + ((this.ValueLength * (this.Type + 1) + 3) & ~3)
        Loop (ObjLength(this.Children))
            Size += this.Children[A_Index].GetSize()
        Return Size
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
