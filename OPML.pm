# $Id: OPML.pm,v 0.1.6 2004/02/14 09:05:00 szul Exp $
package XML::OPML;

use strict;
use Carp;
use XML::Parser;
use Fcntl qw(:DEFAULT :flock);
use vars qw($VERSION $AUTOLOAD @ISA $modules $AUTO_ADD);

$VERSION = '0.1.6';
@ISA = qw(XML::Parser);

$AUTO_ADD = 0;

my %opml_fields = (
    head => {
		title		=> '',
		dateCreated	=> '',
		dateModified	=> '',
		ownerName	=> '',
		ownerEmail	=> '',
		expansionState	=> '',
		vertScrollState	=> '',
		windowTop	=> '',
		windowLeft	=> '',
		windowBottom	=> '',
		windowRight	=> ''
	},
    body  => {
		outline => [],
	},
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(
    	Namespaces    => 1,
		NoExpand      => 1,
		ParseParamEnt => 0,
		Handlers      => { 
		#	Char    => \&handle_char,
			XMLDecl => \&handle_dec,
		#	Start   => \&handle_start
			}
                );
			
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}

sub _initialize {
    my $self = shift;
    my %hash = @_;

    # internal hash
    $self->{_internal} = {};

    # init num of items to 0
    $self->{num_items} = 0;

    # initialize items
    $self->{outline} = [];

    # encode output from as_string?
    (exists($hash{encode_output}))
    ? ($self->{encode_output} = $hash{encode_output})
    : ($self->{encode_output} = 1);

    #get version info
    (exists($hash{version}))
    ? ($self->{version} = $hash{version})
    : ($self->{version} = '1.0');

    # set default output
    (exists($hash{output}))
    ? ($self->{output} = $hash{output})
    : ($self->{output} = "");

    # encoding
    (exists($hash{encoding}))
    ? ($self->{encoding} = $hash{encoding})
    : ($self->{encoding} = 'UTF-8');

    # opml version 1.1
    if ($self->{version} eq '1.1') {
	foreach my $i (qw(head body)) {
	    my %template = %{$opml_fields{$i}};
	    $self->{$i} = \%template;
        }
    }
}

sub add_outline {
    my $self = shift;
    my $hash = {@_};


    # add the item to the list
    if (defined($hash->{mode}) && $hash->{mode} eq 'insert') {
		unshift (@{$self->{outline}}, $hash);
    } else {
		push (@{$self->{outline}}, $hash);
    }

    # return reference to the list of items
    return $self->{outline};
}

sub as_opml_1_1 {
    my $self = shift;
    my $output;

    # XML declaration
    $output .= '<?xml version="1.0" encoding="'.$self->{encoding}.'"?>'."\n";

    # DOCTYPE
#    $output .= '<!DOCTYPE rss PUBLIC "-//Netscape Communications//DTD RSS 0.91//EN"'."\n";
#    $output .= '            "http://my.netscape.com/publish/formats/rss-0.91.dtd">'."\n\n";

    # OPML root element
    $output .= '<opml version="1.1">'."\n";

    ###################
    # Head Element #
    ###################
    $output .= '<head>'."\n";
    $output .= '<title>'. $self->encode($self->{head}->{title}) .'</title>'."\n";
    $output .= '<dateCreated>'. $self->encode($self->{head}->{dateCreated}) .'</dateCreated>'."\n";
    $output .= '<dateModified>'. $self->encode($self->{head}->{dateModified}) .'</dateModified>'."\n";
    $output .= '<ownerName>'. $self->encode($self->{head}->{ownerName}) .'</ownerName>'."\n";
    $output .= '<ownerEmail>'. $self->encode($self->{head}->{ownerEmail}) .'</ownerEmail>'."\n";
    $output .= '<expansionState>'. $self->encode($self->{head}->{expansionState}) .'</expansionState>'."\n";
    $output .= '<vertScrollState>'. $self->encode($self->{head}->{vertScrollState}) .'</vertScrollState>'."\n";
    $output .= '<windowTop>'. $self->encode($self->{head}->{windowTop}) .'</windowTop>'."\n";
    $output .= '<windowLeft>'. $self->encode($self->{head}->{windowLeft}) .'</windowLeft>'."\n";
    $output .= '<windowBottom>'. $self->encode($self->{head}->{windowBottom}) .'</windowBottom>'."\n";
    $output .= '<windowRight>'. $self->encode($self->{head}->{windowRight}) .'</windowRight>'."\n";
    $output .= '</head>' . "\n";
    $output .= '<body>' . "\n";

    ################
    # outline element #
    ################
    foreach my $outline (@{$self->{outline}}) {
            if(($outline->{opmlvalue}) && ($outline->{opmlvalue} eq "embed")) {
            $output .= "<outline>\n";
            $output .= return_embedded($self, $outline);
            $output .= "</outline>\n";
            next;
            }
	    $output .= "<outline ";
          foreach my $atts (sort {$a cmp $b} keys %{$outline}) {
            $output .= "$atts=\"" . $self->encode($outline->{$atts}) . "\" ";
          }
          $output .= " />";
          $output .= "\n";
    }
    $output .= '</body>' . "\n";
    $output .= '</opml>' . "\n";

    return $output;
}

