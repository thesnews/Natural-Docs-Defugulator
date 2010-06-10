###############################################################################
#
#   Package: NaturalDocs::Menu
#
###############################################################################
#
#   A package handling the menu's contents and state.
#
#   Usage and Dependencies:
#
#       - The <Event Handlers> can be called by <NaturalDocs::Project> immediately.
#
#       - Prior to initialization, <NaturalDocs::Project> must be initialized, and all files that have been changed must be run
#         through <NaturalDocs::Parser->ParseForInformation()>.
#
#       - To initialize, call <LoadAndUpdate()>.  Afterwards, all other functions are available.  Also, <LoadAndUpdate()> will
#         call <NaturalDocs::Settings->GenerateDirectoryNames()>.
#
#       - To save the changes back to disk, call <Save()>.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2008 Greg Valure
# Natural Docs is licensed under the GPL

use Tie::RefHash;

use NaturalDocs::Menu::Entry;

use strict;
use integer;

package NaturalDocs::Menu;


#
#   Constants: Constants
#
#   MAXFILESINGROUP - The maximum number of file entries that can be present in a group before it becomes a candidate for
#                                  sub-grouping.
#   MINFILESINNEWGROUP - The minimum number of file entries that must be present in a group before it will be automatically
#                                        created.  This is *not* the number of files that must be in a group before it's deleted.
#
use constant MAXFILESINGROUP => 0;
use constant MINFILESINNEWGROUP => 0;


###############################################################################
# Group: Variables


#
#   bool: hasChanged
#
#   Whether the menu changed or not, regardless of why.
#
my $hasChanged;


#
#   Object: menu
#
#   The parsed menu file.  Is stored as a <MENU_GROUP> <NaturalDocs::Menu::Entry> object, with the top-level entries being
#   stored as the group's content.  This is done because it makes a number of functions simpler to implement, plus it allows group
#   flags to be set on the top-level.  However, it is exposed externally via <Content()> as an arrayref.
#
#   This structure will only contain objects for <MENU_FILE>, <MENU_GROUP>, <MENU_TEXT>, <MENU_LINK>, and
#   <MENU_INDEX> entries.  Other types, such as <MENU_TITLE>, are stored in variables such as <title>.
#
my $menu;

#
#   hash: defaultTitlesChanged
#
#   An existence hash of default titles that have changed, since <OnDefaultTitleChange()> will be called before
#   <LoadAndUpdate()>.  Collects them to be applied later.  The keys are the <FileNames>.
#
my %defaultTitlesChanged;

#
#   String: title
#
#   The title of the menu.
#
my $title;

#
#   String: subTitle
#
#   The sub-title of the menu.
#
my $subTitle;

#
#   String: footer
#
#   The footer for the documentation.
#
my $footer;

#
#   String: timestampText
#
#   The timestamp for the documentation, stored as the final output text.
#
my $timestampText;

#
#   String: timestampCode
#
#   The timestamp for the documentation, storted as the symbolic code.
#
my $timestampCode;

#
#   hash: indexes
#
#   An existence hash of all the defined index <TopicTypes> appearing in the menu.
#
my %indexes;

#
#   hash: previousIndexes
#
#   An existence hash of all the index <TopicTypes> that appeared in the menu last time.
#
my %previousIndexes;

#
#   hash: bannedIndexes
#
#   An existence hash of all the index <TopicTypes> that the user has manually deleted, and thus should not be added back to
#   the menu automatically.
#
my %bannedIndexes;


###############################################################################
# Group: Files

