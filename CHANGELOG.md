# Change Log

## [1.1.0] - 2026-09-23

* [Fix] Fixed `Watch-Command` repeatedly throwing `Compare-Object` errors (and never detecting a change) when the default "compare all properties" fallback picked up live-computed properties, such as a `FileInfo`'s `Target`/`LinkType`, which throw when accessed after the watched item has been deleted. Fixes [#3](https://github.com/markwragg/PowerShell-Watch/issues/3) (Thanks [@gregor-hh](https://github.com/gregor-hh)!)

## [1.0.31] - 2024-08-31

* [Fix] Fixed the `-ClearSceen` switch to only clear the screen after a difference has occurred when `-Diff` is used and before returning the first result when `-PassThru` is used. (Thanks [@ZHider](https://github.com/ZHider)!)

## [1.0.30] - 2023-03-08

* [Feature] Added a `-PassThru` parameter to `Watch-Command` so that the initial result is immediately returned, per the suggestion from [@th0th](https://github.com/th0th) in [#2](https://github.com/markwragg/PowerShell-Watch/issues/2)

## [1.0.29] - 2019-09-10

* Test deployment.
