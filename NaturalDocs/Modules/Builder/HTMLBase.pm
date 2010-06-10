###############################################################################
#
#   Package: NaturalDocs::Builder::HTMLBase
#
###############################################################################
#
#   A base package for all the shared functionality in <NaturalDocs::Builder::HTML> and
#   <NaturalDocs::Builder::FramedHTML>.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2008 Greg Valure
# Natural Docs is licensed under the GPL


use Tie::RefHash;

use strict;
use integer;

package NaturalDocs::Builder::HTMLBase;

use base 'NaturalDocs::Builder::Base';

use NaturalDocs::DefineMembers 'MADE_EMPTY_SEARCH_RESULTS_PAGE', 'MadeEmptySearchResultsPage()',
                                                 'SetMadeEmptySearchResultsPage()';



###############################################################################
# Group: Object Variables


#
#   Constants: Members
#
#   The object is implemented as a blessed arrayref, with the follow constants as indexes.
#
#   MADE_EMPTY_SEARCH_RESULTS_PAGE - Whether the search results page for searches with no results was generated.
#

#
#   Constants: NDMarkupToHTML Styles
#
#   These are the styles used with <NDMarkupToHTML()>.
#
#   NDMARKUPTOHTML_GENERAL - General style.
#   NDMARKUPTOHTML_SUMMARY - For summaries.
#   NDMARKUPTOHTML_TOOLTIP - For tooltips.
#
use constant NDMARKUPTOHTML_GENERAL => undef;
use constant NDMARKUPTOHTML_SUMMARY => 1;
use constant NDMARKUPTOHTML_TOOLTIP => 2;



###############################################################################
# Group: Package Variables
# These variables are shared by all instances of the package so don't change them.


#
#   handle: FH_CSS_FILE
#
#   The file handle to use when updating CSS files.
#


#
#   Hash: abbreviations
#
#   An existence hash of acceptable abbreviations.  These are words that <AddDoubleSpaces()> won't put a second space
#   after when followed by period-whitespace-capital letter.  Yes, this is seriously over-engineered.
#
my %abbreviations = ( mr => 1, mrs => 1, ms => 1, dr => 1,
                                  rev => 1, fr => 1, 'i.e' => 1,
                                  maj => 1, gen => 1, pres => 1, sen => 1, rep => 1,
                                  n => 1, s => 1, e => 1, w => 1, ne => 1, se => 1, nw => 1, sw => 1 );

#
#   array: indexHeadings
#
#   An array of the headings of all the index sections.  First is for symbols, second for numbers, and the rest for each letter.
#
my @indexHeadings = ( '$#!', '0-9', 'A' .. 'Z' );

#
#   array: indexAnchors
#
#   An array of the HTML anchors of all the index sections.  First is for symbols, second for numbers, and the rest for each letter.
#
my @indexAnchors = ( 'Symbols', 'Numbers', 'A' .. 'Z' );

#
#   array: searchExtensions
#
#   An array of the search file name extensions for all the index sections.  First is for symbols, second for numbers, and the rest
#   for each letter.
#
my @searchExtensions = ( 'Symbols', 'Numbers', 'A' .. 'Z' );

#
#   bool: saidUpdatingCSSFile
#
#   Whether the status message "Updating CSS file..." has been displayed.  We only want to print it once, no matter how many
#   HTML-based targets we are building.
#
my $saidUpdatingCSSFile;

#
#   constant: ADD_HIDDEN_BREAKS
#
#   Just a synonym for "1" so that setting the flag on <StringToHTML()> is clearer in the calling code.
#
use constant ADD_HIDDEN_BREAKS => 1;


###############################################################################
# Group: ToolTip Package Variables
#
#   These variables are for the tooltip generation functions only.  Since they're reset on every call to <BuildContent()> and
#   <BuildIndexSections()>, and are only used by them and their support functions, they can be shared by all instances of the
#   package.

#
#   int: tooltipLinkNumber
#
#   A number used as part of the ID for each link that has a tooltip.  Should be incremented whenever one is made.
#
my $tooltipLinkNumber;

#
#   int: tooltipNumber
#
#   A number used as part of the ID for each tooltip.  Should be incremented whenever one is made.
#
my $tooltipNumber;

#
#   hash: tooltipSymbolsToNumbers
#
#   A hash that maps the tooltip symbols to their assigned numbers.
#
my %tooltipSymbolsToNumbers;

#
#   string: tooltipHTML
#
#   The generated tooltip HTML.
#
my $tooltipHTML;


###############################################################################
# Group: Menu Package Variables
#
#   These variables are for the menu generation functions only.  Since they're reset on every call to <BuildMenu()> and are
#   only used by it and its support functions, they can be shared by all instances of the package.
#


#
#   hash: prebuiltMenus
#
#   A hash that maps output directonies to menu HTML already built for it.  There will be no selection or JavaScript in the menus.
#
my %prebuiltMenus;


#
#   bool: menuNumbersAndLengthsDone
#
#   Set when the variables that only need to be calculated for the menu once are done.  This includes <menuGroupNumber>,
#   <menuLength>, <menuGroupLengths>, and <menuGroupNumbers>, and <menuRootLength>.
#
my $menuNumbersAndLengthsDone;


#
#   int: menuGroupNumber
#
#   The current menu group number.  Each time a group is created, this is incremented so that each one will be unique.
#
my $menuGroupNumber;


#
#   int: menuLength
#
#   The length of the entire menu, fully expanded.  The value is computed from the <Menu Length Constants>.
#
my $menuLength;


#
#   hash: menuGroupLengths
#
#   A hash of the length of each group, *not* including any subgroup contents.  The keys are references to each groups'
#   <NaturalDocs::Menu::Entry> object, and the values are their lengths computed from the <Menu Length Constants>.
#
my %menuGroupLengths;
tie %menuGroupLengths, 'Tie::RefHash';


#
#   hash: menuGroupNumbers
#
#   A hash of the number of each group, as managed by <menuGroupNumber>.  The keys are references to each groups'
#   <NaturalDocs::Menu::Entry> object, and the values are the number.
#
my %menuGroupNumbers;
tie %menuGroupNumbers, 'Tie::RefHash';


