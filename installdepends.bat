@echo off
TITLE Shadow Dependency Installer
color 57

echo Starting Shadow IRC Bot Dependency Installer by Aaron Blakely
echo --- DO NOT CLOSE UNTIL PROMPTED TO! ---
echo.

set inspath=%*

set inspath=%inspath:\=/%
set inspath=%inspath: =\ %
set inspath=%inspath::=%
set inspath=/%inspath%
set inspath=%inspath:"=%


echo PATH: %inspath%

IF %1.==. GOTO NOPATHEXISTS
GOTO PATHEXISTS


:NOPATHEXISTS
  "C:\Program Files\Git\bin\bash.exe" -c "/c/Strawberry/perl/bin/perl.exe ./installdepends.pl"
   GOTO SAFEEXIT

:PATHEXISTS

    "C:\Program Files\Git\bin\bash.exe" -c "/c/Strawberry/perl/bin/perl.exe %inspath%/installdepends.pl"
    GOTO SAFEEXIT

:SAFEEXIT
  echo.
  echo --- It is now safe to close this window! ---
  pause