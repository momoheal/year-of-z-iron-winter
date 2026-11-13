@echo off
REM ============================================================
REM  Year of Z: Iron Winter - 一键跑通冒烟测试
REM  先自动导入资产（新克隆必须），再枚举全部 tests/*_smoke.gd。
REM  需要本机已装 Python；Godot 用环境变量 GODOT 或 --godot 指定。
REM  只跑部分：run_tests.bat campaign night_level
REM ============================================================
cd /d "%~dp0"
python "godot_project\tools\run_tests.py" %*
echo.
pause
