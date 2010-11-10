#!/usr/bin/env perl

use Mojolicious::Lite;

plugin 'mail';

get '/' => sub {
	my $self = shift;
	
	$self->mail(
		to      => 'sharifulin@gmail.com',
		subject => 'Mojolicious::Plugin::Mail test mail',
		data    => "Hello, it's Mojolicious::Plugin::Mail test mail.\n\nIt works!",
	);
	
	$self->render_text('OK');
};

get '/render' => sub {
	shift->mail(to => 'sharifulin@gmail.com', template => 'render');
} => '*';

app->log->level('error');

app->start;

__DATA__

@@ render.html.ep
OK

@@ render.mail.ep
% stash subject => 'Mojolicious::Plugin::Mail test mail';
Hello, it's Mojolicious::Plugin::Mail test mail.

It works too!
