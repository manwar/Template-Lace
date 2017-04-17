package Template::Lace::Renderer;

use Moo;
use Scalar::Util;

has [qw(model dom components)] => (is=>'ro', required=>1);

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  my $args = $class->$orig(@args);
  $args->{model} = $class->build_model($args);
  return $args;
};

sub build_model {
  my ($class, $args) = @_;
  my $model_class = delete $args->{model_class};
  my $model_attrs = delete $args->{model_attrs};
  my $model = $model_class->new(%{$model_attrs});
  return $model;
}

sub render {
  my $self = shift;
  return $self->get_processed_dom
    ->to_string;
}

sub get_processed_dom {
  my $self = shift;
  my $dom = $self->dom;
  $self->process_components($dom);
  $self->model->process_dom($dom);
  return $dom;
} 

sub process_components {
  my ($self, $dom) = @_;
  my @ordered_keys = @{$self->components->ordered_component_keys};
  my %constructed_components = ();
  foreach my $id(@ordered_keys) {
    next unless $self->components->handlers->{$id}; # might skip if 'static' handler
    next unless my $local_dom = $dom->at("[uuid='$id']");
    my $constructed_component = $self->process_component(
      $local_dom, 
      $self->components->handlers->{$id},
      \%constructed_components,
      %{$self->components->component_info->{$id}});
    $constructed_components{$id} = $constructed_component
      if $constructed_component;
  }
  # Now post process..  We do this so that parents can have access to
  # children for transforming dom.
  foreach my $id(@ordered_keys) {
    next unless $constructed_components{$id};
    my $processed_component = $constructed_components{$id}->get_processed_dom;

    # Move all the scripts, styles and links to the head area
    # TODO this probably doesn't work if the stuff is in a component
    # inside a component.
    $processed_component->find('link:not(head link)')->each(sub {
        $dom->append_link_uniquely($_->attr);
        $_->remove;
    });
    $processed_component->find('style:not(head style)')->each(sub {
        my $content = $_->content || '';
        $dom->append_style_uniquely(%{$_->attr}, content=>$content);
        $_->remove;
    });
    $processed_component->find('script:not(head script)')->each(sub {
        my $content = $_->content || '';
        $dom->append_script_uniquely(%{$_->attr}, content=>$content);
        $_->remove;
    });

    $dom->at("[uuid='$id']")->replace($processed_component);
  }
}

sub process_component {
  my ($self, $dom, $component, $constructed_components, %component_info) = @_;
  my %attrs = ( 
    $self->process_attrs($self->model, $dom, %{$component_info{attrs}}),
    content=>$dom->content,
    model=>$self->model);

  if(my $container_id = $component_info{current_container_id}) {
    # Its possible if the compoent was a 'on_component_add' type that
    # its been removed from the DOM and a Child might still have it as
    # a container by mistake.  Possible a TODO to have a better idea.
    $attrs{container} = $constructed_components->{$container_id}->model
      if $constructed_components->{$container_id};
  }

  if(Scalar::Util::blessed $component) {
    my $constructed_component;
    if($attrs{container}) {
      if($attrs{container}->can('create_child')) {
        $constructed_component = $attrs{container}->create_child($component, %attrs);
      } else {
        $constructed_component = $component->create(%attrs);
        $attrs{container}->add_child($constructed_component) if
          $attrs{container}->can('add_child');
      }
    } else {
      $constructed_component = $component->create(%attrs);
    }
    return $constructed_component;
  } elsif(ref($component) eq 'CODE') {
    die "Component not an object";
    #my $new_dom = $component->($dom->content, %attrs);
    #warn $new_dom;
    #$dom->replace($new_dom);
    #warn $dom;
    #return;
  }
}

sub process_attrs {
  my ($self, $ctx, $dom, %attrs) = @_;
  return map {
    my $proto = $attrs{$_};
    my $value = ref($proto) ? $proto->($ctx, $dom) : $proto;
    $_ => $value;
  } keys %attrs;
}

1;