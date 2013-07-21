package Mojolicious::Plugin::Mail;
use Mojo::Base 'Mojolicious::Plugin';

use MIME::Lite;
use MIME::EncWords ();
use Mojo::ByteStream 'b';

use constant TEST     => $ENV{MOJO_MAIL_TEST} || 0;
use constant FROM     => 'test-mail-plugin@mojolicio.us';
use constant CHARSET  => 'UTF-8';
use constant ENCODING => 'base64';

our $VERSION = '1.0';

has conf => sub { +{} };

sub register {
	my ($plugin, $app, $conf) = @_;
	
	# default values
	$conf->{from    } ||= FROM;
	$conf->{charset } ||= CHARSET;
	$conf->{encoding} ||= ENCODING;
	
	$plugin->conf( $conf ) if $conf;
	
	$app->helper(
		mail => sub {
			my $self = shift;
			my $args = @_ ? { @_ } : return;
			
			# simple interface
			unless (exists $args->{mail}) {
				$args->{mail}->{ $_->[1] } = delete $args->{ $_->[0] }
					for grep $args->{ $_->[0] },
						[to   => 'To'  ], [from => 'From'], [reply_to => 'Reply-To'],
						[cc   => 'Cc'  ], [bcc  => 'Bcc' ], [subject  => 'Subject' ],
						[data => 'Data'], [type => 'Type'],
				;
			}
			
			# hidden data and subject
			
			my @stash =
				map  { $_ => $args->{$_} }
				grep { !/^(to|from|reply_to|cc|bcc|subject|data|type|test|mail|attach|headers|attr|charset|mimeword|nomailer)$/ }
				keys %$args
			;
			
			$args->{mail}->{Data   } ||= $self->render_mail(@stash);
			$args->{mail}->{Subject} ||= $self->stash ('subject');
			
			my $msg  = $plugin->build( %$args );
			my $test = $args->{test} || TEST;
			$msg->send( $conf->{'how'}, @{$conf->{'howargs'}||[]} ) unless $test;
			
			$msg->as_string;
		},
	);
	
	$app->helper(
		render_mail => sub {
			my $self = shift;
			my $data = $self->render(@_, format => 'mail', partial => 1);
			
			delete @{$self->stash}{ qw(partial cb format mojo.captures mojo.started mojo.content mojo.routed) };
			$data;
		},
	);
}

