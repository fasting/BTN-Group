#!/usr/bin/perl
# ������ ��� ��������� �������� �����������
use Image::Magick;
use POSIX qw/ceil/;

my $input_file = $ARGV[0];
if ( $input_file =~ m/^(.+)\.(.*?)$/ ) {
  our $input     = $1;
  our $input_ext = $2;
}

our @output = ();
$output_object = {};
our $project_id;
our $project_files = '/www/sv-cms/htdocs/files';

foreach my $p (@ARGV) {
  if ( $p =~ m/^--(.+?)(=(.+))?$/ ) {
    my ( $opt, $val ) = ( $1, $3 );
    $val =~ s/^'|'$//g;

    if ( $opt eq 'output_file' ) {
      $val =~ s/\[%input%\]/$input/;
      $val =~ s/\[%input_ext%\]/$input_ext/;
      if ( $val =~ m/^[0-9a-zA-Z\._\-\/]+$/ ) {
        $output_object->{file} = $val;
      }
    }

    # 22.12.2014, Isavnin, ��������� �������
    # ��������� �����
    if ( $opt eq 'crop' ) {
      if ( $val =~ m/^(\d+)x(\d+)$/ ) {
        $output_object->{crop}   = $val;
        $output_object->{crop_x} = $1;
        $output_object->{crop_y} = $2;
      }
      $output_object->{gravity} = 'Center'
        unless ( $output_object->{gravity} );
      $output_object->{xypos} = '+0+0'
        unless ( $output_object->{xypos} );
    }

  # ������ ��������� ����� ��� �������������
    if ( $opt eq 'xypos' )   { $output_object->{xypos}   = $val; }
    if ( $opt eq 'gravity' ) { $output_object->{gravity} = $val; }

    # ��������� ���� �� ������ ����
    if ( $opt eq 'wm' ) {
      $output_object->{wm} = 1;

      #$output_object->{wmresize}='0x0' unless($output_object->{wmresize});
      $output_object->{wmpos} = 'Center'
        unless ( $output_object->{wmpos} );
      $output_object->{wmxy} = '0x0'
        unless ( $output_object->{wmxy} );
    }

    # ����� ��� ������� �����
    if( $opt eq 'wmtext' ) {
      $output_object->{wmtext} = $val;
    }

    if( $opt eq 'wmdeg' ) {
      $output_object->{wmdeg} = $val;
    }
    
    if ( $opt eq 'wmfsize') {
      $output_object->{wmfsize}=$val;
    }

    if ( $opt eq 'wmfcolor1' ) {
      $output_object->{wmfcolor1} = $val;
    }
 
    if ( $opt eq 'wmfcolor2' ) {
      $output_object->{wmfcolor2} = $val;
    }

    if ( $opt eq 'wmsigma' ) {
      $output_object->{wmsigma} = $val;
    }
    if ( $opt eq 'wmradius' ) {
      $output_object->{wmradius} = $val;
    }

    # ������ ������� �����, ���� ����
    if ( $opt eq 'wmresize' ) {
      if ( $val =~ m/^(\d+)x(\d+)$/ ) {
        $output_object->{wmresize} =
          ( $1 > 0 ? $1 : '' ) . 'x' . ( $2 > 0 ? $2 : '' );
      }
    }

    # ������������ ������� �����
    if ( $opt eq 'wmpos' ) {
      $output_object->{wmpos} = $val if ( $val =~ m/^(\w+)$/ );
    }

    # ����
    if ( $opt eq 'wmfile' ) {
      $output_object->{wmfile} = $val if ( $val =~ m/^(\w+)$/ );
    }

    # ����� ������� �����
    if ( $opt eq 'wmxy' ) {
      if ( $val =~ m/^(\d+)x(\d+)$/ ) {
        $output_object->{wmxy} =
          ( $1 > 0 ? $1 : '' ) . 'x' . ( $2 > 0 ? $2 : '' );
        $output_object->{wmx} = $1 > 0 ? $1 : undef;
        $output_object->{wmy} = $2 > 0 ? $2 : undef;
      }
    }

    # ������, ����� ��� ������� �����
    if ( $opt eq 'project_id' ) {
      if ( $val =~ m/^(\d+)$/ ) {
        $project_id = $1;
      }
    }

    # �� � �� �������, �����-������ �������... 8)
    if ( $opt eq 'filter' ) { }

    # ����� �������
    if ( $opt eq 'type' ) {
      $output_object->{type} = $val;
    }

    if ( $opt eq 'size' ) {

      if ( $val =~ m/^(\d+)x(\d+)$/ ) {

        $output_object->{resize} =
          ( $1 > 0 ? $1 : '' ) . 'x' . ( $2 > 0 ? $2 : '' );
        $output_object->{width}  = $1;
        $output_object->{height} = $2;
      }

      &check_output_object;

    }

    &help if ( $opt eq 'help' );
  }
}
if ( $input_file !~ m/[0-9a-zA-Z\._\-\/]+/ ) {
  print
"�� ������� ��� ������� �� ����� ��� �������� ����� ($input_file)\n";
  exit;
}