#
#   int: menuRootLength
#
#   The length of the top-level menu entries without expansion.  The value is computed from the <Menu Length Constants>.
#
my $menuRootLength;


#
#   constants: Menu Length Constants
#
#   Constants used to approximate the lengths of the menu or its groups.
#
#   MENU_TITLE_LENGTH       - The length of the title.
#   MENU_SUBTITLE_LENGTH - The length of the subtitle.
#   MENU_FILE_LENGTH         - The length of one file entry.
#   MENU_GROUP_LENGTH     - The length of one group entry.
#   MENU_TEXT_LENGTH        - The length of one text entry.
#   MENU_LINK_LENGTH        - The length of one link entry.
#
#   MENU_LENGTH_LIMIT    - The limit of the menu's length.  If the total length surpasses this limit, groups that aren't required
#                                       to be open to show the selection will default to closed on browsers that support it.
#
use constant MENU_TITLE_LENGTH => 3;
use constant MENU_SUBTITLE_LENGTH => 1;
use constant MENU_FILE_LENGTH => 1;
use constant MENU_GROUP_LENGTH => 2; # because it's a line and a blank space
use constant MENU_TEXT_LENGTH => 1;
use constant MENU_LINK_LENGTH => 1;
use constant MENU_INDEX_LENGTH => 1;

use constant MENU_LENGTH_LIMIT => 35;


###############################################################################
# Group: Image Package Variables
#
#   These variables are for the image generation functions only.  Since they're reset on every call to <BuildContent()>,
#   and are only used by it and its support functions, they can be shared by all instances of thepackage.


#
#   var: imageAnchorNumber
#   Incremented for each image link in the file that requires an anchor.
#
my $imageAnchorNumber;


#
#   var: imageContent
#
#   The actual embedded image HTML for all image links.  When generating an image link, the link HTML is returned and
#   the HTML for the target image is added here.  Periodically, such as after the end of the paragraph, this content should
#   be added to the page and the variable set to undef.
#
my $imageContent;



###############################################################################
# Group: Search Package Variables
#
#   These variables are for the search generation functions only.  Since they're reset on every call to <BuildIndexSections()> and
#   are only used by them and their support functions, they can be shared by all instances of the package.


#
#   hash: searchResultIDs
#
#   A hash mapping lowercase-only search result IDs to the number of times they've been used.  This is to work around an IE
#   bug where it won't correctly reference IDs if they differ only in case.
#
my %searchResultIDs;



###############################################################################
# Group: Object Functions


#
#   Function: New
#   Creates and returns a new object.
#
sub New
    {
    my $class = shift;

    my $object = $class->SUPER::New();
    $object->SetMadeEmptySearchResultsPage(0);

    return $object;
    };


# Function: MadeEmptySearchResultsPage
# Returns whether the empty search results page was created or not.

# Function: SetMadeEmptySearchResultsPage
# Sets whether the empty search results page was created or not.



###############################################################################
# Group: Implemented Interface Functions
#
#   The behavior of these functions is shared between HTML output formats.
#


#
#   Function: UpdateImage
#
#   Define this function to add or update the passed image in the output.
#
#   Parameters:
#
#       file - The image <FileName>
#
sub UpdateImage #(file)
    {
    my ($self, $file) = @_;

    my $outputFile = $self->OutputImageOf($file);
    my $outputDirectory = NaturalDocs::File->NoFileName($outputFile);

    if (!-d $outputDirectory)
        {  NaturalDocs::File->CreatePath($outputDirectory);  };

    NaturalDocs::File->Copy($file, $outputFile);
    };


#
#   Function: PurgeFiles
#
#   Deletes the output files associated with the purged source files.
#
sub PurgeFiles #(filesToPurge)
    {
    my ($self, $filesToPurge) = @_;

    # Combine directories into a hash to remove duplicate work.
    my %directoriesToPurge;

    foreach my $file (keys %$filesToPurge)
        {
        # It's possible that there may be files there that aren't in a valid input directory anymore.  They won't generate an output
        # file name so we need to check for undef.
        my $outputFile = $self->OutputFileOf($file);
        if (defined $outputFile)
            {
            unlink($outputFile);
            $directoriesToPurge{ NaturalDocs::File->NoFileName($outputFile) } = 1;
            };
        };

    foreach my $directory (keys %directoriesToPurge)
        {
        NaturalDocs::File->RemoveEmptyTree($directory, NaturalDocs::Settings->OutputDirectoryOf($self));
        };
    };


#
#   Function: PurgeIndexes
#
#   Deletes the output files associated with the purged source files.
#
#   Parameters:
#
#       indexes  - An existence hashref of the index types to purge.  The keys are the <TopicTypes> or * for the general index.
#
sub PurgeIndexes #(indexes)
    {
    my ($self, $indexes) = @_;

    foreach my $index (keys %$indexes)
        {
        $self->PurgeIndexFiles($index, undef, undef);
        };
    };


#
#   Function: PurgeImages
#
#   Define this function to make the package remove all output related to the passed image files.  These files are no longer used
#   by the documentation.
#
#   Parameters:
#
#       files - An existence hashref of the image <FileNames> to purge.
#
sub PurgeImages #(files)
    {
    my ($self, $filesToPurge) = @_;

    # Combine directories into a hash to remove duplicate work.
    my %directoriesToPurge;

    foreach my $file (keys %$filesToPurge)
        {
        # It's possible that there may be files there that aren't in a valid input directory anymore.  They won't generate an output
        # file name so we need to check for undef.
        my $outputFile = $self->OutputImageOf($file);
        if (defined $outputFile)
            {
            unlink($outputFile);
            $directoriesToPurge{ NaturalDocs::File->NoFileName($outputFile) } = 1;
            };
        };

    foreach my $directory (keys %directoriesToPurge)
        {
        NaturalDocs::File->RemoveEmptyTree($directory, NaturalDocs::Settings->OutputDirectoryOf($self));
        };
    };


