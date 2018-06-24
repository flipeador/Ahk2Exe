;@Ahk2Exe-SetName             Ahk2Exe
;@Ahk2Exe-SetOrigFilename     Ahk2Exe.exe
;@Ahk2Exe-SetDescription      Compilador de scripts para AutoHotkey v2 en español
;@Ahk2Exe-SetFileVersion      1.1.0.5    ; major.minor.maintenance.build
;@Ahk2Exe-SetCompanyName      AutoHotkey
;@Ahk2Exe-SetCopyright        Copyright (c) 2004-2018
;@Ahk2Exe-SetComments         [2018-06-23] https://github.com/flipeador/Ahk2Exe

;@Ahk2Exe-SetMainIcon Ahk2Exe.ico

;@Ahk2Exe-AddResource logo.bmp         ; imagen logo de AHK
;@Ahk2Exe-AddResource waterctrl.dll    ; para el efecto de agua en la imagen logo

;;@Ahk2Exe-PostExec MsgBox "Done!",,*





; =====================================================================================================================================================
; CONFIGURACIÓN DE INICIO
; =====================================================================================================================================================
#Warn
;@Ahk2Exe-Keep #NoTrayIcon    ; ocultamos el icono en el área de notificación en el script compilado
#SingleInstance Off
;@Ahk2Exe-Keep #KeyHistory 0

;@Ahk2Exe-Keep ListLines FALSE
DetectHiddenWIndows TRUE
;@Ahk2Exe-IgnoreBegin64 1    ; SetRegView no es necesario en compilaciones x64
SetRegView 64
FileEncoding "UTF-8"    ; unicode (el script compilado siempre incluirá BOM)
;;@Ahk2Exe-Keep OnError "_OnError"





; =====================================================================================================================================================
; INCLUDES
; =====================================================================================================================================================
; Lib\
#Include <Gdiplus\Gdiplus>
#Include <LinearGradient>       ; crea imagen para fondos con degradado
#Include <ImageButton>          ; asigna imagenes a botones
#Include <ComboBox>             ; funciones para controles combobox
#Include <RunAsAdmin>           ; función para ejecutar el script como administraor
#Include <TaskDialog>           ; diálogo de tareas (un MsgBox más completo)
#Include <DirGetParent>         ; función para recuperar el directorio superior
#Include <Eval>                 ; evalúa expresiones en una cadena
#Include <SaveFile>             ; diálogo para guardar archivos
#Include <ChooseFile>           ; diálogo para seleccionar archivos
#Include <GuiControlTips>       ; para añadir ToolTips cuando se posiciona le cursor en un control
#Include <GetFullPathName>      ; función para recuperar la ruta absoluta teniendo en cuenta el directorio de trabajo actual
#Include <GetBinaryType>        ; para recuperar el tipo de archivo binario
#Include <Language>             ; algunas funciones de idiomas
#Include <Subprocess>           ; para crear sub-procesos : thanks «coffee» -> https://autohotkey.com/boards/viewtopic.php?f=44&t=48953#p223878

; Include\
#Include Include
#Include Compiler.ahk          ; para compilar el script
#Include ScriptParser.ahk      ; para analizar y procesar el script
#Include Resources.ahk         ; para leer y modificar recursos en el ejecutable
#Include CommandLine.ahk       ; para procesar la línea de comandos
#Include Std.ahk               ; funciones varias
#Include VersionRes.ahk        ; para crear/modificar la estructura VS_VERSIONINFO (recurso de versión)





; =====================================================================================================================================================
; INICIO
; =====================================================================================================================================================
; comprobamos sistema operativo (necesario WIN_V+)
global g_osv := StrSplit(A_OSVersion, ".")
;global   WIN_V := [6,0]
;     ,   WIN_7 := [6,1]
;     ,   WIN_8 := [6,2]
;     , WIN_8_1 := [6,3]
;     ,  WIN_10 := [10,0]

If ( !OSVersion(6) )    ; WIN_V+
    Util_Error("Sistema operativo no soportado.", A_OSVersion, 196)

A_ScriptName := "Ahk2Exe Compilador"
global Title := "Ahk2Exe para AutoHotkey v" . A_AhkVersion . " | Script a EXE Conversor (" . (A_PtrSize==4?"32-Bit)":"64-Bit)")

; variables super-globales
global     g_data := { define: {} }
      ,       g_k := 0, g_v := 0    ; for g_k, g_v in Obj
      , g_ahkpath := Util_GetAhkPath()
global     Cfg := Util_LoadCfg()
global    Gdip := new Gdiplus
global ERROR := FALSE
global BE_QUIET := FALSE


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

