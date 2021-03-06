﻿;@Ahk2Exe-SetName             Ahk2Exe
;@Ahk2Exe-SetOrigFilename     Ahk2Exe.exe
;@Ahk2Exe-SetDescription      AutoHotkey v2 Script Compiler
;@Ahk2Exe-SetFileVersion      1.11.3.8    ; major.minor.maintenance.build
;@Ahk2Exe-SetCompanyName      AutoHotkey
;@Ahk2Exe-SetCopyright        Copyright (c) 2004-2018
;@Ahk2Exe-SetComments         [2018-08-12] https://github.com/flipeador/Ahk2Exe

;;@Ahk2Exe-VerInfo FileDescription, Compilador de scripts para AutoHotkey v2 en español, 0C0A04B0

;@Ahk2Exe-SetMainIcon Ahk2Exe.ico      ; icono principal del ejecutable compilado

;@Ahk2Exe-AddResource logo.bmp         ; imagen logo de AHK
;@Ahk2Exe-AddResource waterctrl.dll    ; para el efecto de agua en la imagen logo

;;@Ahk2Exe-PostExec MsgBox 'Done!',,*  ; mensaje de prueba mostrado al finalizar la compilación con éxito
;;@Ahk2Exe-RequireAdmin                ; indica que el compilador requiere permisos administrativos (obligatorio)
;;@Ahk2Exe-ConsoleApp                  ; quita todo lo referido a la interfaz gráfica y permite el uso del compilador únicamente por línea de parámetros





; =====================================================================================================================================================
; CONFIGURACIÓN DE INICIO
; =====================================================================================================================================================
#Warn
#SingleInstance Off
;@Ahk2Exe-Keep #NoTrayIcon      ; ocultamos el icono en el área de notificación en el script compilado
;@Ahk2Exe-Keep #KeyHistory 0    ; desactivamos el historial de teclas en el script compilado

;@Ahk2Exe-Keep ListLines FALSE
DetectHiddenWIndows TRUE
;@Ahk2Exe-IgnoreBegin64 1    ; SetRegView no es necesario en compilaciones x64
SetRegView 64
;FileEncoding "UTF-8"         ; unicode (el script compilado siempre incluirá BOM)

;@Ahk2Exe-IgnoreBegin 1
TraySetIcon("Ahk2Exe.ico")





; =====================================================================================================================================================
; INCLUDES
; =====================================================================================================================================================
; Lib\
#Include <Gdiplus>
#Include <LinearGradient>       ; crea imagen para fondos con degradado
#Include <ImageButton>          ; asigna imagenes a botones
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
#Include <Tab>                  ; clase para controles Tab
#Include <ComboBoxEx>           ; clase para controles ComboBoxEx
#Include <DownloadText>         ; función para recuperar el texto desde URL
#Include <GetFileVersionInfo>   ; función para recuperar la información de la versión de un archivo

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
A_ScriptName := "Ahk2Exe Compilador"
global   Title := "Ahk2Exe para AutoHotkey v" . A_AhkVersion . " | Script a EXE Conversor (" . (A_PtrSize==4?"32-Bit)":"64-Bit)")

; variables super-globales
global     g_data := { Gui: {}, define: {} }
      ,       g_k := 0, g_v := 0    ; for g_k, g_v in Obj
      , g_ahkpath := Util_GetAhkPath()
global Cfg := Util_LoadCfg()
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
;@Ahk2Exe-ifdef _CONSOLEAPP
;@Ahk2Exe-Keep ERROR_ICON[1] := WARNING_ICON[1] := INFO_ICON[1] := SHIELD_ICON[1] := DllCall("Kernel32.dll\GetConsoleWindow", "Ptr")
;@Ahk2Exe-Keep TaskDialog(INFO_ICON, [Title,"Línea de parámetros"], "No ha especificado ningún parámetro.")
;@Ahk2Exe-Keep ExitApp
;@Ahk2Exe-endif

;@Ahk2Exe-ifndef _CONSOLEAPP
If (WinExist(Title))
    WinShow(Title), WinMoveBottom(Title), WinActivate(Title), ExitApp()


If (!A_IsAdmin && !FileOpen("~tmp", "w"))
    If (!RunAsAdmin())
        Util_Error("Error de permisos.`nIntente ejecutar el compilador como Administrador.",, TRUE)
FileDelete("~tmp")
Gdiplus.Startup()   ; inicializa Gdiplus


; variables super-globales necesarias cuando se muestra la interfaz GUI
global Gui := 0        ; almacena el objeto GUI de la ventana principal
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
     ,     VK_F5 := 0x74    ; F5 key
     , VK_DELETE := 0x2E    ; DEL key
     ,   VK_BACK := 0x08    ; BACKSPACE key


