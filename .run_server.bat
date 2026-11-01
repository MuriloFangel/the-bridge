@echo off
chcp 65001 > nul
title Console Minecraft - server.jar
:INICIO
cls
echo ========================================================
echo   MINECRAFT SERVER CONSOLE - server.jar
echo   Memoria: 1G - 2G
echo ========================================================
echo.
"F:\Users\MuriloF\Downloads\OpenJDK8U-jre_x64_windows_hotspot_8u504b01\jdk8u504-b01-jre\bin\java.exe" -Xms1G -Xmx2G -noverify -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dfile.encoding=UTF-8 -jar "server.jar" 
@echo. & @echo Servidor encerrado. Pressione qualquer tecla para fechar... & pause > nul
