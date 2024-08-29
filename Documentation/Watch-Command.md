# Watch-Command

## SYNOPSIS
Runs a scriptblock or the preceeding pipeline repeatedly until there is change.

## SYNTAX

```
Watch-Command [-ScriptBlock] <Object> [[-Seconds] <Int32>] [-Difference] [-Continuous] [-AsString]
 [-ClearScreen] [-ClearScreenIfDifferent] [-PassThru] [[-Property] <String[]>] [<CommonParameters>]
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

Runs Get-Process and waits for any returns the result when the data has changed.

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

Monitors the result of GEt-ChildItem for changes, returns any differences.
Treats the input as
strings not objects.

### EXAMPLE 5
```
Get-Process | Watch-Command -Difference -Property processname,id -Continuous
```

Monitors Get-Process for differences in the specified properties only, continues until interrupted
by CTRL+C.

## PARAMETERS

### -ScriptBlock
The scriptblock to execute, specified via curly braces.
If you provide input via the pipleine that
isn't a scriptblock then the entire invocation line that preceeded the cmdlet will be used as the
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
dditions or modifications).

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
Switch: Clears the screen between each result.
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

### -ClearScreenIfDifferent
Switch: Clears the screen before each different result.

```yaml
Type: SwitchParameter
Parameter Sets: (All)

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