global NO_COMPRESSION := 0
     ,            UPX := 1
     ,         MPRESS := 2

global SUBLANG_ENGLISH_US := 0x0409    ; https://msdn.microsoft.com/en-us/library/windows/desktop/dd318693(v=vs.85).aspx

global       TD_ERROR_ICON := 0xFFFE,   ERROR_ICON := [0, TD_ERROR_ICON]
     ,     TD_WARNING_ICON := 0xFFFF, WARNING_ICON := [0, TD_WARNING_ICON]
     , TD_INFORMATION_ICON := 0xFFFD,    INFO_ICON := [0, TD_INFORMATION_ICON]
     ,      TD_SHIELD_ICON := 0xFFFC,  SHIELD_ICON := [0, TD_SHIELD_ICON]

global IMAGE_SUBSYSTEM_WINDOWS_GUI := 2
    ,  IMAGE_SUBSYSTEM_WINDOWS_CUI := 3

; Exit Codes
     ; ---- GENERAL ----
global           ERROR_SUCCESS := 0x00    ; todas las operaciones se han realizado con éxito
     ,           UNKNOWN_ERROR := 0x01    ; error desconocido
     ,     ERROR_NOT_SUPPORTED := 0x02    ; no soportado
     , ERROR_INVALID_PARAMETER := 0x03    ; los parámetros pasados son inválidos
     ; ---- APERTURA DE ARCHIVOS ----
     ,        ERROR_SOURCE_NO_SPECIFIED := 0x10    ; el archivo fuente no se ha especificado
     ,           ERROR_SOURCE_NOT_FOUND := 0x11    ; el archivo fuente no existe
     ,         ERROR_CANNOT_OPEN_SCRIPT := 0x12    ; no se ha podido abrir el archivo fuente script (incluyendo includes) para lectura
     ,         ERROR_BIN_FILE_NOT_FOUND := 0x13    ; el archivo BIN no existe
     ,       ERROR_BIN_FILE_CANNOT_OPEN := 0x14    ; no se ha podido abrir el archivo BIN para lectura
     ,        ERROR_MAIN_ICON_NOT_FOUND := 0x15    ; el icono principal no existe
     ,      ERROR_MAIN_ICON_CANNOT_OPEN := 0x16    ; no se ha podido abrir el icono principal para lectura
     ,          ERROR_INVALID_MAIN_ICON := 0x17    ; el icono principal es inválido
     ,     ERROR_INCLUDE_FILE_NOT_FOUND := 0x18    ; el archivo a incluir no existe
     ,      ERROR_INCLUDE_DIR_NOT_FOUND := 0x19    ; el directorio a incluir no existe
     , ERROR_FILEINSTALL_FILE_NOT_FOUND := 0x20    ; el archivo a incluir especificado en FileInstall no existe
     ,    ERROR_RESOURCE_FILE_NOT_FOUND := 0x21    ; el archivo de recurso a incluir no existe
     ,         ERROR_DEST_DIR_NOT_FOUND := 0x22    ; el directorio destino para el archivo destino EXE no existe
     ; ---- ESCRITURA DE ARCHIVOS ----
     ,   ERROR_CANNOT_COPY_BIN_FILE := 0x30    ; no se ha podido copiar el archivo BIN al destino
     ,   ERROR_CANNOT_OPEN_EXE_FILE := 0x31    ; no se ha podido abrir el archivo destino EXE para escritura
     , ERROR_CANNOT_CREATE_DEST_DIR := 0x32    ; no se ha podido crear el directorio destino para archivo destino EXE
     ; ---- SINTAXIS ----
     ,   ERROR_INVALID_DIRECTIVE_SYNTAX := 0x50    ; la sintaxis de la directiva es inválida
     ,  ERROR_UNKNOWN_DIRECTIVE_COMMAND := 0x51    ; la directiva especificada es desconocida
     , ERROR_INVALID_FILEINSTALL_SYNTAX := 0x52    ; la sintaxis de FileInstall es inválida
     ,             ERROR_INVALID_SYNTAX := 0x53    ; la sintaxis en el código fuente AHK es inválida
     ; ---- OTROS ----
     , NO_EXIT := 0x00

; https://msdn.microsoft.com/en-us/library/aa364819(VS.85).aspx
global SCS_32BIT_BINARY := 0    ; A 32-bit Windows-based application
     ;,   SCS_DOS_BINARY := 1    ; An MS-DOS – based application
     ;,   SCS_WOW_BINARY := 2    ; A 16-bit Windows-based application
     ;,   SCS_PIF_BINARY := 3    ; A PIF file that executes an MS-DOS – based application
     ;, SCS_POSIX_BINARY := 4    ; A POSIX – based application
     ;, SCS_OS216_BINARY := 5    ; A 16-bit OS/2-based application
     , SCS_64BIT_BINARY := 6    ; A 64-bit Windows-based application


