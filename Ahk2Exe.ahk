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
#Include Lib\SaveFile.ahk
#Include Lib\ChooseFile.ahk

#Include Include\Compiler.ahk
#Include Include\ScriptParser.ahk
#Include Include\Resources.ahk





; =====================================================================================================================================================
; INICIO
; =====================================================================================================================================================
A_ScriptName := "Ahk2Exe Compilador"
global Title := "Ahk2Exe para AutoHotkey v" . A_AhkVersion . " | Script a EXE Conversor"


; comprobamos instancia (no permitir más de una instancia)
If (StrSplit(A_OSVersion, ".")[1] < 6)
    Util_Error("Sistema operativo no soportado.", A_OSVersion, 196)
If (WinExist(Title))
    WinShow(Title), WinActivate(Title), ExitApp()


; variables super-globales obligatorias
global     Cfg := Util_LoadCfg()
global VerInfo := Util_LoadVerInfo()    ; StringFileInfo BLOCK statement - https://msdn.microsoft.com/en-us/library/windows/desktop/aa381049(v=vs.85).aspx
global    Gdip := new Gdiplus
global AhkPath := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
    global AhkDir := DirExist(GetDirParent(AhkPath)) ? GetDirParent(AhkPath) : GetDirParent(A_ScriptDir)
    global AhkLib := [ DirExist(AhkDir . "\Lib") ? AhkDir . "\Lib" : ""
                     , DirExist(A_MyDocuments . "\AutoHotkey\Lib") ? A_MyDocuments . "\AutoHotkey\Lib" : "" ]


; constantes
global       RT_CURSOR := 1    ; Resource-Definition Statements - https://msdn.microsoft.com/en-us/library/windows/desktop/aa381043(v=vs.85).aspx
     ,       RT_BITMAP := 2    ; Resource Types - https://msdn.microsoft.com/en-us/library/windows/desktop/ms648009(v=vs.85).aspx
     ,         RT_ICON := 3
     ,         RT_MENU := 4
     ,       RT_DIALOG := 5
     ,       RT_STRING := 6
     , RT_ACCELERATORS := 9
     ,       RT_RCDATA := 10
     , RT_MESSAGETABLE := 11
     , RT_GROUP_CURSOR := 12  ; RT_CURSOR + 11 - MAKEINTRESOURCE((ULONG_PTR)(RT_CURSOR) + DIFFERENCE)
     ,   RT_GROUP_ICON := 14  ;   RT_ICON + 11 - MAKEINTRESOURCE((ULONG_PTR)(  RT_ICON) + DIFFERENCE)
     ,      RT_VERSION := 16
     ,    RT_ANICURSOR := 21
     ,      RT_ANIICON := 22
     ,         RT_HTML := 23
     ,     RT_MANIFEST := 24

global    UPX := 1
     , MPRESS := 2

global SUBLANG_ENGLISH_US := 0x0409    ; https://msdn.microsoft.com/en-us/library/windows/desktop/dd318693(v=vs.85).aspx

global ERROR := FALSE

global       TD_ERROR_ICON := 0xFFFE,   ERROR_ICON := [0, TD_ERROR_ICON]
     ,     TD_WARNING_ICON := 0xFFFF, WARNING_ICON := [0, TD_WARNING_ICON]
     , TD_INFORMATION_ICON := 0xFFFD,    INFO_ICON := [0, TD_INFORMATION_ICON]
     ,      TD_SHIELD_ICON := 0xFFFC,  SHIELD_ICON := [0, TD_SHIELD_ICON]

global IMAGE_SUBSYSTEM_WINDOWS_GUI := 2
    ,  IMAGE_SUBSYSTEM_WINDOWS_CUI := 3


; determina si se pasaron parámetros al compilador
If (ObjLength(A_Args))
{
    ExitApp
}


; arquitectura AHK (x32 necesario para el funcionamiento de waterctrl.dll)
If (A_PtrSize != 4)
    Util_Error("Error de arquitectura.`nDebe ejecutar el compilador con AutoHotkey 32-bit.",, TRUE)


; variables super-globales necesarias cuando se muestra la interfaz GUI
global Gui := 0        ; almacena el objeto GUI de la ventana principal
global Log := ""       ; almacena una serie de registros de una operación en contreto separados por "`n"


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
Gui.SetFont("s9", "Segoe UI")

Gui.AddText("x0 y0 w690 h100 vtbg BackgroundFFFFFF +E0x08000000")    ; fondo blanco para la parte superior
Gui.AddPic("x0 y415 w690 h76 vbbg +E0x08000000")    ; fondo de pié de página
    LinearGradient(Gui.Control["bbg"], [0xF0F0F0,0xCDCDCD],, 1)  ; 1=VERTICAL
