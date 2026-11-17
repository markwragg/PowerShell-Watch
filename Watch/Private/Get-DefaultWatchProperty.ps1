function Get-DefaultWatchProperty {
    <#
        .SYNOPSIS
            Returns the names of the properties to compare on an object that has no default display property
            set: its regular (Property/NoteProperty) members, minus ones that change without the item changing.

        .DESCRIPTION
            Excludes ScriptProperty/CodeProperty/AliasProperty members (e.g. a FileInfo's Target/LinkType),
            which are computed live from the filesystem on every access and throw if the item has since been
            deleted, rather than comparing against a snapshot of the value. See issue #3.

            Also excludes last-access times (e.g. a FileSystemInfo's LastAccessTime/LastAccessTimeUtc). Merely
            reading a file updates them, and NTFS only copies the new value into the directory listing that
            Get-ChildItem reads at some later point, so they produce "changes" at seemingly random times. They
            can still be watched by naming them with -Property (or using -Property *).

            This is the single definition used both to choose what Compare-Object compares and to decide which
            properties of a keyed item have changed, so the two can't drift apart.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]
        $InputObject
    )

    $Excluded = 'LastAccessTime', 'LastAccessTimeUtc'

    foreach ($Member in $InputObject.PSObject.Properties) {
        if ($Member.MemberType -in 'Property', 'NoteProperty' -and $Member.Name -notin $Excluded) {
            $Member.Name
        }
    }
}