; barra de menu
g_data.Gui.MenuBar := MenuBarCreate()
g_data.Gui.MenuBar_File := MenuCreate()
g_data.Gui.MenuBar_File.Add("Compilar", "Gui_CompileButton")
g_data.Gui.MenuBar_File.SetIcon("Compilar", "shell32.dll", -167)
g_data.Gui.MenuBar_File.Add()
g_data.Gui.MenuBar_File.Add("Reiniciar", "Reload")
g_data.Gui.MenuBar_File.SetIcon("Reiniciar", "shell32.dll", -47)
g_data.Gui.MenuBar_File.Add("Salir", "ExitApp")
g_data.Gui.MenuBar_File.SetIcon("Salir", "shell32.dll", -240)
g_data.Gui.MenuBar.Add("Archivo", g_data.Gui.MenuBar_File)
g_data.Gui.MenuBar.SetIcon("Archivo", A_WinDir . "\explorer.exe")
g_data.Gui.MenuBar_Edit := MenuCreate()
g_data.Gui.MenuBar_Edit.Add("Refrezcar", () => Util_UpdateSrc())
g_data.Gui.MenuBar_Edit.SetIcon("Refrezcar", "shell32.dll", -16739)
g_data.Gui.MenuBar_Edit.Add()
g_data.Gui.MenuBar_Edit.Add("Limpiar la lista de archivos fuente", () => g_data.Gui.CBSrc.DeleteAll(""))
g_data.Gui.MenuBar_Edit.SetIcon("Limpiar la lista de archivos fuente", "shell32.dll", -261)
g_data.Gui.MenuBar_Edit.Add("Limpiar la lista de iconos", () => g_data.Gui.CBIco.DeleteAll("") . IL_Destroy(g_data.Gui.CBIco.SetImageList(IL_Create())))
g_data.Gui.MenuBar_Edit.SetIcon("Limpiar la lista de iconos", "shell32.dll", -261)
g_data.Gui.MenuBar.Add("Edición", g_data.Gui.MenuBar_Edit)
g_data.Gui.MenuBar.SetIcon("Edición", "shell32.dll", -182)
g_data.Gui.MenuBar_Help := MenuCreate()
g_data.Gui.MenuBar_Help.Add("Ir al sitio oficial de AutoHotkey", () => Run("https://autohotkey.com"))
g_data.Gui.MenuBar_Help.SetIcon("Ir al sitio oficial de AutoHotkey", "shell32.dll", -15)
g_data.Gui.MenuBar_Help.Add("Ir al sitio oficial del compilador en AutoHotkey", () => Run("https://autohotkey.com/boards/viewtopic.php?f=44&p=227964"))
g_data.Gui.MenuBar_Help.SetIcon("Ir al sitio oficial del compilador en AutoHotkey", "shell32.dll", -15)
g_data.Gui.MenuBar_Help.Add("Ir al sitio oficial del compilador en GitHub", () => Run("https://github.com/flipeador/Ahk2Exe"))
g_data.Gui.MenuBar_Help.SetIcon("Ir al sitio oficial del compilador en GitHub", "shell32.dll", -15)
g_data.Gui.MenuBar_Help.Add()
g_data.Gui.MenuBar_Help.Add("Comprobar actualizaciones de AutoHotkey", () => TaskDialog(INFO_ICON, [Title,"Actualizaciones.."], "Versión actual: " . GetFileVersionInfo(g_ahkpath).ProductVersion . "`nÚltima versión: " . DownloadText("https://autohotkey.com/download/2.0/version.txt")))
g_data.Gui.MenuBar_Help.SetIcon("Comprobar actualizaciones de AutoHotkey", "shell32.dll", -244)
g_data.Gui.MenuBar_Help.Add("Comprobar actualizaciones de Ahk2Exe", () => TaskDialog(INFO_ICON, [Title,"Actualizaciones.."], "Versión actual: " . (A_IsCompiled?GetFileVersionInfo(A_ScriptFullPath).FileVersion:FileRead("version.txt")) . "`nÚltima versión: " . DownloadText("https://raw.githubusercontent.com/flipeador/Ahk2Exe/master/version.txt")))
g_data.Gui.MenuBar_Help.SetIcon("Comprobar actualizaciones de Ahk2Exe", "shell32.dll", -244)
g_data.Gui.MenuBar_Help.Add()
g_data.Gui.MenuBar_Help.Add("Ver la ayuda de AutoHotkey", () => Run(DirGetParent(g_ahkpath) . "\AutoHotkey.chm",,"max"))
g_data.Gui.MenuBar_Help.SetIcon("Ver la ayuda de AutoHotkey", A_WinDir . "\hh.exe")
g_data.Gui.MenuBar_Help.Add("Acerca de..", Func("WM_KEYDOWN").Bind(0x70,0))
g_data.Gui.MenuBar_Help.SetIcon("Acerca de..", "HICON:" . LoadPredefinedIcon(32514))
g_data.Gui.MenuBar.Add("Ayuda", g_data.Gui.MenuBar_Help)
g_data.Gui.MenuBar.SetIcon("Ayuda", "HICON:" . LoadPredefinedIcon(32514))

; creamos la interfaz de usuario (GUI)
Gui := GuiCreate("-DPIScale -Resize -MaximizeBox +E0x400", Title)
    ERROR_ICON[1] := WARNING_ICON[1] := INFO_ICON[1] := SHIELD_ICON[1] := Gui.Hwnd
    GCT := new GuiControlTips(Gui)
    GCT.SetTitle("Ahk2Exe", 1)
    GCT.SetFont("Italic", "Segoe UI")
    Gui.MenuBar := g_data.Gui.MenuBar
Gui.SetFont("s9", "Segoe UI")

g_data.Gui.SB := Gui.AddStatusBar("+0x100")
    GCT.Attach(g_data.Gui.SB, "Muestra información del estado actual")
    g_data.Gui.SB.SetIcon("HICON:" . LoadPredefinedIcon(32516))    ; IDI_INFORMATION = 32516
    g_data.Gui.SB.SetFont(, "Courier New")
    g_data.Gui.sbpos := g_data.Gui.SB.Pos

;@Ahk2Exe-IgnoreBegin32 1    ; Ignora la línea "If (A_PtrSize..." en la compilación de 32-bit
;@Ahk2Exe-IgnoreBegin64 3    ; Ignora las líneas "If...", "Gui.AddText..." y "Else" en la compilación de 64-bit
If (A_PtrSize == 4)    ; solo la versión de 32-Bit soporta waterctrl
    g_data.Gui.TXLgo := Gui.AddText("x0 y0 w800 h110"), Util_LoadWaterCtrl(), Util_EnableWater(g_data.Gui.TXLgo.Hwnd, Util_LoadLogo(), 800, 110)
;@Ahk2Exe-IgnoreBegin32 2    ; Ignora las líneas "Else" y "Gui.AddPic..." en la compilación de 32-bit
Else
    g_data.Gui.TXLgo := Gui.AddPic("x0 y0 w800 h110", "HBITMAP:" . Util_LoadLogo())
Gui.AddButton("x395 y4 w400 h100 vbinfo Left", "  ©2004-2009 Chris Mallet`n  ©2008-2011 Steve Gray (Lexikos)`n  ©2011-2018 fincs`n  ©2018-2018 Flipeador`n`n  Nota: La compilación no garantiza la protección del código fuente.")
    DllCall("User32.dll\SetParent", "Ptr", Gui.Control["binfo"].Hwnd, "Ptr", g_data.Gui.TXLgo.Hwnd)
    ImageButton.Create(Gui.Control["binfo"].Hwnd, [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEE786, 0xFEF5BF, 0x2D4868, 5, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1], [0, 0xFEF5BF, 0xFEF5BF, 0x2D4868, 1, 0xFEF5BF, 0xFEF5BF, 1])

g_data.Gui.Tab := new Tab(Gui, "x0 y" . g_data.Gui.TXLgo.Pos.H . " w802", "General", "Registros", "Recursos", "Información de la versión") ;, "Variables")
g_data.Gui.Tab.SetImageList(IL_Create())
IL_Add(g_data.Gui.Tab.GetImageList(), A_IsCompiled ? A_ScriptFullPath : "Ahk2Exe.ico")
IL_Add(g_data.Gui.Tab.GetImageList(), A_WinDir . "\regedit.exe")
IL_Add(g_data.Gui.Tab.GetImageList(), "shell32.dll", -182)
IL_Add(g_data.Gui.Tab.GetImageList(), "shell32.dll", -174)
IL_Add(g_data.Gui.Tab.GetImageList(), "shell32.dll", -154)
Loop g_data.Gui.Tab.GetCount()
    g_data.Gui.Tab.SetItemImage(A_Index-1, A_Index-1)
