@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Unity + xLua + lua-protobuf Setup Script
echo ============================================
echo.

set "ROOT=%~dp0"
set "XLUA_BUILD=%ROOT%xLua\build"
set "PB_SRC=%ROOT%lua-protobuf"
set "PB_DEST=%XLUA_BUILD%\lua-protobuf"
set "CMAKE_FILE=%XLUA_BUILD%\CMakeLists.txt"
set "CS_FILE=%ROOT%xLua\Assets\XLua\Src\LuaProtobufBridge.cs"

REM =============================================
REM  Detect Visual Studio
REM =============================================
set "__VS=Visual Studio 16 2019"
set "__VSWhere=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "%__VSWhere%" (
    for /f "tokens=*" %%p in (
        '"%__VSWhere%" -latest -property catalog_productLineVersion'
    ) do set __VSDISPLAY=%%p

    for /f "tokens=*" %%p in (
        '"%__VSWhere%" -latest -property catalog_productDisplayVersion'
    ) do set __VSVER=%%p
)

if "!__VSVER!" neq "" (
    set "__VS=Visual Studio !__VSVER:~0,2! !__VSDISPLAY!"
)

echo Detected: !__VS!
echo.

REM =============================================
REM  Step 1: Copy pb.c / pb.h
REM =============================================
echo [1/5] Copy pb.c / pb.h to xLua build dir...
echo -----------------------------------------------

if not exist "%PB_SRC%\pb.c" (
    echo [ERROR] Cannot find %PB_SRC%\pb.c
    goto :error
)

if not exist "%PB_DEST%" mkdir "%PB_DEST%"
copy /Y "%PB_SRC%\pb.c" "%PB_DEST%\pb.c"
copy /Y "%PB_SRC%\pb.h" "%PB_DEST%\pb.h"
echo [DONE] Step 1 complete
echo.

REM =============================================
REM  Step 2: Patch CMakeLists.txt
REM =============================================
echo [2/5] Patch CMakeLists.txt for lua-protobuf...
echo -----------------------------------------------

findstr /C:"lua-protobuf" "%CMAKE_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [SKIP] CMakeLists.txt already contains lua-protobuf
) else (
    powershell -Command ^
        "$content = Get-Content '%CMAKE_FILE%' -Raw -Encoding UTF8;" ^
        "$insertion = \"`r`n#begin lua-protobuf`r`nset (LUAPB_SRC lua-protobuf/pb.c)`r`nset_property(`r`n    SOURCE `${LUAPB_SRC}`r`n    APPEND`r`n    PROPERTY COMPILE_DEFINITIONS`r`n    LUA_LIB`r`n)`r`nlist(APPEND THIRDPART_INC lua-protobuf)`r`nset (THIRDPART_SRC `${THIRDPART_SRC} `${LUAPB_SRC})`r`n#end lua-protobuf`r`n\";" ^
        "$content = $content -replace '(endif \(\)\r?\n)\r?\n(set \( LUA_SOCKET)', (\"`$1\" + $insertion + \"`r`n`$2\");" ^
        "[System.IO.File]::WriteAllText('%CMAKE_FILE%', $content)"

    findstr /C:"lua-protobuf" "%CMAKE_FILE%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [DONE] CMakeLists.txt patched
    ) else (
        echo [ERROR] CMakeLists.txt patch failed
        goto :error
    )
)
echo [DONE] Step 2 complete
echo.

REM =============================================
REM  Step 3: Create C# bridge file
REM =============================================
echo [3/5] Create LuaProtobufBridge.cs...
echo -----------------------------------------------

