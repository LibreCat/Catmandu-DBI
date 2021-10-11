use strict;
use warnings;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Serializer::json_string';
    use_ok $pkg;
}

require_ok $pkg;

my $serializer;

lives_ok(
    sub {
        $serializer = $pkg->new();
    }
);

{
    my $data = {title => "café"};

    lives_ok(
        sub {
            $data = $serializer->serialize({title => "café"});
        }
    );

    is($data, qq({"title":"café"}));

    ok(utf8::is_utf8($data));
}

{

    my $data = qq({"title":"café"});

    lives_ok(
        sub {
            $data = $serializer->deserialize($data);
        }
    );

    is_deeply($data, {title => "café"});

}

done_testing;