g_data.Gui.TabDA := g_data.Gui.Tab.GetDisplayArea()

g_data.Gui.Tab.UseTab(0)
g_data.Gui.CBSrc := new ComboBoxEx(Gui, "x" . (g_data.Gui.TabDA.GX+180) . " y" . (g_data.Gui.TabDA.GY+24) . " w" . (800-g_data.Gui.TabDA.GX-250) . " r10 +0x100", StrSplit(Cfg.LastSrcList,"`n")*)
    g_data.Gui.CBSrc.SetImageList(IL_Create())
    IL_Add(g_data.Gui.CBSrc.GetImageList(), A_IsCompiled ? A_ScriptFullPath : "Ahk2Exe.ico")
    g_data.Gui.CBSrc.Selected := g_data.Gui.CBSrc.FindString(Cfg.LastSrcFile)
    g_data.Gui.CBSrc.OnCommand(1, "DDLSrc_Event")    ; CBN_SELCHANGE
    g_data.Gui.CBSrc.OnCommand(5, "DDLSrc_Event")    ; CBN_EDITCHANGE
    GCT.Attach(g_data.Gui.CBSrc.GetComboControl(), "Buscar y seleccionar el archivo fuente en la lista")
    GCT.Attach(g_data.Gui.CBSrc.GetEditControl(), "El archivo fuente script a compilar`nPresione Supr para eliminar el elemento de la lista")
g_data.Gui.TXSrc := Gui.AddText("x" . (g_data.Gui.TabDA.GX+15) . " y" . g_data.Gui.CBSrc.Pos.Y . " w160 h" . g_data.Gui.CBSrc.Pos.H . " +0x200", "Fuente (archivo script)")
g_data.Gui.BTSrc := Gui.AddButton("x" . (g_data.Gui.TabDA.GX+g_data.Gui.TabDA.W-15-40) . " y" . g_data.Gui.CBSrc.Pos.Y . " w40 h" . g_data.Gui.CBSrc.Pos.H, "•••")
    g_data.Gui.BTSrc.OnEvent("Click", "Gui_SrcButton")
    ImageButton.Create(g_data.Gui.BTSrc.Hwnd, ButtonStyle2*)
    GCT.Attach(g_data.Gui.BTSrc, "Buscar y seleccionar un archivo fuente")
g_data.Gui.TXDst := Gui.AddText("x" . g_data.Gui.TXSrc.Pos.X . " y" . (g_data.Gui.CBSrc.Pos.Y+g_data.Gui.CBSrc.Pos.H+5) . " w160 h" . g_data.Gui.CBSrc.Pos.H . " +0x200", "Destino (archivo exe)")
g_data.Gui.EDDst := Gui.AddEdit("x" . (g_data.Gui.TabDA.GX+180) . " y" . g_data.Gui.TXDst.Pos.Y . " w" . g_data.Gui.CBSrc.Pos.W . " h" . g_data.Gui.CBSrc.Pos.H)
    g_data.Gui.EDDst.OnEvent("Change", () => SetTimer("Util_UpdateSrc", g_data.Gui.EDDst.Text == "" ? -1000 : "Off"))
    GCT.Attach(g_data.Gui.EDDst, "El archivo destino compilado EXE`nSe tene en cuenta el directorio del archivo fuente")
g_data.Gui.BTDst := Gui.AddButton("x" . g_data.Gui.BTSrc.Pos.X . " y" . g_data.Gui.TXDst.Pos.Y . " w40 h" . g_data.Gui.CBSrc.Pos.H, "•••")
    g_data.Gui.BTDst.OnEvent("Click", "Gui_DestButton")
    ImageButton.Create(g_data.Gui.BTDst.Hwnd, ButtonStyle2*)
    GCT.Attach(g_data.Gui.BTDst, "Seleccionar el archivo destino")
g_data.Gui.GB1 := Gui.AddGroupBox("x" . g_data.Gui.TabDA.GX . " y" . g_data.Gui.TabDA.GY . " w" . g_data.Gui.TabDA.W . " h" . (2*24+2*g_data.Gui.CBSrc.Pos.H+5), "Parámetros requeridos")

g_data.Gui.CBIco := new ComboBoxEx(Gui, "x" . g_data.Gui.CBSrc.Pos.X . " y" . (g_data.Gui.GB1.Pos.Y+g_data.Gui.GB1.Pos.H+15+24) . " w" . g_data.Gui.CBSrc.Pos.W . " r10 +0x100")
    g_data.Gui.CBIco.SetImageList(IL_Create())
    Loop Parse, Cfg.LastIconList, "`n"
        if (g_data.foo := IL_Add(g_data.Gui.CBIco.GetImageList(), A_LoopField))
            g_data.Gui.CBIco.Add(, A_LoopField, g_data.foo-1, g_data.foo-1, g_data.foo-1,, g_data.foo-1)
    g_data.Gui.CBIco.Selected := g_data.Gui.CBIco.FindString(Cfg.LastIconFile)
    GCT.Attach(g_data.Gui.CBIco.GetComboControl(), "Buscar y seleccionar un icono en la lista")
    GCT.Attach(g_data.Gui.CBIco.GetEditControl(), "El icono principal del archivo compilado`nPresione Supr para eliminar el elemento de la lista")
g_data.Gui.TXIco := Gui.AddText("x" . g_data.Gui.TXSrc.Pos.X . " y" . g_data.Gui.CBIco.Pos.Y . " w160 h" . g_data.Gui.CBIco.Pos.H . " +0x200", "Icono (archivo ico)")
g_data.Gui.BTIco := Gui.AddButton("x" . g_data.Gui.BTSrc.Pos.X . " y" . g_data.Gui.CBIco.Pos.Y . " w40 h" . g_data.Gui.CBIco.Pos.H, "•••")
    g_data.Gui.BTIco.OnEvent("Click", "Gui_IcoButton")
    ImageButton.Create(g_data.Gui.BTIco.Hwnd, ButtonStyle2*)
    GCT.Attach(g_data.Gui.BTIco, "Buscar y seleccionar un archivo icono")