#
#   Function: BeginBuild
#
#   Creates the necessary subdirectories in the output directory.
#
sub BeginBuild #(hasChanged)
    {
    my ($self, $hasChanged) = @_;

    foreach my $directory ( $self->JavaScriptDirectory(), $self->CSSDirectory(), $self->IndexDirectory(),
                                       $self->SearchResultsDirectory() )
        {
        if (!-d $directory)
            {  NaturalDocs::File->CreatePath($directory);  };
        };
    };


#
#   Function: EndBuild
#
#   Synchronizes the projects CSS and JavaScript files.  Also generates the search data JavaScript file.
#
sub EndBuild #(hasChanged)
    {
    my ($self, $hasChanged) = @_;


    # Update the style sheets.

    my $styles = NaturalDocs::Settings->Styles();
    my $changed;

    my $cssDirectory = $self->CSSDirectory();
    my $mainCSSFile = $self->MainCSSFile();

    for (my $i = 0; $i < scalar @$styles; $i++)
        {
        my $outputCSSFile;

        if (scalar @$styles == 1)
            {  $outputCSSFile = $mainCSSFile;  }
        else
            {  $outputCSSFile = NaturalDocs::File->JoinPaths($cssDirectory, ($i + 1) . '.css');  };


        my $masterCSSFile = NaturalDocs::File->JoinPaths( NaturalDocs::Settings->ProjectDirectory(), $styles->[$i] . '.css' );

        if (! -e $masterCSSFile)
            {  $masterCSSFile = NaturalDocs::File->JoinPaths( NaturalDocs::Settings->StyleDirectory(), $styles->[$i] . '.css' );  };

        # We check both the date and the size in case the user switches between two styles which just happen to have the same
        # date.  Should rarely happen, but it might.
        if (! -e $outputCSSFile ||
            (stat($masterCSSFile))[9] != (stat($outputCSSFile))[9] ||
             -s $masterCSSFile != -s $outputCSSFile)
            {
            if (!NaturalDocs::Settings->IsQuiet() && !$saidUpdatingCSSFile)
                {
                print "Updating CSS file...\n";
                $saidUpdatingCSSFile = 1;
                };

            NaturalDocs::File->Copy($masterCSSFile, $outputCSSFile);

            $changed = 1;
            };
        };


    my $deleteFrom;

    if (scalar @$styles == 1)
        {  $deleteFrom = 1;  }
    else
        {  $deleteFrom = scalar @$styles + 1;  };

    for (;;)
        {
        my $file = NaturalDocs::File->JoinPaths($cssDirectory, $deleteFrom . '.css');

        if (! -e $file)
            {  last;  };

        unlink ($file);
        $deleteFrom++;

        $changed = 1;
        };


    if ($changed)
        {
        if (scalar @$styles > 1)
            {
            open(FH_CSS_FILE, '>' . $mainCSSFile);

            for (my $i = 0; $i < scalar @$styles; $i++)
                {
                print FH_CSS_FILE '@import URL("' . ($i + 1) . '.css");' . "\n";
                };

            close(FH_CSS_FILE);
            };
        };



    # Update the JavaScript files

    my $jsMaster = NaturalDocs::File->JoinPaths( NaturalDocs::Settings->JavaScriptDirectory(), 'NaturalDocs.js' );
    my $jsOutput = $self->MainJavaScriptFile();

    # We check both the date and the size in case the user switches between two styles which just happen to have the same
    # date.  Should rarely happen, but it might.
    if (! -e $jsOutput ||
        (stat($jsMaster))[9] != (stat($jsOutput))[9] ||
         -s $jsMaster != -s $jsOutput)
        {
        NaturalDocs::File->Copy($jsMaster, $jsOutput);
        };


    my @indexes = keys %{NaturalDocs::Menu->Indexes()};

    open(FH_INDEXINFOJS, '>' . NaturalDocs::File->JoinPaths( $self->JavaScriptDirectory(), 'searchdata.js'));

    print FH_INDEXINFOJS
    "var indexSectionsWithContent = {\n";

    for (my $i = 0; $i < scalar @indexes; $i++)
        {
        if ($i != 0)
            {  print FH_INDEXINFOJS ",\n";  };

        print FH_INDEXINFOJS '   "' . NaturalDocs::Topics->NameOfType($indexes[$i], 1, 1) . "\": {\n";

        my $content = NaturalDocs::SymbolTable->IndexSectionsWithContent($indexes[$i]);
        for (my $contentIndex = 0; $contentIndex < 28; $contentIndex++)
            {
            if ($contentIndex != 0)
                {  print FH_INDEXINFOJS ",\n";  };

            print FH_INDEXINFOJS '      "' . $searchExtensions[$contentIndex] . '": ' . ($content->[$contentIndex] ? 'true' : 'false');
            };

        print FH_INDEXINFOJS "\n      }";
        };

    print FH_INDEXINFOJS
    "\n   }";

    close(FH_INDEXINFOJS);
    };



###############################################################################
# Group: Section Functions


#
#   Function: BuildTitle
#
#   Builds and returns the HTML page title of a file.
#
#   Parameters:
#
#       sourceFile - The source <FileName> to build the title of.
#
#   Returns:
#
#       The source file's title in HTML.
#
sub BuildTitle #(sourceFile)
    {
    my ($self, $sourceFile) = @_;

    # If we have a menu title, the page title is [menu title] - [file title].  Otherwise it is just [file title].

    my $title = NaturalDocs::Project->DefaultMenuTitleOf($sourceFile);

    my $menuTitle = NaturalDocs::Menu->Title();
    if (defined $menuTitle && $menuTitle ne $title)
        {  $title .= ' - ' . $menuTitle;  };

    $title = $self->StringToHTML($title);

    return $title;
    };

