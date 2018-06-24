/*
    Evalúa una expresión en una cadena.
    Observaciones:
        Las constantes deben especificarse en mayúscula.
        Se aceptan numeros muy grandes.
    Referencia:
        https://www.w3schools.com/jsref/jsref_obj_math.asp
    Ejemplo:
        MsgBox Eval("PI") . "`n" . Eval("2>3") . "`n" . Eval("3>2") . "`n" . Eval("abs(-100)*2+50") . "`n" . Eval("143**143")
*/
Eval(Expression)
{
    Expression := RegExReplace(Expression, "\s")
    Expression := StrReplace(Expression, ",", ".")
    Expression := RegExReplace(StrReplace(Expression, "**", "^"), "(\w+(\.*\d+)?)\^(\w+(\.*\d+)?)", "pow($1,$3)")    ; 2**3 -> 2^3 -> pow(2,3)
    ;Expression := StrReplace(Expression, "PI", ACos(-1))
    Expression := RegExReplace(Expression, "=+", "==")    ; = -> ==  |  === -> ==  |  ==== -> ==  |  ..
    Expression := RegExReplace(Expression, "\b(E|LN2|LN10|LOG2E|LOG10E|PI|SQRT1_2|SQRT2)\b", "Math.$1")
    Expression := RegExReplace(Expression, "\b(abs|acos|asin|atan|atan2|ceil|cos|exp|floor|log|max|min|pow|random|round|sin|sqrt|tan)\b\(", "Math.$1(")

    Local o := ComObjCreate("HTMLfile")
    o.write("<body><script>document.body.innerText=eval('" . Expression . "');</script>")
    o := StrReplace(StrReplace(StrReplace(InStr(o:=o.body.innerText, "body") ? "" : o, "false", 0), "true", 1), "undefined", "")
    Return o ;InStr(o, "e") ? Format("{:f}", o) : o
} ; https://autohotkey.com/boards/viewtopic.php?f=6&t=15389