g_data.Gui.TXBin := Gui.AddText("x" . g_data.Gui.TXSrc.Pos.X . " y" . (g_data.Gui.CBIco.Pos.Y+g_data.Gui.CBIco.Pos.H+5) . " w160 h" . g_data.Gui.CBIco.Pos.H . " +0x200", "Archivo base (bin)")
g_data.Gui.CBBin := new ComboBoxEx(Gui, "x" . g_data.Gui.CBIco.Pos.X . " y" . g_data.Gui.TXBin.Pos.Y . " w" . (g_data.Gui.CBIco.Pos.W-50) . " +0x3 r10")
    GCT.Attach(g_data.Gui.CBBin.GetComboControl(), "El archivo base BIN AutoHotkey")
    Util_LoadBinFiles(Cfg.LastBinFile)
    g_data.Gui.CBBin.OnCommand(1, "CBBin_Event")    ; CBN_SELCHANGE
g_data.Gui.BTRfz := Gui.AddButton("x" . (g_data.Gui.BTIco.Pos.X-50) . " y" . g_data.Gui.TXBin.Pos.Y . " w90 h" . g_data.Gui.TXBin.Pos.H, "Refrezcar")
    g_data.Gui.BTRfz.OnEvent("Click", () => Util_LoadBinFiles(Cfg.LastBinFile))
    ImageButton.Create(g_data.Gui.BTRfz.Hwnd, ButtonStyle2*)
    GCT.Attach(g_data.Gui.BTRfz, "Volver a leer los archivos BIN")
g_data.Gui.GB2 := Gui.AddGroupBox("x" . g_data.Gui.TabDA.GX . " y" . (g_data.Gui.CBIco.Pos.Y-24) . " w" . g_data.Gui.TabDA.W . " h" . (2*24+2*g_data.Gui.CBIco.Pos.H+5), "Parámetros opcionales")

g_data.Gui.CBCmp := new ComboBoxEx(Gui, "x" . g_data.Gui.CBBin.Pos.X . " y" . (g_data.Gui.GB2.Pos.Y+g_data.Gui.GB2.Pos.H+15+24) . " w" . g_data.Gui.CBBin.Pos.W . " r10 +0x3")
    GCT.Attach(g_data.Gui.CBCmp.GetComboControl(), "El método de compresión del archivo EXE")
    Util_LoadCompressionFiles(Cfg.Compression)
g_data.Gui.TXCmp := Gui.AddText("x" . g_data.Gui.TXSrc.Pos.X . " y" . g_data.Gui.CBCmp.Pos.Y . " w160 h" . g_data.Gui.CBCmp.Pos.H . " +0x200", "Método de compresión")
g_data.Gui.BNDwd := Gui.AddButton("x" . g_data.Gui.BTRfz.Pos.X . " y" . g_data.Gui.CBCmp.Pos.Y . " w90 h" . g_data.Gui.CBCmp.Pos.H, "Descargar")
    g_data.Gui.BNDwd.OnEvent("Click", () => RegExMatch(g_data.Gui.CBCmp.Text,"i)\bupx\b") ? Run("https://upx.github.io/") : RegExMatch(g_data.Gui.CBCmp.Text,"i)\bmpress\b") ? Run("http://www.matcode.com/mpress.htm") : 0)
    ImageButton.Create(g_data.Gui.BNDwd.Hwnd, ButtonStyle2*)
    GCT.Attach(g_data.Gui.BNDwd, "Ir a la página oficial para descargar la herramienta seleccionada")
g_data.Gui.GB3 := Gui.AddGroupBox("x" . g_data.Gui.TabDA.GX . " y" . (g_data.Gui.CBCmp.Pos.Y-24) . " w" . g_data.Gui.TabDA.W . " h" . (2*24+g_data.Gui.CBCmp.Pos.H), "Compresión del archivo exe resultante")

g_data.Gui.TXAhk := Gui.AddText("x" . g_data.Gui.TabDA.GX . " y" . (g_data.Gui.GB3.Pos.Y+g_data.Gui.GB3.Pos.H+24) . " w" . g_data.Gui.TabDA.W . " h" . g_data.Gui.CBCmp.Pos.H . " c0000FF", g_ahkpath)
    GCT.Attach(g_data.Gui.TXAhk, "Ruta de AutoHotkey detectada`nEste es el ejecutable que se utilizará para realizar comprobaciones")

g_data.Gui.Tab.Move("h" . (g_data.Gui.TXAhk.Pos.Y+g_data.Gui.TXAhk.Pos.H-g_data.Gui.TXLgo.Pos.H))
    g_data.Gui.TabDA := g_data.Gui.Tab.GetDisplayArea()

g_data.Gui.Tab.UseTab(1)
g_data.Gui.LVReg := Gui.AddListView("x" . g_data.Gui.TabDA.GX . " y" . g_data.Gui.TabDA.GY . " w" . g_data.Gui.TabDA.W . " h" . g_data.Gui.TabDA.H . " -E0x200", "ID|Mensaje|Archivo|Línea|Tiempo")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", g_data.Gui.LVReg.Hwnd, "Str", "Explorer", "UPtr", 0)
    g_data.Gui.LVReg.SetImageList(g_data.log_il:=IL_Create(1))
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32516))    ; IDI_INFORMATION
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32515))    ; IDI_WARNING
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32513))    ; IDI_ERROR
    IL_Add(g_data.log_il, "HICON:" . LoadPredefinedIcon(32518))    ; IDI_SHIELD
    IL_Add(g_data.log_il, "shell32.dll", -51380)    ; INCLUDE

g_data.Gui.Tab.UseTab(2)
g_data.Gui.LVRsc := Gui.AddListView("x" . g_data.Gui.TabDA.GX . " y" . g_data.Gui.TabDA.GY . " w" . g_data.Gui.TabDA.W . " h" . g_data.Gui.TabDA.H . " -E0x200 -LV0x10 +0x8", "Tipo|Archivo|Nombre|Idioma")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", g_data.Gui.LVRsc.Hwnd, "Str", "Explorer", "UPtr", 0)

g_data.Gui.Tab.UseTab(3)
g_data.Gui.TVVer := Gui.AddTreeView("x" . g_data.Gui.TabDA.GX . " y" . g_data.Gui.TabDA.GY . " w" . g_data.Gui.TabDA.W . " h" . g_data.Gui.TabDA.H . " -E0x200 +0x1222")
    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", g_data.Gui.TVVer.Hwnd, "Str", "Explorer", "UPtr", 0)
    g_data.Gui.TVVer.SetFont(, "Courier New")

