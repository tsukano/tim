rem バッチのERRORLEVELが -1 の場合は二重起動でエラー
set RC=-1
call :main 0>>"%~dpnx0"
exit /b %RC%

:main

ruby "%~d0%~p0src\redmine_syncer.rb"

set RC=0
