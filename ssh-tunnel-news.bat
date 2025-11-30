@echo off
REM 永遠重連的 SSH Tunnel

:loop
ssh -L 3000:localhost:3000 ^
    -p 5639 student2@120.126.16.233 ^
    -N ^
    -o ExitOnForwardFailure=yes ^
    -o ServerAliveInterval=60 ^
    -o ServerAliveCountMax=3

echo SSH tunnel 關閉，5 秒後重新連線...
timeout /t 5 /nobreak >nul
goto loop
