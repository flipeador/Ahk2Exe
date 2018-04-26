;@Ahk2Exe-SetDescription     AutoHotkey Script Compilador
;@Ahk2Exe-SetFileVersion     1.0.0.0
;@Ahk2Exe-SetProductVersion  2.0.0.0
;@Ahk2Exe-SetName            Ahk2Exe
;@Ahk2Exe-SetCopyright       Copyright (c) 2004
;@Ahk2Exe-SetCompanyName     AutoHotkey
;@Ahk2Exe-SetOrigFilename    Ahk2Exe.ahk
;@Ahk2Exe-SetMainIcon        Ahk2Exe.ico





; =====================================================================================================================================================
; CONFIGURACIÓN DE INICIO
; =====================================================================================================================================================
#Warn
#NoTrayIcon
#SingleInstance Off
#InstallKeybdHook
#UseHook
#KeyHistory 0

ListLines FALSE
DetectHiddenWIndows "On"
SetRegView 64





; =====================================================================================================================================================
; INCLUDES
; =====================================================================================================================================================
#Include Lib\LinearGradient.ahk
#Include Lib\ComboBox.ahk
#Include Lib\RunAsAdmin.ahk
#Include Lib\TaskDialog.ahk
#Include Lib\GetDirParent.ahk

#Include Include\Compiler.ahk
#Include Include\ScriptParser.ahk





; =====================================================================================================================================================
; INICIO
; =====================================================================================================================================================
; inicializa variables globales y super-globales
A_ScriptName := "Ahk2Exe Compilador"
Title := "Ahk2Exe para AutoHotkey v" . A_AhkVersion . " | Script a EXE Conversor"

global LastError := FALSE    ; almacena el código del último error ocurrido
global       Gui := 0            ; almacena el objeto GUI de la ventana principal
global       Log := ""           ; almacena una serie de registros de una operación en contreto separados por "`n"
global   AhkPath := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
    global AhkDir := "", AhkLib := ""
    SplitPath(AhkPath,, AhkDir)
    AhkDir := DirExist(AhkDir) ? AhkDir : GetDirParent(A_ScriptDir)
    AhkLib := [DirExist(AhkDir . "\Lib") ? AhkDir . "\Lib" : "", DirExist(A_MyDocuments . "\AutoHotkey\Lib") ? A_MyDocuments . "\AutoHotkey\Lib" : ""]

; algunas comprobaciones de inicio
If (WinExist(Title))    ; comprobamos instancia (no permitir más de una instancia)
    WinShow(Title), WinActivate(Title), ExitApp()
If (A_PtrSize != 4)    ; arquitectura AHK (x32 necesario para el funcionamiento de waterctrl.dll)
    Util_Error("Error de arquitectura.`nDebe ejecutar el compilador con AutoHotkey 32-bit.",, TRUE)


; comprobamos permisos
If (!FileOpen("~tmp", "w"))
    If (!RunAsAdmin())
        Util_Error("Error de permisos.`nIntente ejecutar el compilador como Administrador.",, TRUE)
FileDelete(A_ScriptDir . "\~tmp"), A_IconHidden := A_IsCompiled



; cargamos la configuración, variables globales y otras cosas
Gdiplus := Util_GdiplusStartup()
Cfg := Util_LoadCfg()
VerInfo := {      CompanyName: ["CompanyName"]
           ,  FileDescription: ["FileDescription"]
           ,      Description: ["FileDescription"]
           ,      FileVersion: ["FileVersion"]
           ,     InternalName: ["InternalName"]
           ,   LegalCopyright: ["LegalCopyright"]
           ,        Copyright: ["LegalCopyright"]
           , OriginalFilename: ["OriginalFilename"]
           ,     OrigFilename: ["OriginalFilename"]
           ,      ProductName: ["ProductName"]
           ,   ProductVersion: ["ProductVersion"]
           ,          Version: ["FileVersion","ProductVersion"]
           ,             Name: ["ProductName","InternalName"]    }