#
#   Function: BuildMenu
#
#   Builds and returns the side menu of a file.
#
#   Parameters:
#
#       sourceFile - The source <FileName> to use if you're looking for a source file.
#       indexType - The index <TopicType> to use if you're looking for an index.
#
#       Both sourceFile and indexType may be undef.
#
#   Returns:
#
#       The side menu in HTML.
#
#   Dependencies:
#
#       - <Builder::HTML::UpdateFile()> and <Builder::HTML::UpdateIndex()> require this section to be surrounded with the exact
#         strings "<div id=Menu>" and "</div><!--Menu-->".
#       - This function depends on the way <BuildMenuSegment()> formats file and index entries.
#
sub BuildMenu #(FileName sourceFile, TopicType indexType) -> string htmlMenu
    {
    my ($self, $sourceFile, $indexType) = @_;

    if (!$menuNumbersAndLengthsDone)
        {
        $menuGroupNumber = 1;
        $menuLength = 0;
        %menuGroupLengths = ( );
        %menuGroupNumbers = ( );
        $menuRootLength = 0;
        };

    my $outputDirectory;

    if ($sourceFile)
        {  $outputDirectory = NaturalDocs::File->NoFileName( $self->OutputFileOf($sourceFile) );  }
    elsif ($indexType)
        {  $outputDirectory = NaturalDocs::File->NoFileName( $self->IndexFileOf($indexType) );  }
    else
        {  $outputDirectory = NaturalDocs::Settings->OutputDirectoryOf($self);  };


    # Comment needed for UpdateFile().
    my $output = '<div id=Menu>';


    if (!exists $prebuiltMenus{$outputDirectory})
        {
        my $segmentOutput;

        ($segmentOutput, $menuRootLength) =
            $self->BuildMenuSegment($outputDirectory, NaturalDocs::Menu->Content(), 1);

        my $titleOutput;

        my $menuTitle = NaturalDocs::Menu->Title();
        if (defined $menuTitle)
            {
            if (!$menuNumbersAndLengthsDone)
                {  $menuLength += MENU_TITLE_LENGTH;  };

            $menuRootLength += MENU_TITLE_LENGTH;

            $titleOutput .=
            '<div class=MTitle>'
                . $self->StringToHTML($menuTitle);

            my $menuSubTitle = NaturalDocs::Menu->SubTitle();
            if (defined $menuSubTitle)
                {
                if (!$menuNumbersAndLengthsDone)
                    {  $menuLength += MENU_SUBTITLE_LENGTH;  };

                $menuRootLength += MENU_SUBTITLE_LENGTH;

                $titleOutput .=
                '<div class=MSubTitle>'
                    . $self->StringToHTML($menuSubTitle)
                . '</div>';
                };

            $titleOutput .=
            '</div>';
            };

        my $searchOutput;

        if (scalar keys %{NaturalDocs::Menu->Indexes()})
            {
            $searchOutput =
            '<script type="text/javascript"><!--' . "\n"
                . 'var searchPanel = new SearchPanel("searchPanel", "' . $self->CommandLineOption() . '", '
                    . '"' . $self->MakeRelativeURL($outputDirectory, $self->SearchResultsDirectory()) . '");' . "\n"
            . '--></script>'

            . '<div id=MSearchPanel class=MSearchPanelInactive>'
                . '<input type=text id=MSearchField value=Search '
                    . 'onFocus="searchPanel.OnSearchFieldFocus(true)" onBlur="searchPanel.OnSearchFieldFocus(false)" '
                    . 'onKeyUp="searchPanel.OnSearchFieldChange()">'
                . '<select id=MSearchType '
                    . 'onFocus="searchPanel.OnSearchTypeFocus(true)" onBlur="searchPanel.OnSearchTypeFocus(false)" '
                    . 'onChange="searchPanel.OnSearchTypeChange()">';

                my @indexes = keys %{NaturalDocs::Menu->Indexes()};
                @indexes = sort
                    {
                    if ($a eq ::TOPIC_GENERAL())  {  return -1;  }
                    elsif ($b eq ::TOPIC_GENERAL())  {  return 1;  }
                    else  {  return (NaturalDocs::Topics->NameOfType($a, 1) cmp NaturalDocs::Topics->NameOfType($b, 1))  };
                    }  @indexes;

                foreach my $index (@indexes)
                    {
                    my ($name, $extra);
                    if ($index eq ::TOPIC_GENERAL())
                        {
                        $name = 'Everything';
                        $extra = ' id=MSearchEverything selected ';
                        }
                    else
                        {  $name = $self->ConvertAmpChars(NaturalDocs::Topics->NameOfType($index, 1));  }

                    $searchOutput .=
                    '<option ' . $extra . 'value="' . NaturalDocs::Topics->NameOfType($index, 1, 1) . '">'
                        . $name
                    . '</option>';
                    };

                $searchOutput .=
                '</select>'
            . '</div>';
            };

        $prebuiltMenus{$outputDirectory} = $titleOutput . $segmentOutput . $searchOutput;
        $output .= $titleOutput . $segmentOutput . $searchOutput;
        }
    else
        {  $output .= $prebuiltMenus{$outputDirectory};  };


    # Highlight the menu selection.

    if ($sourceFile)
        {
        # Dependency: This depends on how BuildMenuSegment() formats file entries.
        my $outputFile = $self->OutputFileOf($sourceFile);
        my $tag = '<div class=MFile><a href="' . $self->MakeRelativeURL($outputDirectory, $outputFile) . '">';
        my $tagIndex = index($output, $tag);

        if ($tagIndex != -1)
            {
            my $endIndex = index($output, '</a>', $tagIndex);

            substr($output, $endIndex, 4, '');
            substr($output, $tagIndex, length($tag), '<div class=MFile id=MSelected>');
            };
        }
    elsif ($indexType)
        {
        # Dependency: This depends on how BuildMenuSegment() formats index entries.
        my $outputFile = $self->IndexFileOf($indexType);
        my $tag = '<div class=MIndex><a href="' . $self->MakeRelativeURL($outputDirectory, $outputFile) . '">';
        my $tagIndex = index($output, $tag);

        if ($tagIndex != -1)
            {
            my $endIndex = index($output, '</a>', $tagIndex);

            substr($output, $endIndex, 4, '');
            substr($output, $tagIndex, length($tag), '<div class=MIndex id=MSelected>');
            };
        };


    # If the completely expanded menu is too long, collapse all the groups that aren't in the selection hierarchy or near the
    # selection.  By doing this instead of having them default to closed via CSS, any browser that doesn't support changing this at
    # runtime will keep the menu entirely open so that its still usable.

    if ($menuLength > MENU_LENGTH_LIMIT())
        {
        my $menuSelectionHierarchy = $self->GetMenuSelectionHierarchy($sourceFile, $indexType);

        my $toExpand = $self->ExpandMenu($sourceFile, $indexType, $menuSelectionHierarchy, $menuRootLength);

        $output .=

        '<script language=JavaScript><!--' . "\n"

        . 'HideAllBut([' . join(', ', @$toExpand) . '], ' . $menuGroupNumber . ');'

        . '// --></script>';
        };

    $output .= '</div><!--Menu-->';

    $menuNumbersAndLengthsDone = 1;

    return $output;
    };


