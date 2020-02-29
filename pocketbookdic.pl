#! /bin/perl
use strict;
# use autodie; # Does not get along with pragma 'open'.
use Term::ANSIColor;    #Color display on terminal
use Encode;
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use feature 'say';


# $BaseDir is the directory where converter.exe and the language folders reside. 
# Typically the language folders are named by two letters, e.g. english is named 'en'.
# In each folder should be a collates.txt, keyboard.txt and morphems.txt file.
my $BaseDir="/home/mark/Downloads/DictionaryConverter-neu 171109";


# $KindleUnpackLibFolder is the folder in which kindleunpack.py resides.
# You can download KindleUnpack using http with: git clone https://github.com/kevinhendricks/KindleUnpack
# or using ssh with: git clone git@github.com:kevinhendricks/KindleUnpack.git
# Use absolute path beginning with either '/' (root) or '~'(home) on Linux. On Windows use whatever works.
my $KindleUnpackLibFolder="/home/mark/git/KindleUnpack/lib";

my $isRealDead=1; # Some errors should kill the program. However, somtimes you just want to convert.

# Controls manual input: 0 disables.
my ( $lang_from, $lang_to, $format ) = ( "eng", "eng" ,"" ); # Default settings for manual input of xdxf tag.
my $reformat_full_name = 1 ; # Value 1 demands user input for full_name tag.
my $reformat_xdxf = 1 ; # Value 1 demands user input for xdxf tag.

# Deliminator for CSV files, usually ",",";" or "\t"(tab).
my $CVSDeliminator = ",";


# Controls for debugging.
my $isdebug = 1; # Turns off all debug messages
my $isdebugVerbose = 0; # Turns off all verbose debug messages
my $debug_entry = "früh"; # In convertHTML2XDXF only debug messages from this entry are shown.
my $isTestingOn = 0; # Turns tests on
if ( $isTestingOn ){ use warnings; }
my $no_test=1; # Testing singles out a single ar and generates a xdxf-file containing only that ar.
my $ar_chosen = 410; # Ar singled out when no_test = 0;
my ($cycle_dotprinter, $cycles_per_dot) = (0 , 300); # A green dot is printed achter $cycles_per_dot ar's have been processed.
my $i_limit = 27000000000000000000; # Hard limit to the number of lines that are processed.

# Controls for Stardict dictionary creation and Koreader stardict compatabiltiy
my $isCreateStardictDictionary = 1; # Turns on Stardict text and binary dictionary creation.
# Same Type Seqence is the initial value of the Stardict variable set in the ifo-file.
# "h" means html-dictionary. "m" means text.
# The xdxf-file will be filtered for &#xDDDD; values and converted to unicode if set at "m"
my $SameTypeSequence = "h"; # Either "h" or "m" or "x".
my $updateSameTypeSequence = 1; # If the Stardict files give a sametypesequence value, update the initial value.
my $isConvertColorNamestoHexCodePoints = 1; # Converting takes time.
my $isMakeKoreaderReady = 1; # Sometimes koreader want something extra. E.g. create css- and/or lua-file, convert <c color="red"> tags to <span style="color:red;">

# Controls for Pocketbook conversion
my $isCreatePocketbookDictionary = 1; # Controls conversion to Pocketbook Dictionary dic-format
my $remove_color_tags = 0; # Not all viewers can handle color/grayscale. Removing them reduces the article size considerably. Relevant for pocketbook dictionary.
# This controls the maximum article length.
# If set too large, the old converter will crash and the new will truncate the entry.
my $max_article_length = 64000;
# This controls the maximum line length.
# If set too large, the converter wil complain about bad XML syntax and exit.
my $max_line_length = 4000;

# Controls for Mobi dictionary handling
my $isHandleMobiDictionary = 1; 

# Controls for recoding or deleting images and sounds. 
my $isRemoveWaveReferences = 1; # Removes all the references to wav-files Could be encoded in Base64 now.
my $isCodeImageBase64 = 1; # Some dictionaries contain images. Encoding them as Base64 allows coding them inline. Only implemented with convertHTML2XDXF.
# Disable this if you want to make a pocketbook dictionary for now. (For $isCreatePocketBookDictionary = 1.)
if ($isCreatePocketbookDictionary){$isCodeImageBase64 = 0;}
my $isConvertGIF2PNG = 1; # Creates a dependency on Imagemagick "convert".
if( $isCodeImageBase64 ){
	use MIME::Base64;	# To encode into Bas64
	use Storable;		# To store/load the hash %ReplacementImageStrings.
}


# Determine operating system.
my $OperatingSystem = "$^O";
if ($OperatingSystem eq "linux"){ print "Operating system is $OperatingSystem: All good to go!\n";}
else{ print "Operating system is $OperatingSystem: Not linux, so I am assuming Windows!\n";}

# Last filename will be used
# Give the filename relative to the base directory defined in $BaseDir
my $FileName;
$FileName = "dict/öüá.mobi";

# However, when an argument is given, it will supercede the last filename
# Command line argument handling
if( defined($ARGV[0]) ){
	printYellow("Command line arguments provided:\n");
	@ARGV = map { decode_utf8($_, 1) } @ARGV; # Decode terminal input to utf8.
	foreach(@ARGV){ printYellow("\'$_\'\n"); }
	printYellow("Found command line argument: $ARGV[0].\nAssuming it is meant as the dictionary file name.\n");
	$FileName = $ARGV[0];
}
else{
	printYellow("No commandline arguments provided. Remember to either use those or define \$FileName in the script.\n");
	printYellow("First argument is the dictionary name to be converted. E.g dict/dictionary.ifo (Remember to slash forward!)\n");
	printYellow("Second is the language directory name or the CSV deliminator. E.g. eng\nThird is the CVS deliminator. E.g \",\", \";\", \"\\t\"(for tab)\n");
}
my $language_dir = "";
if( defined($ARGV[1]) and $ARGV[1] !~ m~^.$~ and $ARGV[1] !~ m~^\\t$~ ){
	printYellow("Found command line argument: $ARGV[1].\nAssuming it is meant as language directory.\n");
	$language_dir = $ARGV[1];
}
if ( defined($ARGV[1]) and ($ARGV[1] =~ m~^(\\t)$~ or $ARGV[1] =~ m~^(.)$~ )){
	debugFindings();
	printYellow("Found a command line argument consisting of one character.\n Assuming \"$1\" is the CVS deliminator.\n");
	$CVSDeliminator = $ARGV[1];
}

if( defined($ARGV[2]) and ($ARGV[2] =~ m~^(.t)$~ or $ARGV[2] =~ m~^(.)$~) ){
	printYellow("Found a command line argument consisting of one character.\n Assuming \"$1\" is the CVS deliminator.\n");
	$CVSDeliminator = $ARGV[2];
}

# Path checking and cleaning
$BaseDir=~s~/$~~; # Remove trailing slashforward '/'.
if( -e "$BaseDir/converter.exe"){ 
	debugV("Found converter.exe in the base directory $BaseDir."); 
}
elsif( $isCreatePocketbookDictionary ){ 
	debug("Can't find converter.exe in the base directory $BaseDir. Cannot convert to Pocketbook.");
	$isCreatePocketbookDictionary = 0;
}
else{ debugV("Base directory not containing \'converter.exe\' for PocketBook dictionary creation.");}
# Pocketbook converter.exe is dependent on a language directory in which has 3 txt-files: keyboard, morphems and collates.
# Default language directory is English, "en".

$KindleUnpackLibFolder=~s~/$~~; # Remove trailing slashforward '/'.
if( -e "$KindleUnpackLibFolder/kindleunpack.py"){
	debugV("Found \'kindleunpack.py\' in $KindleUnpackLibFolder.");
}
elsif( $isHandleMobiDictionary ){
	debug("Can't find \'kindleunpack.py\' in $KindleUnpackLibFolder. Cannot handle mobi dictionaries.");
	$isHandleMobiDictionary = 0;
}
else{ debugV("$KindleUnpackLibFolder doesn't contain \'kindleunpack.py\' for mobi-format handling.");}
chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";
my $LocalPath = join('', $FileName=~ m~^(.+?)/[^/]+$~);
my $FullPath = "$BaseDir/$LocalPath";
debug("Local path is $LocalPath.");
debug("Full path is $FullPath");


