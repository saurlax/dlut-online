$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot '../scripts/client/credential_store.ps1'
$key = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
function Invoke-Vault([string]$operation, [string]$value = '') {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $script = "& {`n$(Get-Content -Raw $helper)`n} '$operation' '$key'"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $info.Arguments = '-NoLogo -NoProfile -NonInteractive -EncodedCommand ' + $encoded
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    if ($operation -eq 'write') { $process.StandardInput.WriteLine($value) }
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Credential helper timed out' }
    return @{ code = $process.ExitCode; value = $process.StandardOutput.ReadToEnd().Trim() }
}
try {
    if ((Invoke-Vault 'read').code -ne 3) { throw 'Expected missing credential' }
    if ((Invoke-Vault 'write' 'test.token.only').code -ne 0) { throw 'Write failed' }
    $read = Invoke-Vault 'read'
    if ($read.code -ne 0 -or $read.value -ne 'test.token.only') { throw 'Read mismatch' }
    if ((Invoke-Vault 'write' 'updated.test.token').code -ne 0) { throw 'Update failed' }
    if ((Invoke-Vault 'read').value -ne 'updated.test.token') { throw 'Update mismatch' }
    if ((Invoke-Vault 'delete').code -ne 0) { throw 'Delete failed' }
    if ((Invoke-Vault 'read').code -ne 3) { throw 'Credential survived deletion' }
    Write-Output 'PASS: Windows credential read/write/update/delete'
} finally { $null = Invoke-Vault 'delete' }