#
#   Function: BuildMenuSegment
#
#   A recursive function to build a segment of the menu.  *Remember to reset the <Menu Package Variables> before calling this
#   for the first time.*
#
#   Parameters:
#
#       outputDirectory - The output directory the menu is being built for.
#       menuSegment - An arrayref specifying the segment of the menu to build.  Either pass the menu itself or the contents
#                               of a group.
#       topLevel - Whether the passed segment is the top level segment or not.
#
#   Returns:
#
#       The array ( menuHTML, length ).
#
#       menuHTML - The menu segment in HTML.
#       groupLength - The length of the group, *not* including the contents of any subgroups, as computed from the
#                            <Menu Length Constants>.
#
#   Dependencies:
#
#       - <BuildMenu()> depends on the way this function formats file and index entries.
#
sub BuildMenuSegment #(outputDirectory, menuSegment, topLevel)
    {
    my ($self, $outputDirectory, $menuSegment, $topLevel) = @_;

    my $output;
    my $groupLength = 0;

    foreach my $entry (@$menuSegment)
        {
        if ($entry->Type() == ::MENU_GROUP())
            {
            my ($entryOutput, $entryLength) =
                $self->BuildMenuSegment($outputDirectory, $entry->GroupContent());

            my $entryNumber;

            if (!$menuNumbersAndLengthsDone)
                {
                $entryNumber = $menuGroupNumber;
                $menuGroupNumber++;

                $menuGroupLengths{$entry} = $entryLength;
                $menuGroupNumbers{$entry} = $entryNumber;
                }
            else
                {  $entryNumber = $menuGroupNumbers{$entry};  };

            $output .=
            '<div class=MEntry>'
                . '<div class=MGroup>'

                    . '<a href="javascript:ToggleMenu(\'MGroupContent' . $entryNumber . '\', \'ggroup'.$entryNumber.'\')"'
                         . ($self->CommandLineOption() eq 'FramedHTML' ? ' target="_self"' : '') . ' id="ggroup'.
                         $entryNumber.'">'
                        . $self->StringToHTML($entry->Title())
                    . '</a>'

                    . '<div class=MGroupContent id=MGroupContent' . $entryNumber . '>'
                        . $entryOutput
                    . '</div>'

                . '</div>'
            . '</div>';

            $groupLength += MENU_GROUP_LENGTH;
            }

        elsif ($entry->Type() == ::MENU_FILE())
            {
            my $targetOutputFile = $self->OutputFileOf($entry->Target());

        # Dependency: BuildMenu() depends on how this formats file entries.
            $output .=
            '<div class=MEntry>'
                . '<div class=MFile>'
                    . '<a href="' . $self->MakeRelativeURL($outputDirectory, $targetOutputFile) . '">'
                        . $self->StringToHTML( $entry->Title(), ADD_HIDDEN_BREAKS)
                    . '</a>'
                . '</div>'
            . '</div>';

            $groupLength += MENU_FILE_LENGTH;
            }

        elsif ($entry->Type() == ::MENU_TEXT())
            {
            $output .=
            '<div class=MEntry>'
                . '<div class=MText>'
                    . $self->StringToHTML( $entry->Title() )
                . '</div>'
            . '</div>';

            $groupLength += MENU_TEXT_LENGTH;
            }

        elsif ($entry->Type() == ::MENU_LINK())
            {
            $output .=
            '<div class=MEntry>'
                . '<div class=MLink>'
                    . '<a href="' . $entry->Target() . '"' . ($self->CommandLineOption() eq 'FramedHTML' ? ' target="_top"' : '') . '>'
                        . $self->StringToHTML( $entry->Title() )
                    . '</a>'
                . '</div>'
            . '</div>';

            $groupLength += MENU_LINK_LENGTH;
            }

        elsif ($entry->Type() == ::MENU_INDEX())
            {
            my $indexFile = $self->IndexFileOf($entry->Target);

        # Dependency: BuildMenu() depends on how this formats index entries.
            $output .=
            '<div class=MEntry>'
                . '<div class=MIndex>'
                    . '<a href="' . $self->MakeRelativeURL( $outputDirectory, $self->IndexFileOf($entry->Target()) ) . '">'
                        . $self->StringToHTML( $entry->Title() )
                    . '</a>'
                . '</div>'
            . '</div>';

            $groupLength += MENU_INDEX_LENGTH;
            };
        };


    if (!$menuNumbersAndLengthsDone)
        {  $menuLength += $groupLength;  };

    return ($output, $groupLength);
    };


