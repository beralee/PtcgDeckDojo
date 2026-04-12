param(
    [int]$Rounds = 4,
    [int]$TimeBudgetSeconds = 1800,
    [int]$MirrorGames = 160,
    [int]$CrossGames = 96
)

$scriptPath = Join-Path $PSScriptRoot "run_decision_training.ps1"
& $scriptPath `
    -DeckName "gardevoir" `
    -DeckPrefix "gardevoir" `
    -Encoder "gardevoir" `
    -PipelineName "gardevoir_focus_training" `
    -PipelineSuffix "gardevoir_focus" `
    -OptimizedDeck 578647 `
    -Opponents @(575720, 575716, 569061) `
    -Rounds $Rounds `
    -TimeBudgetSeconds $TimeBudgetSeconds `
    -MirrorGames $MirrorGames `
    -CrossGames $CrossGames