g_data.Gui.Tab.UseTab(4)
;g_data.Gui.LVVar := Gui.AddListView("x" . g_data.Gui.TabDA.GX . " y" . g_data.Gui.TabDA.GY . " w" . g_data.Gui.TabDA.W . " h" . g_data.Gui.TabDA.H . " -E0x200 -LV0x10 +0x8", "Variable|Datos")
;    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", g_data.Gui.LVVar.Hwnd, "Str", "Explorer", "UPtr", 0)
;g_data.Gui.LVVar.Add(, "A_IsCompiled", "1")
;g_data.Gui.LVVar.Add(, "A_PtrSize", "")
;g_data.Gui.LVVar.ModifyCol(1, "AutoHdr")

g_data.Gui.Tab.UseTab()
g_data.Gui.TXSPT := Gui.AddText("x0 y" . (g_data.Gui.Tab.Pos.X+g_data.Gui.Tab.Pos.H+g_data.Gui.TXLgo.Pos.H-2) . " w800 h2 vbsp BackgroundFED22C")    ; separador
g_data.Gui.PCBTM := Gui.AddPic("x0 y" . (g_data.Gui.TXSPT.Pos.Y+2) . " w800 h" . (25+2*15) . " +E0x08000000")    ; fondo de pié de página
    LinearGradient(g_data.Gui.PCBTM, [0xFEF5BF, 0xFEE786],, 1)  ; 1=VERTICAL
g_data.Gui.BTExt := Gui.AddButton("x650 y" . (g_data.Gui.PCBTM.Pos.Y+15) . " w140 h25", "Cerrar")
    g_data.Gui.BTExt.OnEvent("Click", "ExitApp")
    ImageButton.Create(g_data.Gui.BTExt.Hwnd, ButtonStyle*)
    GCT.Attach(g_data.Gui.BTExt, "Cerrar el compilador y guardar la sesión")
g_data.Gui.BTCmp := Gui.AddButton("x500 y" . g_data.Gui.BTExt.Pos.Y . " w140 h25 Default", ">Compilar<")
    g_data.Gui.BTCmp.OnEvent("Click", "Gui_CompileButton")
    g_data.Gui.BTCmp.SetFont("Bold")
    ImageButton.Create(g_data.Gui.BTCmp.Hwnd, ButtonStyle*)
    GCT.Attach(g_data.Gui.BTCmp, "Compilar el archivo fuente seleccionado")
g_data.Gui.BTGit := Gui.AddButton("x10 y" . g_data.Gui.BTExt.Pos.Y . " w140 h25", "Ver en GitHub")
    g_data.Gui.BTGit.OnEvent("Click", () => Run("https://github.com/flipeador/Ahk2Exe"))
    ImageButton.Create(g_data.Gui.BTGit.Hwnd, ButtonStyle*)
    GCT.Attach(g_data.Gui.BTGit, "Ir a la página oficial en GitHub")
g_data.Gui.BTAbt := Gui.AddButton("x160 y" . g_data.Gui.BTExt.Pos.Y . " w140 h25", "Acerca de (F1)")
    g_data.Gui.BTAbt.OnEvent("Click", Func("WM_KEYDOWN").Bind(0x70,0))
    ImageButton.Create(g_data.Gui.BTAbt.Hwnd, ButtonStyle*)
    GCT.Attach(g_data.Gui.BTAbt, "Ver acerca de..")

Gui.Show("w800 h" . (g_data.Gui.PCBTM.Pos.Y+g_data.Gui.PCBTM.Pos.H+g_data.Gui.SB.Pos.H))
    Gui.OnEvent("Close", "ExitApp")
    Gui.OnEvent("Size", "Gui_Size")
    Gui.OnEvent("Escape", () => MsgBox("¿Esta seguro de que desea cerrar la aplicación?",, 0x2024) == "Yes" ? ExitApp() : 0)
    Gui.OnEvent("DropFiles", "Gui_DropFiles")

Util_UpdateSrc()
CBBin_Event()
OnExit("_OnExit")    ; al terminar
OnMessage(0x100, "WM_KEYDOWN")    ; cuando se presiona una tecla que no sea del sistema (alt).
Return





; =====================================================================================================================================================
; EVENTOS GUI
; =====================================================================================================================================================
Gui_Size(Gui, MinMax, W, H)
{
    If (MinMax != WIN_MINIMIZED)
        SetTimer("ReSize", -500)    
    
    ReSize()
    {
        ;ToolTip A_ThisFunc
    }
}

Gui_DropFiles(Gui, Ctrl, FileArray, X, Y)
{
    Local LastSrc := "", LastIco := "", foo := new GuiDisable("Leyendo archivos..")
    for g_v, g_k in FileArray    ; g_v = index  |  g_k = filename
    {
        if (PATH(g_k).Ext = "ahk")
        {
            if (g_data.Gui.CBSrc.FindString(g_k) == -1)
                g_data.Gui.CBSrc.Add(, LastSrc := g_k)
        }
        else if (PATH(g_k).Ext = "ico")
        {
            if (g_data.Gui.CBIco.FindString(g_k) == -1)
                if (g_data.foo := IL_Add(g_data.Gui.CBIco.GetImageList(), g_k))
                    g_data.Gui.CBIco.Add(, LastIco := g_k, g_data.foo-1, g_data.foo-1, g_data.foo-1,, g_data.foo-1)
        }
    }
    if (LastSrc != "")
        g_data.Gui.CBSrc.Selected := g_data.Gui.CBSrc.FindString(LastSrc)
      , g_data.Gui.EDDst.Text := "", Util_UpdateSrc()
    if (LastIco != "")
        g_data.Gui.CBIco.Selected := g_data.Gui.CBSrc.FindString(LastIco)
}

DDLSrc_Event()
{
    Util_Status("Esperando ..")
    SetTimer("Timer", -500)
    Timer()
    {
        g_data.Gui.EDDst.Text := ""
        Util_UpdateSrc()
    }
}

CBBin_Event()
{
    return
    local BinaryType := 0
    g_data.BinFile   := Util_CheckBinFile(g_data.Gui.CBBin.Text, BinaryType)
    g_data.Compile64 := BinaryType == SCS_64BIT_BINARY
    g_data.BinVersion := g_data.BinFile ? FileGetVersion(g_data.BinFile) : "0.0.0.0"

    g_data.Gui.LVVar.Modify(2, "Col2", g_data.BinFile ? 32*(1+g_data.Compile64) : "")
}

