::@ECHO OFF
@echo off

IF "%VISION_SDK%"=="" ( 
ECHO.
ECHO ERROR: The VISION_SDK environment variable is not defined. This environment
ECHO        variable should point to your Anarchy install directory.
ECHO.
ECHO        If you ran this script from a location that was open before installing
ECHO        Anarchy please retry after closing and re-opening this location. If this
ECHO        doesn't work then some part of the Anarchy installation process may have
ECHO        failed - try creating the VISION_SDK environment variable manually,
ECHO        reinstalling the Anarchy SDK, or asking for help on the Anarchy forums.
ECHO.
pause
exit
)

REM - Set root directory
set CURR_DIR=%~dp0
set ROOT_DIR=%~dp0
echo Files will be copied from:
echo %VISION_SDK%
echo to:
echo %CURR_DIR%

REM - Start copy (Base data)

set SRC_DIR=%VISION_SDK%\Data\Vision\Base
md Data\Vision\Base
xcopy "%SRC_DIR%" /S "%ROOT_DIR%\Data\Vision\Base" /Y

REM - Start copy (Icons for various platforms)

set SRC_DIR=%VISION_SDK%\Data\Common
md Data\Common
IF EXIST "%SRC_DIR%" xcopy "%SRC_DIR%" /S "%ROOT_DIR%\Data\Common" /Y 