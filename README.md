# PowerShell-Watch

[![Build status](https://ci.appveyor.com/api/projects/status/88kfxhpbhjvrc0ms?svg=true)](https://ci.appveyor.com/project/markwragg/powershell-watch) ![Test Coverage](https://img.shields.io/badge/coverage-95%25-green.svg?)

This PowerShell module contains a `Watch-Command` cmdlet that can be used to repeatedly run a PowerShell command or scriptblock to return output when it has changed.

![Watch-Command Get-Service Example](/Media/watch-command-get-service-continuous.png)


## Installation

The module is published in the PSGallery, so if you have PowerShell 5 can be installed by running:
```
Install-Module Watch -Scope CurrentUser
```

## Usage

You can use the `Watch-Command` cmdlet by providing it with a ScriptBlock. For example:

```
Watch-Command -ScriptBlock { Get-Process }
```

Alternatively ,the cmdlet has been designed so that if it is sent any input via the pipeline other than a ScriptBlock it interprets the pipeline commands that preceded it as the desired ScriptBlock.

This is for convenience, so that you can quickly and easily add `| Watch-Command` (or its Aliases `| watch` or `| wc`) to the end of an existing set of commands to run them repeatedly and output once a change has occurred. For example:

```
Get-Service | wc
```

By default the cmdlet will run the specified ScriptBlock every 1 second and then return its output in full once it has changed from the first iteration. You can change the duration between checks via the `-Seconds` parameter.

You can have the script run continuously (until interrupted via CTRL+C) by adding the `-Continuous` parameter.

You can have the script return only objects in a collection that have changed or been added by using the `-Difference` parameter.

If you use `-Verbose` you will see a timestamp in the console prior to a change being output (particularly useful when using `-Continuous` and `-Difference`).

For example:
```
Get-Service | Watch-Command -Diff -Cont -Verbose
```
This command will continually list output each time one of the default properties of a service has changed state. Verbose statements above each change will show when they occurred.

By default the cmdlet uses the `Compare-Object` cmdlet to perform the comparison of the object output by the ScriptBlock with its intitial interation. If the object has a Default Display Property Set (E.g the properties that appear by default in the console) then the comparison is limited to these properties by default. Otherwise it defaults to all available properties of the object.

If you want to specify specific properties to monitor for change, you can do so via the `-Property` parameter.

For example:
```
Get-Process | Watch-Command -Diff -Cont -Property id
```

![Watch-Command Get-Process Example](/Media/watch-command-get-process-id-continuous.png)

This command will continually list output each time the id property of the output of `Get-Process` has changed (e.g a new process has started). 

By default `Watch-Command` will use the Default Display Set of properties (if a set exists) as the properties to monitor. If a Default Display Set does not exist then it will use all properties. If you want to force the use of all properties you can specify `-Property *`.

You can also use Watch-Command to monitor non-PowerShell command output (which will generally be treated as strings). Here's an example of monitoring the output of ipconfig /all for a change to the DNS server addresses:

![Watch-Command ipconfig Example](/Media/watch-command-ipconfig.png)

If you want to force `Watch-Command` to treat the result of the command as an array of strings regardless of the object type returned, you can do so via the `-AsString` parameter.

## Cmdlets

A full list of cmdlets in this module is provided below for reference. Use `Get-Help <cmdlet name>` with these to learn more about their usage.

Cmdlet        | Description
--------------| -------------------------------------------------------------------------------
Watch-Command | Runs a scriptblock or the preceeding pipeline repeatedly until there is change.
Watch         | Alias for Watch-Command
wc            | Alias for Watch-Command
