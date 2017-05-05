package Neo4j::Cypher::Pattern;
use base Exporter;
use Carp;
use strict;
use warnings;
use overload '""' => 'as_string';

=head1 NAME

Neo4j::Cypher::Pattern - Generate Cypher pattern strings

=head1 SYNOPSIS

# express a cypher pattern

 node();
 N(); #alias
 node("varname");
 node("varname",["label"],{prop => "value"});
 node("varname:label");
 node(["label"],{prop => "value"});

 related_to();
 R(); # alias
 related_to("varname","typename",[minhops,maxhops],{prop => "value"});
 related_to("varname:typename");
 related_to(":typename");
 related_to("", "typename");
 # directed relns
 R("<:typename");
 R("varname:typename>");

 # these return strings
 $pattern->path('varname'); # path variable assigned to a pattern
 $pattern->as('varname'); # alias
 pattern->compound($pattern1, $pattern2); # comma separated patterns
 pattern->C($pattern1, $pattern2); # alias

=cut

our @EXPORT_OK = qw/pattern ptn/;

sub puke(@);
sub belch(@);

sub new {
  my $class = shift;
  my $self = {};
  $self->{stmt}=[];
  bless $self, $class;
}

sub pattern {
  Neo4j::Cypher::Pattern->new;
}

sub ptn { Neo4j::Cypher::Pattern->new; }

sub path {
  my $self = shift;
  puke("Need arg1 => identifier") if (!defined $_[0] || ref($_[0]));
  return "$_[0] = $self";
}

# alias for path
sub as { shift->path(@_) }

sub node {
  # args:
  # scalar string = varname
  # array ref - array of labels
  # hash ref - hash of props/values
  my $self = shift;
  unless (@_) {
    push @{$self->{stmt}}, '()';
    return $self;
  }
  my ($varname) = grep { !ref } @_;
  my ($lbls) = grep { ref eq 'ARRAY' } @_;
  my ($props) = grep { ref eq 'HASH' } @_;
  # look for labels
  my @l;
  ($varname, @l) = split /:/, $varname;
  if (@l) {
    $lbls //= [];
    push @$lbls, @l;
  }
  my $str = $lbls ? join(':',$varname, @$lbls) : $varname;
  if ($props) {
    my $p;
    while (my($k,$v) = each %$props) {
      # escape single quotes
      $v =~ s/'/\\'/g;
      push @$p, "$k:'$v'";
    }
    $p = join(',',@$p);
    $str .= " {$p}";
  }
  push @{$self->{stmt}}, "($str)";
  return $self;
}

sub N {shift->node(@_);}

sub related_to {
  my $self = shift;
  unless (@_) {
    push @{$self->{stmt}}, '--';
    return $self;
  }
  my ($hops) = grep { ref eq 'ARRAY' } @_;
  my ($props) = grep { ref eq 'HASH' } @_;
  my ($varname,$type) = grep { !ref } @_;
  if ($type) {
    ($varname) = split /:/,$varname;
  } else {
    ($varname, $type) = $varname =~ /([^:]+):?(.*)/;
  }
  my $dir;
  if ($varname) {
    $varname =~ s/^(<|>)//;
    $dir = $1;
    $varname =~ s/(<|>)$//;
    $dir = $1;
  }
  unless ($dir) {
    if ($type) {
      $type =~ s/^(<|>)//;
      $dir = $1;
      $type =~ s/(<|>)$//;
      $dir = $1;
    }
  }
  my $str = $varname.($type ? ":$type" : "");

  if ($hops) {
    if (@$hops == 0) {
      $str.="*";
    }
    elsif (@$hops==1) {
      $str .= "*$$hops[0]";
    }
    else {
      $str .= "*$$hops[0]..$$hops[1]"
    }
  }
  if ($props) {
    my $p;
    while (my($k,$v) = each %$props) {
      # escape single quotes
      $v =~ s/'/\\'/g;
      push @$p, "$k:'$v'";
    }
    $p = join(',',@$p);
    $str .= " {$p}";
  }
  $str = ($str ? "-[$str]-" : '--');
  $str =~ s/\[ \{/[{/;
  if ($dir) {
    if ($dir eq "<") {
      $str = "<$str";
    }
    elsif ($dir eq ">") {
      $str = "$str>";
    }
    else {
      1; # huh?
    }
  }
  push @{$self->{stmt}}, $str;
  return $self;
}

sub R {shift->related_to(@_)}

# N('a')->toN('b') -> (a)-->(b)
# N('a')->fromN('b') -> (a)<--(b)
sub _N {shift->related_to->node(@_)}
sub to_N {shift->related_to('>')->node(@_)}
sub from_N {shift->related_to('<')->node(@_)}

  
  
# 'class' method
# do pattern->C($pat1, $pat2)
sub compound {
  my $self = shift;
  return join(',',@_);
}

sub C {shift->compound(@_)}

sub clear { shift->{stmt}=[],1; }

sub as_string {
  my $self = shift;
  return join('',@{$self->{stmt}});
}

sub pop { pop @{shift->{stmt}}; }

sub belch (@) {
  my($func) = (caller(1))[3];
  Carp::carp "[$func] Warning: ", @_;
}

sub puke (@) {
  my($func) = (caller(1))[3];
  Carp::croak "[$func] Fatal: ", @_;
}

1;
