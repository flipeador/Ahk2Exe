;@Ahk2Exe-SetDescription     AutoHotkey Script Compilador
;@Ahk2Exe-SetFileVersion     1.0.0.0
;@Ahk2Exe-SetProductVersion  2.0.0.0
;@Ahk2Exe-SetName            Ahk2Exe
;@Ahk2Exe-SetCopyright       Copyright (c) 2004
;@Ahk2Exe-SetCompanyName     AutoHotkey
;@Ahk2Exe-SetOrigFilename    Ahk2Exe.ahk
;@Ahk2Exe-SetMainIcon        Ahk2Exe.ico

;@Ahk2Exe-AddResource logo.bmp
;@Ahk2Exe-AddResource waterctrl.dll





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
#Include Lib\ImageButton.ahk
#Include Lib\ComboBox.ahk
#Include Lib\RunAsAdmin.ahk
#Include Lib\TaskDialog.ahk
#Include Lib\DirGetParent.ahk
#Include Lib\SaveFile.ahk
#Include Lib\ChooseFile.ahk
#Include Lib\GuiControlTips.ahk
#Include Lib\GetFullPathName.ahk

#Include Include\Compiler.ahk
#Include Include\ScriptParser.ahk
#Include Include\Resources.ahk
#Include Include\CommandLine.ahk





; =====================================================================================================================================================
; INICIO
; =====================================================================================================================================================
A_ScriptName := "Ahk2Exe Compilador"
global Title := "Ahk2Exe para AutoHotkey v" . A_AhkVersion . " | Script a EXE Conversor (" . (A_PtrSize==4?"32-Bit)":"64-Bit)")


; comprobamos instancia (no permitir más de una instancia)
If (StrSplit(A_OSVersion, ".")[1] < 6)
    Util_Error("Sistema operativo no soportado.", A_OSVersion, 196)
If (WinExist(Title))
    WinShow(Title), WinActivate(Title), ExitApp()


; variables super-globales
global  g_data := {}
global     Cfg := Util_LoadCfg()
global VerInfo := Util_LoadVerInfo()    ; StringFileInfo BLOCK statement - https://msdn.microsoft.com/en-us/library/windows/desktop/aa381049(v=vs.85).aspx
global    Gdip := new Gdiplus
global AhkPath := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
    AhkPath := ErrorLevel || !Path(AhkPath).IsFile ? RegRead("HKCU\SOFTWARE\AutoHotkey", "InstallDir") : AhkPath
    global AhkDir := DirExist(DirGetParent(AhkPath)) ? DirGetParent(AhkPath) : DirGetParent(A_ScriptDir)
    global AhkLib := [ DirExist(AhkDir . "\Lib") ? AhkDir . "\Lib" : ""
                     , DirExist(A_MyDocuments . "\AutoHotkey\Lib") ? A_MyDocuments . "\AutoHotkey\Lib" : "" ]
global ERROR := FALSE


; constantes
global       RT_CURSOR := 1    ; Resource-Definition Statements - https://msdn.microsoft.com/en-us/library/windows/desktop/aa381043(v=vs.85).aspx
     ,       RT_BITMAP := 2    ; Resource Types - https://msdn.microsoft.com/en-us/library/windows/desktop/ms648009(v=vs.85).aspx
     ,         RT_ICON := 3
     ,         RT_MENU := 4
     ,       RT_DIALOG := 5
     ,       RT_STRING := 6
     ,      RT_FONTDIR := 7
     ,         RT_FONT := 8
     , RT_ACCELERATORS := 9
     ,       RT_RCDATA := 10
     , RT_MESSAGETABLE := 11
     , RT_GROUP_CURSOR := 12  ; RT_CURSOR + 11 - MAKEINTRESOURCE((ULONG_PTR)(RT_CURSOR) + DIFFERENCE)
     ,   RT_GROUP_ICON := 14  ;   RT_ICON + 11 - MAKEINTRESOURCE((ULONG_PTR)(  RT_ICON) + DIFFERENCE)
     ,      RT_VERSION := 16
     ,   RT_DLGINCLUDE := 17
     ,     RT_PLUGPLAY := 19
     ,          RT_VXD := 20
     ,    RT_ANICURSOR := 21
     ,      RT_ANIICON := 22
     ,         RT_HTML := 23
     ,     RT_MANIFEST := 24

global    UPX := 1
     , MPRESS := 2

global SUBLANG_ENGLISH_US := 0x0409    ; https://msdn.microsoft.com/en-us/library/windows/desktop/dd318693(v=vs.85).aspx

