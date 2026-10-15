@echo off
SETLOCAL EnableDelayedExpansion

echo ==============================================
echo       RAG Assistant - One-Click Startup      
echo ==============================================
echo.

cd /d "%~dp0"

:CheckPython
:: Check if Python is installed
python --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    py --version >nul 2>&1
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Python is not installed on this device!
        echo We need Python 3.11 to run this application.
        echo Please download it from https://www.python.org/downloads/
        echo IMPORTANT: Check the box "Add Python to PATH" during installation!
        echo.
        pause
        exit /b 1
    )
)

:CheckVenv
:: Check if virtual environment exists
IF NOT EXIST "venv\" (
    echo [INFO] First time setup detected! Creating virtual environment...
    
    :: Attempt to use Python 3.11 specifically to avoid wheel issues
    py -3.11 -m venv venv >nul 2>&1
    IF !ERRORLEVEL! NEQ 0 (
        echo [INFO] Python 3.11 not found via 'py', falling back to default Python...
        python -m venv venv
        IF !ERRORLEVEL! NEQ 0 (
            echo [ERROR] Failed to create virtual environment. Ensure Python is installed correctly.
            pause
            exit /b 1
        )
    )
    
    echo [INFO] Activating environment and installing dependencies... (This may take a few minutes)
    call venv\Scripts\activate.bat
    python -m pip install --upgrade pip >nul 2>&1
    pip install -r requirements.txt
    echo [INFO] Installation complete!
    echo.
) ELSE (
    echo [INFO] Virtual environment found. Activating...
    call venv\Scripts\activate.bat
)

:CheckEnvFile
:: Check if .env file exists
IF NOT EXIST ".env" (
    echo.
    echo [WARNING] Security Configuration Required!
    echo No .env file found. We need an API key to allow the AI to answer questions.
    set /p API_KEY="Please paste your Google Gemini API Key: "
    echo GEMINI_API_KEY=!API_KEY!> .env
    echo [INFO] .env file generated successfully and securely hidden!
    echo.
)

:CheckDatabase
:: Check if the ChromaDB vector database exists
IF NOT EXIST "chroma_db\" (
    echo [INFO] Vector database not found. Running ingestion script...
    echo [INFO] This will embed the GAHAR handbook. It may take a few minutes.
    python ingest.py
    echo [INFO] Ingestion complete!
    echo.
)

:StartApp
echo [INFO] Starting the Flask Application Server...
echo [INFO] Opening http://127.0.0.1:5000 in your browser...
echo.
start "" http://127.0.0.1:5000
python app.py

pause
