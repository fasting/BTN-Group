#!/usr/bin/perl
# Модуль для изменения размеров изображения
use Image::Magick;
#use Data::Dumper;

my $input_file = $ARGV[0];
if ( $input_file =~ m/^(.+)\.(.*?)$/ ) {
  our $input     = $1;
  our $input_ext = $2;
}

our @output = ();
$output_object = {};
our $project_id;
our $project_files = '/home/kosmik/dev_perl';

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

    # 22.12.2014, Isavnin, Доработка Ресайза
    # Настройки кропа
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

  # Данные параметры нужны для кроппирования
    if ( $opt eq 'xypos' )   { $output_object->{xypos}   = $val; }
    if ( $opt eq 'gravity' ) { $output_object->{gravity} = $val; }

    # Добавляем сюда же водный знак
    if ( $opt eq 'wm' ) {
      $output_object->{wm} = 1;

      #$output_object->{wmresize}='0x0' unless($output_object->{wmresize});
      $output_object->{wmpos} = 'Center'
        unless ( $output_object->{wmpos} );
      $output_object->{wmxy} = '0x0'
        unless ( $output_object->{wmxy} );
    }

    # Ресайз водного знака, если надо
    if ( $opt eq 'wmresize' ) {
      if ( $val =~ m/^(\d+)x(\d+)$/ ) {
        $output_object->{wmresize} =
          ( $1 > 0 ? $1 : '' ) . 'x' . ( $2 > 0 ? $2 : '' );
      }
    }

    # Расположение водного знака
    if ( $opt eq 'wmpos' ) {
      $output_object->{wmpos} = $val if ( $val =~ m/^(\w+)$/ );
    }

    # Файл
    if ( $opt eq 'wmfile' ) {
      $output_object->{wmfile} = $val if ( $val =~ m/^(\w+)$/ );
    }

    # Сдвиг водного знака
    if ( $opt eq 'wmxy' ) {
      if ( $val =~ m/^(\d+)x(\d+)$/ ) {
        $output_object->{wmxy} =
          ( $1 > 0 ? $1 : '' ) . 'x' . ( $2 > 0 ? $2 : '' );
        $output_object->{wmx} = $1 > 0 ? $1 : undef;
        $output_object->{wmy} = $2 > 0 ? $2 : undef;
      }
    }

    # Проект, нужен для водного знака
    if ( $opt eq 'project_id' ) {
      if ( $val =~ m/^(\d+)$/ ) {
        $project_id = $1;
      }
    }

    # Ну и на будущее, какие-нибудь фильтры... 8)
    if ( $opt eq 'filter' ) { }

    # Выбор ресайза
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
"Не указано или указано не верно имя входного файла ($input_file)\n";
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
{ # проверка объекта, отвечающего за выходной файл
  if ( $output_object->{file} !~ m/[0-9a-zA-Z\._\-\/]+/ ) {
    print
"Не указано имя файла-приёмника ($output_object->{file})\n";
    exit;
  }
  if (    !length( $output_object->{width} )
       || !length( $output_object->{height} ) )
  {
    print
"не указаны или указаны не верно размеры выходного файла; '$output_object->{width}' ; '$output_object->{height}'";
    exit;
  }
  push @output, {

    # Параметры для старого ресайза
    file   => $output_object->{file},
    width  => $output_object->{width},
    height => $output_object->{height},

# Данный параметр отвечает за включение нового ресайза...
    type => $output_object->{type},

# Новые параметры, используються для ресайза, и кропа...
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
#    wmtext    => $output_object->{wmtext}, # Текст для водного знака
#    wmopt     => $output_object->{wmopt}, # Опции для текста

    # Водный знак
    wm => $output_object->{wm} };
  $output_object = {};
}

