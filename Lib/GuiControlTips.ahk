/*
    Gui := GuiCreate("+AlwaysOnTop")
        CTT := new GuiControlTips(Gui)
        CTT.SetTitle("GuiControlTips", 1)
        CTT.SetFont("Italic", "Courier New")
    Button := Gui.AddButton("w200", "Button")
        CTT.Attach(Button, "My Button")
    Text := Gui.AddText("w200 Border", "Text!`nLine 2 ...")
        CTT.Attach(Text, "My Text`nMultiline ...")
    DDL := Gui.AddDDL("w200 R3", "Item 1||Item 2|Item 3")
        CTT.Attach(DDL, "My DDL")
    Gui.Show(), Gui.OnEvent("Close", "ExitApp")
    F1:: CTT.Suspend(-1)
*/





/*
    Crea ToolTips personalizados para controles. Permite modificar el texto, título, ícono y fuente.
    CREDITS: JUSTME - http://ahkscript.org/boards/viewtopic.php?f=6&t=2598.
*/
class GuiControlTips
{
    ; ===================================================================================================================
    ; INSTANCE VARIABLES
    ; ===================================================================================================================
    hToolTip    := 0                        ; El identificador de la ventana ToolTip                               
    Gui         := 0                        ; El objeto GUI
    Controls    := {}                       ; Objeto que almacena todos los controles registrados e información
    IsSuspended := FALSE                    ; Determina si el ToolTip esta desactivado
    
    
    ; ===================================================================================================================
    ; CONSTRUCTOR
    ; ===================================================================================================================
    /*
        Parámetros:
            Gui:
                El objeto GUI.
            Initial:
                El tiempo, en milisegundos, que deberá pasar para que el ToolTip se muestre.
            AutoPop:
                El tiempo, en milisegundos, que el ToolTip permanece visible si el cursor está dentro del rectángulo delimitador del control.
            ReShow:
                El tiempo, en milisegundos, que requiere el ToolTip posterior para aparecer cuando el cursor se mueve de un control a otro.
    */
    __New(Gui, Initial := 1500, AutoPop := 5000, ReShow := 1000)
    {
        If (Type(Gui) != "Gui")
            Throw Exception("Class GuiControlTips invalid parameter #1",, "Type(Gui)=" . Type(Gui))
        this.Gui := Gui

        ; creamos la ventana tooltips_class32
        ; Tooltip Control Messages: https://msdn.microsoft.com/en-us/library/windows/desktop/ff486069(v=vs.85).aspx
        ; CreateWindowEx function: https://msdn.microsoft.com/en-us/library/windows/desktop/ms632680(v=vs.85).aspx
        this.hToolTip := DllCall("User32.dll\CreateWindowEx", "UInt", 8, "Str", "tooltips_class32", "Ptr", 0, "UInt", 0x80000002, "Int", 0x80000000, "Int", 0x80000000, "Int", 0x80000000, "Int", 0x80000000, "Ptr", Gui.Hwnd, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
        If (!this.hToolTip)
            Throw Exception("Class GuiControlTips WINAPI::CreateWindowEx function error")

        ; TTM_SETMAXTIPWIDTH message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760408(v=vs.85).aspx
        DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0418, "Ptr", 0, "Int", 0)
        this.SetDelayTimes(Initial, AutoPop, ReShow)
    }


    ; ===================================================================================================================
    ; DESTRUCTOR
    ; ===================================================================================================================
    __Delete()
    {
        Local hFont := DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0031, "Ptr", 0, "Ptr", 0, "Ptr")
        If (hFont)
            DllCall("Gdi32.dll\DeleteObject", "Ptr", hFont)
        
