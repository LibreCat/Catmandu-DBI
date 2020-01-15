package Catmandu::Serializer::json_string;

use Catmandu::Sane;
use JSON qw();
use Moo;

has json => (
    is => "ro",
    lazy => 1,
    init_arg => undef,
    default => sub { JSON->new()->utf8(0); }
);

sub serialize {
    $_[0]->json()->encode( $_[1] );
}

sub deserialize {
    $_[0]->json()->decode( $_[1] );
}

1;

__END__

=pod

=head1 NAME

Catmandu::Serializer - A (de)serializer from and to json strings

=head1 DESCRIPTION

    serializer 'json' returns a binary utf-8 string,
    which only makes sense if you  send your data to column of type 'binary'

    use this serializer if your data column is a text field or a subtype of text
    (like json or jsonb in postgres)

=head1 SEE ALSO

L<Catmandu::Serializer>

=cut
