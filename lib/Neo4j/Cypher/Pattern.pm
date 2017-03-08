package Neo4j::Cypher::Pattern;
#use JSON;
use strict;
use warnings;

=head1 SYNOPSIS

# express a cypher pattern

node("varname", labels=>["label1"], props=>{"propname"=>"propval"})->
  related_to("<typename", props=>{"propname"=>"propval"})->
  node();

node();
N();
node("varname");
node("varname",["label"],{prop => "value"});
node("varname:label");
node(["label"],{prop => "value"});

related_to();
R();
related_to("varname","typename",[minhops,maxhops],{prop => "value"});
related_to("varname:typename");
related_to(":typename");
related_to("", "typename");

path("varname", $pattern); # path variable assigned to a pattern
P();
compound($pattern1, $pattern2); # comma separated patterns
C();

=cut

sub new {
  my $class = shift;
  my $self = {};
  $self->{stmt}=[];
  bless $self, $class;
}

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
    ($varname, $type) = split /:/,$varname;
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
  $str = "-[$str]-";
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

sub R {shift->related_to(@_);}

sub path {
  my $self = shift;
  return $self;
}

sub compound {
  my $self = shift;
  return $self;
}

sub clear { shift->{stmt}=[],1; }

sub as_string {
  my $self = shift;
  return join('',@{$self->{stmt}});
}

sub pop { pop @{shift->{stmt}}; }

1;
