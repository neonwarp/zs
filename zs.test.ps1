Describe "z function" {
    BeforeAll {
        $global:ZS_EXE_PATH = "$PSScriptRoot\zig-out\bin\zs.exe"
        Set-Content -Path $global:ZS_EXE_PATH -Value "@echo C:\MockPath"
    }

    It "Should change location if zs.exe returns a valid path" {
        function z {
            param($arg)
            $zsOutputFile = "$env:TEMP\zs_output.txt"
            Start-Process -FilePath $global:ZS_EXE_PATH `
                -ArgumentList "query", "--", $arg `
                -RedirectStandardOutput $zsOutputFile `
                -NoNewWindow -Wait

            $result = Get-Content $zsOutputFile | Out-String
            $result = $result.Trim()
            if ($LASTEXITCODE -eq 0 -and (Test-Path $result)) {
                Set-Location $result
            }
            else {
                Write-Host "No match for '$arg'"
            }
        }

        New-Item -ItemType Directory -Path "C:\MockPath" -Force | Out-Null
        z "test"
        (Get-Location).Path | Should -Be "C:\MockPath"
    }

    AfterAll {
        Remove-Item -Path "C:\MockPath" -Recurse -Force -ErrorAction SilentlyContinue
    }
}