#
#   File: Menu.txt
#
#   The file used to generate the menu.
#
#   Format:
#
#       The file is plain text.  Blank lines can appear anywhere and are ignored.  Tags and their content must be completely
#       contained on one line with the exception of Group's braces.  All values in brackets below are encoded with entity characters.
#
#       > # [comment]
#
#       The file supports single-line comments via #.  They can appear alone on a line or after content.
#
#       > Format: [version]
#       > Title: [title]
#       > SubTitle: [subtitle]
#       > Footer: [footer]
#       > Timestamp: [timestamp code]
#
#       The file format version, menu title, subtitle, footer, and timestamp are specified as above.  Each can only be specified once,
#       with subsequent ones being ignored.  Subtitle is ignored if Title is not present.  Format must be the first entry in the file.  If
#       it's not present, it's assumed the menu is from version 0.95 or earlier, since it was added with 1.0.
#
#       The timestamp code is as follows.
#
#           m - Single digit month, where applicable.  January is "1".
#           mm - Always double digit month.  January is "01".
#           mon - Short month word.  January is "Jan".
#           month - Long month word.  January is "January".
#           d - Single digit day, where applicable.  1 is "1".
#           dd - Always double digit day.  1 is "01".
#           day - Day with text extension.  1 is "1st".
#           yy - Double digit year.  2006 is "06".
#           yyyy - Four digit year.  2006 is "2006".
#           year - Four digit year.  2006 is "2006".
#
#       Anything else is left literal in the output.
#
#       > File: [title] ([file name])
#       > File: [title] (auto-title, [file name])
#       > File: [title] (no auto-title, [file name])
#
#       Files are specified as above.  If there is only one input directory, file names are relative.  Otherwise they are absolute.
#       If "no auto-title" is specified, the title on the line is used.  If not, the title is ignored and the
#       default file title is used instead.  Auto-title defaults to on, so specifying "auto-title" is for compatibility only.
#
#       > Group: [title]
#       > Group: [title] { ... }
#
#       Groups are specified as above.  If no braces are specified, the group's content is everything that follows until the end of the
#       file, the next group (braced or unbraced), or the closing brace of a parent group.  Group braces are the only things in this
#       file that can span multiple lines.
#
#       There is no limitations on where the braces can appear.  The opening brace can appear after the group tag, on its own line,
#       or preceding another tag on a line.  Similarly, the closing brace can appear after another tag or on its own line.  Being
#       bitchy here would just get in the way of quick and dirty editing; the package will clean it up automatically when it writes it
#       back to disk.
#
#       > Text: [text]
#
#       Arbitrary text is specified as above.  As with other tags, everything must be contained on the same line.
#
#       > Link: [URL]
#       > Link: [title] ([URL])
#
#       External links can be specified as above.  If the titled form is not used, the URL is used as the title.
#
#       > Index: [name]
#       > [topic type name] Index: [name]
#
#       Indexes are specified as above.  The topic type names can be either singular or plural.  General is assumed if not specified.
#
#       > Don't Index: [topic type name]
#       > Don't Index: [topic type name], [topic type name], ...
#
#       The option above prevents indexes that exist but are not on the menu from being automatically added.
#
#       > Data: [number]([obscured data])
#
#       Used to store non-user editable data.
#
#       > Data: 1([obscured: [directory name]///[input directory]])
#
#       When there is more than one directory, these lines store the input directories used in the last run and their names.  This
#       allows menu files to be shared across machines since the names will be consistent and the directories can be used to convert
#       filenames to the local machine's paths.  We don't want this user-editable because they may think changing it changes the
#       input directories, when it doesn't.  Also, changing it without changing all the paths screws up resolving.
#
#       > Data: 2([obscured: [directory name])
#
#       When there is only one directory and its name is not "default", this stores the name.
#
#
#   Entities:
#
#       &amp; - Ampersand.
#       &lparen; - Left parenthesis.
#       &rparen; - Right parenthesis.
#       &lbrace; - Left brace.
#       &rbrace; - Right brace.
#
#
#   Revisions:
#
#       1.4:
#
#           - Added Timestamp property.
#           - Values are now encoded with entity characters.
#
#       1.3:
#
#           - File names are now relative again if there is only one input directory.
#           - Data: 2(...) added.
#           - Can't use synonyms like "copyright" for "footer" or "sub-title" for "subtitle".
#           - "Don't Index" line now requires commas to separate them, whereas it tolerated just spaces before.
#
#       1.16:
#
#           - File names are now absolute instead of relative.  Prior to 1.16 only one input directory was allowed, so they could be
#             relative.
#           - Data keywords introduced to store input directories and their names.
#
#       1.14:
#
#           - Renamed this file from NaturalDocs_Menu.txt to Menu.txt.
#
#       1.1:
#
#           - Added the "don't index" line.
#
#           This is also the point where indexes were automatically added and removed, so all index entries from prior revisions
#           were manually added and are not guaranteed to contain anything.
#
#       1.0:
#
#           - Added the format line.
#           - Added the "no auto-title" attribute.
#           - Changed the file entry default to auto-title.
#
#           This is also the point where auto-organization and better auto-titles were introduced.  All groups in prior revisions were
#           manually added, with the exception of a top-level Other group where new files were automatically added if there were
#           groups defined.
#
#       Break in support:
#
#           Releases prior to 1.0 are no longer supported.  Why?
#
#           - They don't have a Format: line, which is required by <NaturalDocs::ConfigFile>, although I could work around this
#             if I needed to.
#           - No significant number of downloads for pre-1.0 releases.
#           - Code simplification.  I don't have to bridge the conversion from manual-only menu organization to automatic.
#
#       0.9:
#
#           - Added index entries.
#

#
#   File: PreviousMenuState.nd
#
#   The file used to store the previous state of the menu so as to detect changes.
#
#
#   Format:
#
#   > [BINARY_FORMAT]
#   > [VersionInt: app version]
#
#   First is the standard <BINARY_FORMAT> <VersionInt> header.
#
#   > [UInt8: 0 (end group)]
#   > [UInt8: MENU_FILE] [UInt8: noAutoTitle] [AString16: title] [AString16: target]
#   > [UInt8: MENU_GROUP] [AString16: title]
#   > [UInt8: MENU_INDEX] [AString16: title] [AString16: topic type]
#   > [UInt8: MENU_LINK] [AString16: title] [AString16: url]
#   > [UInt8: MENU_TEXT] [AString16: text]
#
#   The first UInt8 of each following line is either zero or one of the <Menu Entry Types>.  What follows is contextual.
#
#   There are no entries for title, subtitle, or footer.  Only the entries present in <menu>.
#
#   See Also:
#
#       <File Format Conventions>
#
#   Dependencies:
#
#       - Because the type is represented by a UInt8, the <Menu Entry Types> must all be <= 255.
#
#   Revisions:
#
#       1.3:
#
#           - The topic type following the <MENU_INDEX> entries were changed from UInt8s to AString16s, since <TopicTypes>
#             were switched from integer constants to strings.  You can still convert the old to the new via
#             <NaturalDocs::Topics->TypeFromLegacy()>.
#
#       1.16:
#
#           - The file targets are now absolute.  Prior to 1.16, they were relative to the input directory since only one was allowed.
#
#       1.14:
#
#           - The file was renamed from NaturalDocs.m to PreviousMenuState.nd and moved into the Data subdirectory.
#
#       1.0:
#
#           - The file's format was completely redone.  Prior to 1.0, the file was a text file consisting of the app version and a line
#             which was a tab-separated list of the indexes present in the menu.  * meant the general index.
#
#       Break in support:
#
#           Pre-1.0 files are no longer supported.  There was no significant number of downloads for pre-1.0 releases, and this
#           eliminates a separate code path for them.
#
#       0.95:
#
#           - Change the file version to match the app version.  Prior to 0.95, the version line was 1.  Test for "1" instead of "1.0" to
#             distinguish.
#
#       0.9:
#
#           - The file was added to the project.  Prior to 0.9, it didn't exist.
#


###############################################################################
# Group: File Functions