; determina si se pasaron parámetros al compilador
global CMDLN := ObjLength(A_Args)
If (CMDLN)
    ExitApp ProcessCmdLine()


; comprobamos instancia (no permitir más de una instancia de la interfaz gráfica GUI)
If (WinExist(Title))
    WinShow(Title), WinMoveBottom(Title), WinActivate(Title), ExitApp()


; variables super-globales necesarias cuando se muestra la interfaz GUI
global Gui := 0        ; almacena el objeto GUI de la ventana principal
global g_dpix := 0, g_dpiy := 0
global wctrltimer := 0, waterctrldll := {path: A_ScriptDir . "\waterctrl.dll"}
global ButtonStyle := [[3, 0xFEF5BF, 0xFEE88A, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [3, 0xFEDF63, 0xFED025, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [5, 0xFEDF63, 0xFED025, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [0, 0xFEF5BF, "Black", 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1], [3, 0xFEF5BF, 0xFEE88A, 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 2], [0, 0xFEF5BF, "Black", 0x3E566F, 5, 0xFEF5BF, 0xFED22C, 1]]
global ButtonStyle2 := [[0, 0xE1E1E1, "Black", 0x151515, 5, 0xFFFFFF, 0xADADAD, 1], [0, 0xE5F1FB, "Black", 0x151515, 5, 0xFFFFFF, 0x007CE1, 1], [0, 0xCCE4F7, "Black", 0x151515, 5, 0xFFFFFF, 0x005499, 1], [0, 0xE1E1E1, "Black", 0x808080, 5, 0xFFFFFF, 0xADADAD, 1], [0, 0xE1E1E1, "Black", 0x151515, 5, 0xFFFFFF, 0x007CE1, 2], [0, 0xE5F1FB, "Black", 0x151515, 1, 0xFFFFFF, 0x007CE1, 1]]


; constantes
global     MAX_SRCITEMLIST := 10
global     MAX_ICOITEMLIST := 10
global WATER_BLOB_INTERVAL := 2500

global WIN_MINIMIZED := -1
     ,    WIN_NORMAL :=  0
     , WIN_MAXIMIZED :=  1

global     VK_F1 := 0x70    ; F1 key                       || https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
     , VK_DELETE := 0x2E    ; DEL key
     ,   VK_BACK := 0x08    ; BACKSPACE key

global COLOR_3DFACE := DllCall("User32.dll\GetSysColor", "Int", 15, "UInt")    ; color por defecto de las ventanas GUI (BGR)
       COLOR_3DFACE := (COLOR_3DFACE & 255) << 16 | (COLOR_3DFACE & 65280) | (COLOR_3DFACE >> 16)    ; RGB

global MONITOR_DEFAULTTONEAREST := 0x00000002


; comprobamos permisos
If (!FileOpen("~tmp", "w"))
    If (!RunAsAdmin())
        Util_Error("Error de permisos.`nIntente ejecutar el compilador como Administrador.",, TRUE)
FileDelete(A_ScriptDir . "\~tmp")


; creamos la interfaz de usuario (GUI)
Gui := GuiCreate("-DPIScale -Resize -MaximizeBox +MinSize690x481 +E0x00000400", Title)
    ERROR_ICON[1] := WARNING_ICON[1] := INFO_ICON[1] := SHIELD_ICON[1] := Gui.Hwnd
    GCT := new GuiControlTips(Gui)
    GCT.SetTitle("Ahk2Exe", 1)
    GCT.SetFont("Italic", "Segoe UI")
Gui.SetFont("s9", "Segoe UI")

hMonitor := DllCall("User32.dll\MonitorFromWindow", "Ptr", Gui.Hwnd, "UInt", 0x00000002)    ; MONITOR_DEFAULTTONEAREST = 0x00000002
If ( OSVersion(6, 1) )    ; WIN_8_1+
    DllCall("Shcore.dll\GetDpiForMonitor", "Ptr", hMonitor, "Int", 0, "UIntP", g_dpix, "UIntP", g_dpiy)    ; MDT_EFFECTIVE_DPI = 0
Else
{
    MONITORINFOEX := ""
    NumPut(VarSetCapacity(MONITORINFOEX, 104, 0), MONITORINFOEX, 0, "UInt")
    DllCall("User32.dll\GetMonitorInfoW", "Ptr", hMonitor, "UPtr", &MONITORINFOEX)
    hDC := DllCall("Gdi32.dll\CreateDC", "Str", StrGet(&MONITORINFOEX+40), "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
    g_dpix := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 88)    ; LOGPIXELSX = 88
    g_dpiy := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 90)    ; LOGPIXELSY = 90
    DllCall("Gdi32.dll\DeleteDC", "Ptr", hDC)
}

;@Ahk2Exe-IgnoreBegin32 1    // Ignora la línea "If (A_PtrSize..." en la compilación de 32-bit
;@Ahk2Exe-IgnoreBegin64 3    // Ignora las líneas "If...", "Gui.AddText..." y "Else" en la compilación de 64-bit
If (A_PtrSize == 4)    ; solo la versión de 32-Bit soporta waterctrl
    Gui.AddText("x0 y0 w690 h110 vlogo"), Util_LoadWaterCtrl(), Util_EnableWater(Gui.Control["logo"].Hwnd, Util_LoadLogo())
;@Ahk2Exe-IgnoreBegin32 2    // Ignora las líneas "Else" y "Gui.AddPic..." en la compilación de 32-bit
Else
    Gui.AddPic("x0 y0 w690 h110 vlogo", "HBITMAP:" . Util_LoadLogo())
Gui.AddButton("x318 y4 w368 h100 vbinfo Left", "  ©2004-2009 Chris Mallet`n  ©2008-2011 Steve Gray (Lexikos)`n  ©2011-2018 fincs`n  ©2018-2018 Flipeador`n`n  Nota: La compilación no garantiza la protección del código fuente.")
    DllCall("User32.dll\SetParent", "Ptr", Gui.Control["binfo"].Hwnd, "Ptr", Gui.Control["logo"].Hwnd)
    ImageButton.Create(Gui.Control["binfo"].Hwnd, [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEE786, 0xFEF5BF, 0x2D4868, 5, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1])

Gui.AddButton("x585 y111 w100 h20 vbdpi", "High-DPI Settings")
    Gui.Control["bdpi"].SetFont("s" . DPI(8,,0) . " w" . DPI(400,0,1.1), "Tahoma")
    Gui.Control["bdpi"].OnEvent("Click", "HighDPIBtn")
    ImageButton.Create(Gui.Control["bdpi"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bdpi"], "Ajusta la interfaz para adaptarse a pantallas de alto DPI (PPP)")

Gui.AddTab3("x0 y110 w692 h304 vtab", "General|Registros|AutoHotkey")
    Gui.Control["tab"].OnEvent("Change", "Gui_Tab")

Gui.Control["tab"].UseTab(1)
Gui.AddGroupBox("x20 y140 w650 h90", "Parámetros requeridos")
Gui.AddText("x30 y165 w120 h20 +0x200", "Fuente (archivo script)")
Gui.AddComboBox("x180 y165 w435 h22 vddlsrc R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastSrcList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16,  0)
    CB_SetItemHeight(Gui.Control["ddlsrc"], 16, -1)
    Gui.Control["ddlsrc"].OnEvent("Change", "Util_DDLSrc")
    CB_SetSelection(Gui.Control["ddlsrc"], CB_FindString(Gui.Control["ddlsrc"], Cfg.LastSrcFile))
    GCT.Attach(Gui.Control["ddlsrc"], "Buscar y seleccionar el archivo fuente en la lista")
    GCT.Attach(CB_GetInfo(Gui.Control["ddlsrc"]).Edit, "El archivo fuente script a compilar`nPresione Supr para eliminar el elemento de la lista")
Gui.AddButton("x620 y165 w40 h22 vbsrc", "•••")
    Gui.Control["bsrc"].OnEvent("Click", "Gui_SrcButton")
    ImageButton.Create(Gui.Control["bsrc"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bsrc"], "Buscar y seleccionar un archivo fuente")
Gui.AddText("x30 y192 w120 h20 +0x200", "Destino (archivo exe)")
Gui.AddEdit("x180 y192 w435 h20 vedest")
    Gui.Control["edest"].OnEvent("Change", () => SetTimer("Util_UpdateSrc", Gui.Control["edest"].Text == "" ? -1000 : "Off"))
    GCT.Attach(Gui.Control["edest"], "El archivo destino compilado EXE`nSe tene en cuenta el directorio del archivo fuente")
Gui.AddButton("x620 y192 w40 h20 vbdest", "•••")
    Gui.Control["bdest"].OnEvent("Click", "Gui_DestButton")
    ImageButton.Create(Gui.Control["bdest"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bdest"], "Seleccionar el archivo destino")
Gui.AddGroupBox("x20 y239 w650 h90", "Parámetros opcionales")
Gui.AddText("x30 y262 w120 h20 +0x200", "Icono (archivo ico)")
Gui.AddComboBox("x180 y262 w435 h22 vddlico R6 Choose1 +0x400 +0x100", RTrim(StrReplace(Cfg.LastIconList, "`r`n", "|"), "|"))
    CB_SetItemHeight(Gui.Control["ddlico"], 16,  0)
    CB_SetItemHeight(Gui.Control["ddlico"], 16, -1)
    CB_SetSelection(Gui.Control["ddlico"], CB_FindString(Gui.Control["ddlico"], Cfg.LastIconFile))
    GCT.Attach(Gui.Control["ddlico"], "Buscar y seleccionar un icono en la lista")
    GCT.Attach(CB_GetInfo(Gui.Control["ddlico"]).Edit, "El icono principal del archivo compilado`nPresione Supr para eliminar el elemento de la lista")
Gui.AddButton("x620 y262 w40 h22 vbico", "•••")
    Gui.Control["bico"].OnEvent("Click", "Gui_IcoButton")
    ImageButton.Create(Gui.Control["bico"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bico"], "Buscar y seleccionar un archivo icono")
Gui.AddText("x32 y290 w120 h22 +0x200", "Archivo base (bin)")
Gui.AddDDL("x180 y290 w405 h22 vddlbin R6 +0x400")
    CB_SetItemHeight(Gui.Control["ddlbin"], 16,  0)
    CB_SetItemHeight(Gui.Control["ddlbin"], 16, -1)
    Util_LoadBinFiles(Cfg.LastBinFile)
    GCT.Attach(Gui.Control["ddlbin"], "El archivo base BIN AutoHotkey")
Gui.AddButton("x592 y290 w68 h22 vbrefbin", "Refrezcar")
    Gui.Control["brefbin"].OnEvent("Click", () => Util_LoadBinFiles(Cfg.LastBinFile))
    ImageButton.Create(Gui.Control["brefbin"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["brefbin"], "Volver a leer los archivos BIN")
Gui.AddGroupBox("x20 y338 w650 h61", "Compresión del archivo exe resultante")
Gui.AddText("x30 y362 w125 h22 +0x200", "Método de compresión")
Gui.AddDDL("x180 y362 w405 h22 vddlcomp R4 +0x400")
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16,  0)
    CB_SetItemHeight(Gui.Control["ddlcomp"], 16, -1)
    Util_LoadCompressionFiles(Cfg.Compression)
    GCT.Attach(Gui.Control["ddlcomp"], "El método de compresión del archivo EXE")
Gui.AddButton("x592 y362 w68 h22 vbdownload", "Descargar")
    Gui.Control["bdownload"].OnEvent("Click", () => InStr(CB_GetText(Gui.Control["ddlcomp"]), "upx") ? Run("https://upx.github.io/") : InStr(CB_GetText(Gui.Control["ddlcomp"]), "mpress") ? Run("http://www.matcode.com/mpress.htm") : 0)
    ImageButton.Create(Gui.Control["bdownload"].Hwnd, ButtonStyle2*)
    GCT.Attach(Gui.Control["bdownload"], "Ir a la página oficial para descargar la herramienta seleccionada")

Gui.Control["tab"].UseTab(2)
Gui.AddListView("x2 y138 w686 h272 vlvlog -E0x200", "ID|Mensaje|Archivo|Línea|Tiempo")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", Gui.Control["lvlog"].Hwnd, "Str", "Explorer", "UPtr", 0, "UInt")
    Gui.Control["lvlog"].SetImageList(g_data.log_il:=IL_Create(1))
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32516))    ; IDI_INFORMATION
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32515))    ; IDI_WARNING
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32513))    ; IDI_ERROR
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32518))    ; IDI_SHIELD
    IL_Add(g_data.log_il, "shell32.dll", -51380)    ; INCLUDE

Gui.Control["tab"].UseTab(3)
Gui.AddPic("x0 y134 w690 h278 vahk")
    LinearGradient(Gui.Control["ahk"], [0xFF0000,0xFFFF00,0x00FF00,0x00FFFF,0x0000FF])
Gui.AddText("x0 y134 w690 h278 vahk2 Center BackgroundTrans +0x200", "AutoHotkey")
    Try Gui.Control["ahk2"].SetFont("Bold s75", "Segoe Print")
    Catch
        Gui.Control["ahk2"].SetFont("Bold s75", "Arial")

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
Gui.AddStatusBar("vsb +0x100")
    GCT.Attach(Gui.Control["sb"], "Muestra información del estado actual")
    WinSetTransColor(Format("{:06X}", COLOR_3DFACE), "ahk_id" . Gui.Control["sb"].Hwnd)
    Util_Status("Inicializando ..")

Gui.Show("w690 h481")
    Gui.OnEvent("Close", "ExitApp")
    Gui.OnEvent("Size", "Gui_Size")
    Gui.OnEvent("Escape", () => MsgBox("¿Esta seguro de que desea cerrar la aplicación?",, 0x2024) == "Yes" ? ExitApp() : 0)
    Gui.OnEvent("DropFiles", "Gui_DropFiles")


; registramos mensajes del sistema
OnMessage(0x100, "WM_KEYDOWN")    ; cuando se presiona una tecla que no sea del sistema (alt).
OnMessage(0x200, "WM_MOUSEMOVE")  ; cuando se mueve el cursor en la ventana
OnExit("_OnExit")    ; al terminar

Util_UpdateSrc()
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
    Gui.Control["edest"].Text := ""
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
}

Util_DDLSrc()
{
    Gui.Control["edest"].Text := ""
    Util_UpdateSrc()
}

; I know, this is horrible - for the moment it stays like this
HighDPIBtn(Btn)    ; sin terminar (este método no es muy eficiente. lo correcto sería ajustar las dimensiones y coordenadas de los controles)
{
    Btn.Visible := FALSE
    For g_k, g_v in Gui
    {
        try g_v.SetFont(g_v.Name == "ahk2" ? "s" . DPI(75,,0) . " Bold" : "s" . DPI(9) . " w" . DPI(400,0,1.1), "Segoe UI")
        If (g_v.Type == "Button")   
            If InStr("bclosebcompilebgitbabout", g_v.Name)
                ImageButton.Create(g_k, ButtonStyle*)
            Else If (g_v.Name == "binfo")
                    ImageButton.Create(g_k, [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEE786, 0xFEF5BF, 0x2D4868, 5, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1])
            Else
                ImageButton.Create(g_k, ButtonStyle2*)
    }
    WinRedraw("ahk_id" . Gui.Hwnd)
}

Gui_SrcButton()
{
    Local foo := new GuiDisable("Mostrando diálogo para seleccionar archivo fuente AHK..")
    Local File := CB_GetSelection(Gui.Control["ddlsrc"]) == -1 ? Cfg.LastSrcFile : CB_GetText(Gui.Control["ddlsrc"])
        , File := ChooseFile([Gui.Hwnd,"Ahk2Exe - Seleccionar archivo fuente"], File, {"Todos los archivos": "*.*", Scripts: "#*.ahk"},, 0x1200)
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
    Local File := Gui.Control["edest"].Text == "" ? (CB_GetSelection(Gui.Control["ddlsrc"]) == -1 ? DirGetParent(Cfg.LastExeFile) . "\" : CB_GetText(Gui.Control["ddlsrc"])) : GetFullPathName(Gui.Control["edest"].Text, DirGetParent(CB_GetText(Gui.Control["ddlsrc"])))
        , File := SaveFile([Gui.Hwnd,"Ahk2Exe - Guardar como"], SubStr(File, -4) = ".ahk" ? SubStr(File, 1, -4) . ".exe" : File, {Ejecutables: "#*.exe"})
    If (File)
    {
        If (PATH(File).Ext = "exe")
            Gui.Control["edest"].Text := File
        Else
            Util_Error("El archivo destino debe ser un archivo ejecutable EXE.", File)
    }
}

Gui_CompileButton()
{
    ERROR := FALSE
    Util_ClearLog()

    If (A_IsAdmin)
        Util_AddLog("*INFO", "El compilador se está ejecutando con permisos de Administrador")

    ObjRawSet(g_data, "IgnoreSetMainIcon", TRUE)
    ObjRawSet(g_data, "IgnoreBinFile", TRUE)
    ObjRawSet(g_data, "IcoFile", CB_GetText(Gui.Control["ddlico"]))

    Local BinaryType := 0
    ObjRawSet(g_data, "BinFile", Util_CheckBinFile(CB_GetText(Gui.Control["ddlbin"]), BinaryType))
    ObjRawSet(g_data, "Compile64", BinaryType == SCS_64BIT_BINARY)
    If (!g_data.BinFile)
        Return Util_Error("El archivo BIN no existe.", g_data.BinFile)
    ObjRawSet(g_data, "BinVersion", FileGetVersion(g_data.BinFile))
    ObjRawSet(g_data, "SyntaxCheck", TRUE)

    Local Script := CB_GetText(Gui.Control["ddlsrc"])
        ,   Data := PreprocessScript(Script)

    If (Data)
    {
        If (AhkCompile(Data))
            Util_AddLog("INFO", "La compilación a finalizado con éxito", DirGetParent(Script) . "\" . PATH(Script).FNNE . ".exe")
          , OutputDebug("Successful compilation.")
        Else
            Util_AddLog("ERROR", "Ha ocurrido un error durante la compilación", Script)
          , OutputDebug("Failed compilation.")
    }
    Else
        Util_AddLog("ERROR", "Ha ocurrido un error durante el procesado del script", Script)
      , OutputDebug("Failed compilation.")

    Util_AutoHdrLog()
    Util_Status()
}





; =====================================================================================================================================================
; EVENTOS DEL SISTEMA
; =====================================================================================================================================================
WM_KEYDOWN(VKCode, lParam)
{
    Local FocusedCtrl := Gui.FocusedCtrl

    If (VKCode == VK_F1)
    {
        Util_Status("Mostrando Acerca de.. (F1)")
        TaskDialog(INFO_ICON, [Gui.Title,"Acerca de.."], ["Ahk2Exe - Script to EXE Converter`n-----------------------------------`n`n"
                                                        . "Original version:`n"
                                                        . "Copyright ©1999-2003 Jonathan Bennett & AutoIt Team`n"
                                                        . "Copyright ©2004-2009 Chris Mallet`n"
                                                        . "Copyright ©2008-2011 Steve Gray (Lexikos)`n`n"
                                                        . "Script rewrite:`n"
                                                        . "Copyright ©2011-2018 fincs`n"
                                                        . "Copyright ©2018-2018 Flipeador"
                                                        , "flipeador@gmail.com"] )
        Util_Status()
    }

    Else If (VKCode == VK_DELETE)
    {
        If (FocusedCtrl.Name == "ddlsrc")
            CB_Delete(Gui.Control["ddlsrc"], CB_GetText(Gui.Control["ddlsrc"]), 1), CB_SetText(Gui.Control["ddlsrc"], "")
        Else If (FocusedCtrl.Name == "ddlico")
            CB_Delete(Gui.Control["ddlico"], CB_GetText(Gui.Control["ddlico"]), 1), CB_SetText(Gui.Control["ddlico"], "")
    }
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646280(v=vs.85).aspx





WM_MOUSEMOVE(VKCode, Coords)
{
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms645616(v=vs.85).aspx





_OnExit(ExitReason, ExitCode)
{
    Util_Status("Adios ...  =D")
    If (wctrltimer)
        SetTimer(wctrltimer, "Delete")
    DllCall("User32.dll\AnimateWindow", "Ptr", Gui.HWnd, "UInt", 350, "UInt", 0x00080000|0x00010000)

    Util_SaveCfg()

    Return 0    ; EXIT
}





; =====================================================================================================================================================
; FUNCIONES
; =====================================================================================================================================================
Util_Error(Message, ExpandedInfo := "", ExitCode := FALSE)
{
    ERROR := TRUE
    Util_Status("Ha ocurrido un error y las operaciónes an sido abortadas.")
    OutputDebug "[" . FormatTime(, "yyyyMMddhhmmss") . "] " . Message . " | " . ExpandedInfo
    If (!BE_QUIET)
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

Util_LoadBinFiles(Default)
{
    CB_Delete(Gui.Control["ddlbin"])
    Loop Files, "*.bin", "F"
        CB_Insert(Gui.Control["ddlbin"], "v" . FileGetVersion(A_LoopFileFullPath) . A_Space . SubStr(A_LoopFileName, 1, -4))
    CB_SetSelection(Gui.Control["ddlbin"], CB_FindString(Gui.Control["ddlbin"], SubStr(Default, 1, -4),, 2))
}

Util_CheckBinFile(Name, ByRef BinaryType := "")
{
    Local BinFile := RegExReplace(Name, "^v(\d\.?)+\s*")    ; remueve la versión del archivo al inicio "v2.0.0.0 XXX..." --> "XXX..."
    If (PATH(BinFile).Ext == "")
        BinFile .= ".bin"

    BinaryType := GetBinaryType(BinFile := GetFullPathName(BinFile, A_ScriptDir))
    Return BinaryType == SCS_32BIT_BINARY || BinaryType == SCS_64BIT_BINARY ? BinFile : FALSE
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
    Return IS_FILE(Name) ? "v" . FileGetVersion(Name) . A_Space : ""
}

Util_UpdateSrc()
{
    SetTimer("Update", -250)
    Update()
    {
        Util_Status("Leyendo archivo fuente ..")
        Local Data := QuickParse(CB_GetText(Gui.Control["ddlsrc"]))
        CB_SetText(Gui.Control["ddlico"], "")
        If (Data)
        {
            If (Data.MainIcon != "")
                CB_Insert(Gui.Control["ddlico"], Data.MainIcon,, 0), CB_SetSelection(Gui.Control["ddlico"], Data.MainIcon, 0)
            If (Data.BinFile != "")
                CB_SetSelection(Gui.Control["ddlbin"], Data.BinFile, 2)
            If (Trim(Gui.Control["edest"].Text) == "")
                Gui.Control["edest"].Text := PATH(Data.Script).FNNE . ".exe"
        }
        Util_Status()
    }
}

Util_AddLog(What, Message, Script := "-", Line := "-")
{
    static Icon := {INFO: 1, ADVERTENCIA: 2, ERROR: 3, "*INFO": 4, INCLUDE: 5}
    if (!CMDLN)
        Gui.Control["lvlog"].Add("Icon" . Icon[What], What, Message, Script, Line, FormatTime(, "dd/MM/yyyy hh:mm:ss"))
}

Util_ClearLog()
{
    Gui.Control["lvlog"].Delete()
}

Util_AutoHdrLog()
{
    Loop 4
        Gui.Control["lvlog"].ModifyCol(A_Index, "AutoHdr")
}

Util_LoadLogo()
{
    Local hBitmap := LoadImage(-1, "LOGO.BMP")

    ;@Ahk2Exe-IgnoreBegin64 9
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

;@Ahk2Exe-IgnoreBegin64
Util_LoadWaterCtrl()
{
    If (IS_FILE(waterctrldll.path))
        Return waterctrldll.hModule := LoadLibrary(waterctrldll.path)

    ;@Ahk2Exe-IgnoreBegin 2
    If (!A_IsCompiled)
        Util_Error("No se ha encontrado waterctrl.dll.", waterctrldll.path, 2)

    If (IS_FILE(waterctrldll.path := A_Temp . "\waterctrl.dll") && FileGetSize(waterctrldll.path) == 16896)
        Return waterctrldll.hModule := LoadLibrary(waterctrldll.path)

    Local hExe := LoadLibrary(A_ScriptFullPath, 2), Size := 0
    FileOpen(waterctrldll.path, "w", "UTF-8-RAW").RawWrite(LoadResource3(hExe, RT_RCDATA, "WATERCTRL.DLL", Size), Size)
    Return FreeLibrary(hExe) * 0 + (waterctrldll.hModule := LoadLibrary(waterctrldll.path))
}

Util_EnableWater(Hwnd, hBitmap)
{
    For g_k, g_v in ["enablewater","disablewater","waterblob","flattenwater","setwaterparent"]
        waterctrldll[g_v] := GetProcAddress(waterctrldll.hModule, g_k)
    DllCall(waterctrldll.enablewater, "Ptr", Gui.Hwnd, "Int", 0, "Int", 0, "Ptr", hBitmap, "Int", 3, "Int", 20)
    DllCall(waterctrldll.setwaterparent, "Ptr", Hwnd)
    If (WATER_BLOB_INTERVAL)
        SetTimer(wctrltimer := () => DllCall(waterctrldll.waterblob, "Int", Random(0, 690), "Int", Random(0, 110), "Int", Random(3, 12), "Int", Random(20, 75)), WATER_BLOB_INTERVAL)
} ; https://autohotkey.com/boards/viewtopic.php?t=3302
;@Ahk2Exe-IgnoreEnd64

Util_GetAhkPath()
{
    Local AhkPath := DirGetParent(A_ScriptDir) . "\AutoHotkeyU" . (A_Is64bitOS?64:32) . ".exe"
    If (IS_FILE(AhkPath))
        Return AhkPath

    If (IS_FILE(AhkPath := DirGetParent(A_ScriptDir) . "\AutoHotkey.exe"))
        Return AhkPath

    If (IS_FILE(AhkPath := A_ScriptDir . "\AutoHotkey.exe"))
        Return AhkPath

    If (IS_FILE(AhkPath := A_ProgramFiles . "\AutoHotkey\AutoHotkeyU" . (A_Is64bitOS?64:32) . ".exe"))
        Return AhkPath

    If (IS_FILE(AhkPath := A_ProgramFiles . "\AutoHotkey\AutoHotkey.exe"))
        Return AhkPath

    AhkPath := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
    If (IS_FILE(AhkPath))
        Return AhkPath

    AhkPath := RegRead("HKCU\SOFTWARE\AutoHotkey", "InstallDir")
    If (IS_FILE(AhkPath))
        Return AhkPath

    Return ""
}

Util_Status(Info := "Listo. [posiciona el cursor sobre un control para ver información]")
{
    If (!CMDLN)
        Gui.Control["sb"].SetText(Info)
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
        Util_Status()
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
