$path='D:\SCHOOL\CAPSTONE\growbrain_flutter\growbrain_flutter\lib\main.dart'
$s = Get-Content $path -Raw
# remove single and double quoted strings (basic)
$s = $s -replace "'(?:[^'\\]|\\.)*'", ''
$s = $s -replace '"(?:[^"\\]|\\.)*"', ''
# remove // comments
$s = ($s -split "\r?\n") | ForEach-Object { $_ -replace '//.*','' } | Out-String
# remove /* */ comments
$s = $s -replace '/\*(?:.|\n|\r)*?\*/',''
$lines = $s -split "\r?\n"
$stack = @()
for($ln=0;$ln -lt $lines.Length;$ln++){
  $line = $lines[$ln]
  for($i=0;$i -lt $line.Length;$i++){
    $ch = $line[$i]
    if($ch -eq '('){ $stack += @{line=$ln+1; col=$i+1} }
    elseif($ch -eq ')'){
      if($stack.Count -gt 0){ $stack = $stack[0..($stack.Count-2)] } else { Write-Output "Unmatched ) at $($ln+1):$($i+1)" }
    }
  }
}
if($stack.Count -eq 0){ Write-Output 'No unmatched ( found' } else { Write-Output "Unmatched '(' count: $($stack.Count)"; $stack | ForEach-Object { Write-Output "line:$($_.line) col:$($_.col)" } }