Gui_SrcButton()
{
    local foo  := new GuiDisable("Diálogo para seleccionar archivo fuente..")
    local file := g_data.Gui.CBSrc.Text == "" ? Cfg.LastSrcFile : g_data.Gui.CBSrc.Text
    If ( file := ChooseFile([Gui.Hwnd,"Ahk2Exe - Seleccionar archivo fuente"], file, {"Todos los archivos":"*.*", Scripts:"`n*.ahk"},, 0x1200) )
    {
        for g_k, g_v in file    ; g_k = index  |  g_v = filename
            if (g_data.Gui.CBSrc.FindString(g_v) == -1)    ; no añadir duplicados
                g_data.Gui.CBSrc.Add(-1, g_v)
        g_data.Gui.CBSrc.Selected := g_data.Gui.CBSrc.FindString(file[1])    ; establecer la selección en el primer elemento
        Util_UpdateSrc()    ; actualizar los datos para el archivo fuente seleccioado
    }
}

Gui_IcoButton()
{
    local foo  := new GuiDisable("Diálogo para seleccionar archivo icono..")
    local file := g_data.Gui.CBIco.Text == "" ? Cfg.LastIconFile : g_data.Gui.CBIco.Text
    If ( file := ChooseFile([Gui.Hwnd,"Ahk2Exe - Seleccionar icono"], file, {Iconos:"`n*.ico"},, 0x1200) )
    {
        for g_k, g_v in file    ; g_k = index  |  g_v = filename
            if (g_data.Gui.CBIco.FindString(g_v) == -1)    ; no añadir duplicados
                if (g_data.foo := IL_Add(g_data.Gui.CBIco.GetImageList(), g_v))
                    g_data.Gui.CBIco.Add(-1, g_v, g_data.foo-1, g_data.foo-1, g_data.foo-1,, g_data.foo-1)
        g_data.Gui.CBIco.Selected := g_data.Gui.CBIco.FindString(file[1])    ; establecer la selección en el primer elemento
    }
}

