/*
    Recupera el texto de la URL especificada.
    Parámetros:
        Url:
            La dirección web deseada.
        Timeout:
            El tiempo fuera, en segundos. Por defecto espera 30 segundos.
    Return:
        Si tuvo éxito devuelve el texto y ErrorLevel se establece en cero, en caso contrario devuelve una cadena vacía y ErrorLevel se establece en 1.
        Códigos de error: https://msdn.microsoft.com/en-us/library/windows/desktop/aa383887(v=vs.85).aspx
    Ejemplo:
        MsgBox("ResponseText: " . DownloadText("https://autohotkey.com/download/2.0/version.txt") . "`n`nErrorLevel: " . ErrorLevel)
*/
DownloadText(Url, Timeout := 30)
{
    ; Inicializar un objeto WinHttpRequest.
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa384106(v=vs.85).aspx
    local WinHttpReq := ComObjCreate("WinHttp.WinHttpRequest.5.1")

    ; Abre una conexión http a un recurso http.
    ; ErrorLevel:
    ;   0x80072EE6 = La dirección URL no usa un protocolo reconocido
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa383989(v=vs.85).aspx
    local Exception := ""
    try
        WinHttpReq.Open("GET", Url, TRUE)
    catch Exception
    {
        ErrorLevel := StrSplit(Exception.Message, A_Space)[1]
        Return ""
    }

    ; Envía la solicitud http a el servidor http.
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa384045(v=vs.85).aspx
    WinHttpReq.Send()

    ; Espera al método de envío asincrónico Send a que se complete, con el valor de tiempo de espera especificado, en segundos.
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa384064(v=vs.85).aspx
    If (WinHttpReq.WaitForResponse(Timeout) == 0)
    {
        ErrorLevel := 408 ;HTTP_STATUS_REQUEST_TIMEOUT
        Return ""
    }

    ; Recupera el código de estado http de la última respuesta.
    ; Status:
    ;   200 = HTTP_STATUS_OK (la solicitud se completó correctamente)
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa384062(v=vs.85).aspx
    If (WinHttpReq.Status != 200)
    {
        ErrorLevel := WinHttpReq.Status
        Return ""
    }

    ; Recupera el cuerpo de la entidad de respuesta como texto.
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa384040(v=vs.85).aspx
    ErrorLevel := FALSE
    Return WinHttpReq.ResponseText
}
