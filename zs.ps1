if (-not $global:ZS_EXE_PATH) {
    $global:ZS_EXE_PATH = "C:\zs\zs.exe"
}

$global:ZS_LastPath = $null

if (-not $global:OriginalPrompt) {
    $global:OriginalPrompt = $function:prompt
}

function z {
    param($arg)
    $result = (& $global:ZS_EXE_PATH query -- $arg).Trim()
    if ($LASTEXITCODE -eq 0 -and (Test-Path $result)) {
        Set-Location $result
    }
    else {
        Write-Host "No match for '$arg'"
    }
}

function global:prompt {
    if ($global:OriginalPrompt) {
        & $global:OriginalPrompt
    }

    $current = (Get-Location).ProviderPath
    if ($global:ZS_LastPath -ne $current) {
        $global:ZS_LastPath = $current
        try {
            & $global:ZS_EXE_PATH --add $current | Out-Null
        }
        catch {
            Write-Debug "Failed to add path to ZS: $_"
        }
    }

    return "$(Get-Location)> "
}