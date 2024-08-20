package Catmandu::Serializer::json_string;

use Catmandu::Sane;
use JSON qw();
use Moo;

has json => (
    is       => "ro",
    lazy     => 1,
    init_arg => undef,
    default  => sub {JSON->new()->utf8(0);}
);

sub serialize {
    $_[0]->json()->encode($_[1]);
}

sub deserialize {
    $_[0]->json()->decode($_[1]);
}

1;

__END__

=pod

=head1 NAME

Catmandu::Serializer - A (de)serializer from and to json strings

=head1 DESCRIPTION

    The use case for this serializer is the following:

    * The default serializer 'json' for column 'data' returns a binary utf-8 string
      and this binary string is sent over the wire as is to a binary column 'data' (e.g "bytea" in postgres).
      This binary data however is not "visible" (shown as base64 data) however from the database itself.
      This is especially weird if your column contains json data that is perfectly representable
      from within a database like mysql or postgres.

    * You can however set the type of the column "data" to "json", in which case, for postgres, an underlying
      column of type "jsonb" (or "json" in older versions that postgres 10) is made. But json(b) fields
      are seen by postgres clients as text fields, and therefore utf-8 conversion from string to binary will be
      applied (client option "pg_utf8_strings" in DBI), even though that has happened already, leading to double
      encodings.

    * To circumvent that double encoding this serializer creates a non binary json string.
      Please only use this serializer for that purpose

=head1 SEE ALSO

L<Catmandu::Serializer>

=cut