# As NouveauLittre showed a rather big problem with named entities, I decided to write a special filter
# Here is the place to insert your DOCTYPE string.
# Remember to place it between quotes '..' and finish the line with a semicolon ;
# Last Doctype will be used. 
# To omit the filter place an empty DocType string at the end:
# $DocType = '';
my ($DocType,%EntityConversion);
$DocType = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"[<!ENTITY ns "&#9830;"><!ENTITY os "&#8226;"><!ENTITY oo "&#8250;"><!ENTITY co "&#8249;"><!ENTITY a  "&#x0061;"><!ENTITY â  "&#x0251;"><!ENTITY an "&#x0251;&#x303;"><!ENTITY b  "&#x0062;"><!ENTITY d  "&#x0257;"><!ENTITY e  "&#x0259;"><!ENTITY é  "&#x0065;"><!ENTITY è  "&#x025B;"><!ENTITY in "&#x025B;&#x303;"><!ENTITY f  "&#x066;"><!ENTITY g  "&#x0261;"><!ENTITY h  "&#x0068;"><!ENTITY h2 "&#x0027;"><!ENTITY i  "&#x0069;"><!ENTITY j  "&#x004A;"><!ENTITY k  "&#x006B;"><!ENTITY l  "&#x006C;"><!ENTITY m  "&#x006D;"><!ENTITY n  "&#x006E;"><!ENTITY gn "&#x0272;"><!ENTITY ing "&#x0273;"><!ENTITY o  "&#x006F;"><!ENTITY o2 "&#x0254;"><!ENTITY oe "&#x0276;"><!ENTITY on "&#x0254;&#x303;"><!ENTITY eu "&#x0278;"><!ENTITY un "&#x0276;&#x303;"><!ENTITY p  "&#x0070;"><!ENTITY r  "&#x0280;"><!ENTITY s  "&#x0073;"><!ENTITY ch "&#x0283;"><!ENTITY t  "&#x0074;"><!ENTITY u  "&#x0265;"><!ENTITY ou "&#x0075;"><!ENTITY v  "&#x0076;"><!ENTITY w  "&#x0077;"><!ENTITY x  "&#x0078;"><!ENTITY y  "&#x0079;"><!ENTITY z  "&#x007A;"><!ENTITY Z  "&#x0292;">]><html xml:lang="fr" xmlns="http://www.w3.org/1999/xhtml"><head><title></title></head><body>';
$DocType = '';


my @xdxf_start = ( 	'<?xml version="1.0" encoding="UTF-8" ?>'."\n",
				'<xdxf lang_from="" lang_to="" format="visual">'."\n",
				'<full_name></full_name>'."\n",
				'<description>'."\n",
				'<date></date>'."\n",
				'Created with pocketbookdic.pl'."\n",
				'</description>'."\n");
my $lastline_xdxf = "</xdxf>\n";
my @xml_start = ( 	'<?xml version="1.0" encoding="UTF-8" ?>'."\n",
					'<stardict xmlns:xi="http://www.w3.org/2003/XInclude">'."\n",
					'<info>'."\n",
					'<version>2.4.2</version>'."\n",
					'<bookname></bookname>'."\n",
					'<author>pocketbookdic.pl</author>'."\n",
					'<email></email>'."\n",
					'<website></website>'."\n",
					'<description></description>'."\n",
					'<date></date>'."\n",
					'<dicttype></dicttype>'."\n",
					'</info>'."\n");
my $lastline_xml = "</stardict>\n";

sub array2File {
    my ( $FileName, @Array ) = @_;
    # debugV("Array to be written:\n",@Array);
    open( FILE, ">:encoding(utf8)", "$FileName" )
      || warn "Cannot open $FileName: $!\n";
    print FILE @Array;
    close(FILE);
    $FileName =~ s/.+\/(.+)/$1/;
    printGreen("Written $FileName. Exiting sub array2File\n");
    return ("File written");}
sub debug { $isdebug and printRed( @_, "\n" ); return(1);}
sub debugV { $isdebugVerbose and printBlue( @_, "\n" ); return(1);}
sub debugFindings {
    debugV();
    if ( defined $1 )  { debugV("\$1 is: \"$1\"\n"); }
    if ( defined $2 )  { debugV("\$2 is: \"$2\"\n"); }
    if ( defined $3 )  { debugV("\$3 is: \"$3\"\n"); }
    if ( defined $4 )  { debugV("\$4 is:\n $4\n"); }
    if ( defined $5 )  { debugV("5 is:\n $5\n"); }
    if ( defined $6 )  { debugV("6 is:\n $6\n"); }
    if ( defined $7 )  { debugV("7 is:\n $7\n"); }
    if ( defined $8 )  { debugV("8 is:\n $8\n"); }
    if ( defined $9 )  { debugV("9 is:\n $9\n"); }
    if ( defined $10 ) { debugV("10 is:\n $10\n"); }
    if ( defined $11 ) { debugV("11 is:\n $11\n"); }
    if ( defined $12 ) { debugV("12 is:\n $12\n"); }
    if ( defined $13 ) { debugV("13 is:\n $13\n"); }
    if ( defined $14 ) { debugV("14 is:\n $14\n"); }
    if ( defined $15 ) { debugV("15 is:\n $15\n"); }
    if ( defined $16 ) { debugV("16 is:\n $16\n"); }
    if ( defined $17 ) { debugV("17 is:\n $17\n"); }
    if ( defined $18 ) { debugV("18 is:\n $18\n"); }}
sub checkSameTypeSequence{
	my $FileName = $_[0];
	if(! $updateSameTypeSequence ){return;}
	elsif( -e substr($FileName, 0, (length($FileName)-4)).".ifo"){
		my $ifo = join( '',  file2Array(substr($FileName, 0, (length($FileName)-4)).".ifo") ) ;
		if($ifo =~ m~sametypesequence=(?<sametypesequence>\w)~s){
			printGreen("Initial sametypesequence was \"$SameTypeSequence\".");
			$SameTypeSequence = $+{sametypesequence};
			printGreen(" Updated to \"$SameTypeSequence\".\n");
		}
	}
	elsif( -e substr($FileName, 0, (length($FileName)-4)).".xml"){
		my $xml = join( '',  file2Array(substr($FileName, 0, (length($FileName)-4)).".xml") );
		# Extract sametypesequence from Stardict XML
		if( $xml =~ m~<definition type="(?<sametypesequence>\w)">~s){
			printGreen("Initial sametypesequence was \"$SameTypeSequence\".");
			$SameTypeSequence = $+{sametypesequence};
			printGreen(" Updated to \"$SameTypeSequence\".\n");
		}
	}
	return;}
