@echo off
setlocal enabledelayedexpansion

cd /D "%~dp0"

set PATH=%PATH%;%SystemRoot%\system32

echo "%CD%"| findstr /C:" " >nul && echo This script relies on Miniconda which can not be silently installed under a path with spaces. && goto end

@rem Clone the repository if it doesn't exist first
if not exist "F5-TTS" (
    echo Cloning the F5-TTS repository...
    git clone https://github.com/OrphBean/F5-TTS-Server.git
)
cd F5-TTS-Server

@rem fix failed install when installing to a separate drive
set TMP=%cd%\installer_files
set TEMP=%cd%\installer_files

@rem deactivate existing conda envs as needed to avoid conflicts
(call conda deactivate && call conda deactivate && call conda deactivate) 2>nul

@rem config
set INSTALL_DIR=%cd%\installer_files
set CONDA_ROOT_PREFIX=%cd%\installer_files\conda
set INSTALL_ENV_DIR=%cd%\installer_files\env
set ENV_NAME=env
set conda_exists=F

@rem figure out whether conda needs to be installed
call "%CONDA_ROOT_PREFIX%\_conda.exe" --version >nul 2>&1
if "%ERRORLEVEL%" EQU "0" set conda_exists=T

@rem download and install conda if needed
if "%conda_exists%" == "F" (
    echo Downloading Miniconda installer...
    mkdir "%INSTALL_DIR%" 2>nul
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe', '%INSTALL_DIR%\miniconda_installer.exe')"

    echo Installing Miniconda to %CONDA_ROOT_PREFIX%
    start /wait "" "%INSTALL_DIR%\miniconda_installer.exe" /InstallationType=JustMe /NoShortcuts=1 /AddToPath=0 /RegisterPython=0 /NoRegistry=1 /S /D=%CONDA_ROOT_PREFIX%

    @rem test the conda binary
    echo Miniconda version:
    call "%CONDA_ROOT_PREFIX%\_conda.exe" --version || ( echo. && echo Miniconda not found. && goto end )

    @rem delete the installer
    del "%INSTALL_DIR%\miniconda_installer.exe"
)

@rem create the environment if it doesn't exist
if not exist "%CONDA_ROOT_PREFIX%\envs\%ENV_NAME%" (
    echo Creating new environment...
    call "%CONDA_ROOT_PREFIX%\_conda.exe" create --no-shortcuts -y --name %ENV_NAME% python=3.10.6 || ( echo. && echo Conda environment creation failed. && goto end )
)

@rem check if environment was actually created
if not exist "%CONDA_ROOT_PREFIX%\envs\%ENV_NAME%\python.exe" ( echo. && echo Conda environment is empty. && goto end )

@rem environment isolation
set PYTHONNOUSERSITE=1
set PYTHONPATH=
set PYTHONHOME=

@rem activate the environment
call "%CONDA_ROOT_PREFIX%\condabin\conda.bat" activate %ENV_NAME% || ( echo. && echo Miniconda hook not found. && goto end )

@rem Install requirements
echo Installing F5-TTS and dependencies...
pip install -e . || ( echo. && echo Failed to install F5-TTS. && goto end )
pip install api
pip install toml
pip install flask
pip install torch==2.4.1+cu118 torchaudio==2.4.1+cu118 --extra-index-url https://download.pytorch.org/whl/cu118

@rem verify environment
python --version
echo Current conda environment: %ENV_NAME%

@rem keep the environment active
cmd /k

:end
pause
