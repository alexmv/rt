use strict;
use warnings;

package RT::Action::ConfigSystem;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer; 

# TODO XXX
# section support
# doc support

sub arguments {
    my $self = shift;
    return $self->{__cached_arguments} if ( $self->{__cached_arguments} );
    my $args = { };

    my $configs = RT::Model::ConfigCollection->new;
    $configs->unlimit;
    while ( my $config = $configs->next ) {
        $args->{ $config->name } = {
            default_value => defer {
                my $value = $config->value;
                $value = ''
                  if defined $value && $value eq $config->_empty_string;
                if ( ref $value eq 'ARRAY' ) {
                    return '[' . join( ', ', @$value ) . ']';
                }
                elsif ( ref $value eq 'HASH' ) {
                    my $str = '{';
                    for my $key ( keys %$value ) {
                        $str .= qq{$key => $value->{$key},};
                    }
                    $str .= '}';
                    return $str;
                }
                else {
                    return $value;
                }
            }
        };
    }
    return $self->{__cached_arguments} = $args;
}

sub meta {
    my $self = shift;
    return $self->{__cached_meta} if ( $self->{__cached_meta} );
    my $meta = {};
    require Pod::POM;
    my $parser = Pod::POM->new;
    my $pom    = $parser->parse_file( $RT::BASE_PATH . '/lib/RT/Config.pm' )
      or die $parser->error;
    require Pod::POM::View::HTML;
    require Pod::POM::View::Text;
    my $html_view = 'Pod::POM::View::HTML';
    my $text_view = 'Pod::POM::View::Text';

    for my $section ( $pom->head1 ) {
        my $over = $section->over->[0];
        for my $item ( $over->item ) {
            my $title = $item->title;
            my @items = split /\s*,\s*/, $title;
            @items = map { s/C<(\w+)>/$1/; $_ } @items;
            for (@items) {
                $meta->{$_} = {
                    doc     => $item->content->present($html_view),
                    section => $section->title->present($html_view),
                };
            }
        }
    }
    return $self->{__cached_meta} = $meta;
}

sub arguments_by_sections {
    my $self = shift;
    my $args = $self->arguments;
    my $meta = $self->meta;
    my $return;
    for my $name ( keys %$args ) {
        $return->{$meta->{$name} && $meta->{$name}{section} ||
            'Others'}{$name}++;
    }
    return $return;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

            Jifty->log->error( 'ok' );
    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            my $value = $self->argument_value( $arg );
            if ( $value =~ /^\[\s*(.*)\s*$\]/ ) {
                $value = [ split /\s*,\s*/, $1 ];
            }
            elsif ( $value =~ /^{\s*(.*)\s*$}/ ) {
                $value = { split /\s*(?:,|=>)\s*/, $1 };
            }

            RT->config->set( $arg, $value );
        }
    }

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;