sub return_embedded {
  my ($self, $outline) = @_;
  my $return_output = "";
  foreach my $inner_out (keys %{$outline}) {
    next if($inner_out eq "opmlvalue");
    #if(($outline->{$inner_out}->{'opmlvalue'}) && ($outline->{$inner_out}->{'opmlvalue'} eq "embed")) {
      #$return_output .= "<outline>\n";
      #$return_output .= return_embedded($self, $outline);
      #$return_output .= "</outline>\n";
      #next;
    #}
    $return_output .= "<outline ";
    foreach my $atts (sort {$a cmp $b} keys %{$outline->{$inner_out}}) {
      $return_output .= "$atts=\"" . $self->encode($outline->{$inner_out}->{$atts}) . "\" ";
    }
    $return_output .= " />\n";
  }
  return $return_output;
}

sub as_string {
    my $self = shift;
    my $version = ($self->{output} =~ /\d/) ? $self->{output} : $self->{version};
    my $output;
    $output = &as_opml_1_1($self);
    return $output;
}

#sub handle_char {
	# removed assumption that RSS is the default namespace - kellan, 11/5/02

#}

sub handle_dec {
    my ($self,$version,$encoding,$standalone) = (@_);
    $self->{encoding} = $encoding;
    #print "ENCODING: $encoding\n";
}

#sub handle_start {
#    my $self = shift;
#    my $el   = shift;
#    my %attribs = @_;
#}

sub save {
    my ($self,$file) = @_;
    open(OUT,">$file") || croak "Cannot open file $file for write: $!";
    flock(OUT, LOCK_EX);
    print OUT $self->as_string;
    flock(OUT, LOCK_UN);
    close OUT;
}

sub parse {
    my $self = shift;
    $self->_initialize((%$self));
        $self->SUPER::parse(shift);
    $self->_auto_add_modules if $AUTO_ADD;
    $self->{version} = $self->{_internal}->{version};
}
                                                                                
sub parsefile {
    my $self = shift;
        $self->_initialize((%$self));
    $self->SUPER::parsefile(shift);
    $self->_auto_add_modules if $AUTO_ADD;
    $self->{version} = $self->{_internal}->{version};
}

sub strict {
    my ($self,$value) = @_;
    $self->{'strict'} = $value;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) || croak "$self is not an object\n";
    my $name = $AUTOLOAD;
    $name =~ s/.*://;
    return if $name eq 'DESTROY';

    croak "Unregistered entity: Can't access $name field in object of class $type"
		unless (exists $self->{$name});

    # return reference to RSS structure
    if (@_ == 1) {
	return $self->{$name}->{$_[0]} if defined $self->{$name}->{$_[0]};

    # we're going to set values here
    } elsif (@_ > 1) {
	my %hash = @_;
    	# return value
      foreach my $key (keys(%hash)) {
        $self->{$name}->{$key} = $hash{$key};
      }
	return $self->{$name};

    # otherwise, just return a reference to the whole thing
    } else {
	return $self->{$name};
    }
    return 0;

    # make sure we have all required elements
	#foreach my $key (keys(%{$_REQ->{$name}})) {
	    #my $element = $_REQ->{$name}->{$key};
	    #croak "$key is required in $name"
		#if ($element->[0] == 1) && (!defined($hash{$key}));
	    #croak "$key cannot exceed ".$element->[1]." characters in length"
		#unless length($hash{$key}) <= $element->[1];
	#}
}

