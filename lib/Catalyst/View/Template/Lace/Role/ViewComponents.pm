package Catalyst::View::Template::Lace::Role::ViewComponents;

use Moo::Role;

around 'setup_component_info', sub {
  my ($orig, $class, @args) = @_;
  my %info = $class->$orig(@args);
  $info{view} = $class->setup_view_name($info{name})
    if $info{prefix} eq $class->view_prefix;
  return %info;
};

sub setup_view_name {
  my ($class, $name) = @_;
  return join '::', map { ucfirst $_ } split('-', $name);
}

sub view_prefix { 'view' }

around 'prepare_component_handlers', sub {
  my ($orig, $class, @args) = @_;
  my $handlers = $class->$orig(@args);
  $handlers->{view} = sub {
    my ($self, $dom, $component_info, %attrs) = @_;
    $dom->overlay(sub {
      return $self->view($component_info->{view}, %attrs, content=>$_)
        ->get_processed_dom;
    });
  };
  return $handlers;
};

around 'get_component_prefixes', sub {
  my ($orig, $class, @args) = @_;
  my @prefixes = $class->$orig(@args);
  return 'view', @prefixes;
};

1;


=head1 NAME

Catalyst::View::Template::Lace::Role::ViewComponents - Component factory for Views.

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

    TBD

=head1 SEE ALSO
 
L<Catalyst::View::Template::Lace>.

=head1 AUTHOR

Please See L<Catalyst::View::Template::Lace> for authorship and contributor information.
  
=head1 COPYRIGHT & LICENSE
 
Please see L<Catalyst::View::Template::Lace> for copyright and license information.

=cut
