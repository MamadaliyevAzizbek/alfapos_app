param(
    [Parameter(Mandatory = $true)][string]$PrinterName,
    [Parameter(Mandatory = $true)][string]$DataFile
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $DataFile)) { exit 2 }

$dllDir = Join-Path $env:LOCALAPPDATA 'AlfaPOS'
$dllPath = Join-Path $dllDir 'raw_print.dll'
if (-not (Test-Path -LiteralPath $dllPath)) {
    New-Item -ItemType Directory -Force -Path $dllDir | Out-Null
    Add-Type -OutputAssembly $dllPath -Language CSharp @"
using System;
using System.Runtime.InteropServices;
public class AlfaPosRawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct DOCINFO {
    [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPWStr)] public string pDatatype;
  }
  [DllImport("winspool.drv", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool OpenPrinter(string p, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool StartDocPrinter(IntPtr h, int lvl, ref DOCINFO di);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool WritePrinter(IntPtr h, byte[] b, int c, out int w);
  public static bool Send(string printer, byte[] data) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) return false;
    var di = new DOCINFO { pDocName = "AlfaPOS", pDatatype = "RAW" };
    if (!StartDocPrinter(h, 1, ref di)) { ClosePrinter(h); return false; }
    if (!StartPagePrinter(h)) { EndDocPrinter(h); ClosePrinter(h); return false; }
    int written;
    WritePrinter(h, data, data.Length, out written);
    EndPagePrinter(h);
    EndDocPrinter(h);
    ClosePrinter(h);
    return written > 0;
  }
}
"@
}

$bytes = [System.IO.File]::ReadAllBytes($DataFile)
$type = [Reflection.Assembly]::LoadFrom($dllPath).GetType('AlfaPosRawPrint')
$ok = $type.GetMethod('Send').Invoke($null, @($PrinterName, $bytes))
if ($ok) { exit 0 } else { exit 1 }