# the code here is a minorly tweaked version of code from
# Matts' rssmirror.pl script
#
my %entity = (
	      nbsp   => "&#160;",
	      iexcl  => "&#161;",
	      cent   => "&#162;",
	      pound  => "&#163;",
	      curren => "&#164;",
	      yen    => "&#165;",
	      brvbar => "&#166;",
	      sect   => "&#167;",
	      uml    => "&#168;",
	      copy   => "&#169;",
	      ordf   => "&#170;",
	      laquo  => "&#171;",
	      not    => "&#172;",
	      shy    => "&#173;",
	      reg    => "&#174;",
	      macr   => "&#175;",
	      deg    => "&#176;",
	      plusmn => "&#177;",
	      sup2   => "&#178;",
	      sup3   => "&#179;",
	      acute  => "&#180;",
	      micro  => "&#181;",
	      para   => "&#182;",
	      middot => "&#183;",
	      cedil  => "&#184;",
	      sup1   => "&#185;",
	      ordm   => "&#186;",
	      raquo  => "&#187;",
	      frac14 => "&#188;",
	      frac12 => "&#189;",
	      frac34 => "&#190;",
	      iquest => "&#191;",
	      Agrave => "&#192;",
	      Aacute => "&#193;",
	      Acirc  => "&#194;",
	      Atilde => "&#195;",
	      Auml   => "&#196;",
	      Aring  => "&#197;",
	      AElig  => "&#198;",
	      Ccedil => "&#199;",
	      Egrave => "&#200;",
	      Eacute => "&#201;",
	      Ecirc  => "&#202;",
	      Euml   => "&#203;",
	      Igrave => "&#204;",
	      Iacute => "&#205;",
	      Icirc  => "&#206;",
	      Iuml   => "&#207;",
	      ETH    => "&#208;",
	      Ntilde => "&#209;",
	      Ograve => "&#210;",
	      Oacute => "&#211;",
	      Ocirc  => "&#212;",
	      Otilde => "&#213;",
	      Ouml   => "&#214;",
	      times  => "&#215;",
	      Oslash => "&#216;",
	      Ugrave => "&#217;",
	      Uacute => "&#218;",
	      Ucirc  => "&#219;",
	      Uuml   => "&#220;",
	      Yacute => "&#221;",
	      THORN  => "&#222;",
	      szlig  => "&#223;",
	      agrave => "&#224;",
	      aacute => "&#225;",
	      acirc  => "&#226;",
	      atilde => "&#227;",
	      auml   => "&#228;",
	      aring  => "&#229;",
	      aelig  => "&#230;",
	      ccedil => "&#231;",
	      egrave => "&#232;",
	      eacute => "&#233;",
	      ecirc  => "&#234;",
	      euml   => "&#235;",
	      igrave => "&#236;",
	      iacute => "&#237;",
	      icirc  => "&#238;",
	      iuml   => "&#239;",
	      eth    => "&#240;",
	      ntilde => "&#241;",
	      ograve => "&#242;",
	      oacute => "&#243;",
	      ocirc  => "&#244;",
	      otilde => "&#245;",
	      ouml   => "&#246;",
	      divide => "&#247;",
	      oslash => "&#248;",
	      ugrave => "&#249;",
	      uacute => "&#250;",
	      ucirc  => "&#251;",
	      uuml   => "&#252;",
	      yacute => "&#253;",
	      thorn  => "&#254;",
	      yuml   => "&#255;",
	      );

my $entities = join('|', keys %entity);

sub encode {
	my ($self, $text) = @_;
	return $text unless $self->{'encode_output'};
	
	my $encoded_text = '';
	
	while ( $text =~ s/(.*?)(\<\!\[CDATA\[.*?\]\]\>)//s ) {
		$encoded_text .= encode_text($1) . $2;
	}
	$encoded_text .= encode_text($text);

	return $encoded_text;
}

sub encode_text {
	my $text = shift;
	
	$text =~ s/&(?!(#[0-9]+|#x[0-9a-fA-F]+|\w+);)/&amp;/g;
    $text =~ s/&($entities);/$entity{$1}/g;
    $text =~ s/</&lt;/g;

	return $text;
}
1;
__END__

=head1 NAME

XML::OPML - creates and updates OPML (Outline Processor Markup Language) files

=head1 SYNOPSIS

# Create an OPML file

 use XML::OPML;

 my $opml = new XML::OPML(version => "1.1");

 $opml->head(
             title => 'mySubscription',
             dateCreated => 'Mon, 16 Feb 2004 11:35:00 GMT',
             dateModified => 'Mon, 16 Feb 2004 11:35:00 GMT',
             ownerName => 'michael szul',
             ownerEmail => 'michael@madghoul.com',
             expansionState => '',
             vertScrollState => '',
             windowTop => '',
             windowLeft => '',
             windowBottom => '',
             windowRight => '',
           );

 $opml->add_outline(
                 text => 'madghoul.com | the dark night of the soul',
                 description => 'Looking for something strange? Religion, philosophy, and occult science intermingle to form an amalgamation ripe for the counterculture - madghoul.com, keep your nightmares in order with the one site that keeps you up to date on the dark night of the soul.',
                 title => 'madghoul.com | the dark night of the soul',
                 type => 'rss',
                 version => 'RSS',
                 htmlUrl => 'http://www.madghoul.com/ghoul/InsaneRapture/lunacy.mhtml',
                 xmlUrl => 'http://www.madghoul.com/cgi-bin/fearsome/fallout/index.rss10',
               );

 $opml->add_outline(
                 text => 'raelity bytes',
                 descriptions => 'The raelity bytes weblog.',
                 title => 'raelity bytes',
                 type => 'rss',
                 version => 'RSS',
                 htmlUrl => 'http://www.raelity.org',
                 xmlUrl => 'http://www.raelity.org/index.rss10',
               );

# Add one embedded outline

 $opml->add_outline(
                     opmlvalue => 'embed',
                     outline_one => {
                                      text => 'The first embedded outline',
                                    },
                     outline_two => {
                                      text => 'The second embedded outline',
                                    },
                   );

# Save it as a string.
 $opml->as_string();

# Save it to a file.
 $opml->save('mySubscriptions.opml');

# Update the OPML file.
 use XML::OPML;

 my $opml = new XML::OPML;

# Update a file.
 $opml->parsefile('mySubscriptions.opml');

# Update a string ($content is assumed to be an XML formated string).
 $opml->parse($content);

 $opml->add_outline(
                    text => 'Neil Gaiman\'s Journal',
                    description =>'Neil Gaiman\'s Journal',
                    title => 'Neil Gaiman\'s Journal',
                    type => 'rss',
                    version => 'RSS',
                    htmlUrl => 'http://www.neilgaiman.com/journal/journal.asp',
                    xmlUrl => 'http://www.neilgaiman.com/journal/blogger_rss.xml',
                  );

=head1 DESCRIPTION

 This experimental module is designed to allow for easy creation and manipulation of OPML files. OPML files are most commonly used for the sharing of blogrolls or subscriptions - an outlined list of what other blogs and Internet blogger reads. RSS Feed Readers such as AmphetaDesk (http://www.disobey.com/amphetadesk) use *.opml files to store your subscription information for easy access.

 This is purely experimental at this point and has a few bugs and limitations. Most notably: the update feature seems to be wiping out previous outline items and only including the new ones.

 Additionally, this module currently only supports embedded outlines (i.e., outline tags inside of outline tags) to one hierarchy level. Unlimited hierarchy levels are currently under development. You also cannot add attributes to the <outline> element of an embedded hierarchy.

 Rather than reinventing the wheel, this module was modified from the XML::RSS module, so functionality works in a similar way.

=head1 METHODS

=over 4

=item new XML::OPML(version => '1.1')

 This is the constructor. It returns a reference to an XML::OPML object. This will always be version 1.1 for now, so don't worry about it.

=item head(title => '$title', dateCreated => '$cdate', dateModified => '$mdate',ownerName => '$name', ownerEmail => '$email', expansionState => '$es', vertScrollState => '$vs', windowTop => '$wt', windowLeft => '$wl', windowBottom => '$wb',windowRight => '$wr',)

 This method with create all the OPML tags for the <head> subset. For more information on these tags, please see the OPML documentation at http://www.opml.org.

=item add_item(opmlvalue => '$value', %attributes)

 This method adds the <outline> elements to the OPML document(see the example above). There are no statement requirements for the attributes in this tag. The ones shown in the example are the ones most commonly used by RSS Feed Readers, blogrolls, and subscriptions. The opmlvalue element is optional. Only use this with the value 'embed' if you wish to embed another outline with the current outline.

=item as_string

 Returns a string containing the OPML document.

=item save($file)

 Saves the OPML document to $file

=item parse($content)

 Uses XML::Parser to parse the value of the string that is passed to it.

=item parsefile($file)

 Uses XML::Parser to parse the contents of $file.

=back

=head1 SOURCE AVAILABILITY

 Source code is available at the development site at http://opml.madghoul.com. Any contributions or improvements are greatly appreciated.

=head1 AUTHOR

 michael szul <opml-dev@madghoul.com>

=head1 COPYRIGHT

 copyright (c) 2004 michael szul <opml-dev@madghoul.com>

 XML::OPML is free software. It may be redistributed and/or modified under the same terms as Perl.

=head1 CREDITS

 michael szul <opml-dev@madghoul.com>

=head1 SEE ALSO

 perl(1), XML::Parser(3), XML::RSS(3).

=cut