#
#   Function: BuildContent
#
#   Builds and returns the main page content.
#
#   Parameters:
#
#       sourceFile - The source <FileName>.
#       parsedFile - The parsed source file as an arrayref of <NaturalDocs::Parser::ParsedTopic> objects.
#
#   Returns:
#
#       The page content in HTML.
#
sub BuildContent #(sourceFile, parsedFile)
    {
    my ($self, $sourceFile, $parsedFile) = @_;

    $self->ResetToolTips();
    $imageAnchorNumber = 1;
    $imageContent = undef;

    my $output = '<div id=Content>';
    my $i = 0;

    while ($i < scalar @$parsedFile)
        {
        my $anchor = $self->SymbolToHTMLSymbol($parsedFile->[$i]->Symbol());

        my $scope = NaturalDocs::Topics->TypeInfo($parsedFile->[$i]->Type())->Scope();


        # The anchors are closed, but not around the text, so the :hover CSS style won't accidentally kick in.

        my $headerType;

        if ($i == 0)
            {  $headerType = 'h1';  }
        elsif ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
            {  $headerType = 'h2';  }
        else
            {  $headerType = 'h3';  };

        $output .=

        '<div class="C' . NaturalDocs::Topics->NameOfType($parsedFile->[$i]->Type(), 0, 1) . '">'
            . '<div class=CTopic' . ($i == 0 ? ' id=MainTopic' : '') . '>'

                . '<' . $headerType . ' class=CTitle>'
                    . '<a name="' . $anchor . '"></a>'
                    . $self->StringToHTML( $parsedFile->[$i]->Title(), ADD_HIDDEN_BREAKS)
                . '</' . $headerType . '>';


        my $hierarchy;
        if (NaturalDocs::Topics->TypeInfo( $parsedFile->[$i]->Type() )->ClassHierarchy())
            {
            $hierarchy = $self->BuildClassHierarchy($sourceFile, $parsedFile->[$i]->Symbol());
            };

        my $summary;
        if ($i == 0 || $scope == ::SCOPE_START() || $scope == ::SCOPE_END())
            {
            $summary .= $self->BuildSummary($sourceFile, $parsedFile, $i);
            };

        my $hasBody;
        if (defined $hierarchy || defined $summary ||
            defined $parsedFile->[$i]->Prototype() || defined $parsedFile->[$i]->Body())
            {
            $output .= '<div class=CBody>';
            $hasBody = 1;
            };

        $output .= $hierarchy;

        if (defined $parsedFile->[$i]->Prototype())
            {
            $output .= $self->BuildPrototype($parsedFile->[$i]->Type(), $parsedFile->[$i]->Prototype(), $sourceFile);
            };

        if (defined $parsedFile->[$i]->Body())
            {
            $output .= $self->NDMarkupToHTML( $sourceFile, $parsedFile->[$i]->Body(), $parsedFile->[$i]->Symbol(),
                                                                  $parsedFile->[$i]->Package(), $parsedFile->[$i]->Type(),
                                                                  $parsedFile->[$i]->Using() );
            };

        $output .= $summary;


        if ($hasBody)
            {  $output .= '</div>';  };

        $output .=
            '</div>' # CTopic
        . '</div>' # CType
        . "\n\n";

        $i++;
        };

    $output .= '</div><!--Content-->';

    return $output;
    };


#
#   Function: BuildSummary
#
#   Builds a summary, either for the entire file or the current class/section.
#
#   Parameters:
#
#       sourceFile - The source <FileName> the summary appears in.
#
#       parsedFile - A reference to the parsed source file.
#
#       index   - The index into the parsed file to start at.  If undef or zero, it builds a summary for the entire file.  If it's the
#                    index of a <TopicType> that starts or ends a scope, it builds a summary for that scope
#
#   Returns:
#
#       The summary in HTML.
#
sub BuildSummary #(sourceFile, parsedFile, index)
    {
    my ($self, $sourceFile, $parsedFile, $index) = @_;
    my $completeSummary;

    if (!defined $index || $index == 0)
        {
        $index = 0;
        $completeSummary = 1;
        }
    else
        {
        # Skip the scope entry.
        $index++;
        };

    if ($index + 1 >= scalar @$parsedFile)
        {  return undef;  };


    my $scope = NaturalDocs::Topics->TypeInfo($parsedFile->[$index]->Type())->Scope();

    # Return nothing if there's only one entry.
    if (!$completeSummary && ($scope == ::SCOPE_START() || $scope == ::SCOPE_END()) )
        {  return undef;  };


    my $indent = 0;
    my $inGroup;

    my $isMarked = 0;

    my $output =
    '<!--START_ND_SUMMARY-->'
    . '<div class=Summary><div class=STitle>Summary</div>'

        # Not all browsers get table padding right, so we need a div to apply the border.
        . '<div class=SBorder>'
        . '<table border=0 cellspacing=0 cellpadding=0 class=STable>';

        while ($index < scalar @$parsedFile)
            {
            my $topic = $parsedFile->[$index];
            my $scope = NaturalDocs::Topics->TypeInfo($topic->Type())->Scope();

            if (!$completeSummary && ($scope == ::SCOPE_START() || $scope == ::SCOPE_END()) )
                {  last;  };


            # Remove modifiers as appropriate for the current entry.

            if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
                {
                $indent = 0;
                $inGroup = 0;
                $isMarked = 0;
                }
            elsif ($topic->Type() eq ::TOPIC_GROUP())
                {
                if ($inGroup)
                    {  $indent--;  };

                $inGroup = 0;
                $isMarked = 0;
                };


            $output .=
             '<tr class="S' . ($index == 0 ? 'Main' : NaturalDocs::Topics->NameOfType($topic->Type(), 0, 1))
                . ($indent ? ' SIndent' . $indent : '') . ($isMarked ? ' SMarked' : '') .'">'
                . '<td class=SEntry>';

           # Add the entry itself.

            my $toolTipProperties;

            # We only want a tooltip here if there's a protoype.  Otherwise it's redundant.

            if (defined $topic->Prototype())
                {
                my $tooltipID = $self->BuildToolTip($topic->Symbol(), $sourceFile, $topic->Type(),
                                                                     $topic->Prototype(), $topic->Summary());
                $toolTipProperties = $self->BuildToolTipLinkProperties($tooltipID);
                };

            $output .=
            '<a href="#' . $self->SymbolToHTMLSymbol($parsedFile->[$index]->Symbol()) . '" ' . $toolTipProperties . '>'
                . $self->StringToHTML( $parsedFile->[$index]->Title(), ADD_HIDDEN_BREAKS)
            . '</a>';


            $output .=
            '</td><td class=SDescription>';

            if (defined $parsedFile->[$index]->Body())
                {
                $output .= $self->NDMarkupToHTML($sourceFile, $parsedFile->[$index]->Summary(),
                                                                     $parsedFile->[$index]->Symbol(), $parsedFile->[$index]->Package(),
                                                                     $parsedFile->[$index]->Type(), $parsedFile->[$index]->Using(),
                                                                     NDMARKUPTOHTML_SUMMARY);
                };


            $output .=
            '</td></tr>';


            # Prepare the modifiers for the next entry.

            if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
                {
                $indent = 1;
                $inGroup = 0;
                }
            elsif ($topic->Type() eq ::TOPIC_GROUP())
                {
                if (!$inGroup)
                    {
                    $indent++;
                    $inGroup = 1;
                    };
                };

            $isMarked ^= 1;
            $index++;
            };

        $output .=
        '</table>'
    . '</div>' # Body
    . '</div>' # Summary
    . "<!--END_ND_SUMMARY-->";

    return $output;
    };


