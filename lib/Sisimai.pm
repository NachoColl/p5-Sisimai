package Sisimai;
use feature ':5.10';
use strict;
use warnings;
use Module::Load '';

our $VERSION = '4.18.2';
sub version { return $VERSION }
sub sysname { 'bouncehammer'  }
sub libname { 'Sisimai'       }

sub make {
    # Wrapper method for parsing mailbox or Maildir/
    # @param         [String] argv0      Path to mbox or Maildir/
    # @param         [Hash]   argv1      Parser options
    # @options argv1 [Integer] delivered 1 = Including "delivered" reason
    # @return        [Array]             Parsed objects
    # @return        [Undef]             Undef if the argument was wrong or an empty array
    my $class = shift;
    my $argv0 = shift // return undef;

    die ' ***error: wrong number of arguments' if scalar @_ % 2;
    my $argv1 = { @_ };

    require Sisimai::Mail;
    my $mail = Sisimai::Mail->new($argv0);
    my $mesg = undef;
    my $data = undef;
    my $list = [];
    my $opts = { 'delivered' => $argv1->{'delivered'} // 0 };

    return undef unless $mail;
    require Sisimai::Data;
    require Sisimai::Message;

    while( my $r = $mail->read ) {
        # Read and parse each mail file
        $mesg = Sisimai::Message->new('data' => $r);
        next unless defined $mesg;
        $data = Sisimai::Data->make('data' => $mesg, %$opts);
        push @$list, @$data if scalar @$data;
    }

    return undef unless scalar @$list;
    return $list;
}

sub dump {
    # Wrapper method to parse mailbox/Maildir and dump as JSON
    # @param         [String]  argv0     Path to mbox or Maildir/
    # @param         [Hash]    argv1     Parser options
    # @options argv1 [Integer] delivered 1 = Including "delivered" reason
    # @return        [String]            Parsed data as JSON text
    my $class = shift;
    my $argv0 = shift // return undef;

    die ' ***error: wrong number of arguments' if scalar @_ % 2;
    my $argv1 = { @_ };
    my $nyaan = __PACKAGE__->make($argv0, %$argv1) // [];

    # Dump as JSON
    Module::Load::load('JSON', '-convert_blessed_universally');
    my $jsonobject = JSON->new->allow_blessed->convert_blessed;
    my $jsonstring = $jsonobject->encode($nyaan);

    utf8::encode $jsonstring if utf8::is_utf8 $jsonstring;
    return $jsonstring;
}

sub engine {
    # Parser engine list (MTA/MSP modules)
    # @return   [Hash]     Parser engine table
    my $class = shift;
    my $names = ['MTA', 'MSP', 'ARF', 'RFC3464', 'RFC3834'];
    my $table = {};

    for my $e ( @$names ) {
        my $r = 'Sisimai::'.$e;
        Module::Load::load $r;

        if( $e eq 'MTA' || $e eq 'MSP' ) {
            # Sisimai::MTA or Sisimai::MSP
            for my $ee ( @{ $r->index } ) {
                # Load and get the value of "description" from each module
                my $rr = sprintf("Sisimai::%s::%s", $e, $ee);
                Module::Load::load $rr;
                $table->{ $rr } = $rr->description;
            }
        } else {
            # Sisimai::ARF, Sisimai::RFC3464, and Sisimai::RFC3834
            $table->{ $r } = $r->description;
        }
    }
    return $table;
}

sub reason {
    # Reason list Sisimai can detect
    # @return   [Hash]     Reason list table
    my $class = shift;
    my $names = [];
    my $table = {};

    require Sisimai::Reason;
    $names = Sisimai::Reason->index;

    # These reasons are not included in the results of Sisimai::Reason->index
    push @$names, ('Delivered', 'Feedback', 'Undefined', 'Vacation');

    for my $e ( @$names ) {
        # Call ->description() method of Sisimai::Reason::*
        my $r = 'Sisimai::Reason::'.$e;
        Module::Load::load $r;
        $table->{ $e } = $r->description;
    }
    return $table;
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai - Mail Analyzing Interface for bounce mails.

=head1 SYNOPSIS

    use Sisimai;

=head1 DESCRIPTION

Sisimai is the system formerly known as C<bounceHammer> 4, is a Pelr module for
analyzing bounce mails and generate structured data in a JSON format (YAML is 
also available if "YAML" module is installed on your system) from parsed bounce
messages. C<Sisimai> is a coined word: Sisi (the number 4 is pronounced "Si" in
Japanese) and MAI (acronym of "Mail Analyzing Interface").

=head1 BASIC USAGE

=head2 C<B<make(I<'/path/to/mbox'>, I<delivered => 1>)>>

C<make> method provides feature for getting parsed data from bounced email 
messages like following.

    use Sisimai;
    my $v = Sisimai->make('/path/to/mbox'); # or Path to Maildir

    if( defined $v ) {
        for my $e ( @$v ) {
            print ref $e;                   # Sisimai::Data
            print ref $e->recipient;        # Sisimai::Address
            print ref $e->timestamp;        # Sisimai::Time

            print $e->addresser->address;   # shironeko@example.org # From
            print $e->recipient->address;   # kijitora@example.jp   # To
            print $e->recipient->host;      # example.jp
            print $e->deliverystatus;       # 5.1.1
            print $e->replycode;            # 550
            print $e->reason;               # userunknown

            my $h = $e->damn;               # Convert to HASH reference
            my $j = $e->dump('json');       # Convert to JSON string
            my $y = $e->dump('yaml');       # Convert to YAML string
        }

        # Dump entire list as a JSON 
        use JSON '-convert_blessed_universally';
        my $json = JSON->new->allow_blessed->convert_blessed;

        printf "%s\n", $json->encode($v);
    }

If you want to get bounce records which reason is "delivered", set "delivered"
option to make() method like the following:

    my $v = Sisimai->make('/path/to/mbox', 'delivered' => 1);

=head2 C<B<dump(I<'/path/to/mbox'>, I<delivered => 1>)>>

C<dump> method provides feature to get parsed data from bounced email as JSON.

    use Sisimai;
    my $v = Sisimai->dump('/path/to/mbox'); # or Path to Maildir
    print $v;                               # JSON string

=head2 Read email data from STDIN

If you want to pass email data from STDIN, specify B<STDIN> at the first argument
of dump() and make() method like following command:

    % cat ./path/to/bounce.eml | perl -MSisimai -lE 'print Sisimai->dump(STDIN)'

=head2 C<B<engine()>>

C<engine> method provides table including parser engine list and its description.

    use Sisimai;
    my $v = Sisimai->engine();
    for my $e ( keys %$v ) {
        print $e;           # Sisimai::MTA::Sendmail
        print $v->{ $e };   # V8Sendmail: /usr/sbin/sendmail
    }

=head2 C<B<reason()>>

C<reason> method provides table including all the reasons Sisimai can detect

    use Sisimai;
    my $v = Sisimai->reason();
    for my $e ( keys %$v ) {
        print $e;           # Blocked
        print $v->{ $e };   # 'Email rejected due to client IP address or a hostname'
    }

=head1 SEE ALSO

=over

=item L<Sisimai::Mail> - Mailbox or Maildir object

=item L<Sisimai::Data> - Parsed data object

=item L<http://libsisimai.org/> - Sisimai — A successor to bounceHammer, Library to parse error mails

=item L<https://tools.ietf.org/html/rfc3463> - RFC3463: Enhanced Mail System Status Codes

=item L<https://tools.ietf.org/html/rfc3464> - RFC3464: An Extensible Message Format for Delivery Status Notifications

=item L<https://tools.ietf.org/html/rfc5321> - RFC5321: Simple Mail Transfer Protocol

=item L<https://tools.ietf.org/html/rfc5322> - RFC5322: Internet Message Format

=back

=head1 REPOSITORY

L<https://github.com/sisimai/p5-Sisimai> - Sisimai on GitHub

=head1 WEB SITE

L<http://libsisimai.org/> - A successor to bounceHammer, Library to parse error mails.

L<https://github.com/sisimai/rb-Sisimai> - Ruby version of Sisimai

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2016 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut
