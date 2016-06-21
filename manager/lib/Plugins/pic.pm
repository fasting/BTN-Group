#!/usr/bin/perl
package Plugins::pic;
use strict;
use warnings;
use CGI qw/standarts/;
use Image::Magick;

=head1 Plugins::pic

������ ��� ������� � ���� �����������.

=cut

our $in;

=head2 Methods 

=head3 new()

��� �������� ����� ��������� ������� � �������� ������

=cut

sub new {
	my $self = shift;
	my $opt = {};
	$in = $self;
	return bless $opt, $self;
}

=head3 resize()

 �������� �� ������� ����������

=cut

sub resize {
	my $self = shift;
	&check('resize');
	my $img = Image::Magick->new;
=cut
	����� ������ ���� ��������:
	open(IMAGE, param('file'));
	$img->Read(file=>\*IMAGE);
	close(IMAGE);
=cut
	my $pic = $img->Read($in->{src});
	foreach ( @{$in->{dst}} ){
		my $dst = $img->Clone();
		$dst->Resize(geometry => "$_->{width}x$_->{height}");
		if($_->{crop}){
			$dst->Crop(geometry => "", x => $_->{left}, y => $_->{top});
			$dst->Crop(geometry => "", x => $_->{right}, y => $_->{bottom});
		}
		#&save($dst);
		$dst->Write(filename=>$_->{output});
	}
}

=head3 crop()

 ����� �� ������� ����������

=cut

sub crop {
	my $self = shift;
#	&check('crop');
}

=head3 save()

���������� ������

=cut

sub save {
#	my $self = shift;
#	$self->write(
}

=head3 check()

�������� ������� ������

=cut

sub check {
	my $type = shift;

	unless( $in->{src} && scalar(@{$in->{dst}}) ){
		&err('f1');
	}

	if( $type eq 'resize' ){
		foreach( @{$in->{dst}} ){
			&err('r1') unless(defined($_->{size}));
		}
	}

	elsif( $type eq 'crop' ){
		foreach( @{$in->{dst}} ){
			&err('c1') unless(defined($_->{crop}));
		}
	}
}


return 1;