sub cleanseAr{
	my @Content = @_;
	my $Content = join('',@Content) ;
	if( $Content =~ m~^<head>(?<head>(?:(?!</head).)+)</head><def>(?<def>(?:(?!</def).)+)</def>~s){
		# debugFindings();
		# debug("Well formed ar content entry");
		my $head = $+{head};
		my $def_old = $+{def};
		my $def = $def_old;

		# Special characters in $head and $def should be converted to
		#  &lt; (<), &amp; (&), &gt; (>), &quot; ("), and &apos; (')
		$head =~ s~(?<lt><)(?!/?(key>|k>))~&lt;~gs;
		$head =~ s~(?<amp>&)(?!(lt;|amp;|gt;|quot;|apos;))~&amp;~gs;
		$def =~ s~(?<lt><)(?!/?(c>|c c="|block|quote|b>|i>|abr>|ex>|kref>|sup>|sub>|dtrn>|k>|key>|rref|f>|span>|small>|u>|img))~&lt;~gs;
		$def =~ s~(?<amp>&)(?!(lt;|amp;|gt;|quot;|apos;|\#x?[0-9A-Fa-f]{1,6}))~&amp;~gs;
		# $def =~ s~(?<amp>&)(?!([^;]{1,6};))~&amp;~gs; # This excludes the removal of & before &#01234;

		if( $isCreatePocketbookDictionary){
			# Splits complex blockquote blocks from each other. Small impact on layout.
			$def =~ s~</blockquote><blockquote>~</blockquote>\n<blockquote>~gs;
			# Splits blockquote from next heading </blockquote><b><c c=
			$def =~ s~</blockquote><b><c c=~</blockquote>\n<b><c c=~gs;


			# Splits the too long lines.
			my @def = split(/\n/,$def);
			my $def_line_counter = 0;
			foreach my $line (@def){
			 	$def_line_counter++;
			 	# Finetuning of cut location
			 	if (length(encode('UTF-8', $line)) > $max_line_length){
				 	# So I would like to cut the line at say 3500 chars not in the middle of a tag, so before a tag.
				 	# index STR,SUBSTR,POSITION
				 	my $cut_location = index $line, "<", int($max_line_length * 0.85);
				 	if($cut_location == -1 or $cut_location > $max_line_length){
				 		# Saw this with definition without tags a lot a greek characters. Word count <3500, bytes>7500.
				 		# New cut location is from half the line.
				 		$cut_location = index $line, "<", int(length($line)/2);
				 		# But sometimes there are no tags
				 		if($cut_location == -1 or $cut_location > $max_line_length){
				 			$cut_location = index $line, ".", int($max_line_length * 0.85);
				 			if($cut_location == -1 or $cut_location > $max_line_length){
				 				$cut_location = index $line, ".", int(length($line)/2);
				 			}
				 		}


				 	}
			 		debugV("Definition line $def_line_counter is ",length($line)," characters and ",length(encode('UTF-8', $line))," bytes. Cut location is $cut_location.");
			 		my $cutline_begin = substr($line, 0, $cut_location);
			 		my $cutline_end = substr($line, $cut_location);
			 		debug ("Line taken to be cut:") and printYellow("$line\n") and
			 		debug("First part of the cut line is:") and printYellow("$cutline_begin\n") and
			 		debug("Last part of the cut line is:") and printYellow("$cutline_end\n") and
			 		die if ($cut_location > $max_line_length) and $isRealDead;
			 		# splice array, offset, length, list
			 		splice @def, $def_line_counter, 0, ($cutline_end);
			 		$line = $cutline_begin;
			 	}
			}
			$def = join("\n",@def);
			# debug($def);
			# Creates multiple articles if the article is too long.

			my $def_bytes = length(encode('UTF-8', $def));
			if( $def_bytes > $max_article_length ){
				debugV("The length of the definition of \"$head\" is $def_bytes bytes.");
				#It should be split in chunks < $max_article_length , e.g. 64kB
				my @def=split("\n", $def);
				my @definitions=();
				my $counter = 0;
				my $loops = 0;
				my $concatenation = "";
				# Split the lines of the definition in separate chunks smaller than 90kB
				foreach my $line(@def){
					$loops++;
					# debug("\$loops is $loops. \$counter at $counter" );
					$concatenation = $definitions[$counter]."\n".$line;
					if( length(encode('UTF-8', $concatenation)) > $max_article_length ){
						debugV("Chunk is larger than ",$max_article_length,". Creating another chunk.");
						chomp $definitions[$counter];
						$counter++;

					}
					$definitions[$counter] .= "\n".$line;
				}
				chomp $definitions[$counter];
				# Join the chunks with the relevant extra tags to form multiple ar entries.
				# $Content is between <ar> and </ar> tags. It consists of <head>$head</head><def>$def_old</def>
				# So if $def is going to replace $def_old in the later substitution: $Content =~ s~\Q$def_old\E~$def~s; ,
				# how should the chunks be assembled?
				# $defs[0]."</def></ar><ar><head>$head</head><def>".$defs[1]."...".$def[2]
				my $newhead = $head;
				$newhead =~ s~</k>~~;
				# my @Symbols = (".",":","⁝","⁞");
				# my @Symbols = ("a","aa","aaa","aaaa");
				my @Symbols = ("","","","");
				# debug("Counter reached $counter.");
				$def="";
				for(my $a = 0; $a < $counter; $a = $a + 1 ){
						# debug("\$a is $a");
						$def.=$definitions[$a]."</def>\n</ar>\n<ar>\n<head>$newhead$Symbols[$a]</k></head><def>\n";
						debugV("Added chunk ",($a+1)," to \$def together with \"</def></ar>\n<ar><head>$newhead$Symbols[$a]</k></head><def>\".");
				}
				$def .= $definitions[$counter];

			}

		}



		if($remove_color_tags){
			# Removes all color from lemma description.
			# <c c="darkslategray"><c>Derived:</c></c> <c c="darkmagenta">
			$def =~ s~<\?c>~~gs;
			$def =~ s~<c c=[^>]+>~~gs;
		}

		$Content =~ s~\Q$def_old\E~$def~s;
	}
	else{debug("Not well formed ar content!!\n$Content");}

	if ($isRemoveWaveReferences){
		# remove wav-files displaying
		# Example:
		# <rref>
		#z_epee_1_gb_2.wav</rref>
		#<rref>z_a__gb_2.wav</rref> 
		$Content =~ s~<rref>((?!\.wav</rref>).)+\.wav</rref>~~gs;
	}

	return( $Content );}
sub convertColorName2HexValue{
	my $html = join( '', @_);
	my %ColorCoding = qw( 
		aliceblue #F0F8FF
		antiquewhite #FAEBD7
		aqua #00FFFF
		aquamarine #7FFFD4
		azure #F0FFFF
		beige #F5F5DC
		bisque #FFE4C4
		black #0
		blanchedalmond #FFEBCD
		blue #0000FF
		blueviolet #8A2BE2
		brown #A52A2A
		burlywood #DEB887
		cadetblue #5F9EA0
		chartreuse #7FFF00
		chocolate #D2691E
		coral #FF7F50
		cornflowerblue #6495ED
		cornsilk #FFF8DC
		crimson #DC143C
		cyan #00FFFF
		darkblue #00008B
		darkcyan #008B8B
		darkgoldenrod #B8860B
		darkgray #A9A9A9
		darkgrey #A9A9A9
		darkgreen #6400
		darkkhaki #BDB76B
		darkmagenta #8B008B
		darkolivegreen #556B2F
		darkorange #FF8C00
		darkorchid #9932CC
		darkred #8B0000
		darksalmon #E9967A
		darkseagreen #8FBC8F
		darkslateblue #483D8B
		darkslategray #2F4F4F
		darkslategrey #2F4F4F
		darkturquoise #00CED1
		darkviolet #9400D3
		deeppink #FF1493
		deepskyblue #00BFFF
		dimgray #696969
		dimgrey #696969
		dodgerblue #1E90FF
		firebrick #B22222
		floralwhite #FFFAF0
		forestgreen #228B22
		fuchsia #FF00FF
		gainsboro #DCDCDC
		ghostwhite #F8F8FF
		gold #FFD700
		goldenrod #DAA520
		gray #808080
		grey #808080
		green #8000
		greenyellow #ADFF2F
		honeydew #F0FFF0
		hotpink #FF69B4
		indianred  #CD5C5C
		indigo  #4B0082
		ivory #FFFFF0
		khaki #F0E68C
		lavender #E6E6FA
		lavenderblush #FFF0F5
		lawngreen #7CFC00
		lemonchiffon #FFFACD
		lightblue #ADD8E6
		lightcoral #F08080
		lightcyan #E0FFFF
		lightgoldenrodyellow #FAFAD2
		lightgray #D3D3D3
		lightgrey #D3D3D3
		lightgreen #90EE90
		lightpink #FFB6C1
		lightsalmon #FFA07A
		lightseagreen #20B2AA
		lightskyblue #87CEFA
		lightslategray #778899
		lightslategrey #778899
		lightsteelblue #B0C4DE
		lightyellow #FFFFE0
		lime #00FF00
		limegreen #32CD32
		linen #FAF0E6
		magenta #FF00FF
		maroon #800000
		mediumaquamarine #66CDAA
		mediumblue #0000CD
		mediumorchid #BA55D3
		mediumpurple #9370DB
		mediumseagreen #3CB371
		mediumslateblue #7B68EE
		mediumspringgreen #00FA9A
		mediumturquoise #48D1CC
		mediumvioletred #C71585
		midnightblue #191970
		mintcream #F5FFFA
		mistyrose #FFE4E1
		moccasin #FFE4B5
		navajowhite #FFDEAD
		navy #80
		oldlace #FDF5E6
		olive #808000
		olivedrab #6B8E23
		orange #FFA500
		orangered #FF4500
		orchid #DA70D6
		palegoldenrod #EEE8AA
		palegreen #98FB98
		paleturquoise #AFEEEE
		palevioletred #DB7093
		papayawhip #FFEFD5
		peachpuff #FFDAB9
		peru #CD853F
		pink #FFC0CB
		plum #DDA0DD
		powderblue #B0E0E6
		purple #800080
		rebeccapurple #663399
		red #FF0000
		rosybrown #BC8F8F
		royalblue #41690
		saddlebrown #8B4513
		salmon #FA8072
		sandybrown #F4A460
		seagreen #2E8B57
		seashell #FFF5EE
		sienna #A0522D
		silver #C0C0C0
		skyblue #87CEEB
		slateblue #6A5ACD
		slategray #708090
		slategrey #708090
		snow #FFFAFA
		springgreen #00FF7F
		steelblue #4682B4
		tan #D2B48C
		teal #8080
		thistle #D8BFD8
		tomato #FF6347
		turquoise #40E0D0
		violet #EE82EE
		wheat #F5DEB3
		white #FFFFFF
		whitesmoke #F5F5F5
		yellow #FFFF00
		yellowgreen #9ACD32
		);
	waitForIt("Converting all color names to hex values.");
	# This loop takes 1m26s for a dictionary with 132k entries and no color tags.
	# foreach my $Color(keys %ColorCoding){
	# 	$html =~ s~c="$Color">~c="$ColorCoding{$Color}">~isg;
	# 	$html =~ s~color:$Color>~c:$ColorCoding{$Color}>~isg;
	# }

	# This takes 1s for a dictionary with 132k entries and no color tags
	# Not tested with Oxford 2nd Ed. yet!!
	$html =~ s~c="(\w+)">~c="$ColorCoding{lc($1)}">~isg;
	$html =~ s~color:(\w+)>~c:$ColorCoding{lc($1)}>~isg;
	doneWaiting();
	return( split(/$/,$html) );}
sub convertCVStoXDXF{
	my @cvs = @_;
	my @xdxf = @xdxf_start;
	my $number= 0;
	foreach(@cvs){
		$number++;
		debugV("\$CVSDeliminator is \'$CVSDeliminator\'.") if $number<10;
		debugV("CVS line is: $_") if $number<10;
		m~(?<key>((?!$CVSDeliminator).)+)$CVSDeliminator(?<def>.+)~;
		# my $comma_is_at = index $_, $CVSDeliminator, 0;
		# debug("The deliminator is at: $comma_is_at") if $number<10;
		# my $key = substr $_, 0, $comma_is_at - 1;
		# my $def = substr $_, $comma_is_at + length($CVSDeliminator);
		my $key = $+{key};
		my $def = $+{def};

		debugV("key found: $key") if $number<10;
		debugV("def found: $def") if $number<10;
		# Remove whitespaces at the beginning of the definition and EOL at the end.
		$def =~ s~^\s+~~;
		$def =~ s~\n$~~;
		push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
		debugV("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if $number<10;
	}
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}
sub convertHTML2XDXF{
	# Converts html generated by KindleUnpack to xdxf
	my $encoding = shift @_;
	my $html = join('',@_);
	my @xdxf = @xdxf_start;
	# Content excerpt longestframe:
		# <idx:entry scriptable="yes"><idx:orth value="a"></idx:orth><div height="4"><a id="filepos242708" /><a id="filepos242708" /><a id="filepos242708" /><div><sub> </sub><sup> </sup><b>a, </b><b>A </b><img hspace="0" align="middle" hisrc="Images/image15902.gif"/>das; - (UGS.: -s), - (UGS.: -s) [mhd., ahd. a]: <b>1.</b> erster Buchstabe des Alphabets: <i>ein kleines a, ein gro\xDFes A; </i> <i>eine Brosch\xFCre mit praktischen Hinweisen von A bis Z (unter alphabetisch angeordneten Stichw\xF6rtern); </i> <b>R </b>wer A sagt, muss auch B sagen (wer etwas beginnt, muss es fortsetzen u. auch unangenehme Folgen auf sich nehmen); <sup>*</sup><b>das A und O, </b>(SELTENER:) <b>das A und das O </b>(die Hauptsache, Quintessenz, das Wesentliche, Wichtigste, der Kernpunkt; urspr. = der Anfang und das Ende, nach dem ersten [Alpha] und dem letzten [Omega] Buchstaben des griech. Alphabets); <sup>*</sup><b>von A bis Z </b>(UGS.; von Anfang bis Ende, ganz und gar, ohne Ausnahme; nach dem ersten u. dem letzten Buchstaben des dt. Alphabets). <b>2.</b> &#139;das; -, -&#155; (MUSIK) sechster Ton der C-Dur-Tonleiter: <i>der Kammerton a, A.</i> </div></div></idx:entry><div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif"/></div> <idx:entry scriptable="yes"><idx:orth value="\xE4"></idx:orth><div height="4"><div><b>\xE4, </b><b>\xC4 </b><img hspace="0" align="middle" hisrc="Images/image15906.gif"/>das; - (ugs.: -s), - (ugs.: -s) [mhd. \xE6]: Buchstabe, der f\xFCr den Umlaut aus a steht.</div></div></idx:entry><div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif"/></div> <idx:entry scriptable="yes"><idx:orth value="a"></idx:orth><div height="4"><div><sup><font size="2">1&#8204;</font></sup><b>a</b><b> </b>= a-Moll; Ar.</div></div></idx:entry><div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif"/></div> 
	#
	# Prettified:
		# <idx:entry scriptable="yes">
		#     <idx:orth value="a"></idx:orth>
		#     <div height="4"><a id="filepos242708" /><a id="filepos242708" /><a id="filepos242708" />
		#         <div><sub> </sub><sup> </sup><b>a, </b><b>A </b><img hspace="0" align="middle" hisrc="Images/image15902.gif" />das; - (UGS.: -s), - (UGS.: -s) [mhd., ahd. a]: <b>1.</b> erster Buchstabe des Alphabets: <i>ein kleines a, ein gro\xDFes A; </i> <i>eine Brosch\xFCre mit praktischen Hinweisen von A bis Z (unter alphabetisch angeordneten Stichw\xF6rtern); </i> <b>R </b>wer A sagt, muss auch B sagen (wer etwas beginnt, muss es fortsetzen u. auch unangenehme Folgen auf sich nehmen); <sup>*</sup><b>das A und O, </b>(SELTENER:) <b>das A und das O </b>(die Hauptsache, Quintessenz, das Wesentliche, Wichtigste, der Kernpunkt; urspr. = der Anfang und das Ende, nach dem ersten [Alpha] und dem letzten [Omega] Buchstaben des griech. Alphabets); <sup>*</sup><b>von A bis Z </b>(UGS.; von Anfang bis Ende, ganz und gar, ohne Ausnahme; nach dem ersten u. dem letzten Buchstaben des dt. Alphabets). <b>2.</b> &#139;das; -, -&#155; (MUSIK) sechster Ton der C-Dur-Tonleiter: <i>der Kammerton a, A.</i> </div>
		#     </div>
		# </idx:entry>
		# <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /></div>
		# <idx:entry scriptable="yes">
		#     <idx:orth value="\xE4"></idx:orth>
		#     <div height="4">
		#         <div><b>\xE4, </b><b>\xC4 </b><img hspace="0" align="middle" hisrc="Images/image15906.gif" />das; - (ugs.: -s), - (ugs.: -s) [mhd. \xE6]: Buchstabe, der f\xFCr den Umlaut aus a steht.</div>
		#     </div>
		# </idx:entry>
		# <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /></div>
		# <idx:entry scriptable="yes">
		#     <idx:orth value="a"></idx:orth>
		#     <div height="4">
		#         <div><sup>
		#                 <font size="2">1&#8204;</font>
		#             </sup><b>a</b><b> </b>= a-Moll; Ar.</div>
		#     </div>
		# </idx:entry>
		# <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /></div>
	
	my @indexentries = $html=~m~<idx:entry scriptable="yes">((?:(?!</idx:entry>).)+)</idx:entry>~gs;
	if($isTestingOn){ array2File("test_html_indexentries.html",map(qq/$_\n/,@indexentries)  ) ; }
	my $number = 0;
	my $lastkey = "";
	my (%ConversionDebugStrings, %ReplacementImageStrings);
	my $HashFileName = join('', $FileName=~m~^(.+?\.)[^.]+$~)."hash";
	if( -e $HashFileName ){ %ReplacementImageStrings = %{retrieve($HashFileName)}; }
	waitForIt("Converting indexentries from HTML to XDXF.");
	foreach (@indexentries){
		$number++;
		debug($_) if m~<idx:orth value="$debug_entry"~;
		# Remove <a /> tags
		s~(</?a[^>]*>|<betonung/>)~~sg;
		# Remove <mmc:fulltext-word ../>
		s~<mmc:fulltext-word[^>]+>~~sg;
		# Remove <img ../>, e.g. <img hspace="0" align="middle" hisrc="Images/image15907.gif" />
		if( $isCodeImageBase64 and m~(<img[^>]+>)~s){
			my @imagestrings = m~(<img[^>]+>)~sg;
			debug("Number of imagestrings found is ", scalar @imagestrings) if m~<idx:orth value="$debug_entry"~;
			my $replacement;
			foreach my $imagestring(@imagestrings){
				# debug('$ReplacementImageStrings{$imagestring}: ',$ReplacementImageStrings{$imagestring});
				if ( exists $ReplacementImageStrings{$imagestring} ){
					$replacement = $ReplacementImageStrings{$imagestring}
				}
				else{
					# <img hspace="0" align="middle" hisrc="Images/image15907.gif"/>
					$imagestring =~ m~hisrc="(?<image>[^"]*?\.(?<ext>gif|jpg|png|bmp))"~si;
					debug("Found image named $+{image} with extension $+{ext}.") if m~<idx:orth value="$debug_entry"~;
					my $imageName = $+{image};
					my $imageformat = $+{ext};
					if( -e "$FullPath/$imageName"){
						if ( $isConvertGIF2PNG and $imageformat =~ m~gif~i){
							# Convert gif to png
							my $Command="convert \"$FullPath/$imageName\" \"$FullPath/$imageName.png\"";
							debug("Executing command: $Command") if m~<idx:orth value="$debug_entry"~;
							`$Command`;
							$imageName = "$imageName.png";
							$imageformat = "png";
						}
						my $image = join('', file2Array("$FullPath/$imageName", ":raw", "quiet") );
						my $encoded = encode_base64($image);
						$encoded =~ s~\n~~sg;
						$replacement = '<img src="data:image/'.$imageformat.';base64,'.$encoded.'" alt="'.$imageName.'"/>';
						$replacement =~ s~\\\"~"~sg;
						debug($replacement) if m~<idx:orth value="$debug_entry"~;
						$ReplacementImageStrings{$imagestring} = $replacement;
					}
					else{ 
						if( $isRealDead ){ debug("Can't find $FullPath/$imageName. Quitting."); die; } 
						else{ $replacement = ""; }
					}

				}
				s~\Q$imagestring\E~$replacement~;
			}
		}
		else{  s~<img[^>]+>~~sg; }
		# Remove empty sup and sub-blocks
		s~<sub>[\s]*</sub>~~sg;
		s~<sup>[\s]*</sup>~~sg;
		s~<b>[\s]*</b>~~sg;
		# Include encoding conversion
		while( $encoding eq "cp1252" and m~\&\#(\d+);~s ){
			my $encoded = $1;
			my $decoded = decode( $encoding, pack("N", $encoded) ); 
			# The decode step generates four hex values: a triplet of <0x00> followed by the one that's wanted. This goes awry if 
			while( ord( substr( $decoded, 0, 1) ) == 0 ){
				$decoded = substr( $decoded, 1 );
			}
			# Skip character because it cannot be handled by code and is most probably the same in cp1252 and unicode.
			if( length($decoded)>1 ){
				# Convert to hexadecimal value so that the while-loop doesn't become endless.
				my $hex = sprintf("%X", $encoded);  
				$decoded = "&#x$hex;"; 
			}
			# If character is NL, than replacement should be \n
			elsif( ord($decoded) == 12 ){ $decoded = "\n";}
			my $DebugString = "Encoding is $encoding. Encoded is $encoded. Decoded is \'$decoded\' of length ".length($decoded).", numbered ".ord($decoded);
			$ConversionDebugStrings{$encoded} = $DebugString;
			s~\&\#$encoded;~$decoded~sg;				
		}
		# Change div-blocks to spans
		s~(</?)div[^>]*>~$1span>~sg;

		my $round = 0;
		# Change font- to spanblocks
		while( s~<font size="(?:2|-1)">((?:(?!</font).)+)</font>~<small>$1</small>~sg ){ 
			$round++;
			debug("font-blocks substituted with small-blocks in round $round.") if m~<idx:orth value="$debug_entry"~;
		}
		$round = 0;
		while( s~<font[^>]*>((?:(?!</font).)*)</font>~<span>$1</span>~sg ){ 
			$round++;
			debug("font-blocks substituted with span-blocks in round $round.") if m~<idx:orth value="$debug_entry"~;
		}
		# Change <mmc:no-fulltext> to <blockquote>
		$round = 0;
		while( s~<mmc:no-fulltext>((?:(?!</mmc:no-fulltext).)+)</mmc:no-fulltext>~<f> $1</f>~sg ){ 
			$round++;
			debug("<mmc:no-fulltext>-blocks substituted with spans in round $round.") if $number<3;
		}
		# Create key&definition strings.
		m~^<idx:orth value="(?<key>[^"]+)"></idx:orth>(?<def>.+)$~s;
		my $key = $+{key};
		my $def = "<blockquote>".$+{def}."</blockquote>";
		debugV("key found: $key") if $number<10;
		debugV("def found: $def") if $number<10;
		# Remove whitespaces at the beginning of the definition and EOL at the end.
		$def =~ s~^\s+~~;
		$def =~ s~\n$~~;
		# Switch position sup/span/small blocks
		# <sup><small>1&#8204;</small></sup>
		# $html =~ s~<sup><small>([^<]*)</small>~<sup>$1~sg;
		$def =~ s~<sup><small>([^<]*)</small></sup>~<small><sup>$1</sup></small>~sg;
		# $html =~ s~<sup><span>([^<]*)</span>~<sup>$1~sg;
		$def =~ s~<sup><span>([^<]*)</span></sup>~<span><sup>$1</sup></span>~sg;
		$def =~ s~<sub><small>([^<]*)</small></sub>~<small><sub>$1</sub></small>~sg;
		$def =~ s~<sub><span>([^<]*)</span></sub>~<span><sub>$1</sub></span>~sg;
		# Put space in front of ‹, e.g. ‹Adj.›, if it's lacking
		$def =~ s~([^\s])‹~$1 ‹~sg;
		if( $key eq $lastkey){
			# Change the last entry to append current definition
			$xdxf[-1] =~ s~</def></ar>\n~\n$def</def></ar>\n~s;
			debug("Added to the last definition. It's now:\n$xdxf[-1]") if m~<idx:orth value="$debug_entry"~;
		}
		else{
			push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
			debug("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if m~<idx:orth value="$debug_entry"~;
		}
		$lastkey = $key;
	}
	# Save hash for later use.
	store(\%ReplacementImageStrings, $HashFileName);
	foreach( sort keys %ConversionDebugStrings){ debug($ConversionDebugStrings{$_}); }
	doneWaiting();
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}
sub convertNonBreakableSpacetoNumberedSequence{
	my $UnConverted = join('',@_);
	debugV("Entered sub convertNonBreakableSpacetoNumberedSequence");
	$UnConverted =~ s~\&nbsp;~&#160;~sg ;
	my @Converted = split(/$/, $UnConverted);
	return( @Converted );}
sub convertNumberedSequencesToChar{
	my $UnConverted = join('',@_);
	debugV("Entered sub convertNumberedSequencesToChar");
	$UnConverted =~ s~\&\#x([0-9A-Fa-f]{1,6});~chr("0x".$1)~seg ;
	$UnConverted =~ s~\&\#([0-9]{1,6});~chr(int($1))~seg ;
	return( split(/(\n)/, $UnConverted) );}
sub convertStardictXMLtoXDXF{
	my $StardictXML = join('',@_);
	my @xdxf = @xdxf_start;
	# Extract bookname from Stardict XML
	if( $StardictXML =~ m~<bookname>(?<bookname>((?!</book).)+)</bookname>~s ){
		my $bookname = $+{bookname};
		# xml special symbols are not recognized by converter in the dictionary title.
		$bookname =~ s~&lt;~<~;
		$bookname =~ s~&amp;~&~;
		$bookname =~ s~&apos;~'~;
		substr($xdxf[2], 11, 0) = $bookname;
	}
	# Extract date if present from Stardict XML
	if( $StardictXML =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
		substr($xdxf[4], 6, 0) = $+{date};
	}
	# Extract sametypesequence from Stardict XML
	if( $updateSameTypeSequence and $StardictXML =~ m~<definition type="(?<sametypesequence>\w)">~s){
		$SameTypeSequence = $+{sametypesequence};
	}

	waitForIt("Converting stardict xml to xdxf xml.");
	# Initialize variables for collection
	my ($key, $def, $article, $definition) = ("","", 0, 0);
	# Initialize variables for testing
	my ($test_loop, $counter,$max_counter) = (0,0,40) ;
	foreach(@_){
		$counter++;
		# Change state to article
		if(m~<article>~){ $article = 1; debug("Article start tag found at line $counter.") if $test_loop;}

		# Match key within article outside of definition
		if($article and !$definition and m~<key>(?<key>((?!</key>).)+)</key>~){ $key = $+{key}; debug("Key \"$key\" found at line $counter.") if $test_loop;}
		# change state to definition
		if(m~<definition type="\w">~){ $definition = 1; debug("Definition start tag found at line $counter.") if $test_loop;}
		# Fails for multiline definitions such as:
			# <definition type="x">
			# <![CDATA[<k>&apos;Arry</k>
			# <b>&apos;Arry</b>
			# <blockquote><blockquote>(<c c="darkslategray">ˈærɪ</c>)</blockquote></blockquote>
			# <blockquote><blockquote><c c="gray">[The common Christian name <i>Harry</i> vulgarly pronounced without the aspirate.]</c></blockquote></blockquote>
			# <blockquote><blockquote>Used humorously for: A low-bred fellow (who ‘drops his <i>h&apos;</i>s’) of lively temper and manners. Hence <b>&apos;Arryish</b> <i>a.</i>, vulgarly jovial.</blockquote></blockquote>
			# <blockquote><blockquote><blockquote><blockquote><blockquote><blockquote><ex><b>1874</b> <i>Punch&apos;s Almanac</i>, <c c="darkmagenta">&apos;Arry on &apos;Orseback.</c> <b>1881</b> <i><abr>Sat.</abr> <abr>Rev.</abr></i> <abr>No.</abr> 1318. 148 <c c="darkmagenta">The local &apos;Arry has torn down the famous tapestries of the great hall.</c> <b>1880</b> W. Wallace in <i>Academy</i> 28 Feb. 156/1 <c c="darkmagenta">He has a fair stock of somewhat &apos;Arryish animal spirits, but no real humour.</c></ex></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote>]]>
			# </definition>
		s~<definition type="\w">~~;
		s~<\!\[CDATA\[~~;
		s~<k>\Q$key\E</k>~~;
		s~<b>\Q$key\E</b>~~;
		s~^[\n\s]+$~~;
		if($definition and m~(?<def>((?!\]\]>).)+)(\]\]>)?~s){
			my $fund = $+{def};
			$fund =~ s~</definition>\n?~~;
			$def .= $fund if $fund!~m~^[\n\s]+$~;
			debug("Added definition \"$fund\" at line $counter.") if $test_loop and $fund ne "" and $fund!~m~^[\n\s]+$~;
		}
		if(  m~</definition>~ ){
			$definition = 0;
			debug("Definition stop tag found at line $counter.") if $test_loop;
		}
		if(  !$definition and $key ne "" and $def ne ""){
			debug("Found key \'$key\' and definition \'$def\'") if $test_loop;
			push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
			($key, $def, $definition) = ("","",0);
		}
		# reset on end of article
		if(m~</article>~ ){
			($key, $def, $article) = ("","",0);
			debug("Article stop tag found at line $counter.\n") if $test_loop;
		}
		die if $counter==$max_counter and $test_loop and $isRealDead;
	}
	doneWaiting();
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}
sub convertXDXFtoStardictXML{
	my $xdxf = join('',@_);
	$xdxf = removeInvalidChars( $xdxf );
	my @xml = @xml_start;
	if( $xdxf =~ m~<full_name>(?<bookname>((?!</full_name).)+)</full_name>~s ){
		my $bookname = $+{bookname};
		# xml special symbols are not recognized by converter in the dictionary title.
		$bookname =~ s~&lt;~<~;
		$bookname =~ s~&amp;~&~;
		$bookname =~ s~&apos;~'~;
		substr($xml[4], 10, 0) = $bookname;
	}
	if( $xdxf =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
		substr($xml[9], 6, 0) = $+{date};
	}
	if( $xdxf =~ m~<xdxf (?<description>((?!>).)+)>~s ){
		substr($xml[8], 13, 0) = $+{description};
	}
	waitForIt("Converting xdxf-xml to Stardict-xml." );
	my @articles = $xdxf =~ m~<ar>((?:(?!</ar).)+)</ar>~sg ;
	printCyan("Finished getting articles at ", getLoggingTime(),"\n" );
	$cycle_dotprinter = 0;
	foreach my $article ( @articles){
		$cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		push @xml, "<article>\n";
		# <head><k>a</k></head>
		$article =~ m~<head><k>(?<key>((?!</k).)+)</k>~s;
		push @xml, "<key>".$+{key}."</key>\n\n";
		$article =~ m~<def>(?<definition>((?!</def).)+)</def>~s;
		push @xml, '<definition type="'.$SameTypeSequence.'">'."\n";
		push @xml, '<![CDATA['.$+{definition}.']]>'."\n";
		push @xml, "</definition>\n";
		push @xml, "</article>\n\n";
	}
	push @xml, "\n";
	push @xml, $lastline_xml;
	push @xml, "\n";
	doneWaiting();
	return(@xml);}
sub doneWaiting{ printCyan("Done at ",getLoggingTime(),"\n");}
sub file2Array {

    #This subroutine expects a path-and-filename in one and returns an array
    my $FileName = $_[0];
    my $encoding = $_[1];
    my $verbosity = $_[2];
    my $isBinMode = 0; 
    if(defined $encoding and $encoding eq ":raw"){
    	undef $encoding;
    	$isBinMode = 1;
    }
    if(!defined $FileName){debug("File name in file2Array is not defined. Quitting!");die if $isRealDead;}
    if( defined $encoding){ open( FILE, "<:encoding($encoding)", $FileName )
      || (warn "Cannot open $FileName: $!\n" and die);}
	else{    open( FILE, "$FileName" )
      || (warn "Cannot open $FileName: $!\n" and die);
  }
  	if( $isBinMode ){
  		binmode FILE;
  	}
    my @ArrayLines = <FILE>;
    close(FILE);
    printBlue("Read $FileName, returning array. Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");
    return (@ArrayLines);}
sub filterXDXFforEntitites{
	my( @xdxf ) = @_;
	my @Filteredxdxf;
	if( scalar keys %EntityConversion == 0 ){
		debugV("No \%EntityConversion hash defined");
		return(@xdxf);
	}
	else{debugV("These are the keys:", keys %EntityConversion);}
	$cycle_dotprinter = 0 ;
	waitForIt("Filtering entities based on DOCTYPE.");
	foreach my $line (@xdxf){
		$cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		foreach my $EntityName(keys %EntityConversion){
			$line =~ s~(\&$EntityName;)~$EntityConversion{$EntityName}~g;
		}
		push @Filteredxdxf, $line;
	}
	doneWaiting();
	return (@Filteredxdxf);}
sub generateEntityHashFromDocType{
	my $String = $_[0]; # MultiLine DocType string. Not Array!!!
	my %EntityConversion=( );
	while($String =~ s~<!ENTITY\s+(?<name>[^\s]+)\s+"(?<meaning>.+?)">~~s){
		debugV("$+{name} --> $+{meaning}");
		$EntityConversion{$+{name}} = $+{meaning};
	}
	return(%EntityConversion);}
sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;}
sub loadXDXF{
	# Create the array @xdxf
	my @xdxf;
	my $PseudoFileName = join('', $FileName=~m~^(.+?\.)[^.]+$~)."xdxf";
	## Load from xdxffile
	if( $FileName =~ m~\.xdxf$~){@xdxf = file2Array($FileName);}
	elsif( -e $PseudoFileName ){ 
		@xdxf = file2Array($PseudoFileName); 
		# Check SameTypeSequence
		checkSameTypeSequence($FileName);
		# Change FileName to xdxf-extension
		$FileName = $PseudoFileName;
	}
	## Load from ifo-, dict- and idx-files
	elsif( $FileName =~ m~^(?<filename>((?!\.ifo).)+)\.(ifo|xml)$~){
		# Check wheter a converted xml-file already exists or create one.
		if(! -e $+{filename}.".xml"){
			# Convert the ifo/dict using stardict-bin2text $FileName $FileName.".xml";
			if ( $OperatingSystem == "linux"){
				printCyan("Convert the ifo/dict using system command: \"stardict-bin2text $FileName $FileName.xml\"\n");
				system("stardict-bin2text \"$FileName\" \"$+{filename}.xml\"");
			}
			else{ debug("Not linux, so you can't use the script directly on ifo-files, sorry!\n",
				"First decompile your dictionary with stardict-editor to xml-format (Textual Stardict dictionary),\n",
				"than either use the ifo- or xml-file as your dictioanry name for conversion.")}
		}
		# Create an array from the stardict xml-dictionary.
		my @StardictXML = file2Array("$+{filename}.xml");
		@xdxf = convertStardictXMLtoXDXF(@StardictXML);
		# Write it to disk so it hasn't have to be done again.
		array2File($+{filename}.".xdxf", @xdxf);
		# debug(@xdxf); # Check generated @xdxf
		$FileName=$+{filename}.".xdxf";
	}
	## Load from comma separated values cvs-file.
	## It is assumed that every line has a key followed by a comma followed by the definition.
	elsif( $FileName =~ m~^(?<filename>((?!\.csv).)+)\.csv$~){
		my @cvs = file2Array($FileName);
		@xdxf = convertCVStoXDXF(@cvs);
		# Write it to disk so it hasn't have to be done again.
		array2File($+{filename}.".xdxf", @xdxf);
		# debug(@xdxf); # Check generated @xdxf
		$FileName=$+{filename}.".xdxf";
	}
	elsif(	$FileName =~ m~^(?<filename>((?!\.mobi).)+)\.mobi$~ or
			$FileName =~ m~^(?<filename>((?!\.html).)+)\.html$~	){
		# Use full path and filename
		my $InputFile = "$BaseDir/$FileName";
		my $OutputFolder = substr($InputFile, 0, length($InputFile)-5);
		my $DictionaryName = join('',$OutputFolder =~ m~([^/]+)$~);
		
		if( $FileName =~ m~^(?<filename>((?!\.mobi).)+)\.mobi$~ 	){
			# Checklist
			if ($OperatingSystem eq "linux"){ debugV("Converting mobi to html on Linux is possible.") }
			else{ debug("Not Linux, so the script can't convert mobi-format. Quitting!"); die; }
			my $python_version = `python --version`;
			if(  substr($python_version, 0,6) eq "Python"){
				debug("Found python responding as expected.");
			}
			else{ debug("Python binary not working as expected/not installed. Quitting!"); die; }
			
			# Conversion mobi to html
			if( -e "$OutputFolder/mobi7/$DictionaryName.html" ){
				debug("html-file found. Mobi-file already converted.")
			}
			else{
				chdir $KindleUnpackLibFolder || warn "Cannot change to $KindleUnpackLibFolder: $!\n";
				waitForIt("The script kindelunpack.py is now unpacking the file:\n$InputFile\nto: $OutputFolder.");
				my $returnstring = `python kindleunpack.py -r -s --epub_version=A -i "$InputFile" "$OutputFolder"`;
				if( $returnstring =~ m~Completed\n*$~s ){
					debug("Succes!");
				}
				else{
					debug("Failed to convert mobi"); 
					debug($returnstring);
					die;
				}
				chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";
				rename "$OutputFolder/mobi7/book.html", "$OutputFolder/mobi7/$DictionaryName.html";
				doneWaiting();
			}
			debug("Dictionary name is '$DictionaryName'.");
			$LocalPath = "$LocalPath/$DictionaryName/mobi7";
			$FullPath = "$FullPath/$DictionaryName/mobi7";
			$FileName = "$LocalPath/$DictionaryName.html";
			debug("Local path for generated html is \'$LocalPath\'.");
			debug("Full path for generated html is \'$FullPath\.");
			debug("Filename for generated html is \'$FileName\'.");
		}
		# Output of KindleUnpack.pyw
		my $encoding = "UTF-8";
		my @html = file2Array($FileName);
		# <meta http-equiv="content-type" content="text/html; charset=windows-1252" />
		if( $html[0] =~ m~content="text/html; charset=windows-1252"~is ){
			# Reopen with encoding cp-1252
			debugV("Found encoding Windows-1252, a.k.a. cp1252");
			$encoding = "cp1252";
			my @html = file2Array($FileName,$encoding,"quiet");
		}
		elsif( $html[0] =~ m~content="text/html; charset=utf-8"~is ){
			debugV("Found encoding utf-8");
			$encoding = "utf-8";
			my @html = file2Array($FileName,$encoding,"quiet");	
		}
		@xdxf = convertHTML2XDXF($encoding,@html);
		# Check whether there is a saved reconstructed xdxf to get the language and name from.
		if(-e  "$LocalPath/$DictionaryName"."_reconstructed.xdxf"){
			my @saved_xdxf = file2Array("$LocalPath/$DictionaryName"."_reconstructed.xdxf");
			@xdxf[0..2] = @saved_xdxf[0..2];
		}
		else{debug('No prior dictionary reconstructed.');}
		$FileName="$LocalPath/$DictionaryName".".xdxf";
		# Write it to disk so it hasn't have to be done again.
		array2File($FileName, @xdxf);
		# debug(@xdxf); # Check generated @xdxf


	
	}
	else{debug("Not an extension that the script can handle for the given filename. Quitting!");die;}
	return( @xdxf );}