#
#   Function: BuildPrototype
#
#   Builds and returns the prototype as HTML.
#
#   Parameters:
#
#       type - The <TopicType> the prototype is from.
#       prototype - The prototype to format.
#       file - The <FileName> the prototype was defined in.
#
#   Returns:
#
#       The prototype in HTML.
#
sub BuildPrototype #(type, prototype, file)
    {
    my ($self, $type, $prototype, $file) = @_;

    my $language = NaturalDocs::Languages->LanguageOf($file);
    my $prototypeObject = $language->ParsePrototype($type, $prototype);

    my $output;

    if ($prototypeObject->OnlyBeforeParameters())
        {
        $output =
        # A blockquote to scroll it if it's too long.
        '<blockquote>'
            # A surrounding table as a hack to make the div form-fit.
            . '<table border=0 cellspacing=0 cellpadding=0 class=Prototype><tr><td>'
                . $self->ConvertAmpChars($prototypeObject->BeforeParameters())
            . '</td></tr></table>'
        . '</blockquote>';
        }

    else
        {
        my $params = $prototypeObject->Parameters();
        my $beforeParams = $prototypeObject->BeforeParameters();
        my $afterParams = $prototypeObject->AfterParameters();


        # Determine what features the prototype has and its length.

        my ($hasType, $hasTypePrefix, $hasNamePrefix, $hasDefaultValue, $hasDefaultValuePrefix);
        my $maxParamLength = 0;

        foreach my $param (@$params)
            {
            my $paramLength = length($param->Name());

            if ($param->Type())
                {
                $hasType = 1;
                $paramLength += length($param->Type()) + 1;
                };
            if ($param->TypePrefix())
                {
                $hasTypePrefix = 1;
                $paramLength += length($param->TypePrefix()) + 1;
                };
            if ($param->NamePrefix())
                {
                $hasNamePrefix = 1;
                $paramLength += length($param->NamePrefix());
                };
            if ($param->DefaultValue())
                {
                $hasDefaultValue = 1;

                # The length of the default value part is either the longest word, or 1/3 the total, whichever is longer.  We do this
                # because we don't want parameter lines wrapping to more than three lines, and there's no guarantee that the line will
                # wrap at all.  There's a small possibility that it could still wrap to four lines with this code, but we don't need to go
                # crazy(er) here.

                my $thirdLength = length($param->DefaultValue()) / 3;

                my @words = split(/ +/, $param->DefaultValue());
                my $maxWordLength = 0;

                foreach my $word (@words)
                    {
                    if (length($word) > $maxWordLength)
                        {  $maxWordLength = length($word);  };
                    };

                $paramLength += ($maxWordLength > $thirdLength ? $maxWordLength : $thirdLength) + 1;
                };
            if ($param->DefaultValuePrefix())
                {
                $hasDefaultValuePrefix = 1;
                $paramLength += length($param->DefaultValuePrefix()) + 1;
                };

            if ($paramLength > $maxParamLength)
                {  $maxParamLength = $paramLength;  };
            };

        my $useCondensed = (length($beforeParams) + $maxParamLength + length($afterParams) > 80 ? 1 : 0);
        my $parameterColumns = 1 + $hasType + $hasTypePrefix + $hasNamePrefix +
                                               $hasDefaultValue + $hasDefaultValuePrefix + $useCondensed;

        $output =
        '<blockquote><table border=0 cellspacing=0 cellpadding=0 class=Prototype><tr><td>'

            # Stupid hack to get it to work right in IE.
            . '<table border=0 cellspacing=0 cellpadding=0><tr>'

            . '<td class=PBeforeParameters ' . ($useCondensed ? 'colspan=' . $parameterColumns : 'nowrap') . '>'
                . $self->ConvertAmpChars($beforeParams);

                if ($beforeParams && $beforeParams !~ /[\(\[\{\<]$/)
                    {  $output .= '&nbsp;';  };

            $output .=
            '</td>';

            for (my $i = 0; $i < scalar @$params; $i++)
                {
                if ($useCondensed)
                    {
                    $output .= '</tr><tr><td>&nbsp;&nbsp;&nbsp;</td>';
                    }
                elsif ($i > 0)
                    {
                    # Go to the next row and and skip the BeforeParameters cell.
                    $output .= '</tr><tr><td></td>';
                    };

                if ($language->TypeBeforeParameter())
                    {
                    if ($hasTypePrefix)
                        {
                        my $htmlTypePrefix = $self->ConvertAmpChars($params->[$i]->TypePrefix());
                        $htmlTypePrefix =~ s/ $/&nbsp;/;

                        $output .=
                        '<td class=PTypePrefix nowrap>'
                            . $htmlTypePrefix
                        . '</td>';
                        };

                    if ($hasType)
                        {
                        $output .=
                        '<td class=PType nowrap>'
                            . $self->ConvertAmpChars($params->[$i]->Type()) . '&nbsp;'
                        . '</td>';
                        };

                    if ($hasNamePrefix)
                        {
                        $output .=
                        '<td class=PParameterPrefix nowrap>'
                            . $self->ConvertAmpChars($params->[$i]->NamePrefix())
                        . '</td>';
                        };

                    $output .=
                    '<td class=PParameter nowrap' . ($useCondensed && !$hasDefaultValue ? ' width=100%' : '') . '>'
                        . $self->ConvertAmpChars($params->[$i]->Name())
                    . '</td>';
                    }

                else # !$language->TypeBeforeParameter()
                    {
                    $output .=
                    '<td class=PParameter nowrap>'
                        . $self->ConvertAmpChars( $params->[$i]->NamePrefix() . $params->[$i]->Name() )
                    . '</td>';

                    if ($hasType || $hasTypePrefix)
                        {
                        my $typePrefix = $params->[$i]->TypePrefix();
                        if ($typePrefix)
                            {  $typePrefix .= ' ';  };

                        $output .=
                        '<td class=PType nowrap' . ($useCondensed && !$hasDefaultValue ? ' width=100%' : '') . '>'
                            . '&nbsp;' . $self->ConvertAmpChars( $typePrefix . $params->[$i]->Type() )
                        . '</td>';
                        };
                    };

                if ($hasDefaultValuePrefix)
                    {
                    $output .=
                    '<td class=PDefaultValuePrefix>'

                       . '&nbsp;' . $self->ConvertAmpChars( $params->[$i]->DefaultValuePrefix() ) . '&nbsp;'
                    . '</td>';
                    };

                if ($hasDefaultValue)
                    {
                    $output .=
                    '<td class=PDefaultValue width=100%>'
                        . ($hasDefaultValuePrefix ? '' : '&nbsp;') . $self->ConvertAmpChars( $params->[$i]->DefaultValue() )
                    . '</td>';
                    };
                };

            if ($useCondensed)
                {  $output .= '</tr><tr>';  };

            $output .=
            '<td class=PAfterParameters ' . ($useCondensed ? 'colspan=' . $parameterColumns : 'nowrap') . '>'
                 . $self->ConvertAmpChars($afterParams);

                if ($afterParams && $afterParams !~ /^[\)\]\}\>]/)
                    {  $output .= '&nbsp;';  };

            $output .=
            '</td>'
        . '</tr></table>'

        # Hack.
        . '</td></tr></table></blockquote>';
       };

    return $output;
    };