sub build {
	my $self = shift;
	my $conf = $self->conf;
	my $p    = { @_ };
	
	my $mail     = $p->{mail};
	my $charset  = $p->{charset } || $conf->{charset };
	my $encoding = $p->{encoding} || $conf->{encoding};
	my $encode   = $encoding eq 'base64' ? 'B' : 'Q';
	my $mimeword = defined $p->{mimeword} ? $p->{mimeword} : !$encoding ? 0 : 1;
	
	# tuning
	
	$mail->{From} ||= $conf->{from} || '';
	$mail->{Type} ||= $conf->{type} || '';
	
	if ($mail->{Data} && $mail->{Type} !~ /multipart/) {
		$mail->{Encoding} ||= $encoding;
		_enc($mail->{Data} => $charset);
	}
	
	if ($mimeword) {
		$_ = MIME::EncWords::encode_mimeword($_, $encode, $charset)
			for grep { _enc($_ => $charset); 1 } $mail->{Subject}
		;
		
		for (grep $mail->{$_}, qw(From To Cc Bcc)) {
			$mail->{$_} = join ", ",
				grep {
					_enc($_ => $charset);
					{
						next unless /(.*) \s+ (\S+ @ .*)/x;
						
						my($name, $email) = ($1, $2);
						$email =~ s/(^<+|>+$)//sg;
						
						$_ = $name =~ /^[\w\s"'.,]+$/
							? "$name <$email>"
							: MIME::EncWords::encode_mimeword($name, $encode, $charset) . " <$email>"
						;
					}
					1;
				}
				split /\s*,\s*/, $mail->{$_}
			;
		}
	}
	
	# year, baby!
	
	my $msg = MIME::Lite->new( %$mail );
	
	# header
	$msg->delete('X-Mailer'); # remove default MIME::Lite header
	
	$msg->add   ( %$_ ) for @{$p->{headers} || []}; # XXX: add From|To|Cc|Bcc => ... (mimeword)
	$msg->add   ('X-Mailer' => join ' ', 'Mojolicious',  $Mojolicious::VERSION, __PACKAGE__, $VERSION, '(Perl)')
		unless $msg->get('X-Mailer') || $p->{nomailer};
	
	# attr
	$msg->attr( %$_ ) for @{$p->{attr   } || []};
	$msg->attr('content-type.charset' => $charset) if $charset;
	
	# attach
	$msg->attach( %$_ ) for
		grep {
			if (!$_->{Type} || $_->{Type} =~ /text/i) {
				$_->{Encoding} ||= $encoding;
				_enc($_->{Data} => $charset);
			}
			1;
		}
		grep { $_->{Data} || $_->{Path} }
		@{$p->{attach} || []}
	;
	
	$msg;
}

sub _enc($$) {
	my $charset = $_[1] || CHARSET;
	$_[0] = b($_[0])->encode('UTF-8')->to_string if $_[0] && $charset && $charset =~ /utf-8/i;
	$_[0];
}

1;

__END__

=encoding UTF-8

=head1 NAME

Mojolicious::Plugin::Mail - Mojolicious Plugin for send mail

=head1 SYNOPSIS

  # Mojolicious::Lite
  plugin 'mail';

  # Mojolicious with config
  $self->plugin(mail => {
    from => 'sharifulin@gmail.com',
    type => 'text/html',
  });

  # in controller
  $self->mail(
    to      => 'sharifulin@gmail.com',
    subject => 'Test',
    data    => 'use Perl or die;',
  );

  # in controller, using render
  $self->mail(to => 'sharifulin@gmail.com', template => 'controller/action', format => 'mail');

  # template: controller/action.mail.ep
  % stash subject => 'Test';
  use Perl or die;


=head1 DESCRIPTION

L<Mojolicous::Plugin::Mail> is a plugin for Mojolicious apps to send mail using L<MIME::Lite>.

=head1 HELPERS

L<Mojolicious::Plugin::Mail> contains two helpers: I<mail> and I<render_mail>.

=head2 C<mail>

  # simple interface
  $self->mail(
      to       => 'sharifulin@gmail.com',
      from     => 'sharifulin@gmail.com',
      
      reply_to => 'reply_to+sharifulin@gmail.com',
      
      cc       => '..',
      bcc      => '..',
      
      type     => 'text/plain',

      subject  => 'Test',
      data     => 'use Perl or die;',
  );

  # interface as MIME::Lite
  $self->mail(
      # test mode
      test   => 1,
      
      # as MIME::Lite->new( ... )
      mail   => {
        To       => 'sharifulin@gmail.com',
        Subject  => 'Test',
        Data     => 'use Perl or die;',
        
        # add credentials parameters
        AuthUser => 'username',
        AuthPass => 'password',
      },

      attach => [
        # as MIME::Lite->attach( .. )
        { ... },
        ...
      },

      headers => [
        # as MIME::Lite->add( .. )
        { ... },
        ...
      },

      attr => [
        # as MIME::Lite->attr( .. )
        { ... },
        ...
      },
  );

Build and send email, return mail as string.

Supported parameters:

=over 16

=item * to

Header 'To' of mail.

=item * from

Header 'From' of mail.

=item * reply_to

Header 'Reply-To' of mail.

=item * cc

Header 'Cc' of mail.

=item * bcc

Header 'Bcc' of mail.

=item * type

Content type of mail, default is conf's type.

=item * subject

Header 'Subject' of mail.

=item * data

Content of mail

=item * mail

Hashref, containts parameters as I<new(PARAMHASH)>. See L<MIME::Lite>.

=item * attach 

Arrayref of hashref, hashref containts parameters as I<attach(PARAMHASH)>. See L<MIME::Lite>.

=item * headers

Arrayref of hashref, hashref containts parameters as I<add(TAG, VALUE)>. See L<MIME::Lite>.

=item * attr

Arrayref of hashref, hashref containts parameters as I<attr(ATTR, VALUE)>. See L<MIME::Lite>.

=item * test

Test mode, don't send mail.

=item * charset

Charset of mail, default charset is UTF-8.

=item * mimeword

Using mimeword or not, default value is 1.

=item * nomailer

No using 'X-Mailer' header of mail, default value is 1.

=back

If no subject, uses value of stash parameter 'subject'.

If no data, call I<render_mail> helper with all stash parameters.

=head2 C<render_mail>

  my $data = $self->render_mail('user/signup');

  # or use stash params
  my $data = $self->render_mail(template => 'user/signup', user => $user);

Render mail template and return data, mail template format is I<mail>, i.e. I<user/signup.mail.ep>.

=head1 ATTRIBUTES

L<Mojolicious::Plugin::Mail> contains one attribute - conf.

=head2 C<conf>

  $plugin->conf;

Config of mail plugin, hashref.

Keys of conf:

=over 6

=item * from

From address, default value is I<test-mail-plugin@mojolicio.us>.

=item * encoding 

Encoding of Subject and any Data, value is MIME::Lite content transfer encoding L<http://search.cpan.org/~rjbs/MIME-Lite-3.027/lib/MIME/Lite.pm#Content_transfer_encodings>
Default value is I<base64>.

=item * charset

Default charset of Subject and any Data, default value is I<UTF-8>.

=item * type

Default type of Data, default value is I<text/plain>.

=item * how

HOW parameter of MIME::Lite::send: I<sendmail> or I<smtp>.

=item * howargs 

HOWARGS parameter of MIME::Lite::send (arrayref).

=back

  my $conf = {
    from     => 'sharifulin@gmail.com,
    encoding => 'base64',
    type     => 'text/html',
    how      => 'sendmail',
    howargs  => [ '/usr/sbin/sendmail -t' ],
  };

  # in Mojolicious app
  $self->plugin(mail => $conf);
  
  # in Mojolicious::Lite app
  plugin mail => $conf;


=head1 METHODS

L<Mojolicious::Plugin::Mail> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  $plugin->register($app, $conf);

Register plugin hooks in L<Mojolicious> application.

=head2 C<build>

  $plugin->build( mail => { ... }, ... );

Build mail using L<MIME::Lite> and L<MIME::EncWords> and return MIME::Lite object.

=head1 TEST MODE

L<Mojolicious::Plugin::Mail> has test mode, no send mail.

  # all mail don't send mail
  BEGIN { $ENV{MOJO_MAIL_TEST} = 1 };

  # or only once
  $self->mail(
    test => 1,
    to   => '...',
  );

=head1 EXAMPLES

The Mojolicious::Lite example you can see in I<example/test.pl>.

Simple interface for send plain mail:

  get '/simple' => sub {
    my $self = shift;
    
    $self->mail(
      to      => 'sharifulin@gmail.com',
      type    => 'text/plain',
      subject => 'Тест письмо',
      data    => 'Привет!',
    );
  };

Simple send mail:

  get '/simple' => sub {
    my $self = shift;
    
    $self->mail(
      mail => {
        To      => 'sharifulin@gmail.com',
        Subject => 'Тест письмо',
        Data    => "<p>Привет!</p>",
      },
    );
  };

Simple send mail with test mode:

  get '/simple2' => sub {
    my $self = shift;
    
    my $mail = $self->mail(
      test => 1,
      mail => {
        To      => '"Анатолий Шарифулин" sharifulin@gmail.com',
        Cc      => '"Анатолий Шарифулин" <sharifulin@gmail.com>, Anatoly Sharifulin sharifulin@gmail.com',
        Bcc     => 'sharifulin@gmail.com',
        Subject => 'Тест письмо',
        Type    => 'text/plain',
        Data    => "<p>Привет!</p>",
      },
    );
    
    warn $mail;
  };

Mail with binary attachcment, charset is windows-1251, mimewords off and mail has custom header:

  get '/attach' => sub {
    my $self = shift;
    
    my $mail = $self->mail(
      charset  => 'windows-1251',
      mimeword => 0,

      mail => {
        To      => 'sharifulin@gmail.com',
        Subject => 'Test attach',
        Type    => 'multipart/mixed'
      },
      attach => [
        {
          Data => 'Any data',
        },
        {
          Type        => 'BINARY',
          Filename    => 'crash.data',
          Disposition => 'attachment',
          Data        => 'binary data binary data binary data binary data binary data',
        },
      ],
      headers => [ { 'X-My-Header' => 'Mojolicious' } ],
    );
  };

Multipart mixed mail:

  get '/multi' => sub {
    my $self = shift;
    
    $self->mail(
      mail => {
        To      => 'sharifulin@gmail.com',
        Subject => 'Мульти',
        Type    => 'multipart/mixed'
      },

      attach => [
        {
          Type     => 'TEXT',
          Encoding => '7bit',
          Data     => "Just a quick note to say hi!"
        },
        {
          Type     => 'image/gif',
          Path     => $0
        },
        {
          Type     => 'x-gzip',
          Path     => "gzip < $0 |",
          ReadNow  => 1,
          Filename => "somefile.zip"
        },
      ],
    );
  };

Render mail using simple interface and Reply-To header:

  get '/render_simple' => sub {
    my $self = shift;
    my $mail = $self->mail(to => 'sharifulin@gmail.com', reply_to => 'reply_to+sharifulin@gmail.com');

    $self->render(ok => 1, mail => $mail);
} => 'render';

Mail with render data and subject from stash param:

  get '/render' => sub {
    my $self = shift;

    my $data = $self->render_mail('render');
    $self->mail(
      mail => {
        To      => 'sharifulin@gmail.com',
        Subject => $self->stash('subject'),
        Data    => $data,
      },
    );
  } => 'render';

  __DATA__

  @@ render.html.ep
  <p>Hello render!</p>
  
  @@ render.mail.ep
  % stash 'subject' => 'Привет render';
  
  <p>Привет mail render!</p>

Send email via remote SMTP server.

  # in main
  $self->plugin(
    mail => {
      from    => 'info@host.example',
      type    => 'text/html',
      how     => 'smtp',
      howargs => [ 'mail.host.example',
                      AuthUser => 'me@host.example',
                      AuthPass => '123xyz',
                 ],
    }
  );
  
  # in controller
  $self->mail(
    to      => 'friend@hishost.example',
    subject => 'Test',
    data    => 'use Perl or die;',
  );

=head1 SEE ALSO

L<MIME::Lite> L<MIME::EncWords> L<Mojolicious> L<Mojolicious::Guides> L<http://mojolicious.org>.

=head1 AUTHOR

Anatoly Sharifulin <sharifulin@gmail.com>

=head1 THANKS

Alex Kapranoff <kapranoff@gmail.com>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mojolicious-plugin-mail at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.htMail?Queue=Mojolicious-Plugin-Mail>.  We will be notified, and then you'll
automatically be notified of progress on your bug as we make changes.

=over 5

=item * Github

L<http://github.com/sharifulin/mojolicious-plugin-mail/tree/master>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.htMail?Dist=Mojolicious-Plugin-Mail>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Plugin-Mail>

=item * CPANTS: CPAN Testing Service

L<http://cpants.perl.org/dist/overview/Mojolicious-Plugin-Mail>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Plugin-Mail>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Plugin-Mail>

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2010-2012 by Anatoly Sharifulin.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
