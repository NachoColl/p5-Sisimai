package Sisimai::Reason::NoRelaying;
use feature ':5.10';
use strict;
use warnings;

sub text  { 'norelaying' }
sub description { 'Email rejected with error message "Relaying Denied"' }
sub match {
    # Try to match that the given text and regular expressions
    # @param    [String] argv1  String to be matched with regular expressions
    # @return   [Integer]       0: Did not match
    #                           1: Matched
    # @since v4.0.0
    my $class = shift;
    my $argv1 = shift // return undef;
    my $regex = qr{(?> 
         Insecure[ ]Mail[ ]Relay
        |mail[ ]server[ ]requires[ ]authentication[ ]when[ ]attempting[ ]to[ ]
            send[ ]to[ ]a[ ]non-local[ ]e-mail[ ]address    # MailEnable 
        |not[ ]allowed[ ]to[ ]relay[ ]through[ ]this[ ]machine
        |Not[ ]an[ ]open[ ]relay,[ ]so[ ]get[ ]lost
        |relay[ ](?:
             access[ ]denied
            |denied
            |not[ ]permitted
            )
        |relaying[ ]denied  # Sendmail
        |that[ ]domain[ ]isn[']t[ ]in[ ]my[ ]list[ ]of[ ]allowed[ ]rcpthost
        |Unable[ ]to[ ]relay[ ]for
        )
    }ix;

    return 1 if $argv1 =~ $regex;
    return 0;
}

sub true {
    # Whether the message is rejected by 'Relaying denied'
    # @param    [Sisimai::Data] argvs   Object to be detected the reason
    # @return   [Integer]               1: Rejected for "relaying denied"
    #                                   0: is not 
    # @since v4.0.0
    # @see http://www.ietf.org/rfc/rfc2822.txt
    my $class = shift;
    my $argvs = shift // return undef;

    return undef unless ref $argvs eq 'Sisimai::Data';
    my $currreason = $argvs->reason // '';
    my $reexcludes = qr/\A(?:securityerror|systemerror|undefined)\z/;

    if( $currreason ) {
        # Do not overwrite the reason
        return 0 if $currreason =~ $reexcludes;

    } else {
        # Check the value of Diagnosic-Code: header with patterns
        return 1 if __PACKAGE__->match( $argvs->diagnosticcode );
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Reason::NoRelaying - Bounce reason is C<norelaying> or not.

=head1 SYNOPSIS

    use Sisimai::Reason::NoRelaying;
    print Sisimai::Reason::NoRelaying->match('Relaying denied');   # 1

=head1 DESCRIPTION

Sisimai::Reason::NoRelaying checks the bounce reason is C<norelaying> or not.
This class is called only Sisimai::Reason class.

This is the error that SMTP connection rejected with error message 
C<Relaying Denied>. This reason does not exist in any version of bounceHammer.

    ... while talking to mailin-01.mx.example.com.:
    >>> RCPT To:<kijitora@example.org>
    <<< 554 5.7.1 <kijitora@example.org>: Relay access denied
    554 5.0.0 Service unavailable

=head1 CLASS METHODS

=head2 C<B<text()>>

C<text()> returns string: C<norelaying>.

    print Sisimai::Reason::NoRelaying->text;  # norelaying

=head2 C<B<match( I<string> )>>

C<match()> returns 1 if the argument matched with patterns defined in this class.

    print Sisimai::Reason::NoRelaying->match('Relaying denied');   # 1

=head2 C<B<true( I<Sisimai::Data> )>>

C<true()> returns 1 if the bounce reason is C<norelaying>. The argument must be
Sisimai::Data object and this method is called only from Sisimai::Reason class.

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2016 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut
