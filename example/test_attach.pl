#!/usr/bin/env perl
use utf8;

use Mojolicious::Lite;

plugin 'mail';

get '/' => sub {
	my $self = shift;
	
	my $data = $self->render_mail(template => 'render');
	my $att  = $self->render('partial', partial => 1);
	
	warn $self->mail(
		mail => {
			Type => 'multipart/mixed',
			To   => 'sharifulin@gmail.com',
		}, 
		attach => [
				{
					Type => 'text/html',
					Data => $data,
				},
				{
					Type        => 'BINARY',
					Disposition => 'attachment',
					Data        => $att,
					Filename    => 'hall.doc',
				},
			],
	);
} => 'render';

app->log->level('error');

app->start;

__DATA__

@@ render.html.ep
OK

@@ render.mail.ep
% stash subject => 'Тестовое сообщение от Mojolicious::Plugin::Mail';
Привет, это тестовое сообщение от Mojolicious::Plugin::Mail.
<br/>

Тоже работает!

@@ partial.html.ep
Часть аттача