; creamos la interfaz de usuario (GUI)
Gui := GuiCreate("-DPIScale -Resize -MaximizeBox +MinSize690x481 +E0x00000400", Title)
Gui.SetFont("s9", "Segoe UI")

Gui.AddText("x0 y0 w690 h100 vtbg BackgroundFFFFFF +E0x08000000")    ; fondo blanco para la parte superior
Gui.AddPic("x0 y415 w690 h76 vbbg +E0x08000000")    ; fondo de pié de página
    LinearGradient(Gui.Control["bbg"], [0xF0F0F0,0xCDCDCD],, 1)
Gui.AddText("x10 y5 w270 h92 vlogo")
    ; establecemos efecto de agua a la imagen logo AHK
    ; https://autohotkey.com/boards/viewtopic.php?t=3302
    hWaterCtrl := DllCall("Kernel32.dll\LoadLibraryW", "Str", "waterctrl.dll")
    hLogo := DllCall("User32.dll\LoadImageW", "Ptr", 0, "Str", "logo.bmp", "UInt", 0, "Int", 270, "Int", 92, "UInt", 0x2010)
    DllCall("waterctrl\enablewater", "Ptr", Gui.Hwnd, "Int", 0, "Int", 0, "Ptr", hLogo, "Int", 3, "Int", 20)
    DllCall("waterctrl\setwaterparent", "Ptr", Gui.Control["logo"].Hwnd)
    SetTimer(wctimer := () => DllCall("waterctrl\waterblob", "Int", Random(1, 270), "Int", Random(1, 92), "Int", Random(3, 12), "Int", Random(20, 75)), 2500)