if exist "%CS_FILE%" (
    echo [SKIP] %CS_FILE% already exists
) else (
    (
        echo using System;
        echo using System.Runtime.InteropServices;
        echo using XLua;
        echo.
        echo namespace XLua.LuaDLL
        echo {
        echo     public partial class Lua
        echo     {
        echo         [DllImport^(LUADLL, CallingConvention = CallingConvention.Cdecl^)]
        echo         public static extern int luaopen_pb^(IntPtr L^);
        echo.
        echo         [DllImport^(LUADLL, CallingConvention = CallingConvention.Cdecl^)]
        echo         public static extern int luaopen_pb_io^(IntPtr L^);
        echo.
        echo         [DllImport^(LUADLL, CallingConvention = CallingConvention.Cdecl^)]
        echo         public static extern int luaopen_pb_conv^(IntPtr L^);
        echo.
        echo         [DllImport^(LUADLL, CallingConvention = CallingConvention.Cdecl^)]
        echo         public static extern int luaopen_pb_buffer^(IntPtr L^);
        echo.
        echo         [DllImport^(LUADLL, CallingConvention = CallingConvention.Cdecl^)]
        echo         public static extern int luaopen_pb_slice^(IntPtr L^);
        echo.
        echo         [DllImport^(LUADLL, CallingConvention = CallingConvention.Cdecl^)]
        echo         public static extern int luaopen_pb_unsafe^(IntPtr L^);
        echo.
        echo         [MonoPInvokeCallback^(typeof^(lua_CSFunction^)^)]
        echo         public static int LoadPb^(IntPtr L^)
        echo         {
        echo             return luaopen_pb^(L^);
        echo         }
        echo.
        echo         [MonoPInvokeCallback^(typeof^(lua_CSFunction^)^)]
        echo         public static int LoadPbIO^(IntPtr L^)
        echo         {
        echo             return luaopen_pb_io^(L^);
        echo         }
        echo.
        echo         [MonoPInvokeCallback^(typeof^(lua_CSFunction^)^)]
        echo         public static int LoadPbConv^(IntPtr L^)
        echo         {
        echo             return luaopen_pb_conv^(L^);
        echo         }
        echo.
        echo         [MonoPInvokeCallback^(typeof^(lua_CSFunction^)^)]
        echo         public static int LoadPbBuffer^(IntPtr L^)
        echo         {
        echo             return luaopen_pb_buffer^(L^);
        echo         }
        echo.
        echo         [MonoPInvokeCallback^(typeof^(lua_CSFunction^)^)]
        echo         public static int LoadPbSlice^(IntPtr L^)
        echo         {
        echo             return luaopen_pb_slice^(L^);
        echo         }
        echo.
        echo         [MonoPInvokeCallback^(typeof^(lua_CSFunction^)^)]
        echo         public static int LoadPbUnsafe^(IntPtr L^)
        echo         {
        echo             return luaopen_pb_unsafe^(L^);
        echo         }
        echo     }
        echo }
    ) > "%CS_FILE%"
    echo [DONE] Created %CS_FILE%
)
echo [DONE] Step 3 complete
echo.

REM =============================================
REM  Step 4: Build
REM =============================================
echo [4/5] Build native libraries...
echo ===============================================
echo.

set "BUILD_SUCCESS=0"
set "BUILD_FAIL=0"

pushd "%XLUA_BUILD%"

REM ----- Windows x64 Lua 5.3 -----
echo [BUILD] Windows x64 (Lua 5.3)...
echo -----------------------------------------------
mkdir build64 2>nul
pushd build64
echo Running cmake configure...
cmake -G "!__VS!" -A x64 ..
if !errorlevel! neq 0 (
    echo [ERROR] cmake configure failed
    popd
    set /a BUILD_FAIL+=1
    goto :skip_win64
)
popd
echo Running cmake build...
cmake --build build64 --config Release
if !errorlevel! neq 0 (
    echo [ERROR] cmake build failed
    set /a BUILD_FAIL+=1
    goto :skip_win64
)
if exist "build64\Release\xlua.dll" (
    md plugin_lua53\Plugins\x86_64 2>nul
    copy /Y build64\Release\xlua.dll plugin_lua53\Plugins\x86_64\xlua.dll
    echo   [OK] plugin_lua53\Plugins\x86_64\xlua.dll
    set /a BUILD_SUCCESS+=1
) else (
    echo   [FAIL] Build output not found
    set /a BUILD_FAIL+=1
)
:skip_win64
echo.

