rem バッチのERRORLEVELが -1 の場合は二重起動でエラー
set RC=-1
call :main 0>>"%~dpnx0"
exit /b %RC%

:main

ruby "%~d0%~p0mail_picker\mail_picker.rb"

set RC=0
