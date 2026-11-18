# Watch-Command

## SYNOPSIS
Runs a scriptblock or the preceding pipeline repeatedly until there is change.

## SYNTAX

### Default (Default)
```
Watch-Command [-ScriptBlock] <Object> [[-Seconds] <Int32>] [-Continuous] [-AsString] [-ClearScreen] [-PassThru]
 [[-Property] <String[]>] [-ExcludeProperty <String[]>] [-Exclude <String[]>] [-ExcludePattern <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Difference
```
Watch-Command [-ScriptBlock] <Object> [[-Seconds] <Int32>] [-Difference] [-Continuous] [-AsString]
 [-ClearScreen] [-PassThru] [[-Property] <String[]>] [-ExcludeProperty <String[]>] [-Exclude <String[]>]
 [-ExcludePattern <String[]>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ChangeSummary
```
Watch-Command [-ScriptBlock] <Object> [[-Seconds] <Int32>] [-ChangeSummary] [-Key <String[]>] [-Continuous]
 [-AsString] [-ClearScreen] [-PassThru] [[-Property] <String[]>] [-ExcludeProperty <String[]>]
 [-Exclude <String[]>] [-ExcludePattern <String[]>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Watch-Command cmdlet runs a specified scriptblock repeatedly at the specified interval (or
every 1 second by default) and returns the result of the scriptblock when the output has changed.
For the command to work the specified scriptblock must return a result to the pipeline.

## EXAMPLES

### EXAMPLE 1
```
Watch-Command -ScriptBlock { Get-Process }
```

Runs Get-Process and returns the result when the data has changed.

### EXAMPLE 2
```
Get-Service | Watch-Command -Diff -Cont
```

Runs Get-Service and returns any differences in the resultant data, continuously until interrupted
by CTRL+C.

### EXAMPLE 3
```
Watch-Command { Get-Content test.txt } -Difference -Verbose -ClearScreen
```

Uses Get-Content to monitor test.txt.
Shows any changes and clears the screen between changes.

### EXAMPLE 4
```
Get-ChildItem | Watch-Command -Difference -AsString
```

Monitors the result of Get-ChildItem for changes, returns any differences.
Treats the input as
strings not objects.

### EXAMPLE 5
```
Get-Process | Watch-Command -Difference -Property processname,id -Continuous
```

Monitors Get-Process for differences in the specified properties only, continues until interrupted
by CTRL+C.

### EXAMPLE 6
```
Get-ChildItem C:\Temp | Watch-Command -ChangeSummary -Key Name -Continuous
```

Monitors a folder and reports each change as an 'Added', 'Removed' or 'Modified' object,
including which properties changed and their previous/current values, continuously until
interrupted by CTRL+C.

### EXAMPLE 7
```
ipconfig /all | Watch-Command -ChangeSummary -Continuous -Exclude '*Lease*'
```

Monitors the network configuration for changes, excluding the lease times, which ipconfig can show
shifting back and forth by a second between runs.

### EXAMPLE 8
```
ipconfig /all | Watch-Command -ChangeSummary -Continuous -ExcludePattern 'Lease (Obtained|Expires)'
```

As above, but uses a regular expression to exclude only the lease time lines.

### EXAMPLE 9
```
Get-ChildItem C:\Temp | Watch-Command -ChangeSummary -Key Name -ExcludeProperty LastWriteTime*
```

Monitors a folder like the example above, but ignores changes that only affect when the files were
last written to.

## PARAMETERS

### -ScriptBlock
The scriptblock to execute, specified via curly braces.
If you provide input via the pipeline that
isn't a scriptblock then the entire invocation line that preceded the cmdlet will be used as the
scriptblock input.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Seconds
Number of seconds to wait between checks.
Default = 1

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -Difference
Switch: Use to only output items in the collection that have changed
(additions or modifications).

```yaml
Type: SwitchParameter
Parameter Sets: Difference
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ChangeSummary
Switch: Instead of returning raw objects, reports each change as a clean object with
DetectedAt (when the change was detected), ChangeType ('Added', 'Removed' or 'Modified'), Key,
ChangedProperties, Changes (each changed property with its PreviousValue and CurrentValue), and
the whole item before and after the change as PreviousItem and CurrentItem.
Unlike -Difference,
this also reports items that were removed.
Cannot be combined with -Difference.

-Key is optional.
Without it, changes are only reported as 'Added' or 'Removed' (a changed item
appears as its old version removed and its new version added), and Key, ChangedProperties and
Changes are $null.
With -Key, items are paired up between checks, so a changed item is reported
as 'Modified', with its key value in Key, the names of the properties that changed in
ChangedProperties, and their previous and current values in Changes.

```yaml
Type: SwitchParameter
Parameter Sets: ChangeSummary
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Key
One or more property names that uniquely identify an item across checks (e.g.
Name or Id).
Items are paired up by this key between checks so that in-place changes are reported as
'Modified' (with the specific properties that changed) rather than appearing as an unrelated
removal and addition.
Implies -ChangeSummary, so specifying -ChangeSummary as well is optional.
Cannot be used with -Difference or -AsString.

```yaml
Type: String[]
Parameter Sets: ChangeSummary
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Continuous
Switch: Run continuously (even after a change has occurred) until exited with CTRL+C.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsString
Switch: Converts the result of the scriptblock into an array of strings for comparison.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClearScreen
Switch: Clears the screen between each different result.
You can also use 'cls' as an alias.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cls

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Switch: Passes through the initial result from the command (before any change has occurred).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Property
Manually specify one or more property names to be used for comparison.
If not specified,
the default display property set is used.
If there is not a default display property set,
all properties are used.
You can also use '*' to force all properties.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeProperty
One or more property names to leave out of the comparison, so changes to them are ignored.
Wildcards are supported (case-insensitive, e.g.
'Last*Time').
They are removed from whichever
properties would otherwise be compared (see -Property), so they can be combined with -Property *.
The properties are still output, as only the comparison changes.
Cannot be used with -AsString.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclude
One or more wildcard patterns (case-insensitive, e.g.
'*Lease*').
Items whose text matches any of
them are dropped from every result before comparing, so they are neither watched nor output.
Each
pattern must match the whole text, so use * either side to match part of it.
For text output
(e.g.
from a native command, or with -AsString) this excludes matching lines.
For objects it
matches each object's string form; for files and folders that is their full path.
This drops
whole items: to ignore some of an object's properties, use -ExcludeProperty.
Cannot be combined
with -ExcludePattern.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludePattern
One or more regular expressions (case-insensitive).
Works like -Exclude, but matches with regular
expressions instead of wildcards, which match anywhere in the text unless anchored with ^ or $.
Cannot be combined with -Exclude.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{Fill ProgressAction Description}}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