#
#   Function: LoadAndUpdate
#
#   Loads the menu file from disk and updates it.  Will add, remove, rearrange, and remove auto-titling from entries as
#   necessary.  Will also call <NaturalDocs::Settings->GenerateDirectoryNames()>.
#
sub LoadAndUpdate
    {
    my ($self) = @_;

    my ($inputDirectoryNames, $relativeFiles, $onlyDirectoryName) = $self->LoadMenuFile();

    my $errorCount = NaturalDocs::ConfigFile->ErrorCount();
    if ($errorCount)
        {
        NaturalDocs::ConfigFile->PrintErrorsAndAnnotateFile();
        NaturalDocs::Error->SoftDeath('There ' . ($errorCount == 1 ? 'is an error' : 'are ' . $errorCount . ' errors')
                                                    . ' in ' . NaturalDocs::Project->UserConfigFile('Menu.txt'));
        };

    # If the menu has a timestamp and today is a different day than the last time Natural Docs was run, we have to count it as the
    # menu changing.
    if (defined $timestampCode)
        {
        my (undef, undef, undef, $currentDay, $currentMonth, $currentYear) = localtime();
        my (undef, undef, undef, $lastDay, $lastMonth, $lastYear) =
            localtime( (stat( NaturalDocs::Project->DataFile('PreviousMenuState.nd') ))[9] );
            # This should be okay if the previous menu state file doesn't exist.

        if ($currentDay != $lastDay || $currentMonth != $lastMonth || $currentYear != $lastYear)
            {  $hasChanged = 1;  };
        };


    if ($relativeFiles)
        {
        my $inputDirectory = $self->ResolveRelativeInputDirectories($onlyDirectoryName);

        if ($onlyDirectoryName)
            {  $inputDirectoryNames = { $inputDirectory => $onlyDirectoryName };  };
        }
    else
        {  $self->ResolveInputDirectories($inputDirectoryNames);  };

    NaturalDocs::Settings->GenerateDirectoryNames($inputDirectoryNames);

    my $filesInMenu = $self->FilesInMenu();

    my ($previousMenu, $previousIndexes, $previousFiles) = $self->LoadPreviousMenuStateFile();

    if (defined $previousIndexes)
        {  %previousIndexes = %$previousIndexes;  };

    if (defined $previousFiles)
        {  $self->LockUserTitleChanges($previousFiles);  };

    # Don't need these anymore.  We keep this level of detail because it may be used more in the future.
    $previousMenu = undef;
    $previousFiles = undef;
    $previousIndexes = undef;

    # We flag title changes instead of actually performing them at this point for two reasons.  First, contents of groups are still
    # subject to change, which would affect the generated titles.  Second, we haven't detected the sort order yet.  Changing titles
    # could make groups appear unalphabetized when they were beforehand.

    my $updateAllTitles;

    # If the menu file changed, we can't be sure which groups changed and which didn't without a comparison, which really isn't
    # worth the trouble.  So we regenerate all the titles instead.
    if (NaturalDocs::Project->UserConfigFileStatus('Menu.txt') == ::FILE_CHANGED())
        {  $updateAllTitles = 1;  }
    else
        {  $self->FlagAutoTitleChanges();  };

    # We add new files before deleting old files so their presence still affects the grouping.  If we deleted old files first, it could
    # throw off where to place the new ones.

    $self->AutoPlaceNewFiles($filesInMenu);

    my $numberRemoved = $self->RemoveDeadFiles();

    $self->CheckForTrashedMenu(scalar keys %$filesInMenu, $numberRemoved);

    # Don't ban indexes if they deleted Menu.txt.  They may have not deleted PreviousMenuState.nd and we don't want everything
    # to be banned because of it.
    if (NaturalDocs::Project->UserConfigFileStatus('Menu.txt') != ::FILE_DOESNTEXIST())
        {  $self->BanAndUnbanIndexes();  };

    # Index groups need to be detected before adding new ones.

    $self->DetectIndexGroups();

    $self->AddAndRemoveIndexes();

   # We wait until after new files are placed to remove dead groups because a new file may save a group.

    $self->RemoveDeadGroups();

    $self->CreateDirectorySubGroups();

    # We detect the sort before regenerating the titles so it doesn't get thrown off by changes.  However, we do it after deleting
    # dead entries and moving things into subgroups because their removal may bump it into a stronger sort category (i.e.
    # SORTFILESANDGROUPS instead of just SORTFILES.)  New additions don't factor into the sort.

    $self->DetectOrder($updateAllTitles);

    $self->GenerateAutoFileTitles($updateAllTitles);

    $self->ResortGroups($updateAllTitles);


    # Don't need this anymore.
    %defaultTitlesChanged = ( );
    };


#
#   Function: Save
#
#   Writes the changes to the menu files.
#
sub Save
    {
    my ($self) = @_;

    if ($hasChanged)
        {
        $self->SaveMenuFile();
        $self->SavePreviousMenuStateFile();
        };
    };


###############################################################################
# Group: Information Functions

#
#   Function: HasChanged
#
#   Returns whether the menu has changed or not.
#
sub HasChanged
    {  return $hasChanged;  };

#
#   Function: Content
#
#   Returns the parsed menu as an arrayref of <NaturalDocs::Menu::Entry> objects.  Do not change the arrayref.
#
#   The arrayref will only contain <MENU_FILE>, <MENU_GROUP>, <MENU_INDEX>, <MENU_TEXT>, and <MENU_LINK>
#   entries.  Entries such as <MENU_TITLE> are parsed out and are only accessible via functions such as <Title()>.
#
sub Content
    {  return $menu->GroupContent();  };

#
#   Function: Title
#
#   Returns the title of the menu, or undef if none.
#
sub Title
    {  return $title;  };

#
#   Function: SubTitle
#
#   Returns the sub-title of the menu, or undef if none.
#
sub SubTitle
    {  return $subTitle;  };