#
#   Function: BuildFooter
#
#   Builds and returns the HTML footer for the page.
#
#   Parameters:
#
#       multiline - Whether it should be formatted on multiple lines or not.
#
#   Dependencies:
#
#       <Builder::HTML::UpdateFile()> and <Builder::HTML::UpdateIndex()> require this section to be surrounded with the exact
#       strings "<div id=Footer>" and "</div><!--Footer-->".
#
sub BuildFooter #(bool multiline)
    {
    my ($self, $multiline) = @_;

    my $footer = NaturalDocs::Menu->Footer();
    my $timestamp = NaturalDocs::Menu->TimeStamp();
    my $divider;

    if ($multiline)
        {  $divider = '</p><p>';  }
    else
        {  $divider = '&nbsp; &middot;&nbsp; ';  };


    my $output = '<div id=Footer>';
    if ($multiline)
        {  $output .= '<p>';  };

    if (defined $footer)
        {
        $footer =~ s/\(c\)/&copy;/gi;
        $footer =~ s/\(tm\)/&trade;/gi;
        $footer =~ s/\(r\)/&reg;/gi;

        $output .= $footer . $divider;
        };

    if (defined $timestamp)
        {
        $output .= $timestamp . $divider;
        };

    $output .=
    '<a href="' . NaturalDocs::Settings->AppURL() . '">'
        . 'Generated by Natural Docs'
    . '</a>';

    if ($multiline)
        {  $output .= '</p>';  };

    $output .=
    '</div><!--Footer-->';

    return $output;
    };


#
#   Function: BuildToolTip
#
#   Builds the HTML for a symbol's tooltip and stores it in <tooltipHTML>.
#
#   Parameters:
#
#       symbol - The target <SymbolString>.
#       file - The <FileName> the target's defined in.
#       type - The symbol <TopicType>.
#       prototype - The target prototype, or undef for none.
#       summary - The target summary, or undef for none.
#
#   Returns:
#
#       If a tooltip is necessary for the link, returns the tooltip ID.  If not, returns undef.
#
sub BuildToolTip #(symbol, file, type, prototype, summary)
    {
    my ($self, $symbol, $file, $type, $prototype, $summary) = @_;

    if (defined $prototype || defined $summary)
        {
        my $htmlSymbol = $self->SymbolToHTMLSymbol($symbol);
        my $number = $tooltipSymbolsToNumbers{$htmlSymbol};

        if (!defined $number)
            {
            $number = $tooltipNumber;
            $tooltipNumber++;

            $tooltipSymbolsToNumbers{$htmlSymbol} = $number;

            $tooltipHTML .=
            '<div class=CToolTip id="tt' . $number . '">'
                . '<div class=C' . NaturalDocs::Topics->NameOfType($type, 0, 1) . '>';

            if (defined $prototype)
                {
                $tooltipHTML .= $self->BuildPrototype($type, $prototype, $file);
                };

            if (defined $summary)
                {
                # The fact that we don't have scope or using shouldn't matter because links shouldn't be included in the style anyway.
                $summary = $self->NDMarkupToHTML($file, $summary, undef, undef, $type, undef, NDMARKUPTOHTML_TOOLTIP);
                $tooltipHTML .= $summary;
                };

            $tooltipHTML .=
                '</div>'
            . '</div>';
            };

        return 'tt' . $number;
        }
    else
        {  return undef;  };
    };

#
#   Function: BuildToolTips
#
#   Builds and returns the tooltips for the page in HTML.
#
sub BuildToolTips
    {
    my $self = shift;
    return "\n<!--START_ND_TOOLTIP                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           