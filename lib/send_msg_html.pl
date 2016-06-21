#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use MIME::Lite::TT::HTML;

my $TMPL_OPTIONS = { INCLUDE_PATH=>'/www/sv-cms/htdocs/templates/mail_tmpl' };
my $TMPL_VARS = {
	fields => [
		{name=>'name',description=>'���',value=>'������ ���� ������'},
		{name=>'phone',description=>'�������',value=>'123-45-67'},
		{name=>'email',description=>'E-mail',value=>'ivan@ivan.ru'},
		{name=>'message',description=>'���������',value=>'���� �������������� ������������� ������������ �� ������ � ���������� �������. �� �������� ����������� ������������ ���������, ����������� � ������ ����� ������� �������������� �������� (���), �� ������.'},
	],
	site => 'designb2b.ru',	
};

my $msg = MIME::Lite::TT::HTML->new(
	From => 'no-reply@designb2b.ru',
	To => 'timonenkova@trade.su',
	Subject => 'HTML Design',
	TimeZone => 'Europe/Moscow',
	Encoding => 'quoted-printable',
	Template => {
		html => 'default.tmpl',
	},
	Type=>'multipart/mixed',
	Charset => 'windows-1251',
	TmplOptions => $TMPL_OPTIONS,
	TmplParams => $TMPL_VARS,
);

$msg->attach();

print Dumper($msg);

#$msg->send;