sub makeKoreaderReady{
	my $html = join('',@_);
	waitForIt("Making the dictionary Koreader ready.");
	# Not moving it to lua, because it also works with Goldendict.
	$html =~ s~<c>~<span>~sg;
	$html =~ s~<c c="~<span style="color:~sg;
	$html =~ s~</c>~</span>~sg;
	# Things done with css-file
	my @css;
	my $FileNameCSS = join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.css";
	# Remove large blockquote margins
	push @css, "blockquote { margin: 0 0 0 1em }\n";
	# Remove images
	# $html =~ s~<img[^>]+>~~sg;
	# push @css, "img { display: none; }\n"; # Doesn't work. Placeholder [image] still appears in Koreader.
	if(scalar @css>0){array2File($FileNameCSS,@css);}
	# Things done with lua-file
	my @lua;
	my $FileNameLUA = join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.lua";
	# Example
	# return function(html)
	# html = html:gsub('<c c=\"', '<span style="color:')
	# html = html:gsub('</c>', '</span>')
	# html = html:gsub('<c>', '<span>')
	# return html
	# end
	# Example
	# return function(html)
	# -- html = html:gsub(' style=', ' zzztyle=')
	# html = html:gsub(' [Ss][Tt][Yy][Ll][Ee]=', ' zzztyle=')
	# return html
	# end
	my $lua_start = "return function(html)\n";
	my $lua_end = "return html\nend\n";
	# Remove images
	push @lua, "html = html:gsub('<img[^>]+>', '')\n"; 
	if(scalar @lua>0){
		unshift @lua, $lua_start;
		push @lua, $lua_end;
		array2File($FileNameLUA,@lua);
	}
	doneWaiting();
	# Remove oft-file from old dictionary
	unlink join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.idx.oft";

	return(split(/$/, $html));}