#
#   Function: Footer
#
#   Returns the footer of the documentation, or undef if none.
#
sub Footer
    {  return $footer;  };

#
#   Function: TimeStamp
#
#   Returns the timestamp text of the documentation, or undef if none.
#
sub TimeStamp
    {  return $timestampText;  };

#
#   Function: Indexes
#
#   Returns an existence hashref of all the index <TopicTypes> appearing in the menu.  Do not change the hashref.
#
sub Indexes
    {  return \%indexes;  };

#
#   Function: PreviousIndexes
#
#   Returns an existence hashref of all the index <TopicTypes> that previously appeared in the menu.  Do not change the
#   hashref.
#
sub PreviousIndexes
    {  return \%previousIndexes;  };


#
#   Function: FilesInMenu
#
#   Returns a hashref of all the files present in the menu.  The keys are the <FileNames>, and the values are references to their
#   <NaturalDocs::Menu::Entry> objects.
#
sub FilesInMenu
    {
    my ($self) = @_;

    my @groupStack = ( $menu );
    my $filesInMenu = { };

    while (scalar @groupStack)
        {
        my $currentGroup = pop @groupStack;
        my $currentGroupContent = $currentGroup->GroupContent();

        foreach my $entry (@$currentGroupContent)
            {
            if ($entry->Type() == ::MENU_GROUP())
                {  push @groupStack, $entry;  }
            elsif ($entry->Type() == ::MENU_FILE())
                {  $filesInMenu->{ $entry->Target() } = $entry;  };
            };
        };

    return $filesInMenu;
    };



###############################################################################
# Group: Event Handlers
#
#   These functions are called by <NaturalDocs::Project> only.  You don't need to worry about calling them.  For example, when
#   changing the default menu title of a file, you only need to call <NaturalDocs::Project->SetDefaultMenuTitle()>.  That function
#   will handle calling <OnDefaultTitleChange()>.


#
#   Function: OnDefaultTitleChange
#
#   Called by <NaturalDocs::Project> if the default menu title of a source file has changed.
#
#   Parameters:
#
#       file    - The source <FileName> that had its default menu title changed.
#
sub OnDefaultTitleChange #(file)
    {
    my ($self, $file) = @_;

    # Collect them for later.  We'll deal with them in LoadAndUpdate().

    $defaultTitlesChanged{$file} = 1;
    };



###############################################################################
# Group: Support Functions