foreach my $o (@output) {
  if ( $o->{type} eq 'new' || $o->{type} eq 'adaptive' ) {
    new_resize( $input_file, $o );
  }
  else {
    leva_resize( $input_file, $o->{file}, $o->{width}, $o->{height} );
  }

}

sub check_output_object
{ # �������� �������, ����������� �� �������� ����
  if ( $output_object->{file} !~ m/[0-9a-zA-Z\._\-\/]+/ ) {
    print
"�� ������� ��� �����-�������� ($output_object->{file})\n";
    exit;
  }
  if (    !length( $output_object->{width} )
       || !length( $output_object->{height} ) )
  {
    print
"�� ������� ��� ������� �� ����� ������� ��������� �����; '$output_object->{width}' ; '$output_object->{height}'";
    exit;
  }
  push @output, {

    # ��������� ��� ������� �������
    file   => $output_object->{file},
    width  => $output_object->{width},
    height => $output_object->{height},

# ������ �������� �������� �� ��������� ������ �������...
    type => $output_object->{type},

# ����� ���������, ������������� ��� �������, � �����...
    crop     => $output_object->{crop},
    crop_x   => $output_object->{crop_x},
    crop_y   => $output_object->{crop_y},
    resize   => $output_object->{resize},
    xypos    => $output_object->{xypos},
    gravity  => $output_object->{gravity},
    wmresize => $output_object->{wmresize},
    wmxy     => $output_object->{wmxy},
    wmx      => $output_object->{wmx},
    wmy      => $output_object->{wmy},
    wmpos    => $output_object->{wmpos},
    wmfile   => $output_object->{wmfile},
    wmtext   => $output_object->{wmtext}, # ����� ��� ������� �����
    wmdeg    => $output_object->{wmdeg}, # ���� �������� ������
    wmfsize  => $output_object->{wmfsize},
    wmfcolor1=> $output_object->{wmfcolor1}, # ���� 1
    wmfcolor2=> $output_object->{wmfcolor2}, # ���� 2
    sigma  => $output_object->{wmsigma},
    radius => $output_object->{wmradius},
#    wmopt     => $output_object->{wmopt}, # ����� ��� ������

    # ������ ����
    wm => $output_object->{wm} };
  $output_object = {};
}

sub help {
  print q{

������ picture_resize
������������ ��� ��������� ������� ����������� ��������.
�����:
./resize [����-��������] ( --output_file='[����-�������]' --size='[������]x[������]' )
����� ��������� � �������, ����� ����������� ��������� ��� (����� ������� ������ ������ ������� ��������� ����� �����������).

--output_file
  ����-������� -- ��������� ����. �������� ��������, ����� ��� �����-�������� ��������� � ������ �����-���������.
  � ���� ������ ��������� ������������ � ��������. ����� �������� ��������, ����� ����������� ��������� ���������
  (��� ������� �� ��������� ���������� ������ ������ � ������). � ����� ������, �� ������ ��������� ��������� ����� �������� �
  ���������� ���������.
  ��� �������� ��������� ����� �����, �������� ��������� ���������� [%input%] -- ��� ��� �������� ����� ��� ����������.
  [%input_ext%] -- ��������� �������� �����.

  � ���� ������ �������� ����� ������:
  ./resize picture.jpg --output_file='[%input%]_mini.[%input_ext%]' --size='100x100'

--size
  ������ � ������ �����-��������
};
}

sub leva_resize {
  my ( $input_file, $output_file, $border_width, $border_height ) = @_;
  my $image;
  $image = Image::Magick->new;
  my $x = $image->Read($input_file);
  my ( $picture_width, $picture_height ) =
    $image->Get( 'base-columns', 'base-rows' );
  print "($picture_width, $picture_height)\n";
  if (    ( $picture_width < $border_width )
       && ( $picture_height < $border_height ) )
  {
    $image->Resize( width => $picture_width, height => $picture_height );
  }
  elsif ( $border_width != 0 && $border_height != 0 ) {
    my $k;
    my $ko_width =
      $border_width /
      $picture_width
      ; # ����������� ����������� ������������������ ����������� ������ ����� � ��������
    my $ko_height =
      $border_height /
      $picture_height
      ; # ����������� ����������� ������������������ ����������� ������ ����� � ��������
    my $ko =
      $ko_width /
      $ko_height
      ; # ��������� ����������� ����� ��������������
    if ( $ko >= 1 )
    {  # ���� ���������� ���� ���� ������-�����
      $k = $border_height / $picture_height;
    }
    elsif ( $ko < 1 )
    { # ���� ���������� ���� ���� �� �����-������
      $k = $border_width / $picture_width;
    }
    elsif (    ( $border_height >= $picture_height )
            && ( $border_width >= $picture_width ) )
    { # ���� �������� ������ ����� - ������ ������ � ��� �� �����
      $k = undef;
    }
    if ( defined $k ) {
      my $result_height = int( $picture_height * $k );
      my $result_width  = int( $picture_width * $k );
      $image->Resize( width => $result_width, height => $result_height );
    }
    else {
      $image->Resize( width  => $picture_width,
                      height => $picture_height );
    }
  }
  elsif ( $border_height == 0 ) {
    if ( $picture_width < $border_width ) {
      $image->Resize( width  => $picture_width,
                      height => $picture_height );
    }
    else {
      my $k             = $border_width / $picture_width;
      my $result_height = int( $picture_height * $k );
      my $result_width  = int( $picture_width * $k );
      $image->Resize( width => $result_width, height => $result_height );
    }
  }
  elsif ( $border_width == 0 ) {
    if ( $picture_height < $border_height ) {
      $image->Resize( width  => $picture_width,
                      height => $picture_height );
    }
    else {
      my $k             = $border_height / $picture_height;
      my $result_height = int( $picture_height * $k );
      my $result_width  = int( $picture_width * $k );
      $image->Resize( width => $result_width, height => $result_height );
    }
  }
  print "����: $output_file\n";
  $x = $image->Write($output_file);
  1;
}