global       TD_ERROR_ICON := 0xFFFE,   ERROR_ICON := [0, TD_ERROR_ICON]
     ,     TD_WARNING_ICON := 0xFFFF, WARNING_ICON := [0, TD_WARNING_ICON]
     , TD_INFORMATION_ICON := 0xFFFD,    INFO_ICON := [0, TD_INFORMATION_ICON]
     ,      TD_SHIELD_ICON := 0xFFFC,  SHIELD_ICON := [0, TD_SHIELD_ICON]

global IMAGE_SUBSYSTEM_WINDOWS_GUI := 2
    ,  IMAGE_SUBSYSTEM_WINDOWS_CUI := 3


; determina si se pasaron parámetros al compilador
global CMDLN := ObjLength(A_Args)
If (CMDLN)
    ExitApp ProcessCmdLine()


; variables super-globales necesarias cuando se muestra la interfaz GUI
global Gui := 0        ; almacena el objeto GUI de la ventana principal
global Log := ""       ; almacena una serie de registros de una operación en contreto separados por "`n"
global wctrltimer := 0
global ButtonStyle := [[3, 0xFEF5BF, 0xFEE88A, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [3, 0xFEDF63, 0xFED025, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [5, 0xFEDF63, 0xFED025, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [0, 0xFEF5BF, "Black", 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [3, 0xFEF5BF, 0xFEE88A, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 2], [0, 0xFEF5BF, "Black", 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1]]
global ButtonStyle2 := [[0, 0xE1E1E1, "Black", 0x151515, 5, 0xFFFFFF, 0xADADAD, 1], [0, 0xE5F1FB, "Black", 0x151515, 5, 0xFFFFFF, 0x007CE1, 1], [0, 0xCCE4F7, "Black", 0x151515, 5, 0xFFFFFF, 0x005499, 1], [0, 0xE1E1E1, "Black", 0x808080, 5, 0xFFFFFF, 0xADADAD, 1], [0, 0xE1E1E1, "Black", 0x151515, 5, 0xFFFFFF, 0x007CE1, 2], [0, 0xE5F1FB, "Black", 0x151515, 1, 0xFFFFFF, 0x007CE1, 1]]


; constantes
global     MAX_SRCITEMLIST := 10
global     MAX_ICOITEMLIST := 10
global WATER_BLOB_INTERVAL := 2500

global WIN_MINIMIZED := -1
     ,    WIN_NORMAL := 0
     , WIN_MAXIMIZED := 1

global VK_F1 := 0x70    ; https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx


; comprobamos permisos
If (!FileOpen("~tmp", "w"))
    If (!RunAsAdmin())
        Util_Error("Error de permisos.`nIntente ejecutar el compilador como Administrador.",, TRUE)
FileDelete(A_ScriptDir . "\~tmp"), A_IconHidden := A_IsCompiled


; creamos la interfaz de usuario (GUI)
Gui := GuiCreate("-DPIScale -Resize -MaximizeBox +MinSize690x481 +E0x00000400", Title)
    ERROR_ICON[1] := WARNING_ICON[1] := INFO_ICON[1] := SHIELD_ICON[1] := Gui.Hwnd
    GCT := new GuiControlTips(Gui)
    GCT.SetTitle("Ahk2Exe", 1)
    GCT.SetFont("Italic", "Segoe UI")
Gui.SetFont("s9", "Segoe UI")

If (A_PtrSize == 4)
    Gui.AddText("x0 y0 w690 h110 vlogo"), Util_LoadWaterCtrl(), Util_EnableWater(Gui.Control["logo"].Hwnd, Util_LoadLogo())
Else
    Gui.AddPic("x0 y0 w690 h110 vlogo", "HBITMAP:" . Util_LoadLogo())
Gui.AddButton("x318 y4 w368 h100 vinfo Left", "  ©2004-2009 Chris Mallet`n  ©2008-2011 Steve Gray (Lexikos)`n  ©2011-2018 fincs`n  ©2018-2018 Flipeador`n`n  Nota: La compilación no garantiza la protección del código fuente.")
    DllCall("User32.dll\SetParent", "Ptr", Gui.Control["info"].Hwnd, "Ptr", Gui.Control["logo"].Hwnd)
    ImageButton.Create(Gui.Control["a"].Hwnd, [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEE786, 0xFEF5BF, 0x2D4868, 5, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1])
    Gui.Control["info"].OnEvent("Click", Func("WM_KEYDOWN").Bind(0x70, 0))

Gui.AddTab3("x0 y110 w692 h304 vtab", "General|Información de la versión|Registros|AutoHotkey")
    Gui.Control["tab"].OnEvent("Change", "Gui_Tab")

Gui.Control["tab"].UseTab(1)
Gui.AddGroupBox("x20 y150 w650 h90", "Parámetros requeridos")
Gui.AddText("x30 y175 w120 h20 +0x200", "Fuente (archivo script)")
Gui.AddComboBox("x180 y175 w435 h22 vddlsrc R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastSrcList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Gui.Control["ddlsrc"].OnEvent("Change", "Util_UpdateSrc")
    CB_SetSelection(Gui.Control["ddlsrc"], CB_FindString(Gui.Control["ddlsrc"], Cfg.LastSrcFile))
    GCT.Attach(Gui.Control["ddlsrc"], "Buscar y seleccionar el archivo fuente en la lista")
    GCT.Attach(CB_GetInfo(Gui.Control["ddlsrc"]).Edit, "El archivo fuente script a compilar")
Gui.AddButton("x620 y175 w40 h22 vbsrc", "•••")
    Gui.Control["bsrc"].OnEvent("Click", "Gui_SrcButton")
    ImageButton.Create(Gui.Control["bsrc"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bsrc"], "Buscar y seleccionar un archivo fuente")
Gui.AddText("x30 y202 w120 h20 +0x200", "Destino (archivo exe)")
Gui.AddEdit("x180 y202 w435 h20 vedest ReadOnly")
    GCT.Attach(Gui.Control["edest"], "El archivo destino compilado EXE")
Gui.AddButton("x620 y202 w40 h20 vbdest", "•••")
    Gui.Control["bdest"].OnEvent("Click", "Gui_DestButton")
    ImageButton.Create(Gui.Control["bdest"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bdest"], "Seleccionar el archivo destino")
Gui.AddGroupBox("x20 y249 w650 h85", "Parámetros opcionales")
Gui.AddText("x30 y272 w120 h20 +0x200", "Icono (archivo ico)")
Gui.AddComboBox("x180 y272 w435 h22 vddlico R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastIconList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlico"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlico"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    CB_SetSelection(Gui.Control["ddlico"], CB_FindString(Gui.Control["ddlico"], Cfg.LastIconFile))
    GCT.Attach(Gui.Control["ddlico"], "Buscar y seleccionar un icono en la lista")
    GCT.Attach(CB_GetInfo(Gui.Control["ddlico"]).Edit, "El icono principal del archivo compilado")
Gui.AddButton("x620 y272 w40 h22 vbico", "•••")
    Gui.Control["bico"].OnEvent("Click", "Gui_IcoButton")
    ImageButton.Create(Gui.Control["bico"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bico"], "Buscar y seleccionar un archivo icono")
Gui.AddText("x32 y296 w120 h22 +0x200", "Archivo base (bin)")
Gui.AddDDL("x180 y296 w405 h22 vddlbin R6 +0x400")
    CB_SetItemHeight(Gui.Control["ddlbin"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlbin"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Util_LoadBinFiles(Cfg.LastBinFile)
    GCT.Attach(Gui.Control["ddlbin"], "El archivo base BIN AutoHotkey")
Gui.AddButton("x592 y296 w68 h22 vbrefbin", "Refrezcar")
    Gui.Control["brefbin"].OnEvent("Click", () => Util_LoadBinFiles(Cfg.LastBinFile))
    ImageButton.Create(Gui.Control["brefbin"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["brefbin"], "Volver a leer los archivos BIN")
Gui.AddGroupBox("x20 y344 w650 h61", "Compresión del archivo exe resultante")
Gui.AddText("x30 y367 w125 h22 +0x200", "Método de compresión")
Gui.AddDDL("x180 y367 w405 h22 vddlcomp R4 +0x400")
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Util_LoadCompressionFiles(Cfg.Compression)
    GCT.Attach(Gui.Control["ddlcomp"], "El método de compresión del archivo EXE")
Gui.AddButton("x592 y367 w68 h22 vbdownload", "Descargar")
    Gui.Control["bdownload"].OnEvent("Click", () => InStr(CB_GetText(Gui.Control["ddlcomp"]), "upx") ? Run("https://upx.github.io/") : InStr(CB_GetText(Gui.Control["ddlcomp"]), "mpress") ? Run("http://www.matcode.com/mpress.htm") : 0)
    ImageButton.Create(Gui.Control["bdownload"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bdownload"], "Ir a la página oficial para descargar la herramienta seleccionada")

Gui.Control["tab"].UseTab(2)
Gui.AddListView("x2 y138 w686 h272 vlvri -E0x200", "Nombre|Valor")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", Gui.Control["lvri"].Hwnd, "Str", "Explorer", "UPtr", 0, "UInt")
    Util_UpdateSrc()

Gui.Control["tab"].UseTab(3)
Gui.AddListView("x2 y138 w686 h272 vlvlog -E0x200", "ID|Mensaje|Archivo|Línea|Detalles|Código de error|Información adicional|Tiempo")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", Gui.Control["lvlog"].Hwnd, "Str", "Explorer", "UPtr", 0, "UInt")

Gui.Control["tab"].UseTab(4)
Gui.AddGroupBox("x20 y150 w650 h90", "Instalación de AutoHotkey")
Gui.AddText("x30 y175 w120 h20 +0x200", "Ruta de instalación")
Gui.AddEdit("x180 y175 w435 h20 veahkp ReadOnly")
Gui.AddButton("x620 y175 w40 h20 vbahkp", "•••")
    Gui.Control["bahkp"].OnEvent("Click", "Gui_FindAHKButton")
Gui.AddRadio("x30 y212 w130 h20 vrcurru Disabled", "Usuario actual")
    Gui.Control["rcurru"].OnEvent("Click", "Gui_CurrURadio")
Gui.AddRadio("x180 y212 w130 h20 vrallu Disabled", "Todos los usuarios")
    Gui.Control["rallu"].OnEvent("Click", "Gui_AllURadio")

Gui.Control["tab"].UseTab()
Gui.AddText("x0 y413 w690 h2 vbsp BackgroundFED22C")    ; separador
Gui.AddPic("x0 y415 w690 h76 vbbg +E0x08000000")    ; fondo de pié de página
    LinearGradient(Gui.Control["bbg"], [0xFEF5BF, 0xFEE786],, 1)  ; 1=VERTICAL
Gui.AddButton("x590 y426 w90 h22 vbclose", "Cerrar")
    Gui.Control["bclose"].OnEvent("Click", "ExitApp")
    ImageButton.Create(Gui.Control["bclose"].Hwnd, ButtonStyle*)
    GCT.Attach(Gui.Control["bclose"], "Cerrar el compilador y guardar la sesión")
Gui.AddButton("x492 y426 w90 h22 Default vbcompile", ">Compilar<")
    Gui.Control["bcompile"].OnEvent("Click", "Gui_CompileButton")
    Gui.Control["bcompile"].SetFont("Bold")
    ImageButton.Create(Gui.Control["bcompile"].Hwnd, ButtonStyle*)
    GCT.Attach(Gui.Control["bcompile"], "Compilar el archivo fuente seleccionado")
Gui.AddButton("x10 y426 w90 h22 vbgit", "Ver en GitHub")
    Gui.Control["bgit"].OnEvent("Click", () => Run("https://github.com/flipeador/Ahk2Exe"))
    ImageButton.Create(Gui.Control["bgit"].Hwnd, ButtonStyle*)
    GCT.Attach(Gui.Control["bgit"], "Ir a la página oficial en GitHub")
Gui.AddButton("x110 y426 w90 h22 vbabout", "Acerca de (F1)")
    Gui.Control["babout"].OnEvent("Click", Func("WM_KEYDOWN").Bind(0x70, 0))
    ImageButton.Create(Gui.Control["babout"].Hwnd, ButtonStyle*)
    GCT.Attach(Gui.Control["babout"], "Ver acerca de..")
Gui.AddLink("x210 y429 w200 h22 BackgroundFFFFFF vlnk", "<a href=`"https://autohotkey.com/`">https://autohotkey.com/</a>")
    WinSetTransColor("FFFFFF", "ahk_id" . Gui.Control["lnk"].Hwnd)
    GCT.Attach(Gui.Control["lnk"], "Ir a la página oficial de AutoHotkey")
Gui.AddStatusBar("vsb +0x100", "Listo")
    GCT.Attach(Gui.Control["sb"], "Muestra información del estado actual")
    ;WinSetTransColor("F0F0F0", "ahk_id" . Gui.Control["sb"].Hwnd)

Gui.Show("w690 h481")
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
    If (MinMax == WIN_MINIMIZED)
        Return
    ; no implementado aún
}

Gui_DropFiles(Gui, Ctrl, FileArray, X, Y)
{
    Local LastSrc := "", LastIco := "", foo := new GuiDisable("Leyendo archivos..")
    Loop (ObjLength(FileArray))
    {
        If (DirExist(FileArray[A_Index]))
            Loop Files, FileArray[A_Index] . "\*.*", "F"
                Load(A_LoopFileFullPath)
        Else
            Load(FileArray[A_Index])
    }
    CB_SetSelection(Gui.Control["ddlsrc"], LastSrc, 0)
    CB_SetSelection(Gui.Control["ddlico"], LastIco, 0)
    Util_UpdateSrc()

    Load(File)
    {
        If (SubStr(File, -4) = ".ahk")
            LastSrc := File, CB_Insert(Gui.Control["ddlsrc"], File,, 0)
        If (SubStr(FileArray[A_Index], -4) = ".ico")
            LastIco := File, CB_Insert(Gui.Control["ddlico"], File,, 0)
    }
}

Gui_Tab(Tab)
{
    If (Tab.Value == 4)
    {
        Local InstallDir := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
        If (ErrorLevel || DirExist(InstallDir) || !FileExist(InstallDir))
        {
            InstallDir := RegRead("HKCU\SOFTWARE\AutoHotkey", "InstallDir")
            If (ErrorLevel || DirExist(InstallDir) || !FileExist(InstallDir))
                Gui.Control["rcurru"].Value := FALSE, Gui.Control["rallu"].Value := FALSE
            Else
                Gui.Control["rcurru"].Value := TRUE
        }
        Else
            Gui.Control["rallu"].Value := TRUE

        Gui.Control["eahkp"].Text := InstallDir
    }
}

Gui_FindAHKButton()
{
    Local File := ChooseFile([Gui.Hwnd,"Ahk2Exe - Seleccionar ruta de instalación de AutoHotkey.exe"],, {Ejecutables: "#*.exe"})
    If (File)
    {
        RegWrite(File, "REG_SZ", "HKLM\SOFTWARE\AutoHotkey", "InstallDir")
        If (ErrorLevel)
            TaskDialog(INFO_ICON, [Title,"AutoHotkey"], ["Ha ocurrido un error al escribir la clave.`nIntente ejecutar el compilador como Administrador.",File])
        Else
            Gui.Control["eahkp"].Text := File, Gui.Control["rallu"].Value := TRUE
    }
}

Gui_CurrURadio()
{
}

Gui_AllURadio()
{
}

Gui_SrcButton()
{
    Local foo := new GuiDisable("Mostrando diálogo para seleccionar archivo fuente AHK..")
    Local File := CB_GetSelection(Gui.Control["ddlsrc"]) == -1 ? Cfg.LastSrcFile : CB_GetText(Gui.Control["ddlsrc"])
        , File := ChooseFile([Gui.Hwnd,"Ahk2Exe - Seleccionar archivo fuente"], File, {"Todos los archivos": "*.*", Iconos: "#*.ahk"},, 0x1200)
    If (File)
    {
        Loop (ObjLength(File))
            CB_Insert(Gui.Control["ddlsrc"], File[A_Index],, 0)
        CB_SetSelection(Gui.Control["ddlsrc"], File[1], 0)
        Util_UpdateSrc()
    }
}

Gui_IcoButton()
{
    Local foo := new GuiDisable("Mostrando diálogo para seleccionar archivo icono..")
    Local File := CB_GetSelection(Gui.Control["ddlico"]) == -1 ? Cfg.LastIconFile : CB_GetText(Gui.Control["ddlico"])
        , File := ChooseFile([Gui.Hwnd,"Ahk2Exe - Seleccionar icono"], File, {Iconos: "#*.ico"},, 0x1200)
    If (File)
    {
        Loop (ObjLength(File))
            If (SubStr(File[A_Index], -4) = ".ico")
                CB_Insert(Gui.Control["ddlico"], File[A_Index],, 0)
        CB_SetSelection(Gui.Control["ddlico"], File[1], 0)
    }
}

Gui_DestButton()
{
    Local foo := new GuiDisable("Mostrando diálogo para seleccionar archivo de destino..")
    Local File := Gui.Control["edest"].Text == "" ? (CB_GetSelection(Gui.Control["ddlsrc"]) == -1 ? DirGetParent(Cfg.LastExeFile) . "\" : CB_GetText(Gui.Control["ddlsrc"])) : Gui.Control["edest"].Text
        , File := SaveFile([Gui.Hwnd,"Ahk2Exe - Guardar como"], SubStr(File, -4) = ".ahk" ? SubStr(File, 1, -4) . ".exe" : File, {Ejecutables: "#*.exe"})
    If (File)
    {
        Local Ext := ""
        SplitPath(File,,, Ext)
        If (Ext = "exe")
            Gui.Control["edest"].Text := File
        Else
            Util_Error("El archivo destino debe ser un archivo ejecutable EXE.", File)
    }
}

Gui_CompileButton()
{
    ERROR := FALSE
    Util_ClearLog()
    Local foo := new GuiDisable("Compilando..")
        , Script := CB_GetText(Gui.Control["ddlsrc"])
        ,   Data := PreprocessScript(Script)

    If (Data)
    {
        If (AhkCompile(Data))
        {
            Util_AddLog("OK", "La compilación a finalizado con éxito", Script)

            ; EJECUCIONES AL COMPILAR CON ÉXITO ... {}
        }
        Else
            Util_AddLog("ERROR", "Ha ocurrido un error durante la compilación", Script)
    }
    Else
        Util_AddLog("ERROR", "Ha ocurrido un error durante el procesado del script", Script)
}





; =====================================================================================================================================================
; EVENTOS DEL SISTEMA
; =====================================================================================================================================================
WM_KEYDOWN(VKCode, lParam)
{
    If (VKCode == VK_F1)
    {
        Gui.Control["sb"].SetText("Mostrando Acerca de.. (F1)")
        TaskDialog(INFO_ICON, [Gui.Title,"Acerca de.."], ["Ahk2Exe - Script to EXE Converter`n-----------------------------------`n`n"
                                                        . "Original version:`n"
                                                        . "Copyright ©1999-2003 Jonathan Bennett & AutoIt Team`n"
                                                        . "Copyright ©2004-2009 Chris Mallet`n"
                                                        . "Copyright ©2008-2011 Steve Gray (Lexikos)`n`n"
                                                        . "Script rewrite:`n"
                                                        . "Copyright ©2011-2018 fincs`n"
                                                        . "Copyright ©2018-2018 Flipeador"
                                                        , "flipeador@gmail.com"] )
        Gui.Control["sb"].SetText("Listo")
    }
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646280(v=vs.85).aspx





WM_MOUSEMOVE(VKCode, Coords)
{
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms645616(v=vs.85).aspx





_OnExit(ExitReason, ExitCode)
{
    global wctrltimer
    If (wctrltimer)
        SetTimer(wctrltimer, "Delete")
    DllCall("User32.dll\AnimateWindow", "Ptr", Gui.HWnd, "UInt", 350, "UInt", 0x00080000|0x00010000)
    A_IconHidden := TRUE
    Util_SaveCfg()

    Return 0    ; EXIT
}





; =====================================================================================================================================================
; FUNCIONES
; =====================================================================================================================================================
Util_Error(Message, ExpandedInfo := "", ExitCode := FALSE)
{
    ERROR := TRUE
    TaskDialog(ERROR_ICON, [Title,"Ha ocurrido un error y las operaciónes an sido abortadas."], ExpandedInfo == "" ? Message : [Message,ExpandedInfo])
    If (ExitCode)
        ExitApp ExitCode
    Return FALSE
}

Util_LoadCfg()
{
    Return {  LastSrcList: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastSrcList")
           , LastIconList: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconList")
           ,  LastSrcFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastSrcFile")
           ,  LastExeFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastExeFile")
           , LastIconFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconFile")
           ,  LastBinFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastBinFile")
           ,  Compression: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "Compression") }
}

Util_SaveCfg()
{
    ; guarda una lista de máximos MAX_SRCITEMLIST elementos con los archivos fuente AHK en el control
    Cfg.LastSrcList := ""
    Loop (CB_GetCount(Gui.Control["ddlsrc"]))
        If (A_Index <= MAX_SRCITEMLIST)
            Cfg.LastSrcList .= CB_GetText(Gui.Control["ddlsrc"], A_Index-1) . "`r`n"
    RegWrite(Cfg.LastSrcList, "REG_EXPAND_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastSrcList")

    ; guarda una lista de máximos MAX_ICOITEMLIST elementos con los archivos iconos en el control
    Cfg.LastIconList := ""
    Loop (CB_GetCount(Gui.Control["ddlico"]))
        If (A_Index <= MAX_ICOITEMLIST)
            Cfg.LastIconList .= CB_GetText(Gui.Control["ddlico"], A_Index-1) . "`r`n"
    RegWrite(Cfg.LastIconList, "REG_EXPAND_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconList")

    ; guarda el último directorio utilizado con un archivo fuente AHK
    If (CB_GetSelection(Gui.Control["ddlsrc"]) != -1)
        RegWrite(CB_GetText(Gui.Control["ddlsrc"]), "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastSrcFile")

    ; guarda el último directorio utilizado con el archivo destino EXE
    RegWrite(Gui.Control["edest"].Text, "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastExeFile")

    ; guarda el último directorio utilizado con un archivo icono
    If (CB_GetSelection(Gui.Control["ddlico"]) != -1)
        RegWrite(CB_GetText(Gui.Control["ddlico"]), "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconFile")
    
    ; guarda el archivo BIN utilizado
    If (Cfg.LastBinFile != SubStr(CB_GetText(Gui.Control["ddlbin"]), InStr(CB_GetText(Gui.Control["ddlbin"]), A_Space)+1) . ".bin")
        RegWrite(SubStr(CB_GetText(Gui.Control["ddlbin"]), InStr(CB_GetText(Gui.Control["ddlbin"]), A_Space)+1) . ".bin", "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastBinFile")

    ; guarda el método de compresión actual
    If (Cfg.Compression != CB_GetSelection(Gui.Control["ddlcomp"]))
        RegWrite(CB_GetSelection(Gui.Control["ddlcomp"]), "REG_DWORD", "HKCU\Software\AutoHotkey\Ahk2Exe", "Compression")
}

Util_LoadVerInfo()
{
    Return {      CompanyName: ["CompanyName"]
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
           ,         Comments: ["Comments"]
           ,             Name: ["ProductName","InternalName"]    }
}

Util_LoadBinFiles(Default)
{
    CB_Delete(Gui.Control["ddlbin"])
    Loop Files, "*.bin", "F"
        CB_Insert(Gui.Control["ddlbin"], "v" . FileGetVersion(A_LoopFileFullPath) . A_Space . SubStr(A_LoopFileName, 1, -4))
    CB_SetSelection(Gui.Control["ddlbin"], CB_FindString(Gui.Control["ddlbin"], SubStr(Default, 1, -4),, 2))
}

Util_CheckBinFile(Name)
{
    Local BinFile := ""
    If (Name ~= "^v")
        Return Path(BinFile := SubStr(Name, InStr(Name, A_Space)+1) . ".bin").IsFile ? BinFile : 0

    Name .= Path(Name).Ext == "" ? ".bin" : ""
    Return Path(Name).IsFile ? Name : 0 
}

Util_LoadCompressionFiles(Default)
{
    CB_Delete(Gui.Control["ddlcomp"])
    CB_Insert(Gui.Control["ddlcomp"], "Sin compresión")
    CB_Insert(Gui.Control["ddlcomp"], "UPX " . Util_CheckCompressionFile("upx.exe") . "- Ultimate Packer for eXecutables")
    CB_Insert(Gui.Control["ddlcomp"], "MPRESS " . Util_CheckCompressionFile("mpress.exe") . "- High-performance executable packer")
    CB_SetSelection(Gui.Control["ddlcomp"], Default)
}

Util_CheckCompressionFile(Name)
{
    Name := InStr(Name, "upx") ? "upx.exe" : InStr(Name, "mpress ") ? "mpress.exe" : Name
    Return FileExist(Name) ? "v" . FileGetVersion(Name) . A_Space : ""
}

Util_UpdateSrc()
{
    SetTimer("Update", -250)
    Update()
    {
        Local Script := CB_GetText(Gui.Control["ddlsrc"])
            ,    foo := new Status("Analizando archivo fuente.. " . Script)
            ,   Data := QuickParse(Script)
        Gui.Control["ddlsrc"].Enabled := FALSE
        If (Data)
        {
            If (Data.MainIcon != "")
                CB_Insert(Gui.Control["ddlico"], Data.MainIcon,, 0), CB_SetSelection(Gui.Control["ddlico"], Data.MainIcon, 0)

            Gui.Control["lvri"].Delete()
            Loop Parse, "Comments|CompanyName|FileDescription|FileVersion|InternalName|LegalCopyright|OriginalFilename|ProductName|ProductVersion", "|"
                Gui.Control["lvri"].Add(, A_LoopField, IsObject(Data.VerInfo) && ObjHasKey(Data.VerInfo, A_LoopField) ? Data.VerInfo[A_LoopField] : "")
            Gui.Control["lvri"].ModifyCol(1, "AutoHdr")
        }
        Gui.Control["ddlsrc"].Enabled := TRUE
    }
}

Util_AddLog(What, Message, Script := "-", Line := "-", Extra := "-", ErrorCode := "-", Other := "-")
{
    If (CMDLN)
        Return
    Gui.Control["lvlog"].Add(, What, Message, Script, Line, Extra, ErrorCode, Other, FormatTime(, "dd/MM/yyyy hh:mm:ss"))
    Loop 7
        Gui.Control["lvlog"].ModifyCol(A_Index, "AutoHdr")
}

Util_ClearLog()
{
    Gui.Control["lvlog"].Delete()
}

Util_LoadLogo()
{
    Local hBitmap := LoadImage(A_IsCompiled ? -1 : 0, "LOGO.BMP")

    If (A_PtrSize == 4)
    {
        ; necesario rotar la imagen para la correcta visualización con waterctrl
        Local pBitmap := 0
        DllCall("Gdiplus.dll\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "UPtrP", pBitmap)
        DllCall("Gdi32.dll\DeleteObject", "Ptr", hBitmap)
        ; https://msdn.microsoft.com/en-us/library/ms534041(v=vs.85).aspx
        DllCall("Gdiplus.dll\GdipImageRotateFlip", "UPtr", pBitmap, "Int", 6)    ; 6 = Rotate180FlipX (https://msdn.microsoft.com/en-us/library/ms534171(v=vs.85).aspx)
        DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "UPtr", pBitmap, "PtrP", hBitmap, "Int", 0xFFFFFFFF)
        DllCall("Gdiplus.dll\GdipDisposeImage", "UPtr", pBitmap)
    }

    Return hBitmap
}

Util_LoadWaterCtrl()
{
    If (!A_IsCompiled)
        Return LoadLibrary("waterctrl.dll")

    If (FileExist(A_Temp . "\waterctrl.dll"))
        Return LoadLibrary(A_Temp . "\waterctrl.dll")

    Local hExe := LoadLibrary(A_ScriptFullPath, 2), Size := 0
    FileOpen(A_Temp . "\waterctrl.dll", "w").RawWrite(LoadResource3(hExe, RT_RCDATA, "WATERCTRL.DLL", Size), Size)
    FreeLibrary(hExe)
    Return LoadLibrary(A_Temp . "\waterctrl.dll")
}

Util_EnableWater(Hwnd, hBitmap)
{
    DllCall("waterctrl.dll\enablewater", "Ptr", Gui.Hwnd, "Int", 0, "Int", 0, "Ptr", hBitmap, "Int", 3, "Int", 20)
    DllCall("waterctrl.dll\setwaterparent", "Ptr", Hwnd)
    If (WATER_BLOB_INTERVAL)
        SetTimer(wctrltimer := () => DllCall("waterctrl.dll\waterblob", "Int", Random(0, 690), "Int", Random(0, 110), "Int", Random(3, 12), "Int", Random(20, 75)), WATER_BLOB_INTERVAL)
} ; https://autohotkey.com/boards/viewtopic.php?t=3302

Path(Path, ByRef FN := "", ByRef Dir := "", ByRef Ext := "", ByRef FNNE := "", ByRef Drive := "", ByRef Attrib := "")
{
    SplitPath(Path, FN, Dir, Ext, FNNE, Drive), Attrib := FileExist(Path)
    Return {Path: Path, FN: FN, Dir: Dir, Ext: Ext, FNNE: FNNE, Drive: Drive, IsDir: InStr(Attrib, "D")?Attrib:0, IsFile: Attrib!=""&&Attrib&&!InStr(Attrib, "D")?Attrib:0, Exist: Attrib!=""&&Attrib}
}





; =====================================================================================================================================================
; CLASES
; =====================================================================================================================================================
Class Status
{
    __New(str)
    {
        Try Gui.Control["sb"].SetText(str)
    }

    __Delete()
    {
        try Gui.Control["sb"].SetText("Listo")
    }
}

Class GuiDisable
{
    __New(str)
    {
        WinSetEnabled(FALSE, "ahk_id" . Gui.Hwnd)
        this.Status := new Status(str)
    }

    __Delete()
    {
        WinSetEnabled(TRUE, "ahk_id" . Gui.Hwnd)
        Gui.Show()
        WinSetAlwaysOnTop(TRUE, "ahk_id" . Gui.Hwnd)
        WinSetAlwaysOnTop(FALSE, "ahk_id" . Gui.Hwnd)
        WinMoveTop("ahk_id" . Gui.Hwnd)
    }
}

Class Gdiplus
{
    __New()
    {
        If (!(this.hModule := DllCall("Kernel32.dll\LoadLibraryW", "Str", "gdiplus.dll", "Ptr")))
            Util_Error("LoadLibrary Gdiplus Error #" . A_LastError,, TRUE)

        Local GdiplusStartupInput := "", pToken := 0
        NumPut(VarSetCapacity(GdiplusStartupInput, 16, 0) * 0 + 1, &GdiplusStartupInput, "UInt")    ; GdiplusStartupInput.GdiplusVersion = 1
        Local Ret := DllCall("Gdiplus.dll\GdiplusStartup", "UPtrP", pToken, "UPtr", &GdiplusStartupInput, "UPtr", 0, "UInt")
        If (!pToken)
            Util_Error("Gdiplus Error #" . Ret . ".",, TRUE)
        this.pToken := pToken
    }

    __Delete()
    {
        DllCall("Gdiplus.dll\GdiplusShutdown", "UPtr", this.pToken)
        DllCall("Kernel32.dll\FreeLibrary", "Ptr", this.hModule)
    }
}