Gui.AddLink("x300 y10 w370 h80 BackgroundFFFFFF c242424 vlnk", "©2004-2009 Chris Mallet`n©2008-2011 Steve Gray (lexikos)`n©2018-2018 Flipeador  (©2011-2013 fincs)`n<a href=`"https://autohotkey.com/`">https://autohotkey.com/</a>`nNota: La compilación no garantiza la protección del código fuente.")
Gui.AddText("x10 y110 w670 h2 +0x10")    ; separador
Gui.AddTab3("x10 y120 w670 h287 vtab", "General|Información de la versión|Registros")

Gui.Control["tab"].UseTab(1)
Gui.AddGroupBox("x20 y150 w650 h86", "Parámetros requeridos")
Gui.AddText("x30 y175 w120 h20 +0x200", "Fuente (archivo script)")
Gui.AddComboBox("x180 y175 w435 h22 vddlsrc R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastSrcList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Gui.Control["ddlsrc"].OnEvent("Change", () => Gui.Control["sb"].SetText("Cargando información de la versión..") (Gui.Control["bcompile"].Enabled := FALSE) SetTimer("Util_LoadVersionInfo", -1000))
Gui.AddButton("x620 y175 w40 h22 vbsrc", "•••")
    Gui.Control["bsrc"].OnEvent("Click", "Gui_SrcButton")
Gui.AddText("x30 y202 w120 h20 +0x200", "Destino (archivo exe)")
Gui.AddEdit("x180 y202 w435 h20 vedest Disabled")
Gui.AddButton("x620 y202 w40 h20 vbdest", "•••")
    Gui.Control["bdest"].OnEvent("Click", "Gui_DestButton")
Gui.AddGroupBox("x20 y245 w650 h83", "Parámetros opcionales")
Gui.AddText("x30 y266 w120 h20 +0x200", "Icono (archivo ico)")
Gui.AddComboBox("x180 y266 w435 h22 vddlico R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastIconList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlico"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlico"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
;Gui.AddButton("x565 y266 w53 h22 vbdico", "Defecto") ; w380
    ;Gui.Control["bdico"].OnEvent("Click", () => CB_SetText(Gui.Control["ddlico"], ""))
Gui.AddButton("x620 y266 w40 h22 vbico", "•••")
    Gui.Control["bico"].OnEvent("Click", "Gui_IcoButton")
Gui.AddText("x32 y293 w120 h22 +0x200", "Archivo base (bin)")
Gui.AddDDL("x180 y293 w405 h22 vddlbin R6 +0x400")
    CB_SetItemHeight(Gui.Control["ddlbin"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlbin"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Util_LoadBinFiles(Cfg.LastBinFile)
Gui.AddButton("x592 y293 w68 h22 vbrefbin", "Refrezcar")
    Gui.Control["brefbin"].OnEvent("Click", () => Util_LoadBinFiles(Cfg.LastBinFile))
Gui.AddGroupBox("x20 y336 w650 h61", "Compresión del archivo exe resultante")
Gui.AddText("x30 y357 w125 h22 +0x200", "Método de compresión")
Gui.AddDDL("x180 y357 w405 h22 vddlcomp R4 +0x400", "Sin compresión||UPX " . Util_UPXVer() . "- Ultimate Packer for eXecutables|MPRESS " . Util_MPRESSVer() . "- High-performance executable packer")
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Gui.Control["ddlcomp"].OnEvent("Change", () => Util_CheckCompress(Gui.Control["ddlcomp"].Text))
    Gui.Control["ddlcomp"].Choose(Cfg.Compression == 3 ? 3 : Cfg.Compression == 2 ? 2 : 1)
Button := Gui.AddButton("x592 y357 w68 h22", "Descargar")
    Button.OnEvent("Click", () => InStr(Gui.Control["ddlcomp"].Text, "UPX") ? Run("https://upx.github.io/") : InStr(Gui.Control["ddlcomp"].Text, "MPRESS") ? Run("http://www.matcode.com/mpress.htm") : 0)

Gui.Control["tab"].UseTab(2)
Gui.AddListView("x20 y150 w650 h250 vlvri -E0x200", "Nombre|Valor")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", Gui.Control["lvri"].Hwnd, "Str", "Explorer", "UPtr", 0, "UInt")
    Util_LoadVersionInfo()

Gui.Control["tab"].UseTab(3)
Gui.AddEdit("x20 y150 w650 h250 velog ReadOnly -E0x200")

Gui.Control["tab"].UseTab()
Gui.AddText("x0 y415 w690 h2 +0x10")
Gui.AddButton("x590 y426 w90 h22 vbclose", "Cerrar")
    Gui.Control["bclose"].OnEvent("Click", "ExitApp")
Gui.AddButton("x492 y426 w90 h22 vbcompile", "Compilar")
    Gui.Control["bcompile"].OnEvent("Click", "Gui_CompileButton")
Gui.AddButton("x10 y426 w90 h22 vbgit", "Ver en GitHub")
    Gui.Control["bgit"].OnEvent("Click", () => Run("https://github.com/flipeador/"))
Gui.AddButton("x110 y426 w90 h22 vbabout", "Acerca de (F1)")
    Gui.Control["babout"].OnEvent("Click", Func("WM_KEYDOWN").Bind(0x70, 0))
Gui.AddStatusBar("vsb +0x100", "Listo")

Gui.Show("w690 h481", "Ahk2Exe for AutoHotkey v2.0.0.0 | Script a EXE Conversor")
    Gui.OnEvent("Close", "ExitApp")
    Gui.OnEvent("Size", "Gui_Size")
    Gui.OnEvent("Escape", () => MsgBox("¿Esta seguro de que desea cerrar la aplicación?",, 0x2024) == "Yes" ? ExitApp() : 0)
    Gui.OnEvent("DropFiles", "Gui_DropFiles")


; registramos mensajes del sistema
OnMessage(0x100, "WM_KEYDOWN")    ; cuando se presiona una tecla que no sea del sistema (alt).
OnMessage(0x200, "WM_MOUSEMOVE")  ; cuando se mueve el cursor en la ventana
OnExit("_OnExit")    ; al terminar
Return





; =====================================================================================================================================================
; EVENTOS GUI
; =====================================================================================================================================================
Gui_Size(Gui, MinMax, W, H)
{
    If (MinMax == -1)
        Return
    ; no implementado aún
}

Gui_DropFiles(Gui, Ctrl, FileArray, X, Y)
{
    Util_GuiDisable("Leyendo archivos..")
    Gui.Control["ddlsrc"].Opt("-Redraw")
    Gui.Control["ddlico"].Opt("-Redraw")

    Local ArrListSrc := [], ArrListIco := []
    For Each, File in FileArray
    {
        If (DirExist(File))
            Loop Files, File . "\*", "F"
                Check(Gui, A_LoopFileFullPath)
        Else
            Check(Gui, File)
    }
    Loop (ObjLength(ArrListSrc))
        If (SubStr(ArrListSrc[A_Index], 1, 1))
            CB_Insert(Gui.Control["ddlsrc"], SubStr(ArrListSrc[A_Index], 2))
    Loop (ObjLength(ArrListIco))
        If (SubStr(ArrListIco[A_Index], 1, 1))
            CB_Insert(Gui.Control["ddlico"], SubStr(ArrListIco[A_Index], 2))

    If (ObjLength(ArrListSrc))
        CB_SetSelection(Gui.Control["ddlsrc"], CB_FindString(Gui.Control["ddlsrc"], SubStr(ArrListSrc[1], 2)))
    If (ObjLength(ArrListIco))
        CB_SetSelection(Gui.Control["ddlico"], CB_FindString(Gui.Control["ddlico"], SubStr(ArrListIco[1], 2)))

    Gui.Control["ddlsrc"].Opt("+Redraw")
    Gui.Control["ddlico"].Opt("+Redraw")
    Util_GuiEnable()

    Check(Gui, File, Ext := "")
    {
        SplitPath(File,,, Ext)
        If (Ext = "ahk")
            ArrListSrc.Push((CB_FindString(Gui.Control["ddlsrc"], File) == -1) . File)
        Else If (Ext = "ico")
            ArrListIco.Push((CB_FindString(Gui.Control["ddlico"], File) == -1) . File)
    }

    Util_LoadVersionInfo()
}

Gui_SrcButton(Btn)
{
    Global Cfg
    Util_GuiDisable("Mostrando diálogo para seleccionar archivo fuente AHK..")
    Local File := FileSelect("M3", DirExist(Cfg.LastScriptDir) ? Cfg.LastScriptDir : "", "Seleccionar archivo fuente AHK - Ahk2Exe", "*.ahk")
        ,  Ext := "", Dir := "", Index := 0, Added := FALSE, Dir2 := ""
    Loop Parse, File, "`n"
    {
        If (A_Index == 1)
        {
            Dir2 := RTrim(A_LoopField, "\")
            Continue
        }
        SplitPath(Dir2 . "\" . A_LoopField,, Dir, Ext)
        If (Ext = "ahk" && (Index:=CB_Insert(Btn.Gui.Control["ddlsrc"], Dir2 . "\" . A_LoopField,, 0)) != -1 && !Added)
            CB_SetSelection(Btn.Gui.Control["ddlsrc"], Index), Added := TRUE, Cfg.LastScriptDir := Dir
    }
    Util_LoadVersionInfo()
    Util_GuiEnable()
}

Gui_IcoButton(Btn)
{
    Global Cfg
    Util_GuiDisable("Mostrando diálogo para seleccionar archivo icono..")
    Local File := FileSelect("M3", DirExist(Cfg.LastIconDir) ? Cfg.LastIconDir : "", "Seleccionar archivo icono - Ahk2Exe", "*.ico")
        ,  Ext := "", Dir := "", Index := 0, Added := FALSE, Dir2 := ""
    Loop Parse, File, "`n"
    {
        If (A_Index == 1)
        {
            Dir2 := RTrim(A_LoopField, "\")
            Continue
        }
        SplitPath(Dir2 . "\" . A_LoopField,, Dir, Ext)
        If (Ext = "ico" && (Index:=CB_Insert(Btn.Gui.Control["ddlico"], Dir2 . "\" . A_LoopField,, 0)) != -1 && !Added)
            CB_SetSelection(Btn.Gui.Control["ddlico"], Index), Added := TRUE, Cfg.LastIconDir := Dir
    }
    Util_LoadVersionInfo()
    Util_GuiEnable()
}

Gui_DestButton(Btn)
{
    Global Cfg
    Util_GuiDisable("Mostrando diálogo para seleccionar archivo de destino..")
    Local File := FileSelect("S26", DirExist(Cfg.LastExeDir) ? Cfg.LastExeDir : "", "Seleccionar archivo EXE destino - Ahk2Exe", "*.exe")
    If (File != "")
    {
        SplitPath(File,, Dir,, FNNE)
        Btn.Gui.Control["edest"].Text := RTrim(Dir, "\") . "\" . FNNE . ".exe"
    }
    Util_GuiEnable()
}

Gui_CompileButton(Btn)
{
    Util_GuiDisable("Compilando..")

    Local Script := CB_GetText(Btn.Gui.Control["ddlsrc"], CB_GetSelection(Btn.Gui.Control["ddlsrc"]))
        ,   Code := PreprocessScript(Script)

    If (Code != 0)
    {
        If (AhkCompile(Code))
            Log .= "----------------------------------`nLa compilación finalizó con éxito."
        Else
            Log .= "----------------------------------`nHa ocurrido un error con la compilación."
    }

    Gui.Control["elog"].Text := StrReplace(Log, "`n", "`r`n")
    Util_GuiEnable()
}





; =====================================================================================================================================================
; EVENTOS DEL SISTEMA
; =====================================================================================================================================================
WM_KEYDOWN(VKCode, lParam)
{
    If (VKCode == 0x70)    ; VK_F1
    {
        Gui.Control["sb"].SetText("Mostrando Acerca de.. (F1)")
        TaskDialog([Gui.Hwnd,0xFFFD], [Gui.Title,"Acerca de.."], ["Ahk2Exe - Script to EXE Converter`n-----------------------------------`n`n"
                                                               . "Original version:`n"
                                                               . "Copyright ©1999-2003 Jonathan Bennett & AutoIt Team`n"
                                                               . "Copyright ©2004-2009 Chris Mallet`n"
                                                               . "Copyright ©2008-2011 Steve Gray (Lexikos)`n`n"
                                                               . "Script rewrite:`n"
                                                               . "Copyright ©2011-2013 fincs`n"
                                                               . "Copyright ©2018-2018 Flipeador"
                                                                   , "flipeador@gmail.com"] )
        Gui.Control["sb"].SetText("Listo")
    }
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646280(v=vs.85).aspx





WM_MOUSEMOVE(VKCode, Coords)
{
    Static LnkClr := 0

    MouseGetPos(,,, ControlId, 2)
    If (!LnkClr && Gui.Control["lnk"].Hwnd == ControlId)
        Gui.Control["lnk"].SetFont("c1A1AFF"), LnkClr := 1
    Else If (LnkClr && Gui.Control["lnk"].Hwnd != ControlId)
        Gui.Control["lnk"].SetFont("c242424"), LnkClr := 0
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms645616(v=vs.85).aspx





_OnExit(ExitReason, ExitCode)
{
    Global Gdiplus, wctimer

    DllCall("User32.dll\AnimateWindow", "Ptr", Gui.HWnd, "UInt", 350, "UInt", 0x00080000|0x00010000)    ;Gui.Show("Hide")
    A_IconHidden := TRUE

    SetTimer(wctimer, "Delete")
    DllCall("waterctrl.dll\flattenwater")
    DllCall("waterctrl.dll\disablewater")
    ;DllCall("Kernel32.dll\FreeLibrary", "Ptr", hModule)
    ;DllCall("Gdi32.dll\DeleteObject", "Ptr", hBitmap)

    Util_SaveCfg()
    Util_GdiplusShutdown(Gdiplus)

    Gui.Destroy()

    Return 0    ; Exit
}





; =====================================================================================================================================================
; FUNCIONES
; =====================================================================================================================================================
Util_Error(Message, ExpandedInfo := "", Exit := FALSE)
{
    Global Title
    Local OwnerID := [IsObject(Gui) ? Gui.Hwnd : 0, 0xFFFE]
        ,  _Title := [Title, "Ha ocurrido un error y las operaciónes an sido abortadas."]
    TaskDialog(OwnerID, _Title, ExpandedInfo == "" ? Message : [Message,ExpandedInfo])
    LastError := 1
    If (Exit)
        ExitApp
}

Util_LoadCfg()
{
    Local Cfg := { LastScriptDir: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe", "LastScriptDir")
                 ,    LastExeDir: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",    "LastExeDir")
                 ,   LastIconDir: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",    "LastIconDir")
                 ,   LastSrcList: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",   "LastSrcList")
                 ,  LastIconList: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastIconList")
                 ,   LastBinFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",   "LastBinFile")
                 ,   Compression: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",   "Compression") }
    Return Cfg
}

Util_SaveCfg()
{
    Global Cfg
    Cfg.LastBinFile := Gui.Control["ddlbin"].Text == "" ? Cfg.LastBinFile : SubStr(Gui.Control["ddlbin"].Text, InStr(Gui.Control["ddlbin"].Text, A_Space)+1) . ".bin"
    Cfg.Compression := Gui.Control["ddlcomp"].Value

    Cfg.LastSrcList := ""
    Loop (CB_GetCount(Gui.Control["ddlsrc"]))
        If (A_Index < 11)
            Cfg.LastSrcList .= CB_GetText(Gui.Control["ddlsrc"], A_Index-1) . "`r`n"

    Cfg.LastIconList := ""
    Loop (CB_GetCount(Gui.Control["ddlico"]))
        If (A_Index < 11)
            Cfg.LastIconList .= CB_GetText(Gui.Control["ddlico"], A_Index-1) . "`r`n"

    RegWrite(Cfg.LastScriptDir,        "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastScriptDir")
    RegWrite(Cfg.LastExeDir   ,        "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe",    "LastExeDir")
    RegWrite(Cfg.LastIconDir  ,        "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe",   "LastIconDir")
    RegWrite(Cfg.LastSrcList  , "REG_EXPAND_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe",   "LastSrcList")
    RegWrite(Cfg.LastIconList , "REG_EXPAND_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe",  "LastIconList")
    RegWrite(Cfg.LastBinFile  ,        "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe",   "LastBinFile")
    RegWrite(Cfg.Compression  ,     "REG_DWORD", "HKCU\Software\AutoHotkey\Ahk2Exe",   "Compression")
}

Util_GdiplusStartup()
{
    Local Gdiplus := {}
    If (!(Gdiplus.hModule := DllCall("Kernel32.dll\LoadLibraryW", "Str", "gdiplus.dll", "Ptr")))
        Util_Error("LoadLibrary Gdiplus Error #" . A_LastError,, TRUE)

    Local GdiplusStartupInput := "", pToken := 0
    NumPut(VarSetCapacity(GdiplusStartupInput, 16, 0) * 0 + 1, &GdiplusStartupInput, "UInt")    ; GdiplusStartupInput.GdiplusVersion = 1
    Local Ret := DllCall("Gdiplus.dll\GdiplusStartup", "UPtrP", pToken, "UPtr", &GdiplusStartupInput, "UPtr", 0, "UInt")
    If (!pToken)
        Util_Error("Gdiplus Error #" . Ret . ".",, TRUE)
    Gdiplus.pToken := pToken

    Return Gdiplus
}

Util_GdiplusShutdown(Gdiplus)
{
    DllCall("Gdiplus.dll\GdiplusShutdown", "UPtr", Gdiplus.pToken)
    DllCall("Kernel32.dll\FreeLibrary", "Ptr", Gdiplus.hModule)
}

Util_GuiDisable(Text)
{
    WinSetEnabled(FALSE, "ahk_id" . Gui.Hwnd)
    Gui.Control["sb"].SetText(Text)
}

Util_GuiEnable()
{
    WinSetEnabled(TRUE, "ahk_id" . Gui.Hwnd)
    Gui.Control["sb"].SetText("Listo")
    WinSetAlwaysOnTop(TRUE, "ahk_id" . Gui.Hwnd)
    WinSetAlwaysOnTop(FALSE, "ahk_id" . Gui.Hwnd)
    Gui.Show()
}

Util_LoadBinFiles(Default)
{
    Gui.Control["ddlbin"].Delete()
    Loop Files, "*.bin", "F"
    {
        Gui.Control["ddlbin"].Add("v" . FileGetVersion(A_LoopFileFullPath) . A_Space . SubStr(A_LoopFileName, 1, -4))
        If (A_LoopFileName = Default)
            Gui.Control["ddlbin"].Choose(A_Index)
    }
}

Util_CheckBinFile(Name)
{
    Local BinFile := ""
    Return FileExist(BinFile := SubStr(Name, InStr(Name, A_Space)+1) . ".bin") ? BinFile : FALSE
}

Util_CheckCompress(Name)
{
    Local File := InStr(Name, "UPX") ? "upx.exe" : InStr(Name, "MPRESS") ? "mpress.exe" : ""
    
    If (File != "")
    {
        If (FileExist(File))
            Return A_ScriptDir . "\" . File

        If (FileExist(A_WinDir . "\" . File))
            Return A_WinDir . "\" . File

        If (FileExist(A_WinDir . "\System32\" . File))
            Return A_WinDir . "\System32\" . File

        MsgBox("No se a encontrado " . File . ".`nHaga clic en Descargar para ir a la página oficial de descarga.`nEl archivo debe estar en el mismo directorio que el compilador o en la carpeta del sistema.",, 0x2010)
    }

    Return FALSE
}

Util_UPXVer()
{
    If (FileExist("upx.exe"))
        Return "(" . FileGetVersion("upx.exe") . ") "
    If (FileExist(A_WinDir . "\upx.exe"))
        Return "(" . FileGetVersion(A_WinDir . "\upx.exe") . ") "
    If (FileExist(A_WinDir . "\System32\upx.exe"))
        Return "(" . FileGetVersion(A_WinDir . "\System32\upx.exe") . ") "
    Return ""
}

Util_MPRESSVer()
{
    If (FileExist("mpress.exe"))
        Return "(" . FileGetVersion("mpress.exe") . ") "
    If (FileExist(A_WinDir . "\mpress.exe"))
        Return "(" . FileGetVersion(A_WinDir . "\mpress.exe") . ") "
    If (FileExist(A_WinDir . "\System32\mpress.exe"))
        Return "(" . FileGetVersion(A_WinDir . "\System32\mpress.exe") . ") "
    Return ""
}

Util_LoadVersionInfo()
{
    try Gui.Control["sb"].SetText("Cargando información de la versión..")
    try Gui.Control["bcompile"].Enabled := FALSE
    Local SrcFile := CB_GetText(Gui.Control["ddlsrc"], CB_GetSelection(Gui.Control["ddlsrc"]))
        , VerInfo := ParseVersionInfo(SrcFile)

    Gui.Control["lvri"].Delete()
    Loop Parse, "Comments|CompanyName|FileDescription|FileVersion|InternalName|LegalCopyright|OriginalFilename|ProductName|ProductVersion", "|"
        Gui.Control["lvri"].Add(, A_LoopField, IsObject(VerInfo) && ObjHasKey(VerInfo, A_LoopField) ? VerInfo[A_LoopField] : "")
    Gui.Control["lvri"].ModifyCol(1, "AutoHdr")
    try Gui.Control["bcompile"].Enabled := TRUE
    try Gui.Control["sb"].SetText("Listo")
}

Util_GetFullPathName(Path)
{
    ;If (!InStr(Path, ".."))
    ;    Return InStr(Path, ":") ? Path : A_WorkingDir . "\" . Path

    VarSetCapacity(Buffer, 2002, 0)
    DllCall("Kernel32.dll\GetFullPathNameW", "UPtr", &Path, "UInt", 1000, "Str", Buffer, "UPtr", 0, "UInt")
    Return Buffer
}