sub new_resize {
  my ( $file, $opt ) = @_;
  my $img = Image::Magick->new;
  my $pic = $img->Read($file);
  my ( $w, $h ) = $img->Get( 'base-columns', 'base-rows' );

  # ��������
  if ( $opt->{resize} ) {
    if ( $opt->{width} != 0 && $opt->{height} != 0 ) {
      $opt->{orig} = undef;
    }
    elsif ( $opt->{width} == 0 && $h >= $opt->{height} ) {

      $opt->{orig} = undef;
    }
    elsif ( $opt->{height} == 0 && $w >= $opt->{width} ) {

      $opt->{orig} = undef;
    }
    else {
      $opt->{orig} = 1;
    }

    if ( !$opt->{orig} ) {
      if ( $opt->{type} eq 'adaptive' ) {
        $img->AdaptiveResize( $opt->{resize} );
      }
      else {
        $img->Resize( $opt->{resize} );
      }
    }

    print "������: $w x $h => $opt->{resize}\t" if ( !$opt->{orig} );
    print
"������: �� �����, �������� ������ ��������\t"
      if ( $opt->{orig} == 1 );
  }

  # ������
  if ( $opt->{crop} ) {

    if ( $w > $opt->{crop_x} && $h > $opt->{crop_y} ) {
      $img->Crop( geometry => $opt->{crop} . $opt->{xypos},
                  gravity  => $opt->{gravity} );
      print "������: $opt->{crop}$opt->{xypos} $opt->{gravity}\t";
    }
  }
  if ( $opt->{wm} eq '1' && $project_id ) {
    my $wm_file = qq{$project_files/project_$project_id/const_watermark.png};
    if ( $opt->{wmfile} ) {
      $wm_file =
        qq{$project_files/project_$project_id/const_$opt->{wmfile}.png};
    }
    if ( -f $wm_file ) {
      my $watermark = Image::Magick->new;
      my $wm        = $watermark->Read($wm_file);
      my ( $wm_width, $wm_height ) =
        $watermark->Get( 'base-columns', 'base-rows' );

      # �������� ������ ����
      $watermark->Resize( geometry => $opt->{wmresize} )
        if ( $opt->{wmresize} );

      # ������ ���� ������ ��������
      $opt->{wmpos} = 'Center' unless ( $opt->{wmpos} );
      $opt->{wmx}   = 0        unless ( $opt->{wmx} );
      $opt->{wmy}   = 0        unless ( $opt->{wmy} );
      print "G:$opt->{wmpos} X:$opt->{wmx} Y:$opt->{wmy}\n";
      if ( $w > $wm_width ) {
        $img->Composite( image   => $watermark,
                         compose => 'Over',
                         gravity => $opt->{wmpos},
                         x       => $opt->{wmx},
                         y       => $opt->{wmy} );
      }
      else {
        $opt->{wmresize} =
            $opt->{wmresize}
          ? $opt->{wmresize}
          : ( $wm_width - ( $wm_width - $w ) ) . 'x'
          . ( $wm_height - ( $wm_height - $h ) );
        $watermark->Resize( geometry => $opt->{wmresize} );
        $img->Composite( image   => $watermark,
                         compose => 'Over',
                         gravity => $opt->{wmpos},
                         x       => $opt->{wmx},
                         y       => $opt->{wmy} );
        print
"�������� ������ ����: $wm_width x $wm_height => $opt->{wmresize}\t";
      }
      print "��������� ������ ����\t";
    }
    else {
      print "<b color='red'>������ ���� �� ������</b>\t";
    }
    if($opt->{wmtext}){
      my $wm_tmp = &wm_text(
        $opt->{wmtext},
        ($opt->{wmfsize} ? $opt->{wmfsize} : 20),
        ($opt->{wmfcolor1} ? $opt->{wmfcolor1} : 1),
        ($opt->{wmfcolor2} ? $opt->{wmfcolor2} : 2),
        ($opt->{sigma} ? $opt->{sigma} : 6),
        ($opt->{radius} ? $opt->{radius} : 0),
      );
      my $wmf = qq{$project_files/project_$project_id/tmpwm.png};
      $wm_tmp->Write($wmf);
      my $wm = Image::Magick->new();
      $wm->ReadImage($wmf);
      my $degress = $opt->{wmdeg} ? $opt->{wmdeg} : -45;     
      $wm->Rotate(degrees=>$degress,background=>'rgba( 0, 0, 0, 0.0)');
      
      my($h,$w) = $img->Get('height','width');
      my ($wm_h,$wm_w) = $wm->Get('height','width');
      my $cheight = ( $h > $wm_h ? $h : $wm_h );
      my $cwidth = ( $w > $wm_w ? $w : $wm_w );

      # ����� ����� ��� ��������
      my $c = Image::Magick->new(size=>"${cwidth}x${cheight}");
      $c->Read('canvas:transparent');

      # ����� ��� �����
      my $tl = Image::Magick->new(size => "${cwidth}x${cheight}");
      $tl->Read('canvas:transparent');

      # ���-�� ����� � �������� � �����
      my $cols = ceil($w/$wm_w);
      my $rows = ceil($h/$wm_h);

      $cols++ if $cols % 2 == 0;
      $rows++ if $rows % 2 == 0;

      my $center_col = ceil($cols / 2);
      my $center_row = ceil($rows / 2);

      my $cx = ($w - $wm_w) * 0.5;
      my $cy = ($h - $wm_h) * 0.5;

      for my $col(1 .. $cols) {
        for my $row(1 .. $rows) {
          my $x = $cx + ($col - $center_col) * $wm_w;
          my $y = $cy + ($row - $center_row) * $wm_h;
          $tl->Composite(
            image => $wm,
            compose => 'over',
            x => $x,
            y => $y,
            gravity => 'NorthWest',
          );
        }
      }
     
      $c->Composite(
        image=>$img,
        compose=>'over',
        gravity=>'center',
      );
      $c->Composite(
        image=>$tl,
        compose=>'over',
        gravity=>'center',
      );
      $c->Crop(
        x => ($cwidth-$w) * 0.5,
        y => ($cheight-$h) * 0.5,
        width => $w,
        height => $h,
      );
      
      $img = $c;
      unlink($project_files.'/project_'.$opt->{project_id}.'/tmpwm.png');
    }
  }

  # ��������� �������...

  # �����
  $pic = $img->Write( $opt->{file} );
  print "�����: $opt->{file}\n<br/>";
  1;
}