#
#   Function: LoadMenuFile
#
#   Loads and parses the menu file <Menu.txt>.  This will fill <menu>, <title>, <subTitle>, <footer>, <timestampText>,
#   <timestampCode>, <indexes>, and <bannedIndexes>.  If there are any errors in the file, they will be recorded with
#   <NaturalDocs::ConfigFile->AddError()>.
#
#   Returns:
#
#       The array ( inputDirectories, relativeFiles, onlyDirectoryName ) or an empty array if the file doesn't exist.
#
#       inputDirectories - A hashref of all the input directories and their names stored in the menu file.  The keys are the
#                                 directories and the values are their names.  Undef if none.
#       relativeFiles - Whether the menu uses relative file names.
#       onlyDirectoryName - The name of the input directory if there is only one.
#
sub LoadMenuFile
    {
    my ($self) = @_;

    my $inputDirectories = { };
    my $relativeFiles;
    my $onlyDirectoryName;

    # A stack of Menu::Entry object references as we move through the groups.
    my @groupStack;

    $menu = NaturalDocs::Menu::Entry->New(::MENU_GROUP(), undef, undef, undef);
    my $currentGroup = $menu;

    # Whether we're currently in a braceless group, since we'd have to find the implied end rather than an explicit one.
    my $inBracelessGroup;

    # Whether we're right after a group token, which is the only place there can be an opening brace.
    my $afterGroupToken;

    my $version;

    if ($version = NaturalDocs::ConfigFile->Open(NaturalDocs::Project->UserConfigFile('Menu.txt'), 1))
        {
        # We don't check if the menu file is from a future version because we can't just throw it out and regenerate it like we can
        # with other data files.  So we just keep going regardless.  Any syntactic differences will show up as errors.

        while (my ($keyword, $value, $comment) = NaturalDocs::ConfigFile->GetLine())
            {
            # Check for an opening brace after a group token.  This has to be separate from the rest of the code because the flag
            # needs to be reset after every line.
            if ($afterGroupToken)
                {
                $afterGroupToken = undef;

                if ($keyword eq '{')
                    {
                    $inBracelessGroup = undef;
                    next;
                    }
                else
                    {  $inBracelessGroup = 1;  };
                };


            # Now on to the real code.

            if ($keyword eq 'file')
                {
                my $flags = 0;

                if ($value =~ /^(.+)\(([^\(]+)\)$/)
                    {
                    my ($title, $file) = ($1, $2);

                    $title =~ s/ +$//;

                    # Check for auto-title modifier.
                    if ($file =~ /^((?:no )?auto-title, ?)(.+)$/i)
                        {
                        my $modifier;
                        ($modifier, $file) = ($1, $2);

                        if ($modifier =~ /^no/i)
                            {  $flags |= ::MENU_FILE_NOAUTOTITLE();  };
                        };

                    my $entry = NaturalDocs::Menu::Entry->New(::MENU_FILE(), $self->RestoreAmpChars($title),
                                                                                       $self->RestoreAmpChars($file), $flags);

                    $currentGroup->PushToGroup($entry);
                    }
                else
                    {  NaturalDocs::ConfigFile->AddError('File lines must be in the format "File: [title] ([location])"');  };
                }


            elsif ($keyword eq 'group')
                {
                # End a braceless group, if we were in one.
                if ($inBracelessGroup)
                    {
                    $currentGroup = pop @groupStack;
                    $inBracelessGroup = undef;
                    };

                my $entry = NaturalDocs::Menu::Entry->New(::MENU_GROUP(), $self->RestoreAmpChars($value), undef, undef);

                $currentGroup->PushToGroup($entry);

                push @groupStack, $currentGroup;
                $currentGroup = $entry;

                $afterGroupToken = 1;
                }


            elsif ($keyword eq '{')
                {
                NaturalDocs::ConfigFile->AddError('Opening braces are only allowed after Group tags.');
                }


            elsif ($keyword eq '}')
                {
                # End a braceless group, if we were in one.
                if ($inBracelessGroup)
                    {
                    $currentGroup = pop @groupStack;
                    $inBracelessGroup = undef;
                    };

                # End a braced group too.
                if (scalar @groupStack)
                    {  $currentGroup = pop @groupStack;  }
                else
                    {  NaturalDocs::ConfigFile->AddError('Unmatched closing brace.');  };
                }


            elsif ($keyword eq 'title')
                {
                if (!defined $title)
                    {  $title = $self->RestoreAmpChars($value);  }
                else
                    {  NaturalDocs::ConfigFile->AddError('Title can only be defined once.');  };
                }


            elsif ($keyword eq 'subtitle')
                {
                if (defined $title)
                    {
                    if (!defined $subTitle)
                        {  $subTitle = $self->RestoreAmpChars($value);  }
                    else
                        {  NaturalDocs::ConfigFile->AddError('SubTitle can only be defined once.');  };
                    }
                else
                    {  NaturalDocs::ConfigFile->AddError('Title must be defined before SubTitle.');  };
                }


            elsif ($keyword eq 'footer')
                {
                if (!defined $footer)
                    {  $footer = $self->RestoreAmpChars($value);  }
                else
                    {  NaturalDocs::ConfigFile->AddError('Footer can only be defined once.');  };
                }


            elsif ($keyword eq 'timestamp')
                {
                if (!defined $timestampCode)
                    {
                    $timestampCode = $self->RestoreAmpChars($value);
                    $self->GenerateTimestampText();
                    }
                else
                    {  NaturalDocs::ConfigFile->AddError('Timestamp can only be defined once.');  };
                }


            elsif ($keyword eq 'text')
                {
                $currentGroup->PushToGroup( NaturalDocs::Menu::Entry->New(::MENU_TEXT(), $self->RestoreAmpChars($value),
                                                                                                              undef, undef) );
                }


            elsif ($keyword eq 'link')
                {
                my ($title, $url);

                if ($value =~ /^([^\(\)]+?) ?\(([^\)]+)\)$/)
                    {
                    ($title, $url) = ($1, $2);
                    }
                elsif (defined $comment)
                    {
                    $value .= $comment;

                    if ($value =~ /^([^\(\)]+?) ?\(([^\)]+)\) ?(?:#.*)?$/)
                        {
                        ($title, $url) = ($1, $2);
                        };
                    };

                if ($title)
                    {
                    $currentGroup->PushToGroup( NaturalDocs::Menu::Entry->New(::MENU_LINK(), $self->RestoreAmpChars($title),
                                                                 $self->RestoreAmpChars($url), undef) );
                    }
                else
                    {  NaturalDocs::ConfigFile->AddError('Link lines must be in the format "Link: [title] ([url])"');  };
                }


            elsif ($keyword eq 'data')
                {
                $value =~ /^(\d)\((.*)\)$/;
                my ($number, $data) = ($1, $2);

                $data = NaturalDocs::ConfigFile->Unobscure($data);

                # The input directory naming convention changed with version 1.32, but NaturalDocs::Settings will handle that
                # automatically.

                if ($number == 1)
                    {
                    my ($dirName, $inputDir) = split(/\/\/\//, $data, 2);
                    $inputDirectories->{$inputDir} = $dirName;
                    }
                elsif ($number == 2)
                    {  $onlyDirectoryName = $data;  };
                # Ignore other numbers because it may be from a future format and we don't want to make the user delete it
                # manually.
                }

            elsif ($keyword eq "don't index")
                {
                my @indexes = split(/, ?/, $value);

                foreach my $index (@indexes)
                    {
                    my $indexType = NaturalDocs::Topics->TypeFromName( $self->RestoreAmpChars($index) );

                    if (defined $indexType)
                        {  $bannedIndexes{$indexType} = 1;  };
                    };
                }

            elsif ($keyword eq 'index')
                {
                my $entry = NaturalDocs::Menu::Entry->New(::MENU_INDEX(), $self->RestoreAmpChars($value),
                                                                                   ::TOPIC_GENERAL(), undef);
                $currentGroup->PushToGroup($entry);

                $indexes{::TOPIC_GENERAL()} = 1;
                }

            elsif (substr($keyword, -6) eq ' index')
                {
                my $index = substr($keyword, 0, -6);
                my ($indexType, $indexInfo) = NaturalDocs::Topics->NameInfo( $self->RestoreAmpChars($index) );

                if (defined $indexType)
                    {
                    if ($indexInfo->Index())
                        {
                        $indexes{$indexType} = 1;
                        $currentGroup->PushToGroup(
                            NaturalDocs::Menu::Entry->New(::MENU_INDEX(), $self->RestoreAmpChars($value), $indexType, undef) );
                        }
                    else
                        {
                        # If it's on the menu but isn't indexable, the topic setting may have changed out from under it.
                        $hasChanged = 1;
                        };
                    }
                else
                    {
                    NaturalDocs::ConfigFile->AddError($index . ' is not a valid index type.');
                    };
                }

            else
                {
                NaturalDocs::ConfigFile->AddError(ucfirst($keyword) . ' is not a valid keyword.');
                };
            };


        # End a braceless group, if we were in one.
        if ($inBracelessGroup)
            {
            $currentGroup = pop @groupStack;
            $inBracelessGroup = undef;
            };

        # Close up all open groups.
        my $openGroups = 0;
        while (scalar @groupStack)
            {
            $currentGroup = pop @groupStack;
            $openGroups++;
            };

        if ($openGroups == 1)
            {  NaturalDocs::ConfigFile->AddError('There is an unclosed group.');  }
        elsif ($openGroups > 1)
            {  NaturalDocs::ConfigFile->AddError('There are ' . $openGroups . ' unclosed groups.');  };


        if (!scalar keys %$inputDirectories)
            {
            $inputDirectories = undef;
            $relativeFiles = 1;
            };

        NaturalDocs::ConfigFile->Close();

        return ($inputDirectories, $relativeFiles, $onlyDirectoryName);
        }

    else
        {  return ( );  };
    };


#
#   Function: SaveMenuFile
#
#   Saves the current menu to <Menu.txt>.
#
sub SaveMenuFile
    {
    my ($self) = @_;

    open(MENUFILEHANDLE, '>' . NaturalDocs::Project->UserConfigFile('Menu.txt'))
        or die "Couldn't save menu file " . NaturalDocs::Project->UserConfigFile('Menu.txt') . "\n";


    print MENUFILEHANDLE
    "Format: " . NaturalDocs::Settings->TextAppVersion() . "\n\n\n";

    my $inputDirs = NaturalDocs::Settings->InputDirectories();


    if (defined $title)
        {
        print MENUFILEHANDLE 'Title: ' . $self->ConvertAmpChars($title) . "\n";

        if (defined $subTitle)
            {
            print MENUFILEHANDLE 'SubTitle: ' . $self->ConvertAmpChars($subTitle) . "\n";
            }
        else
            {
            print MENUFILEHANDLE
            "\n"
            . "# You can also add a sub-title to your menu like this:\n"
            . "# SubTitle: [subtitle]\n";
            };
        }
    else
        {
        print MENUFILEHANDLE
        "# You can add a title and sub-title to your menu like this:\n"
        . "# Title: [project name]\n"
        . "# SubTitle: [subtitle]\n";
        };

    print MENUFILEHANDLE "\n";

    if (defined $footer)
        {
        print MENUFILEHANDLE 'Footer: ' . $self->ConvertAmpChars($footer) . "\n";
        }
    else
        {
        print MENUFILEHANDLE
        "# You can add a footer to your documentation like this:\n"
        . "# Footer: [text]\n"
        . "# If you want to add a copyright notice, this would be the place to do it.\n";
        };

    if (defined $timestampCode)
        {
        print MENUFILEHANDLE 'Timestamp: ' . $self->ConvertAmpChars($timestampCode) . "\n";
        }
    else
        {
        print MENUFILEHANDLE
        "\n"
        . "# You can add a timestamp to your documentation like one of these:\n"
        . "# Timestamp: Generated on month day, year\n"
        . "# Timestamp: Updated mm/dd/yyyy\n"
        . "# Timestamp: Last updated mon day\n"
        . "#\n";
        };

    print MENUFILEHANDLE
        qq{#   m     - One or two digit month.  January is "1"\n}
        . qq{#   mm    - Always two digit month.  January is "01"\n}
        . qq{#   mon   - Short month word.  January is "Jan"\n}
        . qq{#   month - Long month word.  January is "January"\n}
        . qq{#   d     - One or two digit day.  1 is "1"\n}
        . qq{#   dd    - Always two digit day.  1 is "01"\n}
        . qq{#   day   - Day with letter extension.  1 is "1st"\n}
        . qq{#   yy    - Two digit year.  2006 is "06"\n}
        . qq{#   yyyy  - Four digit year.  2006 is "2006"\n}
        . qq{#   year  - Four digit year.  2006 is "2006"\n}

        . "\n";

    if (scalar keys %bannedIndexes)
        {
        print MENUFILEHANDLE

        "# These are indexes you deleted, so Natural Docs will not add them again\n"
        . "# unless you remove them from this line.\n"
        . "\n"
        . "Don't Index: ";

        my $first = 1;

        foreach my $index (keys %bannedIndexes)
            {
            if (!$first)
                {  print MENUFILEHANDLE ', ';  }
            else
                {  $first = undef;  };

            print MENUFILEHANDLE $self->ConvertAmpChars( NaturalDocs::Topics->NameOfType($index, 1), CONVERT_COMMAS() );
            };

        print MENUFILEHANDLE "\n\n";
        };


    # Remember to keep lines below eighty characters.

    print MENUFILEHANDLE
    "\n"
    . "# --------------------------------------------------------------------------\n"
    . "# \n"
    . "# Cut and paste the lines below to change the order in which your files\n"
    . "# appear on the menu.  Don't worry about adding or removing files, Natural\n"
    . "# Docs will take care of that.\n"
    . "# \n"
    . "# You can further organize the menu by grouping the entries.  Add a\n"
    . "# \"Group: [name] {\" line to start a group, and add a \"}\" to end it.\n"
    . "# \n"
    . "# You can add text and web links to the menu by adding \"Text: [text]\" and\n"
    . "# \"Link: [name] ([URL])\" lines, respectively.\n"
    . "# \n"
    . "# The formatting and comments are auto-generated, so don't worry about\n"
    . "# neatness when editing the file.  Natural Docs will clean it up the next\n"
    . "# time it is run.  When working with groups, just deal with the braces and\n"
    . "# forget about the indentation and comments.\n"
    . "# \n";

    if (scalar @$inputDirs > 1)
        {
        print MENUFILEHANDLE
        "# You can use this file on other computers even if they use different\n"
        . "# directories.  As long as the command line points to the same source files,\n"
        . "# Natural Docs will be able to correct the locations automatically.\n"
        . "# \n";
        };

    print MENUFILEHANDLE
    "# --------------------------------------------------------------------------\n"

    . "\n\n";


    $self->WriteMenuEntries($menu->GroupContent(), \*MENUFILEHANDLE, undef, (scalar @$inputDirs == 1));


    if (scalar @$inputDirs > 1)
        {
        print MENUFILEHANDLE
        "\n\n##### Do not change or remove these lines. #####\n";

        foreach my $inputDir (@$inputDirs)
            {
            print MENUFILEHANDLE
            'Data: 1(' . NaturalDocs::ConfigFile->Obscure( NaturalDocs::Settings->InputDirectoryNameOf($inputDir)
                                                                              . '///' . $inputDir ) . ")\n";
            };
        }
    elsif (lc(NaturalDocs::Settings->InputDirectoryNameOf($inputDirs->[0])) != 1)
        {
        print MENUFILEHANDLE
        "\n\n##### Do not change or remove this line. #####\n"
        . 'Data: 2(' . NaturalDocs::ConfigFile->Obscure( NaturalDocs::Settings->InputDirectoryNameOf($inputDirs->[0]) ) . ")\n";
        }

    close(MENUFILEHANDLE);
    };


#
#   Function: WriteMenuEntries
#
#   A recursive function to write the contents of an arrayref of <NaturalDocs::Menu::Entry> objects to disk.
#
#   Parameters:
#
#       entries          - The arrayref of menu entries to write.
#       fileHandle      - The handle to the output file.
#       indentChars   - The indentation _characters_ to add before each line.  It is not the number of characters, it is the characters
#                              themselves.  Use undef for none.
#       relativeFiles - Whether to use relative file names.
#
sub WriteMenuEntries #(entries, fileHandle, indentChars, relativeFiles)
    {
    my ($self, $entries, $fileHandle, $indentChars, $relativeFiles) = @_;
    my $lastEntryType;

    foreach my $entry (@$entries)
        {
        if ($entry->Type() == ::MENU_FILE())
            {
            my $fileName;

            if ($relativeFiles)
                {  $fileName = (NaturalDocs::Settings->SplitFromInputDirectory($entry->Target()))[1];  }
            else
                {  $fileName = $entry->Target();  };

            print $fileHandle $indentChars . 'File: ' . $self->ConvertAmpChars( $entry->Title(), CONVERT_PARENTHESIS() )
                                  . '  (' . ($entry->Flags() & ::MENU_FILE_NOAUTOTITLE() ? 'no auto-title, ' : '')
                                  . $self->ConvertAmpChars($fileName) . ")\n";
            }
        elsif ($entry->Type() == ::MENU_GROUP())
            {
            if (defined $lastEntryType && $lastEntryType != ::MENU_GROUP())
                {  print $fileHandle "\n";  };

            print $fileHandle $indentChars . 'Group: ' . $self->ConvertAmpChars( $entry->Title() ) . "  {\n\n";
            $self->WriteMenuEntries($entry->GroupContent(), $fileHandle, '   ' . $indentChars, $relativeFiles);
            print $fileHandle '   ' . $indentChars . '}  # Group: ' . $self->ConvertAmpChars( $entry->Title() ) . "\n\n";
            }
        elsif ($entry->Type() == ::MENU_TEXT())
            {
            print $fileHandle $indentChars . 'Text: ' . $self->ConvertAmpChars( $entry->Title() ) . "\n";
            }
        elsif ($entry->Type() == ::MENU_LINK())
            {
            print $fileHandle $indentChars . 'Link: ' . $self->ConvertAmpChars( $entry->Title() ) . '  '
                                                        . '(' . $self->ConvertAmpChars( $entry->Target(), CONVERT_PARENTHESIS() ) . ')' . "\n";
            }
        elsif ($entry->Type() == ::MENU_INDEX())
            {
            my $type;
            if ($entry->Target() ne ::TOPIC_GENERAL())
                {
                $type = NaturalDocs::Topics->NameOfType($entry->Target()) . ' ';
                };

            print $fileHandle $indentChars . $self->ConvertAmpChars($type, CONVERT_COLONS()) . 'Index: '
                                                        . $self->ConvertAmpChars( $entry->Title() ) . "\n";
            };

        $lastEntryType = $entry->Type();
        };
    };


#
#   Function: LoadPreviousMenuStateFile
#
#   Loads and parses the previous menu state file.
#
#   Returns:
#
#       The array ( previousMenu, previousIndexes, previousFiles ) or an empty array if there was a problem with the file.
#
#       previousMenu - A <MENU_GROUP> <NaturalDocs::Menu::Entry> object, similar to <menu>, which contains the entire
#                              previous menu.
#       previousIndexes - An existence hashref of the index <TopicTypes> present in the previous menu.
#       previousFiles - A hashref of the files present in the previous menu.  The keys are the <FileNames>, and the entries are
#                             references to its object in previousMenu.
#
sub LoadPreviousMenuStateFile
    {
    my ($self) = @_;

    my $fileIsOkay;
    my $version;
    my $previousStateFileName = NaturalDocs::Project->DataFile('PreviousMenuState.nd');

    if (open(PREVIOUSSTATEFILEHANDLE, '<' . $previousStateFileName))
        {
        # See if it's binary.
        binmode(PREVIOUSSTATEFILEHANDLE);

        my $firstChar;
        read(PREVIOUSSTATEFILEHANDLE, $firstChar, 1);

        if ($firstChar == ::BINARY_FORMAT())
            {
            $version = NaturalDocs::Version->FromBinaryFile(\*PREVIOUSSTATEFILEHANDLE);

            # Only the topic type format has changed since switching to binary, and we support both methods.

            if (NaturalDocs::Version->CheckFileFormat($version))
                {  $fileIsOkay = 1;  }
            else
                {  close(PREVIOUSSTATEFILEHANDLE);  };
            }

        else # it's not in binary
            {  close(PREVIOUSSTATEFILEHANDLE);  };
        };

    if ($fileIsOkay)
        {
        if (NaturalDocs::Project->UserConfigFileStatus('Menu.txt') == ::FILE_CHANGED())
            {  $hasChanged = 1;  };


        my $menu = NaturalDocs::Menu::Entry->New(::MENU_GROUP(), undef, undef, undef);
        my $indexes = { };
        my $files = { };

        my @groupStack;
        my $currentGroup = $menu;
        my $raw;

        # [UInt8: type or 0 for end group]

        while (read(PREVIOUSSTATEFILEHANDLE, $raw, 1))
            {
            my ($type, $flags, $title, $titleLength, $target, $targetLength);
            $type = unpack('C', $raw);

            if ($type == 0)
                {  $currentGroup = pop @groupStack;  }

            elsif ($type == ::MENU_FILE())
                {
                # [UInt8: noAutoTitle] [AString16: title] [AString16: target]

                read(PREVIOUSSTATEFILEHANDLE, $raw, 3);
                (my $noAutoTitle, $titleLength) = unpack('Cn', $raw);

                if ($noAutoTitle)
                    {  $flags = ::MENU_FILE_NOAUTOTITLE();  };

                read(PREVIOUSSTATEFILEHANDLE, $title, $titleLength);
                read(PREVIOUSSTATEFILEHANDLE, $raw, 2);

                $targetLength = unpack('n', $raw);

                read(PREVIOUSSTATEFILEHANDLE, $target, $targetLength);
                }

            elsif ($type == ::MENU_GROUP())
                {
                # [AString16: title]

                read(PREVIOUSSTATEFILEHANDLE, $raw, 2);
                $titleLength = unpack('n', $raw);

                read(PREVIOUSSTATEFILEHANDLE, $title, $titleLength);
                }

            elsif ($type == ::MENU_INDEX())
                {
                # [AString16: title]

                read(PREVIOUSSTATEFILEHANDLE, $raw, 2);
                $titleLength = unpack('n', $raw);

                read(PREVIOUSSTATEFILEHANDLE, $title, $titleLength);

                if ($version >= NaturalDocs::Version->FromString('1.3'))
                    {
                    # [AString16: topic type]
                    read(PREVIOUSSTATEFILEHANDLE, $raw, 2);
                    $targetLength = unpack('n', $raw);

                    read(PREVIOUSSTATEFILEHANDLE, $target, $targetLength);
                    }
                else
                    {
                    # [UInt8: topic type (0 for general)]
                    read(PREVIOUSSTATEFILEHANDLE, $raw, 1);
                    $target = unpack('C', $raw);

                    $target = NaturalDocs::Topics->TypeFromLegacy($target);
                    };
                }

            elsif ($type == ::MENU_LINK())
                {
                # [AString16: title] [AString16: url]

                read(PREVIOUSSTATEFILEHANDLE, $raw, 2);
                $titleLength = unpack('n', $raw);

                read(PREVIOUSSTATEFILEHANDLE, $title, $titleLength);
                read(PREVIOUSSTATEFILEHANDLE, $raw, 2);
                $targetLength = unpack('n', $raw);

                read(PREVIOUSSTATEFILEHANDLE, $target, $targetLength);
                }

            elsif ($type == ::MENU_TEXT())
                {
                # [AString16: text]

                read(PREVIOUSSTATEFILEHANDLE, $raw, 2);
                $titleLength = unpack('n', $raw);

                read(PREVIOUSSTATEFILEHANDLE, $title, $titleLength);
                };


            # The topic type of the index may have been removed.

            if ( !($type == ::MENU_INDEX() && !NaturalDocs::Topics->IsValidType($target)) )
                {
                my $entry = NaturalDocs::Menu::Entry->New($type, $title, $target, ($flags || 0));
                $currentGroup->PushToGroup($entry);

                if ($type == ::MENU_FILE())
                    {
                    $files->{$target} = $entry;
                    }
                elsif ($type == ::MENU_GROUP())
                    {
                    push @groupStack, $currentGroup;
                    $currentGroup = $entry;
                    }
                elsif ($type == ::MENU_INDEX())
                    {
                    $indexes->{$target} = 1;
                    };
                };

            };

        close(PREVIOUSSTATEFILEHANDLE);

        return ($menu, $indexes, $files);
        }
    else
        {
        $hasChanged = 1;
        return ( );
        };
    };


#
#   Function: SavePreviousMenuStateFile
#
#   Saves changes to <PreviousMenuState.nd>.
#
sub SavePreviousMenuStateFile
    {
    my ($self) = @_;

    open (PREVIOUSSTATEFILEHANDLE, '>' . NaturalDocs::Project->DataFile('PreviousMenuState.nd'))
        or die "Couldn't save " . NaturalDocs::Project->DataFile('PreviousMenuState.nd') . ".\n";

    binmode(PREVIOUSSTATEFILEHANDLE);

    print PREVIOUSSTATEFILEHANDLE '' . ::BINARY_FORMAT();

    NaturalDocs::Version->ToBinaryFile(\*PREVIOUSSTATEFILEHANDLE, NaturalDocs::Settings->AppVersion());

    $self->WritePreviousMenuStateEntries($menu->GroupContent(), \*PREVIOUSSTATEFILEHANDLE);

    close(PREVIOUSSTATEFILEHANDLE);
    };


#
#   Function: WritePreviousMenuStateEntries
#
#   A recursive function to write the contents of an arrayref of <NaturalDocs::Menu::Entry> objects to disk.
#
#   Parameters:
#
#       entries          - The arrayref of menu entries to write.
#       fileHandle      - The handle to the output file.
#
sub WritePreviousMenuStateEntries #(entries, fileHandle)
    {
    my ($self, $entries, $fileHandle) = @_;

    foreach my $entry (@$entries)
        {
        if ($entry->Type() == ::MENU_FILE())
            {
            # We need to do length manually instead of using n/A in the template because it's not supported in earlier versions
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           