# Known-bad versions (Sep 9, 2025)
$bad = @{
  'ansi-styles'=@(); 'debug'=@(); 'backslash'=@(); 'chalk-template'=@()
  'supports-hyperlinks'=@(); 'has-ansi'=@(); 'simple-swizzle'=@(); 'color-string'=@()
  'error-ex'=@(); 'color-name'=@(); 'is-arrayish'=@(); 'slice-ansi'=@()
  'color-convert'=@(); 'wrap-ansi'=@(); 'ansi-regex'=@(); 'supports-color'=@()
  'strip-ansi'=@(); 'chalk'=@()
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