package Sisimai::MDA;
use feature ':5.10';
use strict;
use warnings;

my $Re0 = {
    'from' => qr/\A(?:Mail Delivery Subsystem|MAILER-DAEMON|postmaster)/i,
};
my $Re1 = {
    # dovecot/src/deliver/deliver.c
    # 11: #define DEFAULT_MAIL_REJECTION_HUMAN_REASON \
    # 12: "Your message to <%t> was automatically rejected:%n%r"
    'dovecot'    => qr/\AYour message to .+ was automatically rejected:\z/,
    'mail.local' => qr/\Amail[.]local: /,
    'procmail'   => qr/\Aprocmail: /,
    'maildrop'   => qr/\Amaildrop: /,
    'vpopmail'   => qr/\Avdelivermail: /,
    'vmailmgr'   => qr/\Avdeliver: /,
};

# dovecot/src/deliver/mail-send.c:94
my $ReFailure = {
    'dovecot' => {
        'userunknown' => [
            qr/\AMailbox doesn't exist: /i,
        ],
        'mailboxfull' => [
            qr/\AQuota exceeded/,   # Dovecot 1.2 dovecot/src/plugins/quota/quota.c
            qr/\AQuota exceeded [(]mailbox for user is full[)]\z/i,  # dovecot/src/plugins/quota/quota.c
            qr/\ANot enough disk space\z/i,
        ],
    },
    'mail.local' => {
        'userunknown' => [
            qr/: unknown user/i,
            qr/: User unknown/i,
            qr/: Invalid mailbox path/i,
            qr/: User missing home directory/i,
        ],
        'mailboxfull' => [
            qr/Disc quota exceeded\z/i,
            qr/Mailbox full or quota exceeded/i,
        ],
        'systemerror' => [
            qr/Temporary file write error/i,
        ],
    },
    'procmail' => {
        'mailboxfull' => [
            qr/Quota exceeded while writing/i,
        ],
        'systemfull' => [
            qr/No space left to finish writing/i,
        ],
    },
    'maildrop' => {
        'userunknown' => [
            qr/Invalid user specified[.]\z/i,
            qr/Cannot find system user/i,
        ],
        'mailboxfull' => [
            qr/maildir over quota[.]\z/i,
        ],
    },
    'vpopmail' => {
        'userunknown' => [
            qr/Sorry, no mailbox here by that name[.]/i,
        ],
        'filtered' => [
            qr/account is locked email bounced/,
            qr/user does not exist, but will deliver to /i,
        ],
        'mailboxfull' => [
            qr/(?:domain|user) is over quota/i,
        ],
    },
    'vmailmgr' => {
        'userunknown' => [
            qr/Invalid or unknown base user or domain/i,
            qr/Invalid or unknown virtual user/i,
            qr/User name does not refer to a virtual user/i,
        ],
        'mailboxfull' => [
            qr/Delivery failed due to system quota violation/i,
        ],
    },
};

sub scan { 
    # Parse message body and return reason and text
    # @param         [Hash] mhead       Message header of a bounce email
    # @options mhead [String] from      From header
    # @options mhead [String] date      Date header
    # @options mhead [String] subject   Subject header
    # @options mhead [Array]  received  Received headers
    # @options mhead [String] others    Other required headers
    # @param         [String] mbody     Message body of a bounce email
    # @return        [Hash, Undef]      Bounce data list and message/rfc822 part
    #                                   or Undef if it failed to parse or the
    #                                   arguments are missing
    my $class = shift;
    my $mhead = shift // return undef;
    my $mbody = shift // return undef;

    return undef unless ref( $mhead ) eq 'HASH';
    return undef unless $mhead->{'from'} =~ $Re0->{'from'};
    return undef unless ref( $mbody ) eq 'SCALAR';
    return undef unless length $$mbody;

    my $agentname0 = '';    # [String] MDA name
    my $reasonname = '';    # [String] Error reason
    my $bouncemesg = '';    # [String] Error message
    my @hasdivided = split( "\n", $$mbody );
    my @linebuffer = ();

    for my $e ( keys %$Re1 ) {
        # Detect MDA from error string in the message body.
        @linebuffer = ();
        for my $f ( @hasdivided ) {
            # Check each line with each MDA's symbol regular expression.
            next if( $agentname0 eq '' && $f !~ $Re1->{ $e } );
            $agentname0 ||= $e;
            push @linebuffer, $f;
            last unless length $f;
        }

        last if $agentname0;
    }

    return undef unless $agentname0;
    return undef unless scalar @linebuffer;

    for my $e ( keys %{ $ReFailure->{ $agentname0 } } ) {
        # Detect an error reason from message patterns of the MDA.
        for my $f ( @linebuffer ) {

            next unless grep { $f =~ $_ } @{ $ReFailure->{ $agentname0 }->{ $e } };
            $reasonname = $e;
            $bouncemesg = $f;
            last;
        }
        last if $bouncemesg && $reasonname;
    }

    return { 
        'mda'     => $agentname0, 
        'reason'  => $reasonname // '', 
        'message' => $bouncemesg // '',
    };
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::MDA - Error message parser for MDA

=head1 SYNOPSIS

    use Sisimai::MDA;
    my $header = { 'from' => 'mailer-daemon@example.jp' };
    my $string = 'mail.local: Disc quota exceeded';
    my $return = Sisimai::MDA->scan( $header, \$string );

=head1 DESCRIPTION

Sisimai::MDA parse bounced email which created by some MDA, such as C<dovecot>,
C<mail.local>, C<procmail>, and so on. 
This class is called from Sisimai::Message only.

=head1 CLASS METHODS

=head2 C<B<scan( I<Header>, I<Reference to message body> )>>

C<scan()> is a parser for detecting an error from mail delivery agent.

    my $header = { 'from' => 'mailer-daemon@example.jp' };
    my $string = 'mail.local: Disc quota exceeded';
    my $return = Sisimai::MDA->scan( $header, \$string );
    warn Dumper $return;
    $VAR1 = {
        'mda' => 'mail.local',
        'reason' => 'mailboxfull',
        'message' => 'mail.local: Disc quota exceeded'
    }

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2015 azumakuniyuki E<lt>perl.org@azumakuniyuki.orgE<gt>,
All Rights Reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut
