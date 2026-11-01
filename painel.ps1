# =====================================================================
#  MINECRAFT SERVER LAUNCHER & CONTROLLER (GUI WINDOWS FORMS)
# =====================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ConfigFile = Join-Path $PSScriptRoot "painel_config.json"

$DefaultJvmFlags = "-noverify -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dfile.encoding=UTF-8"

$Config = [ordered]@{
    JarName      = "server.jar"
    JavaPath     = "java"
    MinRam       = "2G"
    MaxRam       = "4G"
    CustomArgs   = $DefaultJvmFlags
    ServerArgs   = ""
    AutoRestart  = $false
}

if (Test-Path $ConfigFile) {
    try {
        $Loaded = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $Loaded.PSObject.Properties) {
            $Config[$prop.Name] = $prop.Value
        }
    } catch {}
}

function Save-AppConfig {
    $Config.JarName     = $ComboJar.Text
    $Config.JavaPath    = $TxtJava.Text
    $Config.MinRam      = $TxtMinRam.Text
    $Config.MaxRam      = $TxtMaxRam.Text
    $Config.AutoRestart = $ChkRestart.Checked
    $Config | ConvertTo-Json -Depth 4 | Set-Content $ConfigFile -Encoding UTF8
}

# --- JANELA PRINCIPAL ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Minecraft Server Launcher"
$Form.Size = New-Object System.Drawing.Size(520, 520)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$Form.ForeColor = [System.Drawing.Color]::White
$FontRegular = New-Object System.Drawing.Font("Segoe UI", 9.5)
$FontBold = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$FontTitle = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$Form.Font = $FontRegular

$LblTitle = New-Object System.Windows.Forms.Label
$LblTitle.Text = "Painel de Controle do Servidor"
$LblTitle.Font = $FontTitle
$LblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 210, 255)
$LblTitle.Location = New-Object System.Drawing.Point(25, 20)
$LblTitle.Size = New-Object System.Drawing.Size(460, 30)
$Form.Controls.Add($LblTitle)

$Grp = New-Object System.Windows.Forms.GroupBox
$Grp.Text = " Configuracoes Principais "
$Grp.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 185)
$Grp.Location = New-Object System.Drawing.Point(25, 60)
$Grp.Size = New-Object System.Drawing.Size(455, 215)
$Form.Controls.Add($Grp)

# JAR
$LblJar = New-Object System.Windows.Forms.Label
$LblJar.Text = "Arquivo Executavel (.jar):"
$LblJar.Location = New-Object System.Drawing.Point(18, 26)
$LblJar.Size = New-Object System.Drawing.Size(180, 18)
$LblJar.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($LblJar)

$ComboJar = New-Object System.Windows.Forms.ComboBox
$ComboJar.Location = New-Object System.Drawing.Point(18, 46)
$ComboJar.Size = New-Object System.Drawing.Size(325, 26)
$ComboJar.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46)
$ComboJar.ForeColor = [System.Drawing.Color]::White
$ComboJar.FlatStyle = "Flat"
$Jars = Get-ChildItem -Path $PSScriptRoot -Filter "*.jar" -File
foreach ($j in $Jars) { [void]$ComboJar.Items.Add($j.Name) }
if ($ComboJar.Items.Contains($Config.JarName)) {
    $ComboJar.SelectedItem = $Config.JarName
} else {
    $ComboJar.Text = $Config.JarName
}
$Grp.Controls.Add($ComboJar)

$BtnSearchJar = New-Object System.Windows.Forms.Button
$BtnSearchJar.Text = "Procurar..."
$BtnSearchJar.Location = New-Object System.Drawing.Point(350, 45)
$BtnSearchJar.Size = New-Object System.Drawing.Size(85, 27)
$BtnSearchJar.BackColor = [System.Drawing.Color]::FromArgb(58, 58, 60)
$BtnSearchJar.ForeColor = [System.Drawing.Color]::White
$BtnSearchJar.FlatStyle = "Flat"
$BtnSearchJar.Add_Click({
    $OFD = New-Object System.Windows.Forms.OpenFileDialog
    $OFD.Filter = "Arquivos JAR (*.jar)|*.jar"
    $OFD.InitialDirectory = $PSScriptRoot
    if ($OFD.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $ComboJar.Text = [System.IO.Path]::GetFileName($OFD.FileName)
    }
})
$Grp.Controls.Add($BtnSearchJar)

# JAVA
$LblJava = New-Object System.Windows.Forms.Label
$LblJava.Text = "Executavel Java (java.exe):"
$LblJava.Location = New-Object System.Drawing.Point(18, 82)
$LblJava.Size = New-Object System.Drawing.Size(200, 18)
$LblJava.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($LblJava)

$TxtJava = New-Object System.Windows.Forms.TextBox
$TxtJava.Text = $Config.JavaPath
$TxtJava.Location = New-Object System.Drawing.Point(18, 102)
$TxtJava.Size = New-Object System.Drawing.Size(325, 26)
$TxtJava.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46)
$TxtJava.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($TxtJava)

$BtnSearchJava = New-Object System.Windows.Forms.Button
$BtnSearchJava.Text = "Procurar..."
$BtnSearchJava.Location = New-Object System.Drawing.Point(350, 101)
$BtnSearchJava.Size = New-Object System.Drawing.Size(85, 27)
$BtnSearchJava.BackColor = [System.Drawing.Color]::FromArgb(58, 58, 60)
$BtnSearchJava.ForeColor = [System.Drawing.Color]::White
$BtnSearchJava.FlatStyle = "Flat"
$BtnSearchJava.Add_Click({
    $OFD = New-Object System.Windows.Forms.OpenFileDialog
    $OFD.Filter = "Java Executavel (java.exe)|java.exe|Todos os Arquivos (*.*)|*.*"
    if ($OFD.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtJava.Text = $OFD.FileName
    }
})
$Grp.Controls.Add($BtnSearchJava)

# RAM
$LblRam = New-Object System.Windows.Forms.Label
$LblRam.Text = "RAM Minima / Maxima:"
$LblRam.Location = New-Object System.Drawing.Point(18, 138)
$LblRam.Size = New-Object System.Drawing.Size(180, 18)
$LblRam.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($LblRam)

$TxtMinRam = New-Object System.Windows.Forms.TextBox
$TxtMinRam.Text = $Config.MinRam
$TxtMinRam.Location = New-Object System.Drawing.Point(18, 158)
$TxtMinRam.Size = New-Object System.Drawing.Size(70, 26)
$TxtMinRam.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46)
$TxtMinRam.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($TxtMinRam)

$LblDiv = New-Object System.Windows.Forms.Label
$LblDiv.Text = "/"
$LblDiv.Location = New-Object System.Drawing.Point(92, 160)
$LblDiv.Size = New-Object System.Drawing.Size(15, 20)
$LblDiv.ForeColor = [System.Drawing.Color]::Gray
$Grp.Controls.Add($LblDiv)

$TxtMaxRam = New-Object System.Windows.Forms.TextBox
$TxtMaxRam.Text = $Config.MaxRam
$TxtMaxRam.Location = New-Object System.Drawing.Point(110, 158)
$TxtMaxRam.Size = New-Object System.Drawing.Size(70, 26)
$TxtMaxRam.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46)
$TxtMaxRam.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($TxtMaxRam)

# AUTO RESTART
$ChkRestart = New-Object System.Windows.Forms.CheckBox
$ChkRestart.Text = "Reiniciar se cair"
$ChkRestart.Checked = [bool]$Config.AutoRestart
$ChkRestart.Location = New-Object System.Drawing.Point(205, 159)
$ChkRestart.Size = New-Object System.Drawing.Size(130, 24)
$ChkRestart.ForeColor = [System.Drawing.Color]::White
$Grp.Controls.Add($ChkRestart)

# BOTAO EDITAR ARGUMENTOS (ABRE SEGUNDA JANELA)
$BtnEditArgs = New-Object System.Windows.Forms.Button
$BtnEditArgs.Text = "Configurar Argumentos JVM..."
$BtnEditArgs.Location = New-Object System.Drawing.Point(25, 290)
$BtnEditArgs.Size = New-Object System.Drawing.Size(455, 36)
$BtnEditArgs.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 54)
$BtnEditArgs.ForeColor = [System.Drawing.Color]::FromArgb(0, 210, 255)
$BtnEditArgs.FlatStyle = "Flat"
$BtnEditArgs.Cursor = [System.Windows.Forms.Cursors]::Hand
$BtnEditArgs.Add_Click({
    $ArgForm = New-Object System.Windows.Forms.Form
    $ArgForm.Text = "Editar Parametros de Inicializacao"
    $ArgForm.Size = New-Object System.Drawing.Size(560, 420)
    $ArgForm.StartPosition = "CenterParent"
    $ArgForm.FormBorderStyle = "FixedDialog"
    $ArgForm.MaximizeBox = $false
    $ArgForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
    $ArgForm.ForeColor = [System.Drawing.Color]::White
    $ArgForm.Font = $FontRegular

    $LblJvmDesc = New-Object System.Windows.Forms.Label
    $LblJvmDesc.Text = "Argumentos da JVM (Flags de GC, encoding, etc. passados antes do -jar):"
    $LblJvmDesc.Location = New-Object System.Drawing.Point(20, 15)
    $LblJvmDesc.Size = New-Object System.Drawing.Size(500, 20)
    $LblJvmDesc.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $ArgForm.Controls.Add($LblJvmDesc)

    $TxtCustomArgs = New-Object System.Windows.Forms.TextBox
    $TxtCustomArgs.Multiline = $true
    $TxtCustomArgs.ScrollBars = "Vertical"
    $TxtCustomArgs.Text = $Config.CustomArgs
    $TxtCustomArgs.Location = New-Object System.Drawing.Point(20, 38)
    $TxtCustomArgs.Size = New-Object System.Drawing.Size(505, 120)
    $TxtCustomArgs.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46)
    $TxtCustomArgs.ForeColor = [System.Drawing.Color]::White
    $ArgForm.Controls.Add($TxtCustomArgs)

    $LblSrvDesc = New-Object System.Windows.Forms.Label
    $LblSrvDesc.Text = "Argumentos do Servidor (passados depois do -jar, ex: -o false):"
    $LblSrvDesc.Location = New-Object System.Drawing.Point(20, 172)
    $LblSrvDesc.Size = New-Object System.Drawing.Size(500, 20)
    $LblSrvDesc.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $ArgForm.Controls.Add($LblSrvDesc)

    $TxtServerArgs = New-Object System.Windows.Forms.TextBox
    $TxtServerArgs.Text = $Config.ServerArgs
    $TxtServerArgs.Location = New-Object System.Drawing.Point(20, 195)
    $TxtServerArgs.Size = New-Object System.Drawing.Size(505, 26)
    $TxtServerArgs.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46)
    $TxtServerArgs.ForeColor = [System.Drawing.Color]::White
    $ArgForm.Controls.Add($TxtServerArgs)

    $BtnResetDefault = New-Object System.Windows.Forms.Button
    $BtnResetDefault.Text = "Restaurar Padrao"
    $BtnResetDefault.Location = New-Object System.Drawing.Point(20, 325)
    $BtnResetDefault.Size = New-Object System.Drawing.Size(160, 36)
    $BtnResetDefault.BackColor = [System.Drawing.Color]::FromArgb(58, 58, 60)
    $BtnResetDefault.ForeColor = [System.Drawing.Color]::White
    $BtnResetDefault.FlatStyle = "Flat"
    $BtnResetDefault.Add_Click({
        $TxtCustomArgs.Text = $DefaultJvmFlags
        $TxtServerArgs.Text = ""
    })
    $ArgForm.Controls.Add($BtnResetDefault)

    $BtnSaveArgs = New-Object System.Windows.Forms.Button
    $BtnSaveArgs.Text = "Salvar e Fechar"
    $BtnSaveArgs.Font = $FontBold
    $BtnSaveArgs.Location = New-Object System.Drawing.Point(365, 325)
    $BtnSaveArgs.Size = New-Object System.Drawing.Size(160, 36)
    $BtnSaveArgs.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 110)
    $BtnSaveArgs.ForeColor = [System.Drawing.Color]::White
    $BtnSaveArgs.FlatStyle = "Flat"
    $BtnSaveArgs.Add_Click({
        $Config.CustomArgs = $TxtCustomArgs.Text.Trim()
        $Config.ServerArgs = $TxtServerArgs.Text.Trim()
        Save-AppConfig
        $ArgForm.Close()
    })
    $ArgForm.Controls.Add($BtnSaveArgs)

    [void]$ArgForm.ShowDialog()
})
$Form.Controls.Add($BtnEditArgs)

# BOTÃO INICIAR SERVIDOR
$BtnStart = New-Object System.Windows.Forms.Button
$BtnStart.Text = "[>] INICIAR SERVIDOR"
$BtnStart.Font = $FontBold
$BtnStart.Location = New-Object System.Drawing.Point(25, 340)
$BtnStart.Size = New-Object System.Drawing.Size(455, 48)
$BtnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 110)
$BtnStart.ForeColor = [System.Drawing.Color]::White
$BtnStart.FlatStyle = "Flat"
$BtnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$BtnStart.Add_Click({
    Save-AppConfig

    $RawJava = $Config.JavaPath.Trim()
    $JavaCmd = if ($RawJava -match '\\\\|/' -or $RawJava.EndsWith(".exe")) {
        "`"$RawJava`""
    } else {
        $RawJava
    }

    $RunnerBat = Join-Path $PSScriptRoot ".run_server.bat"
    $RestartLoop = if ($Config.AutoRestart) {
        "@echo Servidor caiu! Reiniciando em 5 segundos... & timeout /t 5 & goto INICIO"
    } else {
        "@echo. & @echo Servidor encerrado. Pressione qualquer tecla para fechar... & pause > nul"
    }

    $JvmFlags = $Config.CustomArgs
    $SrvFlags = $Config.ServerArgs

    $BatContent = @"
@echo off
chcp 65001 > nul
title Console Minecraft - $($Config.JarName)
:INICIO
cls
echo ========================================================
echo   MINECRAFT SERVER CONSOLE - $($Config.JarName)
echo   Memoria: $($Config.MinRam) - $($Config.MaxRam)
echo ========================================================
echo.
$JavaCmd -Xms$($Config.MinRam) -Xmx$($Config.MaxRam) $JvmFlags -jar "$($Config.JarName)" $SrvFlags
$RestartLoop
"@
    Set-Content -Path $RunnerBat -Value $BatContent -Encoding ASCII

    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$RunnerBat`""
})
$Form.Controls.Add($BtnStart)

# BOTÃO LIMPAR LOGS
$BtnClean = New-Object System.Windows.Forms.Button
$BtnClean.Text = "Limpar Logs Antigos"
$BtnClean.Location = New-Object System.Drawing.Point(25, 405)
$BtnClean.Size = New-Object System.Drawing.Size(220, 36)
$BtnClean.BackColor = [System.Drawing.Color]::FromArgb(58, 58, 60)
$BtnClean.ForeColor = [System.Drawing.Color]::White
$BtnClean.FlatStyle = "Flat"
$BtnClean.Cursor = [System.Windows.Forms.Cursors]::Hand
$BtnClean.Add_Click({
    $LogsDir = Join-Path $PSScriptRoot "logs"
    $CrashesDir = Join-Path $PSScriptRoot "crash-reports"
    $Count = 0
    if (Test-Path $LogsDir) {
        $Files = Get-ChildItem -Path $LogsDir -Filter "*.log.gz" -File
        $Count += $Files.Count
        $Files | Remove-Item -Force
    }
    if (Test-Path $CrashesDir) {
        $Crashes = Get-ChildItem -Path $CrashesDir -File
        $Count += $Crashes.Count
        $Crashes | Remove-Item -Force
    }
    [System.Windows.Forms.MessageBox]::Show("$Count arquivos de log e crash removidos!", "Limpeza Concluida", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})
$Form.Controls.Add($BtnClean)

# BOTÃO ABRIR PASTA DO SERVIDOR
$BtnFolder = New-Object System.Windows.Forms.Button
$BtnFolder.Text = "Abrir Pasta Raiz"
$BtnFolder.Location = New-Object System.Drawing.Point(260, 405)
$BtnFolder.Size = New-Object System.Drawing.Size(220, 36)
$BtnFolder.BackColor = [System.Drawing.Color]::FromArgb(58, 58, 60)
$BtnFolder.ForeColor = [System.Drawing.Color]::White
$BtnFolder.FlatStyle = "Flat"
$BtnFolder.Cursor = [System.Windows.Forms.Cursors]::Hand
$BtnFolder.Add_Click({
    Start-Process explorer.exe -ArgumentList $PSScriptRoot
})
$Form.Controls.Add($BtnFolder)

$Form.Add_FormClosing({
    Save-AppConfig
})

[void]$Form.ShowDialog()