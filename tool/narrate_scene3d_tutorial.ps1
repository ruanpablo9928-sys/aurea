$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$tutorialRoot = Join-Path $PSScriptRoot '..\output\tutorial-scene3d'
$tutorialRoot = [IO.Path]::GetFullPath($tutorialRoot)
$audioFolder = Join-Path $tutorialRoot 'narration'
New-Item -ItemType Directory -Path $audioFolder -Force | Out-Null
$clips = Get-Content -LiteralPath (Join-Path $tutorialRoot 'recording\clips.json') -Raw | ConvertFrom-Json
$groups = [Collections.Generic.List[object]]::new()
$previousKey = ''
foreach ($clip in $clips) {
    $nextKey = "$($clip.chapter)|$($clip.caption)"
    if ($nextKey -ne $previousKey) {
        $groups.Add([pscustomobject]@{ text=$clip.caption; file=('voice-{0:D3}.wav' -f $groups.Count) })
        $previousKey = $nextKey
    }
}
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $speaker.SelectVoice('Microsoft Maria Desktop')
    $speaker.Rate = 0
    foreach ($group in $groups) {
        $speechText = $group.text.Replace('Auto-key','keyframes automáticos').Replace('Camera','Câmera').Replace('2.50','2,5').Replace('5.00','5').Replace('7.50','7,5')
        $speaker.SetOutputToWaveFile((Join-Path $audioFolder $group.file))
        $speaker.Speak($speechText)
        $speaker.SetOutputToNull()
    }
} finally { $speaker.Dispose() }
$groups | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $audioFolder 'manifest.json') -Encoding utf8
Write-Output "Narração criada: $($groups.Count) passos em português."
