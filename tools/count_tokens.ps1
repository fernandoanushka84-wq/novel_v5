$path = 'c:\lakmal_code\novel_mobile_app\lib\ui\screens\discover_screen.dart'
$s = Get-Content $path -Raw
Write-Output "LBRACE: $($s.ToCharArray() | Where-Object {$_ -eq '{'} | Measure-Object).Count"
Write-Output "RBRACE: $($s.ToCharArray() | Where-Object {$_ -eq '}'} | Measure-Object).Count"
Write-Output "LPAREN: $($s.ToCharArray() | Where-Object {$_ -eq '('} | Measure-Object).Count"
Write-Output "RPAREN: $($s.ToCharArray() | Where-Object {$_ -eq ')'} | Measure-Object).Count"
Write-Output "-- tail 300 chars --"
Write-Output ($s[-300..-1] -join '')
