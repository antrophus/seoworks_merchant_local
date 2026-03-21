@echo off
chcp 65001 >nul
echo ================================================
echo  merchant_local - Flutter Project Init
echo ================================================
echo.

REM Check Flutter installation
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found in PATH.
    echo Please install Flutter first:
    echo https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
)

echo [STEP 1/4] Enable Windows desktop support...
flutter config --enable-windows-desktop

echo.
echo [STEP 2/4] Initialize Flutter project (keeping existing sources)...
flutter create --org com.seoworks --platforms android,windows .

echo.
echo [STEP 3/4] Install packages...
flutter pub get

echo.
echo [STEP 4/4] Code generation (Drift, Freezed, Riverpod)...
flutter pub run build_runner build --delete-conflicting-outputs

echo.
echo ================================================
echo  Done! Run with:
echo    Windows : flutter run -d windows
echo    Android : flutter run -d android
echo ================================================
pause
