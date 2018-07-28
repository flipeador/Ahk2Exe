/*
    Clase para crear y modificar la estructura de versión de información para archivos binarios en Windows.

    Referencias:
        VS_VERSIONINFO structure
        https://docs.microsoft.com/es-es/windows/desktop/menurc/vs-versioninfo
        
        VS_FIXEDFILEINFO structure
        https://docs.microsoft.com/en-us/windows/desktop/api/VerRsrc/ns-verrsrc-tagvs_fixedfileinfo

        StringFileInfo structure
        https://docs.microsoft.com/es-es/windows/desktop/menurc/stringfileinfo

        StringTable structure
        https://docs.microsoft.com/es-es/windows/desktop/menurc/stringtable

        String structure
        https://docs.microsoft.com/es-es/windows/desktop/menurc/string-str

        VarFileInfo structure
        https://docs.microsoft.com/es-es/windows/desktop/menurc/varfileinfo

        Var structure
        https://docs.microsoft.com/es-es/windows/desktop/menurc/var-str

    Thanks to:
        fincs : https://autohotkey.com/boards/viewtopic.php?f=24&t=521
*/
Class VersionRes    ;// updated on 2018-07-28 | Flipeador
{
    ; ===================================================================================================================
    ; INSTANCE VARIABLES
    ; ===================================================================================================================
    ValueLength := 0     ; WORD  wValueLength
           Type := 0     ; WORD  wType
            Key := ""    ; WCHAR szKey
          Value := ""    ; VS_FIXEDFILEINFO|WORD Value
       Children := []    ; VS_VERSIONINFO|StringFileInfo|StringTable|String|VarFileInfo|Var Children
    

    ; ===================================================================================================================
    ; CONSTRUCTOR
    ; ===================================================================================================================
    /*
        Crea un objeto de clase «VersionRes» con los datos especificados.
        «Ptr» puede ser un puntero o el nombre de la clave para la nueva estructura.
    */
    __New(Ptr, Data := 0, Length := "")
    {
        if (Type(Ptr) == "String")    ; comprueba si se debe crear un objeto mediante la clave y datos dados
        {
            if ( Type(Data) == "Integer" )    ; si «Data» es de tipo entero la tratamos como una dirección de memoria
                this.SetBinary(Data, Length == "" ? 0 : Length)    ; si «Length» es cero la estructura no tiene un miembro «Value» (como es el caso de StringTable)
            else                              ; en caso contrario la tratamos como una cadena
                this.SetText(Data, Length)
            return this.SetKey(Ptr)    ; establece el nombre de la clave y devuelve este objeto de clase «VersionRes»
        }
        
        if (Type(Ptr) != "Integer" || Ptr < 0x10000)    ; comprueba si «Ptr» es una dirección de memoria válida
            throw Exception("Class VersionRes invalid parameter #1", -1, "Invalid address")

        ; nota: el uso de "(.. + 3) & ~3" es para alinear los datos (relleno/padding) en un límite de 32-Bit
        local limit := Ptr + NumGet(Ptr, "UShort")        ; almacena el tamaño completo de esta y todas las sub-estructuras
        this.ValueLength := NumGet(Ptr += 2, "UShort")    ; el tamaño de los datos (si es una cadena el tamaño es en caracteres + caracter de terminación nula)
        this.Type        := NumGet(Ptr += 2, "UShort")    ; 0 = Datos binarios  |  1 = Texto
        this.Key         := StrGet(Ptr += 2, "UTF-16")    ; el nombre de la clave (una cadena vacía es reprecentada por una caracter nulo, cero)

        Ptr := (Ptr + 2 * ( StrLen(this.Key) + 1 ) + 3) & ~3    ; posiciona el puntero al comienzo de los datos (Value) - si no hay datos el puntero indica el final de esta estructura

        local size := this.ValueLength * (this.Type + 1)        ; almacena el tamaño de los datos (si es una cadena lo multiplica por 2 para obtener el tamaño en bytes)
        ObjSetCapacity(this, "Value", size)                     ; ajusta la capacidad de «Value» para almacenar una copia de los datos
        if (size)    ; si el tamaño es 0 quiere decir que la estructura no almacena ningún valor
            DllCall("msvcrt.dll\memcpy", "UPtr", ObjGetAddress(this, "Value"), "UPtr", Ptr, "UPtr", size, "Cdecl")    ; copia los datos y los almacena en «Value»
          , Ptr := (Ptr + size + 3) & ~3    ; posiciona el puntero al final de la estructura actual (comienzo de la estructura siguiente)

        while (Ptr < limit)    ; iteramos por todas las estructuras
        {
            size := (NumGet(Ptr, "UShort") + 3) & ~3    ; recupera el tamaño total de la estructura actual (añadimos relleno si lo necesita)
            this.Children.Push( new VersionRes(Ptr) )   ; añade un nuevo objeto que representa a la estructura actual
            Ptr += size                                 ; avanza el puntero a la siguiente estructura
        }
    }
    

    ; ===================================================================================================================
    ; PUBLIC METHODS
    ; ===================================================================================================================
    /*
        Añade la estructura especificada mediante un objeto de clase «VersionRes».
    */
    AddChild(Node)
    {
        if ( !IsObject(Node) || Node.__Class != "VersionRes" )    ; comprueba que «Node» sea un objeto de clase «VersionRes»
            throw Exception("Class VersionRes::AddChild invalid parameter #1", -1)
        return this.Children.Push( Node ) ? Node : 0    ; añade la estructura y devuelve el objeto
    }
    
    /*
        Recupera un objeto de clase «VersionRes» de la estructura especificada mediante el nombre de la clave.
    */
    GetChild(Key, CaseSensitive := FALSE)
    {
        loop ( this.Children.Length() )
            if ( (CaseSensitive && this.Children[A_Index].Key == Key) || (!CaseSensitive && this.Children[A_Index].Key = Key) )
                return this.Children[A_Index]
        return FALSE
    }

    /*
        Elimina la estructura especificada mediante el nombre de la clave.
    */
    Delete(Key, CaseSensitive := FALSE)
    {
        loop ( this.Children.Length() )
            if ( (CaseSensitive && this.Children[A_Index].Key == Key) || (!CaseSensitive && this.Children[A_Index].Key = Key) )
                return this.Children.RemoveAt( A_Index )
        return FALSE
    }
    
    /*
        Elimina todas las sub-estructuras de la estructura actual.
    */
    DeleteAll()
    {
        return (this.Children := []) ? this : 0
    }

    /*
        Establece el nombre de la clave en la estructura actual.
    */
    SetKey(Key)
    {
        Return (this.Key := String(Key)) ? this : this
    }

    /*
        Establece texto como datos en la estructura actual. Los datos anteriores son reemplazados.
    */
    SetText(Text, Length := "")
    {
        Text := Length == "" ? String(Text) : SubStr(Text,1,Length)
        this.ValueLength := StrLen(Text) + 1   ; establece la longitud del texto (en caracteres + caracter de terminación nula)
        this.Value       := Text               ; establece el texto (datos; miembro «Value»)
        this.Type        := 1                  ; 1 = Texto
        return this.ValueLength                ; devuelve la longitud del texto en caracteres + caracter de terminación nula
    }
    
    /*
        Establece datos binarios en la estructura actual. Los datos anteriores son reemplazados.
        Si «Length» es cero, indica que la estructura no posee el miembro «Value» (sin datos).
        Si «Length» es mayor que cero los datos en el puntero especificado son copiados.
    */
    SetBinary(Address, Length := 0)
    {
        If (Type(Address) != "Integer" || Address < 0)    ; comprueba que «Address» sea una dirección de memoria válida
            Throw Exception("Class VersionRes::SetBinary invalid parameter #1", -1, "Invalid address")

        If (Type(Length) != "Integer" || Length < 0)    ; comprueba que el valor de «Length» sea válido (tamaño de los datos binarios pasados en «Address»)
            Throw Exception("Class VersionRes::SetBinary invalid parameter #2", -1, "Invalid data size")

        this.ValueLength := Length   ; establece el tamaño de los datos (en bytes)
        this.Type        := 0        ; 0 = Datos binarios

        ObjSetCapacity(this, "Value", Length)   ; establece la capacidad de «Value» en «Length» bytes
        if (Length)    ; si el tamaño es 0 quiere decir que la estructura no almacena ningún valor
            DllCall("msvcrt.dll\memcpy", "UPtr", ObjGetAddress(this, "Value"), "UPtr", Address, "UPtr", Length, "Cdecl")    ; copia los datos a «Value»

        return Length
    }

    /*
        Recupera el nombre de la clave (una cadena).
    */
    GetKey()
    {
        return this.Key
    }

    /*
        Recupera los datos de la estructura actual.
        Si hay datos binarios o texto pero se especificó «Offset», devuelve la dirección de memoria + «Offset»; En caso contrario devuelve una cadena.
        «Offset» puede ser cero para recuperar siempre una dirección de memoria.
        «Length» se establece en el tamaño de los datos. Si es texto, el tamaño es en caracteres + el caracter de terminación nula.
        VS_FIXEDFILEINFO.dwFileVersionMS de la estructura VS_VERSIONINFO comienza en el «Offset» 8 y el miembro es de tipo DWORD (4 bytes).
    */
    GetValue(Offset := "", ByRef Length := 0)
    {
        Length := this.ValueLength  ; devuelve el tamaño de los datos (si es una cadena el tamaño es en caracteres + caracter de terminación nula)
        if (this.Type == 1)    ; 1 = Texto
            return Offset == "" ? this.Value : ObjGetAddress(this, "Value") + Offset
        return ObjGetAddress(this, "Value") + ( Offset == "" ? 0 : Offset )
    }

    /*
        Recupera el tamaño de los datos de la estructura actual. Si la estructura no posee el miembro «Value» (datos) devuelve cero.
        Si «Bytes» es verdadero devuelve el tamaño en bytes. Una cadena siempre incluye el caracter de terminación nula.
        Si los datos son binarios el tamaño siempre es en bytes. Si los datos es texto el tamaño es en caracteres + el caracter de terminación nula.
        Si «Padding» es verdadero añade el relleno automáticamente (si lo requiere).
    */
    GetValueLength(Bytes := FALSE, Padding := FALSE)
    {
        local size := this.ValueLength * (Bytes ? this.Type + 1 : 1)
        return Padding ? ( size + 3 ) & ~3 : size
    }

    /*
        Recupera el tipo de datos almacenados en la estructura actual.
    */
    GetType()
    {
        return this.Type    ; 0 = Datos binarios  |  1 = Texto
    }

    /*
        Recupera el tamaño total de la estructura actual.
        Si «Flag» es verdadero incluye también el tamaño de todas las sub-estructuras.
    */
    GetSize(Flag := 0)
    {
        local size := ( (6 + 2*StrLen(this.Key)+2 + 3) & ~3 ) + this.GetValueLength(1,1)
        loop ( Flag ? this.Children.Length() : 0 )
            size += this.Children[A_Index].GetSize(1)
        return size
    }

    /*
        Devuelve un puntero a un búfer con todas las estructuras escritas en él.
    */
    Alloc(ByRef Size)
    {
        this.Buffer := ""   ; crea una variable como búfer para almacenar los datos
        ObjSetCapacity(this, "Buffer", this.GetSize(1))    ; establece la capacidad de «Buffer» para almacenar todas las estructuras
        Size := this.Save(ObjGetAddress(this, "Buffer"))   ; copia todas las estructuras a «Buffer» y establece el tamaño total en «Size»
        return ObjGetAddress(this, "Buffer")   ; devuelve la dirección de memoria de «Buffer»
    }

    /*
        Escribe todos las estructuras en la dirección de memoria especificada.
    */
    Save(Address)
    {
        local Address2 := Address    ; crea una copia del puntero en la posición inicial para luego escribir el tamaño total
        NumPut(this.ValueLength, Address += 2, "UShort")    ; escribe el tamaño de la estructura actual
        NumPut(this.Type, Address += 2, "UShort")           ; escribe el tipo de datos que almacena la estructura actual

        Address := ( Address + 2 * StrPut(this.Key, Address += 2, "UTF-16") + 3 ) & ~3    ; escribe el nombre de la clave y avanza el puntero al inicio de los datos

        local size := this.ValueLength * (this.Type + 1)    ; almacena el tamaño de los datos (si es una cadena el tamaño es en caracteres + caracter de terminación nula)
        if (size)    ; si el tamaño es 0 quiere decir que la estructura no almacena ningún valor
            DllCall("msvcrt.dll\memcpy", "UPtr", Address, "UPtr", ObjGetAddress(this, "Value"), "UPtr", size, "Cdecl")    ; copia los datos en la posición actual (puntero al comienzo de los datos)
          , Address := ( Address + size + 3 ) & ~3    ; avanza el puntero al final de la estructura actual (para poder escribir la siguiente estructura, si la hay)
        
        loop ( this.Children.Length() )    ; busca todas las sub-estructuras en la estructura actual
            Address += this.Children[A_Index].Save(Address)    ; escribe la estructura actual (en el 'loop')

        NumPut(size := Address - Address2, Address2, "UShort")    ; escribe el tamaño total en «Address2» (y también lo almacena en «size»)
        return size    ; devuelve el tamaño total
    }
}
