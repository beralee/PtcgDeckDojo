param(
    [int]$Rounds = 4,
    [int]$TimeBudgetSeconds = 1800,
    [int]$MirrorGames = 160,
    [int]$CrossGames = 96
)

$scriptPath = Join-Path $PSScriptRoot "run_decision_training.ps1"
& $scriptPath `
    -DeckName "miraidon" `
    -DeckPrefix "miraidon" `
    -Encoder "miraidon" `
    -PipelineName "miraidon_focus_training" `
    -PipelineSuffix "miraidon_focus" `
    -OptimizedDeck 575720 `
    -Opponents @(578647, 575716, 569061) `
    -Rounds $Rounds `
    -TimeBudgetSeconds $TimeBudgetSeconds `
    -MirrorGames $MirrorGames `
    -CrossGames $CrossGames
