# Requires Node. Uses npx to handle .asar archives.
$names = @('ansi-styles','debug','backslash','chalk-template','supports-hyperlinks','has-ansi','simple-swizzle','color-string','error-ex','color-name','is-arrayish','slice-ansi','color-convert','wrap-ansi','ansi-regex','supports-color','strip-ansi','chalk')
$bad = @{
  'ansi-styles'=@('6.2.2'); 'debug'=@('4.4.2'); 'chalk'=@('5.6.1');
  'supports-color'=@('10.2.1'); 'strip-ansi'=@('7.1.1'); 'ansi-regex'=@('6.2.1');
  'wrap-ansi'=@('9.0.1'); 'color-convert'=@('3.1.1'); 'color-name'=@('2.0.1');
  'is-arrayish'=@('0.3.3'); 'slice-ansi'=@('7.1.1'); 'color'=@('5.0.1');
  'color-string'=@('2.1.1'); 'simple-swizzle'=@('0.2.3'); 'supports-hyperlinks'=@('4.1.1');
  'has-ansi'=@('6.0.1'); 'chalk-template'=@('1.1.1'); 'backslash'=@('0.2.1')
}

function Scan-NodeModules([string]$root){
  if(-not (Test-Path $root)){ return @() }
  $hits = @()
  Get-ChildItem -Path $root -Recurse -Directory -Filter node_modules -ErrorAction SilentlyContinue |
    ForEach-Object {
      foreach($n in $names){
        $pkg = Join-Path $_.FullName "$n\package.json"
        if(Test-Path $pkg){
          try{
            $pj = Get-Content -Raw $pkg | ConvertFrom-Json
            if($pj -and $pj.name -and $pj.version){
              if($bad.ContainsKey($pj.name) -and $bad[$pj.name] -contains $pj.version){
                $hits += [pscustomobject]@{ appRoot=$root; name=$pj.name; version=$pj.version; file=$pkg }
              }
            }
          } catch {}
        }
      }
    }
  return $hits  # never $null
}

function Extract-Asar([string]$asar,[string]$dest){
  try{
    if(Test-Path $dest){ Remove-Item -Recurse -Force $dest }
    & npx --yes asar extract "$asar" "$dest" 2>$null | Out-Null
  } catch {}
  return (Test-Path $dest)
}

$roots = @(
  "$env:LOCALAPPDATA\Programs",
  "$env:ProgramFiles",
  "$env:ProgramFiles(x86)",
  "$env:APPDATA"
) | Where-Object { Test-Path $_ }

$all = @()

foreach($r in $roots){
  # Packed Electron bundles
  Get-ChildItem -Path $r -Recurse -File -Filter app.asar -ErrorAction SilentlyContinue | ForEach-Object {
    $asar = $_.FullName
    $resDir = Split-Path $asar
    $unpacked = Join-Path $resDir 'app.asar.unpacked'
    if(Test-Path $unpacked){
      $found = Scan-NodeModules $unpacked
      if($found){ $all += $found }
    } else {
      $tmp = Join-Path $env:TEMP ("asar-scan\" + ($_.Directory.Parent.Name + "_" + $_.Directory.Name))
      if(Extract-Asar $asar $tmp){
        $found = Scan-NodeModules $tmp
        if($found){ $all += $found }
        try{ Remove-Item -Recurse -Force $tmp } catch {}
      }
    }
  }

  # Unpacked app folders (resources\app\…)
  Get-ChildItem -Path $r -Recurse -Directory -Filter app -ErrorAction SilentlyContinue |
    ForEach-Object {
      $found = Scan-NodeModules $_.FullName
      if($found){ $all += $found }
    }
}

if($all){ $all | Sort-Object appRoot,name,version,file | Format-Table -Auto }
else { 'No known-bad versions found in Electron app bundles.' }