sub printGreen   { print color('green') if $OperatingSystem eq "linux";   print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printBlue    { print color('blue') if $OperatingSystem eq "linux";    print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printRed     { print color('red') if $OperatingSystem eq "linux";     print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printYellow  { print color('yellow') if $OperatingSystem eq "linux";  print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printMagenta { print color('magenta') if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printCyan    { print color('cyan') if $OperatingSystem eq "linux";    print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub reconstructXDXF{
	# Construct a new xdxf array to prevent converter.exe from crashing.
	## Initial values
	my @xdxf = @_;
	my @xdxf_reconstructed = ();
	my $xdxf_closing = "</xdxf>\n";
	
	waitForIt("Reconstructing xdxf array.");
	## Step through the array line by line until the articles start.
	## Then push (altered) entry to array.
	foreach my $entry (@xdxf){
		# Handling of xdxf tag
		if ( $entry =~ m~^<xdxf(?<xdxf>.+)>\n$~){
			my $xdxf = $+{xdxf};
			if( $reformat_xdxf and $xdxf =~ m~ lang_from="(.*)" lang_to="(.*)" format="(.*)"~){
				$lang_from = $1 if defined $1 and $1 ne "";
				$lang_to = $2 if defined $2 and $2 ne "";
				$format = $3 if defined $3 and $3 ne "";
				print(" lang_from is \"$1\". Would you like to change it? (press enter to keep default \[$lang_from\] ");
				my $one = <STDIN>; chomp $one; if( $one ne ""){ $lang_from = $one ; }
				print(" lang_to is \"$2\". Would you like to change it? (press enter to keep default \[$lang_to\] ");
				my $two = <STDIN>; chomp $two; if( $two ne ""){ $lang_to = $two ; }
				print(" format is \"$3\". Would you like to change it? (press enter to keep default \[$format\] ");
				my $three = <STDIN>; chomp $three; if( $three ne ""){ $format = $three ; }
				$xdxf= 'lang_from="'.$lang_from.'" lang_to="'.$lang_to.'" format="'.$format.'"';
			}
			$entry = "<xdxf ".$xdxf.">\n";
			printMagenta($entry);
		}
		# Handling of full_name tag
		elsif ( $entry =~ m~^<full_name>~){
			if ( $entry !~ m~^<full_name>.*</full_name>\n$~){ debug("full_name tag is not on one line. Investigate!\n"); die if $isRealDead;}
			elsif( $reformat_full_name and $entry =~ m~^<full_name>(?<fullname>((?!</full).)*)</full_name>\n$~ ){
				my $full_name = $+{fullname};
				my $old_name = $full_name;
				print("Full_name is \"$full_name\".\nWould you like to change it? (press enter to keep default \[$full_name\] ");
				my $one = <STDIN>; chomp $one; if( $one ne ""){ $full_name = $one ; };
				debug("\$entry was: $entry");
				$entry = "<full_name>$full_name</full_name>\n";
				debug("Fullname tag entry is now: ");
			}
			printMagenta($entry);
		}
		# Handling of Description. Turns one line into multiple.
		elsif( $entry =~ m~^(?<des><description>)(?<cont>((?!</desc).)*)(?<closetag></description>)\n$~ ){
			my $Description_content .= $+{cont} ; 
			chomp $Description_content;
			$entry = $+{des}."\n".$Description_content."\n".$+{closetag}."\n";
		}
		# Handling of an ar-tag
		elsif ( $entry =~ m~^<ar>~){last;}  #Start of ar block
		
		push @xdxf_reconstructed, $entry;
	}

	# Push cleaned articles to array
	my $xdxf = join( '', @xdxf);
	my @articles = $xdxf =~ m~<ar>((?:(?!</ar).)+)</ar>~sg ;
	my ($ar, $ar_count) = ( 0, 0);
	foreach my $article (@articles){
		$ar_count++; $cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		$article = cleanseAr($article);
		chomp $article;
		push @xdxf_reconstructed, "<ar>\n$article\n</ar>\n";
	}
	
	push @xdxf_reconstructed, $xdxf_closing;
	printMagenta("\nTotal number of articles processed \$ar = ",scalar @articles,".\n");
	doneWaiting();
	return( @xdxf_reconstructed );}
sub removeInvalidChars{
	my $xdxf = $_[0]; # Only a string or first entry of array is checked and returned.
	waitForIt("Removing invalid characters.");
	my @results = $xdxf =~ s~(\x05|\x02|\x01)~~sg;
	shift @results;
	if( scalar @results > 0 ){ 
		# Make unique results;
		my %unique_results;
		foreach(@results){ $unique_results{$_} = 1; }
		debug("Number of characters removed: ",scalar @results); 
		debug( map qq/"$_", /, keys %unique_results );
	}
	else{ debugV('Nothing removed. If \"parser error : PCDATA invalid Char value...\" remains, look at subroutine removeInvalidChars.');}
	doneWaiting();
	return($xdxf); }
sub waitForIt{ printCyan("@_"," This will take some time. ", getLoggingTime(),"\n");}
# Generate entity hash defined in DOCTYPE
%EntityConversion = generateEntityHashFromDocType($DocType);

# Fill array from file.
my @xdxf;
@xdxf = loadXDXF();
array2File("testLoadedDVDX.xml", @xdxf) if $isTestingOn;
# filterXDXFforEntitites
@xdxf = filterXDXFforEntitites(@xdxf);
array2File("testFilteredDVDX.xml", @xdxf) if $isTestingOn;
my @xdxf_reconstructed = reconstructXDXF( @xdxf );
array2File("test_Constructed.xml", @xdxf_reconstructed) if $isTestingOn;
# If SameTypeSequence is not "h", remove &#xDDDD; sequences and replace them with characters.
if ( $SameTypeSequence ne "h" ){
	@xdxf_reconstructed = convertNumberedSequencesToChar(
							convertNonBreakableSpacetoNumberedSequence( @xdxf_reconstructed )
								) ;
}
# Save reconstructed XDXF-file
my $dict_xdxf=$FileName;
if( $dict_xdxf !~ s~\.xdxf~_reconstructed\.xdxf~ ){ debug("Filename substitution did not work for : \"$dict_xdxf\""); die if $isRealDead; }
array2File($dict_xdxf, @xdxf_reconstructed);

# Convert colors to hexvalues
if( $isConvertColorNamestoHexCodePoints ){ @xdxf_reconstructed = convertColorName2HexValue(@xdxf_reconstructed); }
# Create Stardict dictionary
if( $isCreateStardictDictionary ){
	if ( $isMakeKoreaderReady ){ @xdxf_reconstructed = makeKoreaderReady(@xdxf_reconstructed); }
	# Save reconstructed XML-file
	my @StardictXMLreconstructed = convertXDXFtoStardictXML(@xdxf_reconstructed);
	my $dict_xml = $FileName;
	if( $dict_xml !~ s~\.xdxf~_reconstructed\.xml~ ){ debug("Filename substitution did not work for : \"$dict_xml\""); die if $isRealDead; }
	array2File($dict_xml, @StardictXMLreconstructed);

	# Convert reconstructed XML-file to binary
	if ( $OperatingSystem eq "linux"){
		my $dict_bin = $dict_xml;
		$dict_bin =~ s~\.xml~\.ifo~;
		my $command = "stardict-text2bin \"$dict_xml\" \"$dict_bin\" ";
		printYellow("Running system command:\"$command\"\n");
		system($command);
	}
	else{ 
		debug("Not linux, so you the script created an xml Stardict dictionary.");
		debug("You'll have to convert it to binary manually using Stardict editor.")
	}

}

# Create Pocketbook dictionary
if( $isCreatePocketbookDictionary ){
	my $ConvertCommand;
	if( $language_dir ne "" ){ $lang_from = $language_dir ;}
	if( $OperatingSystem eq "linux"){ $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$dict_xdxf\" $lang_from"; }
	else{ $ConvertCommand = "converter.exe \"$dict_xdxf\" $lang_from"; }
	printYellow("Running system command:\"$ConvertCommand\"\n");
	system($ConvertCommand);
}
