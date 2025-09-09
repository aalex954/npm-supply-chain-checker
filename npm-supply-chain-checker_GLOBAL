# Known-bad versions (Sep 9, 2025)
$bad = @{
  'ansi-styles'=@('6.2.2'); 'debug'=@('4.4.2'); 'chalk'=@('5.6.1');
  'supports-color'=@('10.2.1'); 'strip-ansi'=@('7.1.1'); 'ansi-regex'=@('6.2.1');
  'wrap-ansi'=@('9.0.1'); 'color-convert'=@('3.1.1'); 'color-name'=@('2.0.1');
  'is-arrayish'=@('0.3.3'); 'slice-ansi'=@('7.1.1'); 'color'=@('5.0.1');
  'color-string'=@('2.1.1'); 'simple-swizzle'=@('0.2.3'); 'supports-hyperlinks'=@('4.1.1');
  'has-ansi'=@('6.0.1'); 'chalk-template'=@('1.1.1'); 'backslash'=@('0.2.1')
}

function Get-NpmTree {
  param([switch]$Global)
  $args = @('--all','--json'); if($Global){ $args = @('-g') + $args }
  $json = npm ls @args 2>$null
  if(!$json){ return @() }
  try { $obj = $json | ConvertFrom-Json } catch { return @() }

  $out = New-Object System.Collections.Generic.List[object]
  function Walk($deps){
    if(!$deps){ return }
    foreach($e in $deps.GetEnumerator()){
      $name = $e.Key
      $info = $e.Value
      if([string]::IsNullOrWhiteSpace($name)){ continue }
      $ver = if($info -and $info.version){ $info.version } else { $null }
      $out.Add([pscustomobject]@{ name = $name; version = $ver }) | Out-Null
      if($info -and $info.dependencies){ Walk $info.dependencies }
    }
  }
  Walk $obj.dependencies
  $out | Where-Object { $_.name } | Sort-Object name,version -Unique
}

$tree =  (Get-NpmTree) + (Get-NpmTree -Global)
$hits = $tree | Where-Object {
  $_.name -and $_.version -and $bad.ContainsKey($_.name) -and $bad[$_.name] -contains $_.version
}

if($hits){ $hits | Format-Table -Auto } else { 'No known-bad versions found.' }
