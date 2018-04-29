/* 
    Crea un mapa de bits con degradado lineal para un control Picture.
    Parámetros:
        Pic:
            El objeto control Picture.
        Colors:
            Un Array con los colores RGB a utilizar. Debe especificar por lo menos dos colores.
        Positions:
            Un Array que contiene las posiciones relativas de los valores de color como valores de coma flotante. 0.0 es el inicio y 1.0 es el finál.
            Por defecto los colores se dividen automáticamente teniendo en cuenta la cantidad de colores especificados.
        Direction:
            Dirección de los colores. 0 hirizontal. 1 vertical. 2 diagonal (sup-iz inf-der). 3 diagonal (sup-der inf-iz).
        GammaCorrection:
            TRUE para activar la corrección de gama. FALSE para desactivar, este es el valor por defecto.
        BrushWidth:
            El ancho del pincel, en píxeles. Por defecto se establece en el ancho del control. Este valor debe estar comprendido entre 1 y el ancho del control inclusive.
        BrushHeight:
            El alto del pincel, en píxeles. Por defecto se establece en el alto del control. Este valor debe estar comprendido entre 1 y el alto del control inclusive.
    Return:
        La función no devuelve ningún valor, en caso de error envía una Excepción con detalles del problema.
    Ejemplo:
        LinearGradient((Gui:=GuiCreate()).AddPic("x0 y0 w500 h350"), [0xFF0000,0xFFFF00,0x00FF00,0x00FFFF,0x0000FF]), Gui.Show("w500 h350")
*/
LinearGradient(Pic, Colors, Positions := "", Direction := 0, GammaCorrection := FALSE, BrushWidth := 0, BrushHeight := 0)
{
    If (!IsObject(Pic) || SubStr(Type(Pic), 1, 3) != "Gui" || Pic.Type != "Pic")
        Throw Exception("Function LinearGradient invalid parameter #1.",, IsObject(Pic) ? "Type " . Type(Pic) : "!Object")

    If (!IsObject(Colors) || ObjLength(Colors) == 0)
        Throw Exception("Function LinearGradient invalid parameter #2",, IsObject(Colors) ? "!ObjLength" : "!Object")

    If (!IsObject(Positions))
    {
        Positions := [0.0]
        Loop (ObjLength(Colors) - 2)
            Positions.Push((1.0 / (ObjLength(Colors) - 1)) * A_Index)
        Positions.Push(1.0)
    }
    If (ObjLength(Colors) != ObjLength(Positions))
        Throw Exception("Function LinearGradient invalid parameter #3",, "ObjLen#1(" . ObjLength(Colors) . ")!=ObjLen#2(" . ObjLength(Positions) . ")")

    If (Direction != 0 && Direction != 1 && Direction != 2 && Direction != 3)
        Throw Exception("Function LinearGradient invalid parameter #4",, SubStr(Direction, 1, 50))

    Local hGdiplus := 0, SI := "", pToken := 0
    If (!DllCall("Kernel32.dll\GetModuleHandleW", "Str", "Gdiplus.dll", "Ptr"))
        hGdiplus := DllCall("Kernel32.dll\LoadLibraryW", "Str", "Gdiplus.dll", "Ptr")
    VarSetCapacity(SI, 16, 0), Numput(1, SI, "UInt")
    DllCall("Gdiplus.dll\GdiplusStartup", "PtrP", pToken, "UPtr", &SI, "Ptr", 0)

    Local pos := Pic.Pos, pBitmap := 0, pGraphics := 0
    DllCall("Gdiplus.dll\GdipCreateBitmapFromScan0", "Int", pos.w, "Int", pos.h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "PtrP", pBitmap)
    DllCall("Gdiplus.dll\GdipGetImageGraphicsContext", "Ptr", pBitmap, "PtrP", pGraphics)

    Local RECTF := 0
    VarSetCapacity(RECTF, 16, 0)
    NumPut( BrushWidth < 1 ||  BrushWidth > pos.w ? pos.w :  BrushWidth, &RECTF +  8, "Float")
    NumPut(BrushHeight < 1 || BrushHeight > pos.h ? pos.h : BrushHeight, &RECTF + 12, "Float")

    Local pBrush := 0
    DllCall("Gdiplus.dll\GdipCreateLineBrushFromRect", "UPtr", &RECTF, "Int", 0, "Int", 0, "Int", Direction, "Int", 0, "PtrP", pBrush)
    DllCall("Gdiplus.dll\GdipSetLineGammaCorrection", "Ptr", pBrush, "Int", GammaCorrection)

    Local _COLORS := ""
    Loop (VarSetCapacity(_COLORS, ObjLength(Colors) * 4, 0) // 4)
        NumPut(Colors[A_Index] | 0xFF000000, &_COLORS + 4 * (A_Index - 1), "UInt")

    Local _POSITIONS := ""
    Loop (VarSetCapacity(_POSITIONS, ObjLength(Positions) * 4, 0) // 4)
        NumPut(Positions[A_Index], &_POSITIONS + 4 * (A_Index - 1), "Float")

    DllCall("Gdiplus.dll\GdipSetLinePresetBlend", "Ptr", pBrush, "UPtr", &_COLORS, "UPtr", &_POSITIONS, "Int", ObjLength(Colors))
    DllCall("Gdiplus.dll\GdipFillRectangle", "Ptr", pGraphics, "Ptr", pBrush, "Float", 0, "Float", 0, "Float", pos.w, "Float", pos.h)

    Local hBitmap := 0
    DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "PtrP", hBitmap, "Int", 0x00FFFFFF)

    DllCall("Gdiplus.dll\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("Gdiplus.dll\GdipDeleteBrush", "Ptr", pBrush)
    DllCall("Gdiplus.dll\GdipDeleteGraphics", "Ptr", pGraphics)

    DllCall("Gdiplus.dll\GdiplusShutdown", "Ptr", pToken)
    If (hGdiplus)
        DllCall("Kernel32.dll\FreeLibrary", "Ptr", hGdiplus)

    ; STM_SETIMAGE message
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb760782(v=vs.85).aspx
    Pic.Value := "HBITMAP:" . hBitmap . " *w0 *h0"
} ; https://autohotkey.com/boards/viewtopic.php?f=6&t=3593&p=18573&hilit=LinearGradient#p18573