REM ----- Android ARM64 Lua 5.3 -----
echo [BUILD] Android ARM64 (Lua 5.3)...
echo -----------------------------------------------

set "NDK="
if defined ANDROID_NDK set "NDK=%ANDROID_NDK%"
if not defined NDK if defined ANDROID_NDK_HOME set "NDK=%ANDROID_NDK_HOME%"
if not defined NDK if defined ANDROID_NDK_ROOT set "NDK=%ANDROID_NDK_ROOT%"

if not defined NDK (
    echo   [SKIP] ANDROID_NDK not set
    echo          Example: set ANDROID_NDK=C:\Android\ndk\25.2.9519653
    set /a BUILD_FAIL+=1
) else if not exist "!NDK!\build\cmake\android.toolchain.cmake" (
    echo   [SKIP] Invalid NDK path: !NDK!
    set /a BUILD_FAIL+=1
) else (
    echo   Using NDK: !NDK!
    mkdir build.Android.arm64-v8a 2>nul
    echo   Running cmake configure...
    cmake -H. -Bbuild.Android.arm64-v8a -DANDROID_ABI=arm64-v8a -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=!NDK!\build\cmake\android.toolchain.cmake -DANDROID_NATIVE_API_LEVEL=android-21 -DANDROID_TOOLCHAIN=clang
    if !errorlevel! neq 0 (
        echo   [ERROR] Android cmake configure failed
        set /a BUILD_FAIL+=1
    ) else (
        echo   Running cmake build...
        cmake --build build.Android.arm64-v8a --config Release
        if !errorlevel! neq 0 (
            echo   [ERROR] Android cmake build failed
            set /a BUILD_FAIL+=1
        ) else if exist "build.Android.arm64-v8a\libxlua.so" (
            md plugin_lua53\Plugins\Android\libs\arm64-v8a 2>nul
            copy /Y build.Android.arm64-v8a\libxlua.so plugin_lua53\Plugins\Android\libs\arm64-v8a\libxlua.so
            echo   [OK] plugin_lua53\Plugins\Android\libs\arm64-v8a\libxlua.so
            set /a BUILD_SUCCESS+=1
        ) else (
            echo   [FAIL] Android build output not found
            set /a BUILD_FAIL+=1
        )
    )
)
echo.

popd

REM =============================================
REM  Step 5: Summary
REM =============================================
echo ===============================================
echo [5/5] Build Summary
echo ===============================================
echo.
echo   Success: !BUILD_SUCCESS!
echo   Failed:  !BUILD_FAIL!
echo.
echo --- Apple platforms (use GitHub Actions) ---
echo   iOS / macOS Intel / macOS ARM
echo.
echo ===============================================
echo  Output: %XLUA_BUILD%\plugin_lua53\Plugins\
echo ===============================================
echo.
echo  Next steps:
echo ===============================================
echo  1. Copy Plugins to Unity Assets/Plugins/
echo  2. LuaProtobufBridge.cs is at xLua/Assets/XLua/Src/
echo  3. (Optional) Copy protoc.lua to Lua resources
echo  4. Add to LuaEnv init:
echo.
echo     luaenv.AddBuildin("pb",        XLua.LuaDLL.Lua.LoadPb);
echo     luaenv.AddBuildin("pb.io",     XLua.LuaDLL.Lua.LoadPbIO);
echo     luaenv.AddBuildin("pb.conv",   XLua.LuaDLL.Lua.LoadPbConv);
echo     luaenv.AddBuildin("pb.buffer", XLua.LuaDLL.Lua.LoadPbBuffer);
echo     luaenv.AddBuildin("pb.slice",  XLua.LuaDLL.Lua.LoadPbSlice);
echo     luaenv.AddBuildin("pb.unsafe", XLua.LuaDLL.Lua.LoadPbUnsafe);
echo.
echo ===============================================
echo.
echo [DONE] Press any key to exit...
pause >nul
exit /b 0

:error
echo.
echo ============================================
echo  [FAILED] See errors above
echo  Press any key to exit...
echo ============================================
pause >nul
exit /b 1