Gui_DestButton()
{
    local foo  := new GuiDisable("Diálogo para seleccionar archivo destino..")
    local file := g_data.Gui.EDDst.Text == "" ? ( g_data.Gui.CBSrc.Text == "" ? DirGetParent(Cfg.LastExeFile) . "\" : g_data.Gui.CBSrc.Text )
                                              : ( GetFullPathName(g_data.Gui.EDDst.Text, DirGetParent(g_data.Gui.CBSrc.Text))               )
    if ( file := SaveFile([Gui.Hwnd,"Ahk2Exe - Seleccionar archivo destino"], SetFileExt(File,"exe"), {Ejecutables:"`n*.exe"}) )
        g_data.Gui.EDDst.Text := file
}

Gui_CompileButton()
{
    ERROR := FALSE
    Util_ClearLog()

    If (A_IsAdmin)
        Util_AddLog("*INFO", "El compilador se está ejecutando con permisos de Administrador")

    ObjRawSet(g_data, "IgnoreSetMainIcon", TRUE)
    ObjRawSet(g_data, "IgnoreBinFile", TRUE)
    ObjRawSet(g_data, "IcoFile", g_data.Gui.CBIco.Text)

    Local BinaryType := 0
    ObjRawSet(g_data, "BinFile", Util_CheckBinFile(g_data.Gui.CBBin.Text, BinaryType))
    ObjRawSet(g_data, "Compile64", BinaryType == SCS_64BIT_BINARY)
    If (!g_data.BinFile)
        Return Util_Error("El archivo BIN no existe.", g_data.BinFile)
    ObjRawSet(g_data, "BinVersion", FileGetVersion(g_data.BinFile))
    ObjRawSet(g_data, "SyntaxCheck", TRUE)

    Local Script := g_data.Gui.CBSrc.Text
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
WM_KEYDOWN(VK_CODE)
{
    if (VK_CODE == VK_F1)
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

    else if (VK_CODE == VK_F5)
        Util_UpdateSrc()

    else if (VK_CODE == VK_DELETE)
    {
        SetTimer("Timer", -50)    ; necesario para el correcto funcionamiento al eliminar un elemento
        return 1    ; evita el procesamiento de la tecla
    }
    
    Timer()
    {
        if (g_data.Gui.CBSrc.Focused)
            g_data.Gui.CBSrc.Delete(g_data.Gui.CBSrc.Selected, g_data.Gui.CBSrc.Selected ? g_data.Gui.CBSrc.Selected - 1 : 0)
        else if (g_data.Gui.CBIco.Focused)
            g_data.Gui.CBIco.Delete(g_data.Gui.CBIco.Selected, g_data.Gui.CBIco.Selected ? g_data.Gui.CBIco.Selected - 1 : 0)
    }
} ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646280(v=vs.85).aspx





_OnExit(ExitReason, ExitCode)
{
    If (wctrltimer)
        SetTimer(wctrltimer, "Delete")
    DllCall("User32.dll\AnimateWindow", "Ptr", Gui.Hwnd, "UInt", 350, "UInt", 0x80000|0x10000)

    Util_SaveCfg()
    Gdiplus.Shutdown()

    Return 0    ; EXIT
}
;@Ahk2Exe-endif




; =====================================================================================================================================================
; FUNCIONES
; =====================================================================================================================================================
Util_Error(Message := "", ExpandedInfo := "", ExitCode := 0)
{
    OutputDebug("[" . FormatTime(, "yyyyMMddhhmmss") . "] " . Message . " | " . ExpandedInfo)
    ERROR := TRUE
    if (!BE_QUIET)
        TaskDialog(ERROR_ICON, [Title,"Ha ocurrido un error y las operaciónes an sido abortadas."], ExpandedInfo == "" ? Message : [Message,ExpandedInfo])
    if (ExitCode)
        ExitApp ExitCode
    return FALSE
}

Util_LoadCfg()
{
    Return {  LastSrcList: RTrim(RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastSrcList"), "`n")
           , LastIconList: RTrim(RegRead("HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconList"), "`n")
           ,  LastSrcFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastSrcFile")
           ,  LastExeFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastExeFile")
           , LastIconFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconFile")
           ,  LastBinFile: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "LastBinFile")
           ,  Compression: RegRead("HKCU\Software\AutoHotkey\Ahk2Exe",  "Compression") }
}

Util_SaveCfg()
{
    ; guarda una lista de máximos MAX_SRCITEMLIST archivos fuente en el control
    local LastSrcList := ""
    Loop g_data.Gui.CBSrc.GetCount()
        LastSrcList .= g_data.Gui.CBSrc.GetText(A_Index-1) . "`n"
    Until (A_Index == MAX_SRCITEMLIST)
    if ((LastSrcList := SubStr(LastSrcList,1,-1)) != Cfg.LastSrcList)
        RegWrite(LastSrcList, "REG_MULTI_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastSrcList")

    ; guarda una lista de máximos MAX_ICOITEMLIST archivos icono en el control
    local LastIconList := ""
    Loop g_data.Gui.CBIco.GetCount()
            LastIconList .= g_data.Gui.CBIco.GetText(A_Index-1) . "`n"
    Until (A_Index == MAX_ICOITEMLIST)
    if ((LastIconList := SubStr(LastIconList,1,-1)) != Cfg.LastIconList)
        RegWrite(LastIconList, "REG_MULTI_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconList")

    ; guarda el último directorio de archivo fuente utilizado
    If (g_data.Gui.CBSrc.Text != Cfg.LastSrcFile && g_data.Gui.CBSrc.Text != "")
        RegWrite(g_data.Gui.CBSrc.Text, "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastSrcFile")

    ; guarda el último directorio de archivo destino utilizado
    if (g_data.Gui.EDDst.Text != Cfg.LastExeFile && g_data.Gui.EDDst.Text != "")
        RegWrite(g_data.Gui.EDDst.Text, "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastExeFile")

    ; guarda el último directorio de archivo icono utilizado
    If (g_data.Gui.CBIco.Text != Cfg.LastIconFile && g_data.Gui.CBIco.Text != "")
        RegWrite(g_data.Gui.CBIco.Text, "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastIconFile")
    
    ; guarda el último archivo BIN utilizado
    If (Cfg.LastBinFile != g_data.Gui.CBBin.Text)
        RegWrite(g_data.Gui.CBBin.Text, "REG_SZ", "HKCU\Software\AutoHotkey\Ahk2Exe", "LastBinFile")

    ; guarda el último método de compresión utilizado
    If (Cfg.Compression != g_data.Gui.CBCmp.Selected)
        RegWrite(g_data.Gui.CBCmp.Selected, "REG_DWORD", "HKCU\Software\AutoHotkey\Ahk2Exe", "Compression")
}

Util_CheckBinFile(Name, ByRef BinaryType := "")
{
    Local BinFile := RegExReplace(Name, "^v(\d\.?)+\s*")    ; remueve la versión del archivo al inicio "v2.0.0.0 XXX..." --> "XXX..."
    If (PATH(BinFile).Ext == "")
        BinFile := SetFileExt(BinFile, "bin")

    BinaryType := GetBinaryType(BinFile := GetFullPathName(BinFile, A_ScriptDir))
    Return BinaryType == SCS_32BIT_BINARY || BinaryType == SCS_64BIT_BINARY ? BinFile : FALSE
}

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

Util_Status(Info := "Listo.  [posiciona el cursor sobre un control para ver información]")
{
    If (!CMDLN)
        g_data.Gui.SB.SetText(Info)
}

Util_AddLog(What, Message, Script := "-", Line := "-")
{
    static Icon := {INFO: 1, ADVERTENCIA: 2, ERROR: 3, "*INFO": 4, INCLUDE: 5}
    if (!CMDLN)
        g_data.Gui.LVReg.Add("Icon" . Icon[What], What, Message, Script, Line, FormatTime(, "dd/MM/yyyy hh:mm:ss"))
    return What != "ERROR"
}

;@Ahk2Exe-ifndef _CONSOLEAPP
Util_ClearLog()
{
    g_data.Gui.LVReg.Delete()
}

Util_AutoHdrLog()
{
    Loop g_data.Gui.LVReg.GetCount("Col") - 1
        g_data.Gui.LVReg.ModifyCol(A_Index, "AutoHdr")
}

Util_LoadBinFiles(Default)
{
    IL_Destroy(g_data.Gui.CBBin.SetImageList(IL_Create()))
    IL_Add(g_data.Gui.CBBin.GetImageList(), "shell32.dll", -266)

    g_data.Gui.CBBin.DeleteAll()
    Loop Files, "*.bin", "F"
        g_data.Gui.CBBin.Add(, "v" . FileGetVersion(A_LoopFileFullPath) . A_Space . SetFileExt(A_LoopFileName))
    local item := g_data.Gui.CBBin.FindString(Default,, 2)
    g_data.Gui.CBBin.Selected := item == -1 ? 0 : item
}

Util_LoadCompressionFiles(Default)
{
    IL_Destroy(g_data.Gui.CBCmp.SetImageList(IL_Create()))
    IL_Add(g_data.Gui.CBCmp.GetImageList(), "shell32.dll", -154)

    g_data.Gui.CBCmp.DeleteAll()
    g_data.Gui.CBCmp.Add(0, "Sin compresión")
    g_data.Gui.CBCmp.Add(1, "UPX " . Util_CheckCompressionFile("upx") . "- Ultimate Packer for eXecutables")
    g_data.Gui.CBCmp.Add(2, "MPRESS " . Util_CheckCompressionFile("mpress") . "- High-performance executable packer")
    g_data.Gui.CBCmp.Selected := Default >= 0 || Default < g_data.Gui.CBCmp.GetCount() ? Default : 0
}

Util_CheckCompressionFile(Name)
{
    Name := RegExMatch(Name, "i)\bupx\b") ? "upx.exe" : RegExMatch(Name, "i)\bmpress\b") ? "mpress.exe" : Name
    Return IS_FILE(Name) ? "v" . GetFileVersionInfo(Name).ProductVersion . A_Space : ""
}

Util_UpdateSrc()
{
    static rsc := {1:"RT_CURSOR",2:"RT_BITMAP",3:"RT_ICON",4:"RT_MENU",5:"RT_DIALOG",6:"RT_STRING",7:"RT_FONTDIR",8:"RT_FONT",9:"RT_ACCELERATORS",10:"RT_RCDATA",11:"RT_MESSAGETABLE"
                 , 12:"RT_GROUP_CURSOR",14:"RT_GROUP_ICON",16:"RT_VERSION",17:"RT_DLGINCLUDE",19:"RT_PLUGPLAY",20:"RT_VXD",21:"RT_ANICURSOR",22:"RT_ANIICON",23:"RT_HTML",24:"RT_MANIFEST"}
    Util_Status("Leyendo archivo fuente ..")
    g_data.Gui.LVRsc.Delete()
    g_data.Gui.TVVer.Delete()

    local BinaryType := 0
    g_data.BinFile   := Util_CheckBinFile(g_data.Gui.CBBin.Text, BinaryType)
    g_data.Compile64 := BinaryType == SCS_64BIT_BINARY
    g_data.BinVersion := g_data.BinFile ? FileGetVersion(g_data.BinFile) : "0.0.0.0"

    local data := QuickParse(g_data.Gui.CBSrc.Text)
    if (data)
    {
        if (data.MainIcon != "")
        {
            if (g_data.Gui.CBIco.FindString(data.MainIcon) == -1)
            {
                if (g_data.foo := IL_Add(g_data.Gui.CBIco.GetImageList(), data.MainIcon))
                    g_data.Gui.CBIco.Selected := g_data.Gui.CBIco.Add(, data.MainIcon, g_data.foo-1, g_data.foo-1, g_data.foo-1,, g_data.foo-1)
            }
            else
                g_data.Gui.CBIco.Selected := g_data.Gui.CBIco.FindString(data.MainIcon)
        }
        
        if (data.BinFile != "")
            g_data.Gui.CBBin.Selected := g_data.Gui.CBBin.FindString(data.BinFile,, 2)
        
        if (Trim(g_data.Gui.EDDst.Text) == "")
            g_data.Gui.EDDst.Text := PATH(data.Script).FNNE . ".exe"
        
        for g_k, g_v in data.Directives.Resources
            if (IsObject(g_v))
                g_data.Gui.LVRsc.Add(, rsc.HasKey(g_v.ResType)?rsc[g_v.ResType]:g_v.ResType, GetFullPathName(g_v.FileName,DirGetParent(data.Script)), g_v.ResName, (g_v.LangID:=g_v.LangID==""?data.Directives.ResourceLang:g_v.LangID) . " (" . (g_v.LangID is "integer"?Format("{:04X}",g_v.LangID) . ":" . LCIDToLocaleName(g_v.LangID):"") . ")")
        
        local LangID := "", StringTable := 0, String := 0
            , VS_VERSIONINFO   := g_data.Gui.TVVer.Add("VS_VERSIONINFO",, "Bold")
        g_data.Gui.TVVer.Add("wType: 0 (binary data)", VS_VERSIONINFO)
        g_data.Gui.TVVer.Add("szKey: VS_VERSION_INFO", VS_VERSIONINFO)
        local VS_FIXEDFILEINFO := g_data.Gui.TVVer.Add("Value: VS_FIXEDFILEINFO (structure)", VS_VERSIONINFO)
        g_data.Gui.TVVer.Add("dwFileVersionMS   : " . Format("{:08X}",MAKELONG(data.FileVersion[2], Data.FileVersion[1])) . " (" . Data.FileVersion[1] . "." . Data.FileVersion[2] . ")", VS_FIXEDFILEINFO)
        g_data.Gui.TVVer.Add("dwFileVersionLS   : " . Format("{:08X}",MAKELONG(Data.FileVersion[4], Data.FileVersion[3])) . " (" . Data.FileVersion[3] . "." . Data.FileVersion[4] . ")", VS_FIXEDFILEINFO)
        g_data.Gui.TVVer.Add("dwProductVersionMS: " . Format("{:08X}",MAKELONG(Data.ProductVersion[2], Data.ProductVersion[1])) . " (" . Data.ProductVersion[1] . "." . Data.ProductVersion[2] . ")", VS_FIXEDFILEINFO)
        g_data.Gui.TVVer.Add("dwProductVersionLS: " . Format("{:08X}",MAKELONG(Data.ProductVersion[4], Data.ProductVersion[3])) . " (" . Data.ProductVersion[3] . "." . Data.ProductVersion[4] . ")", VS_FIXEDFILEINFO)
        local StringFileInfo   := g_data.Gui.TVVer.Add("StringFileInfo", VS_VERSIONINFO, "Bold")
        g_data.Gui.TVVer.Add("wType: 0 (binary data)", StringFileInfo)
        g_data.Gui.TVVer.Add("szKey: StringFileInfo", StringFileInfo)
        local VarFileInfo      := g_data.Gui.TVVer.Add("VarFileInfo", VS_VERSIONINFO, "Bold")
        g_data.Gui.TVVer.Add("szKey: VarFileInfo", VarFileInfo)
        local Var              := g_data.Gui.TVVer.Add("Var", VarFileInfo, "Bold")
        g_data.Gui.TVVer.Add("szKey   : Translation", Var)
        for LangID, g_v in data.VerInfo
        {
            LangID := LangID . " (" . Integer("0x" . SubStr(LangID,1,4)) . "/" . Integer("0x" . SubStr(LangID,-4)) . ")  |  " . LCIDToLocaleName("0x" . SubStr(LangID,1,4))
            g_data.Gui.TVVer.Add("Value[" . A_Index . "]: " . LangID, Var)
            StringTable := g_data.Gui.TVVer.Add("StringTable", StringFileInfo, "Bold")
            g_data.Gui.TVVer.Add("wType: 0 (binary data)", StringTable)
            g_data.Gui.TVVer.Add("szKey: " . LangID, StringTable)
            for g_k, g_v in g_v
                String := g_data.Gui.TVVer.Add("String", StringTable, "Bold")
              , g_data.Gui.TVVer.Add("wType: 1 (text data)", String)
              , g_data.Gui.TVVer.Add("szKey: " . g_k, String)
              , g_data.Gui.TVVer.Add("Value: " . g_v, String)
        }
    }

    loop g_data.Gui.LVRsc.GetCount("Col") - 1
        g_data.Gui.LVRsc.ModifyCol(A_Index, "AutoHdr")

    local ItemID := 0
    while ( ItemID := g_data.Gui.TVVer.GetNext(ItemID,"Full") )
        g_data.Gui.TVVer.Modify( ItemID, "Expand" )
    g_data.Gui.TVVer.Modify(VS_VERSIONINFO, "Vis")

    Util_Status()
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

Util_EnableWater(Hwnd, hBitmap, Width, Height)
{
    For g_k, g_v in ["enablewater","disablewater","waterblob","flattenwater","setwaterparent"]
        waterctrldll[g_v] := GetProcAddress(waterctrldll.hModule, g_v)
    DllCall(waterctrldll.enablewater, "Ptr", Gui.Hwnd, "Int", 0, "Int", 0, "Ptr", hBitmap, "Int", 3, "Int", 20)
    DllCall(waterctrldll.setwaterparent, "Ptr", Hwnd)
    If (WATER_BLOB_INTERVAL)
        SetTimer(wctrltimer := () => DllCall(waterctrldll.waterblob, "Int", Random(0, Width), "Int", Random(0, Height), "Int", Random(3, 12), "Int", Random(20, 75)), WATER_BLOB_INTERVAL)
} ; https://autohotkey.com/boards/viewtopic.php?t=3302
;@Ahk2Exe-IgnoreEnd64





; =====================================================================================================================================================
; CLASES
; =====================================================================================================================================================
Class Status
{
    __New(str)
    {
        Try g_data.Gui.SB.SetText(str)
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
;@Ahk2Exe-endif