Gui.AddText("x10 y5 w270 h92 vlogo")
    ; establecemos efecto de agua a la imagen logo AHK
    ; https://autohotkey.com/boards/viewtopic.php?t=3302
    DllCall("Kernel32.dll\LoadLibraryW", "Str", "waterctrl.dll")
    hLogo := DllCall("User32.dll\LoadImageW", "Ptr", 0, "Str", "logo.bmp", "UInt", 0, "Int", 270, "Int", 92, "UInt", 0x2010)
    DllCall("waterctrl\enablewater", "Ptr", Gui.Hwnd, "Int", 0, "Int", 0, "Ptr", hLogo, "Int", 3, "Int", 20)
    DllCall("waterctrl\setwaterparent", "Ptr", Gui.Control["logo"].Hwnd)
    global wctrltimer := 0
    If (WATER_BLOB_INTERVAL)
        SetTimer(wctrltimer := () => DllCall("waterctrl\waterblob", "Int", Random(1, 270), "Int", Random(1, 92), "Int", Random(3, 12), "Int", Random(20, 75)), WATER_BLOB_INTERVAL)
Gui.AddLink("x300 y10 w370 h80 BackgroundFFFFFF c242424 vlnk", "©2004-2009 Chris Mallet`n©2008-2011 Steve Gray (lexikos)`n©2018-2018 Flipeador  (©2011-2013 fincs)`n<a href=`"https://autohotkey.com/`">https://autohotkey.com/</a>`nNota: La compilación no garantiza la protección del código fuente.")
Gui.AddText("x10 y110 w670 h2 +0x10")    ; separador
Gui.AddTab3("x10 y120 w670 h287 vtab", "General|Información de la versión|Registros")

Gui.Control["tab"].UseTab(1)
Gui.AddGroupBox("x20 y150 w650 h86", "Parámetros requeridos")
Gui.AddText("x30 y175 w120 h20 +0x200", "Fuente (archivo script)")
Gui.AddComboBox("x180 y175 w435 h22 vddlsrc R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastSrcList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Gui.Control["ddlsrc"].OnEvent("Change", "Util_UpdateSrc")
    CB_SetSelection(Gui.Control["ddlsrc"], CB_FindString(Gui.Control["ddlsrc"], Cfg.LastSrcFile))
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
    CB_SetSelection(Gui.Control["ddlico"], CB_FindString(Gui.Control["ddlico"], Cfg.LastIconFile))
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
Gui.AddDDL("x180 y357 w405 h22 vddlcomp R4 +0x400")
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16,  0)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura de los elementos en la lista
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16, -1)    ; 0x153 = CB_SETITEMHEIGHT - Establece la altura del campo de selección
    Util_LoadCompressionFiles(Cfg.Compression)
Button := Gui.AddButton("x592 y357 w68 h22", "Descargar")
    Button.OnEvent("Click", () => InStr(CB_GetText(Gui.Control["ddlcomp"]), "upx") ? Run("https://upx.github.io/") : InStr(CB_GetText(Gui.Control["ddlcomp"]), "mpress") ? Run("http://www.matcode.com/mpress.htm") : 0)

Gui.Control["tab"].UseTab(2)
Gui.AddListView("x20 y150 w650 h250 vlvri -E0x200", "Nombre|Valor")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", Gui.Control["lvri"].Hwnd, "Str", "Explorer", "UPtr", 0, "UInt")
    Util_UpdateSrc()

Gui.Control["tab"].UseTab(3)
Gui.AddListView("x20 y150 w650 h250 vlvlog -E0x200", "ID|Mensaje|Archivo|Línea|Detalles|Código de error|Información adicional|Tiempo")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", Gui.Control["lvlog"].Hwnd, "Str", "Explorer", "UPtr", 0, "UInt")

Gui.Control["tab"].UseTab()
Gui.AddText("x0 y415 w690 h2 +0x10")
Gui.AddButton("x590 y426 w90 h22 vbclose", "Cerrar")
    Gui.Control["bclose"].OnEvent("Click", "ExitApp")
Gui.AddButton("x492 y426 w90 h22 vbcompile", "Compilar")
    Gui.Control["bcompile"].OnEvent("Click", "Gui_CompileButton")
Gui.AddButton("x10 y426 w90 h22 vbgit", "Ver en GitHub")
    Gui.Control["bgit"].OnEvent("Click", () => Run("https://github.com/flipeador/Ahk2Exe"))
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
    Local File := Gui.Control["edest"].Text == "" ? (CB_GetSelection(Gui.Control["ddlsrc"]) == -1 ? GetDirParent(Cfg.LastExeFile) . "\" : CB_GetText(Gui.Control["ddlsrc"])) : Gui.Control["edest"].Text
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
    Return FileExist(BinFile := SubStr(Name, InStr(Name, A_Space)+1) . ".bin") ? BinFile : FALSE
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

Util_GetFullPathName(Path)
{
    ;If (!InStr(Path, ".."))
    ;    Return InStr(Path, ":") ? Path : A_WorkingDir . "\" . Path

    VarSetCapacity(Buffer, 2002, 0)
    DllCall("Kernel32.dll\GetFullPathNameW", "UPtr", &Path, "UInt", 1000, "Str", Buffer, "UPtr", 0, "UInt")
    Return Buffer
}

Util_AddLog(What, Message, Script := "-", Line := "-", Extra := "-", ErrorCode := "-", Other := "-")
{
    Gui.Control["lvlog"].Add(, What, Message, Script, Line, Extra, ErrorCode, Other, FormatTime(, "dd/MM/yyyy hh:mm:ss"))
    Loop 7
        Gui.Control["lvlog"].ModifyCol(A_Index, "AutoHdr")
}

Util_ClearLog()
{
    Gui.Control["lvlog"].Delete()
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