sub resize {    # ��������� ����������
  my ( $input_file, $output_file, $width, $height ) = @_;
  my $image;
  $image = Image::Magick->new;    #����� ������
  my $x = $image->Read($input_file);    #��������� ����
  my ( $ox, $oy ) = $image->Get( 'base-columns', 'base-rows' );

  #my $nx=int(($ox/$oy)*$height); #��������� ������
  my $ny = int( ( $oy / $ox ) * $width );    #��������� ������
  $image->Resize( width => $width, height => $ny );
  if ( $ny > $height ) {
    $nny =
      int( ( $ny - $height ) / 2 )
      ;    #��������� ������ ��� ������

    $image->Crop( x => 0, y => $nny );
    $image->Crop( $width . 'x' . $height )
      ;    #� ���� ����� �������� 200�150
  }
  $x = $image->Write($output_file);
}


sub wm_text {
  my($text,$fsize,$color1,$color2,$sigma,$radius) = @_;
  $text = 'WaterMarkText' unless($text);
  my $font = 'Bookman-Demi';
  my $font_size = $fsize ? $fsize : 20;
  my $geom='+'.($font_size*2).'+'.($font_size*2);
  my $kerning = 3;
  print "GEOM: $geom";
  $sigma = 6 unless($sigma);
  $radius = 0 unless($radius);

  $color1 = '0,0,0' unless($color1 =~ m/^(\d+),(\d+),(\d+)$/);
  $color2 = '255,255,255' unless($color2 =~ m/^(\d+),(\d+),(\d+)$/);
  # ����� � ���������� �����
  my $img = Image::Magick->new(size=>'1000x70');
  $img->ReadImage('canvas:transparent');
  
  # ����� �����, � ������������� 30%
  $img->Annotate(
    text => $text,
    geometry => $geom, #"+50+50",
    pen => $img->QueryColorname('rgba('.$color1.',0.3)'),
    font => $font,
    pointsize => $font_size,
    kerning => $kerning,
  );
  
  # ���������
  $img->Blur(
    radius => $radius,
    sigma => $sigma,
    channel => 'RGBA',
  );

  # ������� ����� � ���������� �����
  my $mask = Image::Magick->new(size=>'1000x70');
  $mask->ReadImage('canvas:transparent');

  # ����� �����, � ������������ �����
  $mask->Annotate(
    text => $text,
    geometry => $geom, #"+50+50",
    pen => $img->QueryColorname('rgba('.$color2.',1)'),
    font => $font,
    pointsize => $font_size,
    kerning => $kerning,
  );
  
  $img->Composite(
    image => $mask,
    mask => $mask,
    compose => 'Clear',
  );

  $img->Annotate(
    text => $text,
    geometry => $geom, #"+50+50",
    pen => $img->QueryColorname('rgba('.$color2.',0.3)'),
    font => $font,
    pointsize => $font_size,
    kerning => $kerning,
  );

  $img->Trim();

  return $img;
}

=cut
sub resize{ # ��������� ����������
	my ($input_file, $output_file, $width, $height)=@_;
	my $image;
	$image = Image::Magick->new; #����� ������
	my $x = $image->Read($input_file); #��������� ����
	my ($ox,$oy)=$image->Get('base-columns','base-rows');
	my $nx=int(($ox/$oy)*$height); #��������� ������
	$image->Resize(width=>$nx, height=>$height);
	if($nx>$width){
		$nnx=int(($nx-$width)/2); #��������� ������ ��� ������
		print "nnx: $nnx\n";
		$image->Crop(x=>$nnx, y=>0);
		$image->Crop($width.'x'.$height); #� ���� ����� �������� 200�150
	}
	$x = $image->Write($output_file);
}
=cut
