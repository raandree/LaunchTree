# Entry ID resolution reads Generated State, which is JSON. The only caller left
# in this delivery is the activation timer, and single-instance activation is
# absent here, so the timer exits before reaching it. Fail loudly if it does.
function Resolve-LaunchTreeEntry {
    throw [System.NotSupportedException]::new(
        'Entry ID resolution is not part of the minimal LaunchTree delivery.'
    )
}
