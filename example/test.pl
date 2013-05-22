#!/usr/bin/env perl
use utf8;

use Mojolicious::Lite;

plugin 'mail';

get '/' => sub {
	my $self = shift;
	
	$self->mail(
		to       => 'sharifulin@gmail.com',
		reply_to => 'reply_to+sharifulin@gmail.com',
		subject  => 'Тестовое сообщение от Mojolicious::Plugin::Mail',
		data     => "Привет, это тестовое сообщение от Mojolicious::Plugin::Mail.\n\nРаботает!",
	);
	
	$self->render(text => 'OK');
};

get '/render' => sub {
	shift->mail(to => 'sharifulin@gmail.com', template => 'render');
} => 'render';

# app->log->level('error');

app->start;

__DATA__

@@ render.html.ep
OK

@@ render.mail.ep
% stash subject => 'Тестовое сообщение от Mojolicious::Plugin::Mail';
Привет, это тестовое сообщение от Mojolicious::Plugin::Mail.

Тоже работает!
