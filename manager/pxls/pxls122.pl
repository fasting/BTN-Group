#!/usr/bin/perl 

#use strict;
use CGI::Carp qw/fatalsToBrowser/;
use warnings;
use vars qw($DBhost_parser $DBhost_parser_port);
use vars qw($fields $pa);

use DBI;
use Encode;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::FmtUnicode;
use CGI qw(:standard);
use Data::Dumper;
use HTML::Template;
use Template;

#=======================
# DATABASE
#
use vars qw($DBname $DBhost $DBuser $DBpassword);
do '../connect';
my $dbh=DBI->connect("DBI:mysql:$DBname:$DBhost",$DBuser,$DBpassword, , { RaiseError => 1 }) || die($!);

#=======================
my $config_id=param('config_id');
print "Content-type: text/html\n\n";
unless($config_id=~m/^\d+$/){
	print "�� ������ Config_id!";
	exit;
}

## ��������� ������, ������� �������� ������ ������ ������ ������ �������
#print "SELECT p.body FROM pxls p, project pr, manager m WHERE p.id=$config_id and p.project_id=pr.project_id and pr.project_id=m.project_id and m.login='$ENV{REMOTE_USER}'<br>";
#exit;

my $sth=$dbh->prepare(
	"SELECT p.body, p.project_id ".
	"FROM pxls p, project pr, manager m ".
	"WHERE p.id=? and p.project_id=pr.project_id and pr.project_id=m.project_id and m.login=?"
);
$sth->execute($config_id, $ENV{REMOTE_USER});

unless($sth->rows()){
	print "�� ������� ������� ������!";
	exit;
}
my $config;
my ($config_body, $project_id)=$sth->fetchrow();
eval($config_body);
print $@ if($@);

$config->{key}=$config_id;

my $template=Template->new({INCLUDE_PATH => '.'});

$config->{cols}=unpackFieldCol( loadConfigData($dbh, $config->{key}, 'cols') );

#=======================
my $h;

foreach my $e (qw(item tree)){
	$h={};
	$config->{ $e }->{fields_hash}=$h;
	foreach my $field (@{ $config->{ $e }->{fields} })
	{
		if($field->{unique}){
			$h->{unique} ||= $field;
		}

		if($field->{core}){
			$h->{core}->{ $field->{name} }=$field;
		}
		else{
			$h->{dynamic}->{ $field->{name} }=$field;
		}

		$h->{all}->{ $field->{name} }=$field;
	}
}
#=======================



#=======================
my $UPLOAD="/tmp/pxls122";
if( ! -e $UPLOAD ){
	print "Upload dir '$UPLOAD' not exists\n";
}
umask 0111;

#=======================
open LOG, ">$UPLOAD/pxls122.log";

#=======================
my $TPLDIR="./";
my $TPLFILE="$TPLDIR/pxls122.tmpl";



my $valuta={};

# =============================================================
my $REDIRECT=undef;

my $tmpl={};
$tmpl->{config}=$config;
$tmpl->{form}={};
$tmpl->{form}->{config_id}=$config_id;

$tmpl->{is_debug}=0;


#####################################################################
### ============================================================= ###
###                    M A I N     C Y C L E                      ###
### ============================================================= ###
#####################################################################

my $action=param('a')||'';
$tmpl->{form}->{a}=$action;


	my $FILENAME='';

	#==============================================
	if($action eq 'upload_file')
	{
		$FILENAME=upload_file('filename', $UPLOAD, $$, 10_000_000);

		if( $FILENAME ){
			$tmpl->{form}->{new_filename}=$FILENAME;

			my ($price_dump_ref, $cols)=prepare_price($FILENAME);
	    	if($price_dump_ref){
		        $tmpl->{price}          = $$price_dump_ref;
    		}
		    else{
    		    $tmpl->{price}          = '������ ��������� �����';
	    	}

			$tmpl->{fields}		= $config->{item}->{fields};
			$tmpl->{cols}		= $cols;
			$tmpl->{is_setup}	= 1;
		}
	}
	#==============================================
	elsif($action eq 'parse')
	{
		$FILENAME=param('new_filename');
		my $ROW_START=param('row_start')||0;

		my @field_list	= keys %{ $config->{item}->{fields_hash}->{dynamic} };
		my $field_col	= {};

		foreach my $cgi_param (param()){
			foreach my $field (@field_list){
				if( $cgi_param =~ /^${field}_(\d+)$/ ){
					if(param( $cgi_param ) =~ /^(\d+)$/){
						$field_col->{ $field } ||= [];
						push @{ $field_col->{ $field } }, $1;
					}
				}
			}
		}

		$config->{cols}=$field_col;
		saveConfigData( $dbh, $config->{key}, 'cols', packFieldCol( $config->{cols} ) );

		#=== ����� ������� ===
		#
		($$tmpl{insert_cnt},$$tmpl{insert_group_cnt},$$tmpl{updated_cnt})=
		parse_file3({
			file		=> $FILENAME,
			field_col	=> $config->{cols},
			row_start	=> $ROW_START,
			parent		=> $config->{tree}->{fields_hash}->{core}->{parent}->{default},
			config		=> $config,
		});

		#
		#=====================

		# debug
		$tmpl->{heap}=packFieldCol( $config->{cols} ) . "==" . $FILENAME;

		$tmpl->{is_parsed}=1;

		if( (exists $$config{run_scripts}{after_parse}) && (ref($$config{run_scripts}{after_parse}) eq 'ARRAY') ){
			foreach (@{ $$config{run_scripts}{after_parse} }){ `$_` }
		}
	}
	#==============================================
	else
	{
		# $tmpl->{heap}="project_id: $project_id<br>\n";
		# $tmpl->{heap}="use_project_id: $config->{use_project_id}<br>\n";
		$tmpl->{is_form}=1;
	}

# print "Content-type: text/html; charset=windows-1251\n\n";
$template->process('pxls122.tmpl', $tmpl);


###################################################################################
### =========================================================================== ###
###################################################################################

# =============================================================
sub parse_file3
{
    my ($PARAM)=@_;

    my $added_cnt=0;
    my $diff_cols={};

    foreach my $f (keys %{ $PARAM->{field_col} })
	{
        foreach my $c (@{ $PARAM->{field_col}->{ $f } })
		{
            $diff_cols->{ $c }=1;
        }
    }

    my $oFmtJ=Spreadsheet::ParseExcel::FmtUnicode->new( Unicode_Map => 'CP1251' );

    my $parser=Spreadsheet::ParseExcel->new();
    my $wb=$parser->Parse("$UPLOAD/$PARAM->{file}", $oFmtJ);

    my $ws=$wb->Worksheet(0);
    return undef if($ws!~/Spreadsheet/);

	#=========================
    my ($r_min,$r_max)=$ws->row_range();
	$r_min=$PARAM->{row_start} if($PARAM->{row_start});

    my $r_col_names=$r_min++;
	my $r_head=undef;

    my ($c_min,$c_max)=$ws->col_range();

	my $pfx=0;

	#=========================
	my $head=[];
	foreach my $c ($c_min..$c_max){
		my $cell=$ws->get_cell($r_col_names, $c);
		if($cell){
			my $val=$cell->unformatted;
			if($cell->{Code} && $cell->{Code}=~/ucs2/){
	        	$val=encode('CP1251',decode("UCS-2BE", $val));
				$head->[$c]=$val;
        	}
		}
	}

	#=========================
	# ���� ��������� �������� ������
	#
	while($r_max>$r_min)
	{
		my $t='';
		foreach my $c ($c_min..$c_max){
			my $cell=$ws->get_cell($r_max, $c);
			$t.=$cell->unformatted if $cell;
		}
		last if length($t)>1;
		$r_max--;
	}

	# print STDERR "r_max=$r_max\n";

	#=========================
	if(param('items_only'))
	{
=c
		printf "<pre>%s</pre><br>",Dumper($$PARAM{field_col});
		printf "<pre>%s</pre><br>",Dumper($diff_cols);
		printf "<pre>%s</pre><br>",Dumper($r_col_names);
		printf "<pre>%s</pre><br>",Dumper($head);
		exit;
=cut

		my ($cnt, $cnt2, $cnt3)=
		load_goods({
			r_min 		=> $r_min,
			r_max		=> $r_max,
			c_min		=> $c_min,
			c_max 		=> $c_max,
			ws          => $ws,
			config		=> $$PARAM{config},
            cols        => $$PARAM{field_col},
            head        => $head,
		});
	}
	#=========================
	else
	{
		my ($cnt, $cnt2, $cnt3)=
		parse_block(
			$pfx, $r_head, $r_min, $r_max, $c_min, $c_max, $PARAM->{parent},
			{
				ws			=> $ws,
				cols		=> $PARAM->{field_col},
				diff_cols	=> $diff_cols,
				r_col_names	=> $r_col_names,
				head		=> $head,
				valuta		=> $PARAM->{valuta},
				config		=> $$PARAM{config},
			},
		);

		return ($cnt, $cnt2, $cnt3);
	}
}


# =============================================================
sub prepare_price
{
    my ($file)=@_;

    my $oFmtJ = Spreadsheet::ParseExcel::FmtUnicode->new(Unicode_Map=>'CP1251');

    my $parser=Spreadsheet::ParseExcel->new();
    my $wb=$parser->Parse("$UPLOAD/$file",$oFmtJ);

	# print "Content-type: text/plain\n\n$file\n";
	# return undef;

    my $ws=$wb->Worksheet(0);
    if($ws!~/Spreadsheet/){
        $tmpl->{heap} .= "Module error<bR>";
        return undef;
    }

        my ($r_min,$r_max)=$ws->row_range();
        my ($c_min,$c_max)=$ws->col_range();

    
        my $fill={};
        my @rval=();
    
        $r_max=$r_max>105?105:$r_max;
        for my $r ($r_min..$r_max){
            my @cval=();
            for my $c ($c_min..$c_max){
                my $cell=$ws->get_cell($r,$c);
                my $val=($cell)?$cell->unformatted:'';
				if($cell->{Code}=~/ucs2/){
					$val=encode('CP1251',decode("UCS-2BE", $val));
				}
                # my $idx=$c+100;
                $fill->{$c}=0 if(!$fill->{$c});
                $fill->{$c}++ if($cell && (length($val)>0));
                push(@cval,$val?substr($val,0,100):'');
            }
	    # next if(join('',@cval) eq '');
            push(@rval,{r=>$r,cval=>\@cval});
        }
    
		foreach my $fk (keys %$fill){
			delete $fill->{$fk} if !$fill->{$fk};
		}

        my $COLS=[];

        my $out='';
        # $out.="cmin=$c_min, cmax=$c_max<BR>";
        $out.='<TABLE class="price1" border="1">';
        my $head='<td class="sel head" align="center" style="color:white;font-weight:bold;">\/</td>';
        foreach my $k (sort { $a<=>$b } keys %$fill){
            # next if !$fill->{$k};
            # $k-=100;

            push @$COLS, $k;

            my $kselect='';
            $head.=qq{<TD class="sel head" align="center" width="150"><nobr><b>������� $k</b>$kselect</nobr></TD>};
        }
        $head="<TR>$head</TR>";
        $out.=$head;

        foreach my $rec (@rval){
            my ($r,$row)=($rec->{r},$rec->{cval});
            my @out1=(qq{<td><input name="row_start" value="$r" type="radio"></td>});
            for(my $i=0; $i<scalar(@$row); $i++){
                next if not exists $fill->{($i+$c_min)};
				#my $val=encode('cp1251',encode('utf8',$$row[$i]));
				my $val=$row->[$i] ? $row->[$i] : '&nbsp;';
				# $val=encode('cp1251',$val);
                push(@out1,"<TD>$val</TD>");
            }
            $out.="<TR>".join('',@out1)."</TR>";
        }
        $out.='</TABLE>';
        return \$out, $COLS;
}

# =============================================================
#
# ����������� �������.
# � ������� ����� ���� ��������� �����. �������������, ���
# ��������� ������ ������ �������� �����, �.�. � �������������� 
# ���������.
#
sub parse_block
{
=c
	parse_block(
		$pfx, $r_head, $r_min, $r_max, $c_min, $c_max, $tree_id,
		{
			ws			=> $ws,
			cols		=> $cols,
			diff_cols	=> $diff_cols,
			r_col_names	=> $r_col_names,
			valuta		=> $valuta,
			owner_id	=> $owner_id,
		},
	);
=cut

	my ($pfx, $r_head, $r_min, $r_max, $c_min, $c_max, $parent_id, $CONST) = @_;

	my $r_color;
	my $g_color;

	my $goods=undef;

	my $groups=undef;
	my $group_start=undef;

	my $c_index=$$CONST{cols}{header}[0];

	my $ws=$$CONST{ws};

	while($r_max>$r_min)
	{
		last if $ws->get_cell($r_max, $c_index);
		$r_max--;
	}

	if($r_max>$r_min)
	{
		# print LOG "r_max/r_min: $r_max/$r_min, c_index: $c_index\n";
		# �������� ���� ���������

		my $color_1st =$ws->get_cell($r_min,$c_index)->{Format}->{Fill}->[1];
		my $color_2nd =$ws->get_cell($r_min+1,$c_index)->{Format}->{Fill}->[1];
		my $color_last=$ws->get_cell($r_max,$c_index)->{Format}->{Fill}->[1];

		if($color_1st eq $color_last)
		{
			# ���� ����� ���������� -- �� �������� ���. �� ������ ������ ���� ���������.
			my $r=$r_min;
			$group_start=$r_min;

			while($r<$r_max)
			{
				my $color_cur=$CONST->{ws}->get_cell($r,$c_index)->{Format}->{Fill}->[1];
				if($color_cur ne $color_1st)
				{
					# ������� ���������
					$groups=[] if !$groups;

					my $gr={};
					$gr->{r_head} = scalar(@$groups)?$group_start:undef; #$r_head;
					$gr->{start}  = $group_start;
					$gr->{stop}   = $r-1;

        			push @$groups, $gr;
					$group_start=$r;
				}
				$r++;
			}

        	push @$groups, {
					r_head => $group_start,
					start  => ($group_start+1),
					stop   => $r_max,
			} if $groups;

			$goods=[$r_min..$r_max] if !$groups;
		}
		else
		{
			# ���� ���������
			$g_color=$color_1st;
			$group_start=$r_min++;
			$groups=[];

			# ��������� ���� �� ������
			my $r=$r_min;
        	while($r<$r_max)
			{
				my $cell=$CONST->{ws}->get_cell($r,$c_index);

        		$r_color=undef;
				$r_color=$cell->{Format}->{Fill}->[1] if $cell;

        		if($r_color eq $g_color){
        			push @$groups, {
							r_head => $group_start,
							start  => ($group_start+1),
							stop   => ($r-1),
					};
        			$group_start = $r;
        		}
				$r++;
        	}
        	# if($group_start<$r_max){
        	push @$groups, {
					r_head => $group_start,
					start  => ($group_start+1),
					stop   => $r_max,
			};
        	# }
		}
	}
	else{
		$goods=[$r_min];
	}

	#===========================
	my $group_cnt			= 0;
	my $goods_cnt			= 0;
	my $goods_cnt_updated	= 0;
	#===========================

	print "groups: ", $groups?$#$groups+1:'undef', "\n";
	print "goods: ", $goods?$#$goods+1:'undef', "\n";
	exit;

	if($groups)
	{
		foreach my $gr(@$groups)
		{
			# Create Node
			my $data=get_data($gr->{r_head}, $c_min, $c_max, $CONST);

			my $node_id=p3_add_node($data, $parent_id, $CONST->{owner_id});
			$group_cnt++;

			my ($cnt, $cnt2)=parse_block($pfx+1, $gr->{r_head}, $gr->{start}, $gr->{stop}, $c_min, $c_max, $node_id, $CONST);

			# print LOG "$node_id: $cnt\n";
			if($cnt){
				$goods_cnt+=$cnt;
			}
			else{
				p3_delete_node($node_id);
				$group_cnt--;
			}
		}
	}

    if($goods)
	{
		# Create Goods
		foreach my $r_good (@$goods)
		{
			my $data=get_data($r_good, $c_min, $c_max, $CONST);
	        my $result=p3_add_point($data, $parent_id, $CONST->{cols}, undef, $CONST->{valuta}, $CONST->{head});
			if( $result ){ $result > 0 ? $goods_cnt++ : $goods_cnt_updated++ }
		}
	};

	return ($goods_cnt, $group_cnt, $goods_cnt_updated);
}
# =============================================================
sub get_data
{
	my ($r,$c_min,$c_max,$CONST)=@_;

	my $data=[];

	if($r){
	    for my $c ($c_min..$c_max){

    	    my $cell=$CONST->{ws}->get_cell($r,$c);
        	my $val=($cell)?$cell->unformatted:'';

			if($cell && $cell->{Code} && $cell->{Code}=~/ucs2/){
				$val=encode('CP1251',decode("UCS-2BE", $val));
			}

	        $val=~s/^\s+|\s+$//g;
			push @$data, $val;
		}
	}
	else{
		push @$data, '����� ������';
	}

	return $data;
}

# =============================================================
sub p3_delete_node
{
	my ($node_id)=@_;

	my $db_table	= $config->{tree}->{table};
	my $tab_id		= $config->{tree}->{fields_hash}->{core}->{id}->{db_name};

	my $cmd=
		"DELETE FROM $db_table ".
		"WHERE $tab_id='$node_id'".
			($config->{use_project_id} && ($db_table !~ /^(?:test_)?struc/) ? " && project_id=$project_id" : '');
	# print LOG "delete: $node_id\n";
	$dbh->do($cmd);
}

# =============================================================
sub p3_add_node
{
    my ($data,$parent,$owner_id)=@_;

	my $db_table	= $config->{tree}->{table};
	my $tab_id		= $config->{tree}->{fields_hash}->{core}->{id}->{db_name};
	my $tab_parent	= $config->{tree}->{fields_hash}->{core}->{parent}->{db_name};
	my $tab_header	= $config->{tree}->{fields_hash}->{core}->{header}->{db_name};
	my $tab_path	= $config->{tree}->{fields_hash}->{core}->{path}->{db_name};
	my $tab_sort	= $config->{tree}->{fields_hash}->{core}->{sort}->{db_name};

    my $name='';
    foreach my $val (@$data){
        $name.="$val " if $val;
    }
    $name=~s/\s+/ /g;
    $name=~s/^\s+|\s+$//g;
    $name=~s/[\\']/\\$1/g;
	$name='---' if !$name;

	my $parent_path;

	if(defined $parent){
		my $cmd=
			"SELECT $tab_path ".
			"FROM $db_table ".
			"WHERE ".
				"$tab_id=$parent".
					($config->{use_project_id} && ($db_table !~ /^(?:test_)?struc/) ? " && project_id=$project_id" : '');

		# print "$cmd<br>\n<br>\n";
    	($parent_path)=$dbh->selectrow_array($cmd);
	}
    $parent_path||='';
    $parent_path=~s/'//g;

	my $max_sort=$dbh->selectrow_array(
		"SELECT MAX($tab_sort) ".
		"FROM $db_table ".
		"WHERE ".
			($tab_parent?"$tab_parent='$parent'":"$tab_parent IS NULL").
			($config->{use_project_id} && ($db_table !~ /^(?:test_)?struc/) ? " && project_id=$project_id" : '')
	);
	$max_sort||=0;
	$max_sort++;

	my @set=();
	push @set, "$tab_parent=?";
	push @set, "$tab_path=?";
	push @set, "$tab_header=?";
	push @set, "$tab_sort=?" if $tab_sort;
	push @set, "project_id=$project_id" if $config->{use_project_id} && ($db_table !~ /^(?:test_)?struc/);

    my $cmd="INSERT INTO $db_table ".
            "SET ". join(',', @set);

	my $node_id=undef;		
	# print "<br>$cmd<br>".join('|',($parent?$parent:undef, "$parent_path->[0]/$parent", $name))."<br>";

    $dbh->do($cmd, undef, ($parent ? $parent : undef), (defined $parent ? "$parent_path/$parent" : ''), $name, $max_sort);

   	$node_id=$dbh->last_insert_id( undef, undef, $db_table, undef );

    return $node_id;
}

# =============================================================
sub p3_add_point
{
    my ($data, $parent, $cols, $owner_id, $valuta, $head)=@_;

	my $db_table	= $config->{item}->{table};
	my $tab_id		= $config->{item}->{fields_hash}->{core}->{id}->{db_name};
	my $tab_tree_id	= $config->{item}->{fields_hash}->{core}->{tree_id}->{db_name};

	my $fields_hash = $config->{item}->{fields_hash}->{dynamic};


	my $point_id=undef;
    my $point={};

    foreach my $f (keys %$cols){

        my $j=0;
        foreach my $i (@{ $cols->{$f} }){
            $point->{$f}.='; ' if $j;
            if($data->[$i]){
                if($f=~/^cena_/){
                    $point->{$f}=$data->[$i];
                }
                else{
                    $point->{$f}.=( ($j || ($fields_hash->{$f}->{concat} && $f ne 'header') ) ?
                                    ($head->[$i] ? "$head->[$i]: " : ' ') : '' ).($data->[$i]);
                }
            }
            $j++;
        }

		if($point->{$f}){
    	    $point->{$f}=~s/;\s+$//g;
	        $point->{$f}=~s/\s+/ /g;
        	$point->{$f}=~s/^\s+|\s+$//g;
		}

        my $s=$fields_hash->{$f}->{s};
        if($s){
            foreach my $s1 (@{ $s }){
				if($point->{$f}){
                	$point->{$f}=~s/$s1->[0]/$s1->[1]/gsi
				}
            }
        }

		if($point->{$f}){ $point->{$f}=~s/([\\'])/\\$1/g; }

		# FOR UPDATE
		if($config->{item}->{fields_hash}->{unique}){

			my $tab_uniq=$config->{item}->{fields_hash}->{unique}->{name};

			my $cmd=
				"SELECT $tab_id ".
				"FROM $db_table ".
				"WHERE $tab_uniq=?".
					($config->{use_project_id} && ($db_table !~ /^(?:test_)?struc/) ? " && project_id=$project_id" : '');

			($point_id)=$dbh->selectrow_array(
				$cmd, undef, $point->{$tab_uniq});

			# print LOG "UNIQ $tab_uniq = $point_id\n\n";
		}

    }

    my @set=();

    foreach my $f (sort keys %$point){
        push @set, "$f='".($point->{$f}?$point->{$f}:'')."'";
    }

	push @set, "project_id=$project_id" if $config->{use_project_id} && ($db_table !~ /^(?:test_)?struc/);


	# print LOG "p3_add_point: point_id=$point_id; ", join('; ', @set), "\n";

	if($point_id)
	{
		my $cmd="UPDATE $db_table SET ".join(', ', @set)." WHERE $tab_id='$point_id'";
		# print "$cmd<br>";
		$dbh->do($cmd);
		return -1;
	}
	else
	{
	    push @set, "$tab_tree_id=$parent" if $tab_tree_id;
    	my $cmd="INSERT INTO $db_table SET ".join(', ', @set);
		# print "$cmd<br>";
	    return $dbh->do($cmd);
	}
}

# =============================================================
sub upload_file
{
    my ($p,$dir,$fname_pfx,$size_max)=@_;
    $size_max||=4*1024*1024;
    # $p='doc_file';

    my $is_uploaded=undef;
    my $fname='';

    my $fh=param($p);
    if($fh){
        my ($file_ext) = $fh =~ /\.([^\.]+)$/s;
        $fname=sprintf "%s_%d.%s", $fname_pfx, time, $file_ext;
        my $i=0;
        while($i++<100 && -e "$dir/$fname"){
            $fname=sprintf "%s_%d_%d.%s", $fname_pfx, time, $i, $file_ext;
        }

        my $size=0;
        my $buff='';
        my $buff_size=1024;

        umask 0111;
        open DOC, ">$dir/$fname";
        binmode DOC;
        my $cnt=0;
        while($size<=$size_max){
            $cnt=read($fh, $buff, $buff_size);
            last if not defined $cnt;

            $size+=$cnt;
            print DOC $buff;
            if($cnt<$buff_size){
                $is_uploaded=1; last;
            }
        }
        close DOC;
        unlink "$dir/$fname" unless $is_uploaded;
    }
    return $is_uploaded ? $fname : undef;
}

# =============================================================
sub loadConfigData
{
	my ($dbh, $ckey, $param)=@_;
	if($ckey && $param){
		my $cmd="SELECT data FROM pxls_config WHERE ckey=? && param=?";
		my ($data)=$dbh->selectrow_array($cmd, undef, $ckey, $param);
		return $data;
	}
	return undef;
}

# =============================================================
sub saveConfigData
{
	my ($dbh, $ckey, $param, $data)=@_;
	if($ckey && $param && $data){
		my $cmd="INSERT INTO pxls_config SET ckey=?, param=?, data=? ON DUPLICATE KEY UPDATE data=?";
		return $dbh->do($cmd, undef, $ckey, $param, $data, $data);
	}
	return undef;
}

# =============================================================
sub packFieldCol
{
	my ($field_col)=@_;
	my $col_str='';

	foreach my $field (keys %$field_col){
		$col_str.="$field:".join(',', @{ $field_col->{ $field } }).";";
	}

	return $col_str;
}

# =============================================================
sub unpackFieldCol
{
	my ($col_str)=@_;
	return undef if not defined $col_str;

	my $field_col={};

	while($col_str=~s/^([^\:]+)\:([^\;]+);//){
        $field_col->{$1}=[ split(/,/, $2) ];
    }

	return $field_col;
}

# =============================================================
sub load_goods
{
	my ($p)=@_;
=c
			r_min 		=> $r_min,
			r_max		=> $r_max,
			c_min		=> $c_min,
			c_max 		=> $c_max,
			ws          => $ws,
			config		=> $$PARAM{config},
            cols        => $$PARAM{field_col},
            head        => $head,
=cut

	#===========================
	my $group_cnt			= 0;
	my $goods_cnt			= 0;
	my $goods_cnt_updated	= 0;
	#===========================

	my $i=0;

	foreach my $r ($$p{r_min}..$$p{r_max})
	{
		# last if $i++>10;

		my $data=get_data($r, $$p{c_min}, $$p{c_max}, { ws => $$p{ws} });
		my $result=p3_add_point($data, $$data[ $$p{cols}{rubric_id}[0] ], $$p{cols}, undef, undef, $$p{head});
		if( $result ){ $result > 0 ? $goods_cnt++ : $goods_cnt_updated++ }
	}

	return ($goods_cnt, $group_cnt, $goods_cnt_updated);
}

# =============================================================
# =============================================================
1;
