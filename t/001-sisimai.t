use strict;
use Test::More;
use lib qw(./lib ./blib/lib);
use Sisimai;
use JSON;

my $PackageName = 'Sisimai';
my $MethodNames = {
    'class' => [ 'sysname', 'libname', 'version', 'make', 'dump' ],
    'object' => [],
};
my $SampleEmail = {
    'mailbox' => './set-of-emails/mailbox/mbox-0',
    'maildir' => './set-of-emails/maildir/bsd',
};
my $IsNotBounce = {
    'maildir' => './set-of-emails/maildir/not',
};

use_ok $PackageName;
can_ok $PackageName, @{ $MethodNames->{'class'} };

MAKE_TEST: {

    is $PackageName->sysname, 'bouncehammer', '->sysname = bouncehammer';
    is $PackageName->libname, $PackageName, '->libname = '.$PackageName;
    is $PackageName->version, $Sisimai::VERSION, '->version = '.$Sisimai::VERSION;
    is $PackageName->make(undef), undef;
    is $PackageName->dump(undef), undef;

    for my $e ( 'mailbox', 'maildir' ) {

        MAKE: {
            my $v = $PackageName->make( $SampleEmail->{ $e } );
            isa_ok $v, 'ARRAY';
            ok scalar @$v, 'entries = '.scalar @$v;

            for my $r ( @$v ) {
                isa_ok $r, 'Sisimai::Data';
                isa_ok $r->timestamp, 'Sisimai::Time';
                isa_ok $r->addresser, 'Sisimai::Address';
                isa_ok $r->recipient, 'Sisimai::Address';
                ok $r->addresser->address, '->addresser = '.$r->addresser->address;
                ok $r->recipient->address, '->recipient = '.$r->recipient->address;
                ok length $r->reason, '->reason = '.$r->reason;
                ok defined $r->replycode, '->replycode = '.$r->replycode;

                my $h = $r->damn;
                isa_ok $h, 'HASH';
                ok scalar keys %$h;
                is $h->{'recipient'}, $r->recipient->address, '->recipient = '.$h->{'recipient'};
                is $h->{'addresser'}, $r->addresser->address, '->addresser = '.$h->{'addresser'};

                for my $p ( keys %$h ) {
                    next if ref $r->$p;
                    next if $p eq 'subject';
                    is $h->{ $p }, $r->$p, '->'.$p.' = '.$h->{ $p };
                }

                my $j = $r->dump('json');
                ok length $j, 'length( dump("json") ) = '.length $j;
            }
        }

        DUMP: {
            my $j = $PackageName->dump( $SampleEmail->{ $e } );
            ok length $j;
            utf8::encode $j if utf8::is_utf8 $j;

            my $v = JSON::decode_json( $j );
            my $k = [ qw|
                addresser recipient senderdomain destination reason timestamp 
                token smtpagent|
            ];

            isa_ok $v, 'ARRAY';
            for my $p ( @$v ) {
                isa_ok $p, 'HASH';
                for my $x ( @$k ) {
                    ok $p->{ $x }, $x.' = '.$p->{ $x };
                }
            }
        }
    }

    for my $e ( 'maildir' ) {
        my $v = $PackageName->make( $IsNotBounce->{ $e } );
        is $v, undef;

        $v = $PackageName->dump( $IsNotBounce->{ $e } );
        is $v, '[]';
    }

}

done_testing;
