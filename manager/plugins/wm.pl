#!/usr/bin/perl
#���� ��������� --project_id --src
use Image::Magick;
use Data::Dumper;

my $project_id;
my $src_name;
my $wm_name;
do '../connect';
my $project_files_path = "$CMSpath/files"; #'/www/sv-cms/htdocs/files';
#my $project_files_path = './files';

print "Content-type: text/html\n\n";


    foreach ( @ARGV ) {
        
        $_=~s/^'|'$//g;
        
        if ( $_ =~ /^--project_id=(\d+)$/  ) {
            $project_id = $1;
        }
    
        if ( $_ =~ /^--src=((.*).{3})$/  ) {
            $src_name = $1;
        }
    }
    
    if ( $project_id && $src_name ) {
        
        $wm_file = qq{$project_files_path/project_$project_id/watermark.png};
           # if ( -e $wm_file ) {
           #     print "== watermark file found.\n";
           # }
           # else { die "!! watermark file not found in $wm_file exit.\n"; }
        
        #print $project_id, $src_name;
        my $image;
            $image = Image::Magick->new;
            my $src = $image->Read($src_name);

	print $src."\n";
	print $src_name;

            my ($src_width, $src_height) = $image->Get('base-columns', 'base-rows');
          
            
        my $watermark;
            $watermark = Image::Magick->new;
            my $wm = $watermark->Read($wm_file);
            my ($wm_width, $wm_height) = $watermark->Get('base-columns', 'base-rows');
            
            if (!$wm_width || !$wm_height) {
                die "!! watermerk file error [$wm_file] exit.\n";
            }
            else {
                print "== watermark size [$wm_width]x[$wm_height]\n";
            }
            
            if ( $src_width>0 && $src_height>0 ) {
            
            print "== processing [$src_name] file\n";
            
                #���� src ������ ��� ����
                if ( $src_width>$wm_width ) {
                    print "== src size [$src_width]x[$src_height]\n";
                    print "== case 1 [$src_width]>[$wm_width]\n";
                    
                    $image->Composite( image => $watermark,
                                           compose => 'Plus',
                                           gravity => 'Center'
                    );

                   my $x = $image->Write($src_name);
		   print $x;
                    
                }
                else {
                    #���� ��������� $wm
                    print "== src size [$src_width]x[$src_height]\n";
                    print "== case 2 [$src_width]<[$wm_width]\n";

                        my $width=$src_width-10;
                        my $nh;
                        
                           if ( ($wm_width>$width)&&($wm_width/$width>1) ) {
                            my $prop=$wm_width/$width;
                            $nh=int($wm_height/$prop);
                            }

                           else {
                            $nh=$wm_height; $width=$src_width;
                           }
      
                    print "== Resize watermark to [$width]x[$nh]\n";
                    
                    #����� ������ #src � ������ �� 10 �������� ������
                    $watermark->Resize(width=>$width, height=>$nh );
                    
                                       
                    $image->Composite( image => $watermark,
                                           compose => 'Plus',
                                           gravity => 'Center'
                    );

                    my $x = $image->Write($src_name);
		    print $x;
                    
		    
		    
                }
            }
            else {
                die "!! src file error [$src_name] exit.\n";
            }
            
            
        
        
    }
    else {
        print "\n==========================================\n==Awiting params --project_id=xx and --src='xxx.xxx' for image srv file. \n";
    }
        
