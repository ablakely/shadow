@echo off
TITLE Shadow Dependency Installer
color 57

echo Starting Shadow IRC Bot Dependency Installer by Aaron Blakely
echo --- DO NOT CLOSE UNTIL PROMPTED TO! ---
echo.

REM Sleep for 5 seconds 
ping 127.0.0.1 -n 1 -w 5000

IF %1.==. GOTO NOPATHEXISTS >nul
GOTO PATHEXISTS


:NOPATHEXISTS
  "C:\Program Files\Git\bin\bash.exe" -c "/c/Strawberry/perl/bin/perl.exe ./installdepends.pl"
   GOTO SAFEEXIT

:PATHEXISTS
    "C:\Program Files\Git\bin\bash.exe" -c "/c/Strawberry/perl/bin/perl.exe %*/installdepends.pl"
    GOTO SAFEEXIT

:SAFEEXIT
  echo.
  echo --- It is now safe to close this window! ---
  pause