        DllCall("User32.dll\DestroyWindow", "Ptr", this.hToolTip)
    } ;https://msdn.microsoft.com/en-us/library/windows/desktop/ms632682(v=vs.85).aspx
   
   
    ; ===================================================================================================================
    ; PRIVATE METHODS
    ; ===================================================================================================================
    TOOLINFO(ByRef TOOLINFO, Flags, Control, ByRef Text := "")
    {
        ; TOOLINFO structure
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760256(v=vs.85).aspx
        NumPut(VarSetCapacity(TOOLINFO, 24 + 6*A_PtrSize, 0), &TOOLINFO, "UInt")
        NumPut(Flags, &TOOLINFO + 4, "UInt")
        NumPut(this.Gui.Hwnd, &TOOLINFO + 8, "Ptr")
        NumPut(Control, &TOOLINFO + 8 + A_PtrSize, "Ptr")
        NumPut(&Text, &TOOLINFO + 8 + 3*A_PtrSize + 16)
    }

    ValidateControl(ByRef Control, InList := FALSE)
    {
        Control := IsObject(Control) ? Control.Hwnd : Control
        If (!(Control is "Integer") || !DllCall("User32.dll\IsWindow", "Ptr", Control:=Integer(Control)))
            Return Exception("Class GuiControlTips invalid control")

        If (InList && !ObjHasKey(this.Controls, Control))
            Return Exception("Class GuiControlTips unregistered control")

        Return ObjHasKey(this.Controls, Control)
    }


    ; ===================================================================================================================
    ; PUBLIC METHODS
    ; ===================================================================================================================
    /*
        Añadir un ToolTip al control especificado. Si el control ya tiene un ToolTip asignado, se actualiza con la información especificada.
        Parámetros:
            Control:
                El objeto Gui Control o el identificador de un control.
            Text:
                Una cadena con el texto del ToolTip.
            Center:
                Determina si el ToolTip deberá aparecer centrado con respecto al control.
    */
    Attach(Control, Text, Center := FALSE)
    {
        Local Exception := ""
        If (IsObject(Exception := this.ValidateControl(Control)))
            Throw Exception
        If (Exception)
            Return this.Update(Control, Text)

        If (WinGetClass("ahk_id" . Control) == "Static")
            WinSetStyle("+0x100", "ahk_id" . Control)

        Local TOOLINFO := ""
        this.TOOLINFO(TOOLINFO, 0x0001|0x0010|(Center?0x0002:0), Control, Text)

        ; TTM_ADDTOOL message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760338(v=vs.85).aspx
        DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0432, "Ptr", 0, "UPtr", &TOOLINFO)
        ObjRawSet(this.Controls, Control, 0)
    }
    
    /*
        Remueve el ToolTip asignado al control especificado.
        Parámetros:
            Control:
                El objeto Gui Control o el identificador de un control.
    */
    Detach(Control)
    {
        Local Exception := ""
        If (IsObject(Exception := this.ValidateControl(Control)))
            Throw Exception
        If (!Exception)
            Return

        If (WinGetClass("ahk_id" . Control) == "Static")
            WinSetStyle("-0x100", "ahk_id" . Control)

        Local TOOLINFO := ""
        this.TOOLINFO(TOOLINFO, 0x0001|0x0010, Control)

        ; TTM_DELTOOL message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760365(v=vs.85).aspx
        If (!DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0433, "Ptr", 0, "UPtr", &TOOLINFO))
            Throw Exception("Class GuiControlTips TTM_DELTOOL message error")
        ObjDelete(this.Controls, Control)
    }

    /*
        Cambia el texto del ToolTip en el control especificado.
        Parámetros:
            Control:
                El objeto Gui Control o el identificador de un control.
            Text:
                Una cadena con el texto a mostrar.
    */
    Update(Control, Text)
    {
        Local Exception := ""
        If (IsObject(Exception := this.ValidateControl(Control, 1)))
            Throw Exception

        Local TOOLINFO := ""
        this.TOOLINFO(TOOLINFO, 0x0001|0x0010, Control, Text)

        ; TTM_UPDATETIPTEXT message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760427(v=vs.85).aspx
        DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0439, "Ptr", 0, "UPtr", &TOOLINFO)
    }
    
    /*
        Suspende, reanuda o alterna el estado actual de todos los ToolTips.
        Parámetros:
            Mode:
                Debe espesificar uno de los siguientes valores.
                     1 = Suspende todos los ToolTips.
                     0 = Reanuda todos los ToolTips.
                    -1 = Alterna el estado actual.
    */
    Suspend(Mode := TRUE)
    {
        ; TTM_ACTIVATE message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760326(v=vs.85).aspx
        Mode := Mode == -1 ? !(this.IsSuspended := !this.IsSuspended) : !(this.IsSuspended := !!Mode)
        DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0401, "Int", Mode, "Ptr", 0)
    }
    
    /*
        Establece los tiempos de retraso de todos los ToolTips.
        Parámetros:
            Initial:
                El tiempo, en milisegundos, que deberá pasar para que el ToolTip se muestre.
            AutoPop:
                El tiempo, en milisegundos, que el ToolTip permanece visible si el cursor está dentro del rectángulo delimitador del control.
            ReShow:
                El tiempo, en milisegundos, que requiere el ToolTip posterior para aparecer cuando el cursor se mueve de un control a otro.
        Notas:
            Si se especifica una cadena vacía el valor actual no es modificado.
    */
    SetDelayTimes(Initial := "", AutoPop := "", ReShow := "")
    {
        ; TTM_SETDELAYTIME message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760404(v=vs.85).aspx
        If (Initial != "")
            DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0403, "Ptr", 3, "Ptr", Initial)
        If (AutoPop != "")
            DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0403, "Ptr", 2, "Ptr", AutoPop)
        If (ReShow != "")
            DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0403, "Ptr", 1 , "Ptr", ReShow)
    }
    
    /*
        Recupera los tiempos de retraso de todos los ToolTips.
        Return:
            Devuelve un objeto con las claves Initial, AutoPop y ReShow. Ver el método SetDelayTimes para la descripción de las claves.
    */
    GetDelayTimes()
    {
        ; TTM_GETDELAYTIME message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760390(v=vs.85).aspx
        Return { Initial:  DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0415, "UInt", 3, "Ptr", 0)
               , AutoPop:  DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0415, "UInt", 2, "Ptr", 0)
               ,  ReShow:  DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0415, "UInt", 1, "Ptr", 0) }
    }

    /*
        Cambia el título y el icono.
        Parámetros:
            Title:
                El nuevo título. Si este parámetro es una cadena vacía, el título es removido.
            Icon:
                Un valor que identifica al icono a mostrar. Este parámetro puede ser un identificador a un icono (HICON).
                    0 (TTI_NONE)          = Sin icono.
                    1 (TTI_INFO)          = Icono de información pequeño.
                    4 (TTI_INFO_LARGE)    = Icono de información grande.
                    2 (TTI_WARNING)       = Icono de advertencia pequeño.
                    5 (TTI_WARNING_LARGE) = Icono de advertencia grande.
                    3 (TTI_ERROR)         = Icono de error pequeño.
                    6 (TTI_ERROR_LARGE)   = Icono de error grande.
    */
    SetTitle(Title, Icon := 0)
    {
        ; TTM_SETTITLE message
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760414(v=vs.85).aspx
        DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0421, "Ptr", Icon, "UPtr", &Title)
    }

    /*
        Cambia la fuente del texto de este ToolTip.
        Parámetros:
            Options: Las opciones de la fuente. Debe especificar una cadena con una o más de las siguientes palabras claves:
                sN                                 = El tamaño del texto. Por defecto es 9.
                qN                                 = La calidad de la fuente. Por defecto es 5 (ClearType).
                wN                                 = El peso del texto. 400 es normal, 600 es semi-negrita, 700 es negrita. Por defecto es 400.
                Italic / Underline / Strike / Bold = El estilo de la fuente. Cursiva / Subrayado / Tachado / Negrita.
            FontName: El nombre de la fuente. Si este parámetro es una cadena vacía, la fuente actual es removida y se reestablece a la fuente original.
        Nota: Si especifica el peso del texto (wN), "Bold" no tiene efecto; ya que "Bold" hace que wN sea 700 (negrita).
    */
    SetFont(Options := "", FontName := "Segoe UI")
    {
        Local hFont := DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0031, "Ptr", 0, "Ptr", 0, "Ptr")
        If (hFont)
            DllCall("Gdi32.dll\DeleteObject", "Ptr", hFont)

        If (FontName == "")
            Return DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0030, "Ptr", 0, "Int", TRUE)    ; WM_SETFONT = 0x0030

        Local hDC := DllCall("Gdi32.dll\CreateDCW", "Str", "DISPLAY", "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
              , R := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 90)
        DllCall("Gdi32.dll\DeleteDC", "Ptr", hDC)
            
        Local         t := ""
            ,      Size := RegExMatch(Options, "i)s([\-\d\.]+)(p*)", t) ? t[1] : 10
            ,    Height := Round((Abs(Size) * R) / 72) * -1
            ,   Quality := RegExMatch(Options, "i)q([\-\d\.]+)(p*)", t) ? t[1] : 5
            ,    Weight := RegExMatch(Options, "i)w([\-\d\.]+)(p*)", t) ? t[1] : (InStr(Options, "Bold") ? 700 : 400)
            ,    Italic := !!InStr(Options, "Italic")
            , Underline := !!InStr(Options, "Underline")
            ,    Strike := !!InStr(Options, "Strike")
            
        hFont := DllCall("Gdi32.dll\CreateFontW", "Int", Height, "Int", 0, "Int", 0, "Int", 0, "Int", Weight, "UInt", Italic, "UInt", Underline, "UInt", Strike, "UInt", 1, "UInt", 4, "UInt", 0, "UInt", Quality, "UInt", 0, "UPtr", &FontName, "Ptr")
        Return DllCall("User32.dll\SendMessageW", "Ptr", this.hToolTip, "UInt", 0x0030, "Ptr", hFont, "Int", TRUE)
    }
}
