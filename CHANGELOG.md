# Change Log

## !Deploy 1.2.0

* [Feature] Added a `-ChangeSummary` switch to `Watch-Command` that reports each change as a clean object (`DetectedAt` timestamp, `ChangeType` of `Added`, `Removed` or `Modified`, plus the whole item before and after the change as `PreviousItem`/`CurrentItem`) instead of raw `Compare-Object` output, and fixes removed items never being reported (previously only additions/modifications surfaced under `-Difference`). Use the new `-Key` parameter (e.g. `-Key Name`, which implies `-ChangeSummary`) to pair up the same logical item across checks and detect in-place modifications, including which properties changed (`ChangedProperties`) and their before and after values (`Changes`, with `PreviousValue`/`CurrentValue` for each property). Change summaries display as a fixed-width table by default, so with `-Continuous` each change appears as soon as it is detected (rather than being held back by `Format-Table` until the next change arrives).
* [Fix] The pipeline shorthand (e.g. `Get-ChildItem | Watch-Command`) now parses the command rather than splitting the line text, so it re-runs only the commands piped into `Watch-Command`. Previously an assignment (`$r = Get-ChildItem | Watch-Command`) or an earlier `;`-separated statement on the same line was re-run as part of every check, pipelines split across several lines in a script didn't work, and pipelines starting with an expression (e.g. `$Items | Watch-Command`) were rejected. The piped commands also now run in the caller's scope, so they can use a calling function's local variables.
* [Fix] When `-Property` isn't specified and `Watch-Command` falls back to comparing every property (e.g. when `Get-ChildItem` lists a folder first), `LastAccessTime` and `LastAccessTimeUtc` are no longer compared. Reading a file updates them, and NTFS only updates the folder listing's copy at some later point, so files were reported as changed at seemingly random times. They can still be watched by naming them with `-Property`.
* [Fix] When the watched command returned nothing (e.g. an empty folder), `Watch-Command` re-ran it continuously without waiting `-Seconds` between checks. It also chose which properties to compare from the first result only, so if that was empty, later modifications to items that appeared were never detected. Both now work once the command returns its first item.

## [1.1.0] - 2026-09-23

* [Fix] Fixed `Watch-Command` repeatedly throwing `Compare-Object` errors (and never detecting a change) when the default "compare all properties" fallback picked up live-computed properties, such as a `FileInfo`'s `Target`/`LinkType`, which throw when accessed after the watched item has been deleted. Fixes [#3](https://github.com/markwragg/PowerShell-Watch/issues/3) (Thanks [@gregor-hh](https://github.com/gregor-hh)!)

## [1.0.31] - 2024-08-31

* [Fix] Fixed the `-ClearScreen` switch to only clear the screen after a difference has occurred when `-Diff` is used and before returning the first result when `-PassThru` is used. (Thanks [@ZHider](https://github.com/ZHider)!)

## [1.0.30] - 2023-03-08

* [Feature] Added a `-PassThru` parameter to `Watch-Command` so that the initial result is immediately returned, per the suggestion from [@th0th](https://github.com/th0th) in [#2](https://github.com/markwragg/PowerShell-Watch/issues/2)

## [1.0.29] - 2019-09-10

* Test deployment.