sub help {
  print q{

МОДУЛЬ picture_resize
Предназначен для изменения размера загружаемых картинок.
опции:
./resize [файл-источник] ( --output_file='[файл-приёмник]' --size='[ширина]x[высота]' )
часть указанная в скобках, может повторяться несколько раз (таким образом данный модуль сделает несколько копий изображений).

--output_file
  файл-приёмник -- изменённый файл. Возможна ситуация, когда имя файла-приёмника совпадаем с именем файла-источника.
  В этом случае изменения записываются в источник. Также возможна ситуация, когда указывается несколько приёмников
  (для каждого из приёмников необходимо задать ширину и высоту). В таком случае, на выходе получится несколько копий картинок с
  изменёнными размерами.
  При указании выходного имени файла, возможно указывать переменную [%input%] -- это имя входного файла без расширения.
  [%input_ext%] -- расирение входного файла.

  В этом случае возможны такие записи:
  ./resize picture.jpg --output_file='[%input%]_mini.[%input_ext%]' --size='100x100'

--size
  ширина и высота файла-приёмника
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
      ; # Высчитываем коэффициент пропорциональности соотношения высоты рамки и картинки
    my $ko_height =
      $border_height /
      $picture_height
      ; # Высчитываем коэффициент пропорциональности соотношения ширины рамки и картинки
    my $ko =
      $ko_width /
      $ko_height
      ; # Вычисляем соотношение обоих коэффициенктов
    if ( $ko >= 1 )
    {  # если уменьшение дает поля сверху-снизу
      $k = $border_height / $picture_height;
    }
    elsif ( $ko < 1 )
    { # если уменьшение дает поля по слева-справа
      $k = $border_width / $picture_width;
    }
    elsif (    ( $border_height >= $picture_height )
            && ( $border_width >= $picture_width ) )
    { # если картинка меньше рамки - ничего делать с ней не будем
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
  print "пишу: $output_file\n";
  $x = $image->Write($output_file);
  1;
}

sub new_resize {
  my ( $file, $opt ) = @_;
  my $img = Image::Magick->new;
  my $pic = $img->Read($file);
  my ( $w, $h ) = $img->Get( 'base-columns', 'base-rows' );

  # Ресайзим
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

    print "Ресайз: $w x $h => $opt->{resize}\t" if ( !$opt->{orig} );
    print
"Ресайз: не нужен, исходник меньше задоного\t"
      if ( $opt->{orig} == 1 );
  }

  # Кропим
  if ( $opt->{crop} ) {

    if ( $w > $opt->{crop_x} && $h > $opt->{crop_y} ) {
      $img->Crop( geometry => $opt->{crop} . $opt->{xypos},
                  gravity  => $opt->{gravity} );
      print "Кропим: $opt->{crop}$opt->{xypos} $opt->{gravity}\t";
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

      # Ресайзим водный знак
      $watermark->Resize( geometry => $opt->{wmresize} )
        if ( $opt->{wmresize} );

      # Водный знак меньше картинки
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
"Ресайзим водный знак: $wm_width x $wm_height => $opt->{wmresize}\t";
      }
      print "Добавляем водный знак\t";
    }
    else {
      print "<b color='red'>Водный знак не найден</b>\t";
    }
  }

  # Добавляем фильтры...

  # Пишем
  $pic = $img->Write( $opt->{file} );
  print "Пишем: $opt->{file}\n<br/>";
  1;
}

sub resize {    # процедура ресайзинга
  my ( $input_file, $output_file, $width, $height ) = @_;
  my $image;
  $image = Image::Magick->new;    #новый проект
  my $x = $image->Read($input_file);    #открываем файл
  my ( $ox, $oy ) = $image->Get( 'base-columns', 'base-rows' );

  #my $nx=int(($ox/$oy)*$height); #вычисляем ширину
  my $ny = int( ( $oy / $ox ) * $width );    #вычисляем высоту
  $image->Resize( width => $width, height => $ny );
  if ( $ny > $height ) {
    $nny =
      int( ( $ny - $height ) / 2 )
      ;    #Вычисляем откуда нам резать

    $image->Crop( x => 0, y => $nny );
    $image->Crop( $width . 'x' . $height )
      ;    #С того места вырезаем 200х150
  }
  $x = $image->Write($output_file);
}

=cut
sub resize{ # процедура ресайзинга
	my ($input_file, $output_file, $width, $height)=@_;
	my $image;
	$image = Image::Magick->new; #новый проект
	my $x = $image->Read($input_file); #открываем файл
	my ($ox,$oy)=$image->Get('base-columns','base-rows');
	my $nx=int(($ox/$oy)*$height); #вычисляем ширину
	$image->Resize(width=>$nx, height=>$height);
	if($nx>$width){
		$nnx=int(($nx-$width)/2); #Вычисляем откуда нам резать
		print "nnx: $nnx\n";
		$image->Crop(x=>$nnx, y=>0);
		$image->Crop($width.'x'.$height); #С того места вырезаем 200х150
	}
	$x = $image->Write($output_file);
}
=cut
