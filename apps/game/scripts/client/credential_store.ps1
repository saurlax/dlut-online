param(
    [ValidateSet('read', 'write', 'delete')][string]$Operation,
    [ValidatePattern('^[a-f0-9]{64}$')][string]$AccountKey
)
$ErrorActionPreference = 'Stop'
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DLUTCredential {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct Credential {
        public UInt32 Flags, Type;
        public string TargetName, Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 BlobSize;
        public IntPtr Blob;
        public UInt32 Persist, AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias, UserName;
    }
    [DllImport("advapi32.dll", EntryPoint="CredReadW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool Read(string target, UInt32 type, UInt32 flags, out IntPtr result);
    [DllImport("advapi32.dll", EntryPoint="CredWriteW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool Write(ref Credential credential, UInt32 flags);
    [DllImport("advapi32.dll", EntryPoint="CredDeleteW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool Delete(string target, UInt32 type, UInt32 flags);
    [DllImport("advapi32.dll")] public static extern void CredFree(IntPtr buffer);
}
'@
    $target = 'com.saurlax.dlutonline.account/' + $AccountKey
    if ($Operation -eq 'read') {
        $pointer = [IntPtr]::Zero
        if (-not [DLUTCredential]::Read($target, 1, 0, [ref]$pointer)) {
            if ([Runtime.InteropServices.Marshal]::GetLastWin32Error() -eq 1168) { exit 3 }
            exit 1
        }
        try {
            $credential = [Runtime.InteropServices.Marshal]::PtrToStructure($pointer, [type][DLUTCredential+Credential])
            $bytes = New-Object byte[] $credential.BlobSize
            [Runtime.InteropServices.Marshal]::Copy($credential.Blob, $bytes, 0, $bytes.Length)
            [Console]::Out.WriteLine([Text.Encoding]::UTF8.GetString($bytes))
            [Array]::Clear($bytes, 0, $bytes.Length)
        } finally { [DLUTCredential]::CredFree($pointer) }
    } elseif ($Operation -eq 'write') {
        $token = [Console]::In.ReadLine()
        if ($token -notmatch '^[A-Za-z0-9._-]+$' -or $token.Length -gt 2500) { exit 1 }
        $bytes = [Text.Encoding]::UTF8.GetBytes($token)
        $token = $null
        $pointer = [Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length)
        try {
            [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $pointer, $bytes.Length)
            $credential = New-Object DLUTCredential+Credential
            $credential.Type = 1
            $credential.TargetName = $target
            $credential.UserName = 'DLUT Online'
            $credential.Persist = 2
            $credential.BlobSize = $bytes.Length
            $credential.Blob = $pointer
            if (-not [DLUTCredential]::Write([ref]$credential, 0)) { exit 1 }
        } finally {
            [Array]::Clear($bytes, 0, $bytes.Length)
            [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $pointer, $bytes.Length)
            [Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)
        }
    } else {
        if (-not [DLUTCredential]::Delete($target, 1, 0)) {
            if ([Runtime.InteropServices.Marshal]::GetLastWin32Error() -eq 1168) { exit 3 }
            exit 1
        }
    }
    exit 0
} catch { exit 1 }
