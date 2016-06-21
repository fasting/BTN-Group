package basket_par;
use CGI::Fast qw(:standard);
use CGI::Cookie;
use CGI::Carp qw/fatalsToBrowser/;
use Data::Dumper;
use DBI;
#use cms_struct;
BEGIN {
		use Exporter ();
		@ISA = "Exporter";
		@EXPORT = 
		(
			'&add_to_basket', '&clean_basket','$params','&processing_basket', '&init_basket',
			'&basket_info','&basket_full_info'
		);
}
# ��������� �� ��������� ������
our $params;

sub processing_basket{	
	my $action=param('action');
	my $cookie_name=param('basket');
	$cookie_name='basket' unless($cookie_name);	
	my $attr=undef;
	
	foreach my $attr_name (@{$::params->{basket}->{$cookie_name}->{attr_list}}){
		#print "$attr_name: ".param('attr_'.$attr_name).'<br>';
		$attr->{$attr_name}=param('attr_'.$attr_name);
	}
	#&::print_header;
	if($action eq 'add'){ # ���������� ������ � �������
		my $rec=param('rec');
		my $count=param('cnt');
		# ����� � ����������

=cut
		# �������� �������� � ����:
		[
			{
				name=>'..',
				value=>'..'
			}
		]
=cut
		#print "Content-type: text/html\n\nattr:".Dumper($attr)."<br>";exit;


		# 30.09.2014 ������� \d �� \w �� ������� ������������� �� ��������� �� � �������
		# if($rec=~m/^\d+$/ && $count=~m/^\d+$/){
		if($rec=~m/^\w+$/ && $count=~m/^\d+$/){
			#print "add<br/>";
			&add_to_basket(
			{
			  record_id=>$rec,
			  count=>$count,
			  cookie_name=>$cookie_name,
			  attr=>$attr # ������� ������ ��������� � �������� ��� ������������ ������
			});
		}
	}
	elsif($action eq 'clean'){
		&clean_basket($cookie_name);
		return;
	}
	elsif($action eq 'del'){ # �������� �� ������� �������� �������
			#print "action: del"; exit;
			my $rec=param('rec');
			my $count=param('cnt');
			&del_from_basket(
			{
			  record_id=>$rec,
			  count=>$count,
			  cookie_name=>$cookie_name,
			  attr=>$attr
			});
			$::params->{basket}->{basket}->{cur_record_count}=$count;
			&basket_full_info({basket=>$params->{basket}->{basket}});
	}
	elsif($action eq 'basket_update'){
		my @idlist=param('rec_id');
		my @counts=param('cnt');
		my @values=();
		my @attr=(); # ���� �������� ��������
		my $i=0;
	#print "Content-type: text/html\n\n";
	# $attr -- ������ ��������� ���������
	
	foreach my $attr_name (keys(%{$attr})){
		my @tmp=();
		@tmp=param('attr_'.$attr_name);
		my $i=0;
		foreach my $v (@tmp){
			if($attr[$i]){$attr[$i].=';;'}
			$attr[$i].="$attr_name=$v";
			$i++;
		}
	}
	
	#print '<pre>777'.Dumper(\@attr).'</pre>';exit;
		$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_count}=0;
		$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_price}=0;
		
		
		foreach my $id (@idlist){
			push @values, qq{$id;$counts[$i];$attr[$i]};
			# ����������� ���-�� �������
			$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_count}+=$counts[$i];

			# ������������� �����, �� ���. ��������� �������:
			my $price=get_price($cookie_name,$id);

			$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_price}+=$counts[$i]*$price;			
			$i++;
		}
		
		my $cookie=new CGI::Cookie(
			-name=>$cookie_name,
			-value=>[
				@values
			]
		);		
		print "Set-Cookie: $cookie\n";
		undef(@values);		
		#&::print_header;
		#print "total_price: $::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_price}<br>";
	}
	#&basket_full_info();
	
	#print "action: $action";
	
}
sub add_to_basket{
=cut
���������� � �������
{
	cookie_name=>[������������ ����, � ���. ����� ��� ������], # �� ��������� basket
	record_id=>[��-���� ������]
	count=>[���-��]
}
=cut		
	my $opt=shift;
	$opt->{cookie_name}='basket' unless($opt->{cookie_name});
	$opt->{count}=1 unless($opt->{count});

	# �������� ������ �������� cookie � ��������� ���
	@values = cookie($opt->{cookie_name});
	# �������� ��� ��������� � �� ��������
	
	
	my $exists=0;
	my $i=0;
	#print "Content-type: text/html\n\n";
	#&::pre($::params->{TMPL_VARS}->{basket}->{basket});
	foreach my $v (@values){ # ���� ����� ����� ��� ������ ����� -- ������� ���-��
		
		if($v=~m/^(.+?);(\d+);(.+)?$/){
			#print "attr_string: $attr_string<br>";
			my ($rec_id,$count,$attr_string)=($1,$2,$3);
			
			# ������� �������� ��������� ���� ������ � ����������� id, �������� � ������� �����������
			my $attr_complete=1;
			if($::params->{basket}->{$opt->{cookie_name}}->{attr_list}){
				while($attr_string=~m/([^;]+?)=([^;]+?)/g){
					my ($attr_name,$attr_value)=($1,$2); # -- ��� �������� � �������� ��� ������ �� �������
					
					foreach my $name (@{$::params->{basket}->{$opt->{cookie_name}}->{attr_list}}){ # ������� �� ���� ���������
						if(($name eq $attr_name) && ($attr_value ne $opt->{attr}->{$name})){
						# ���� �������� ����������, �� �� �������� ������, ����� ������ ������
							$attr_complete=0 
						}
					}
				}
			}
			# attr -- ������� ����������� ������ � ����: [�������]=��������;[�������]=��������;....
			
			if($attr_complete && $rec_id==$opt->{record_id}){
				$values[$i]=qq{$rec_id;}.($count+$opt->{count}).qq{;$attr_string};
				$exists=1;
				$::params->{TMPL_VARS}->{basket}->{basket}->{cur_record_count}=($count+$opt->{count});			
				last;
			}
		}		
		$i++;
	}
	#pre($::params->{TMPL_VARS}->{basket}->{cur_record_count});
	#&::pre($opt);
	$params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$opt->{count};
	#$params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}+=(&get_price($opt->{cookie_name},$opt->{record_id})*$opt->{count});
	#&::pre($::params->{TMPL_VARS}->{basket}->{basket});
	unless($exists){ # ������ ������ � ������� ���, ��������� � ������
		# ������������ ������ ��������� � ���� "���=��������&���=��������&..."
		my $attr_string='';
		# ���������� ������ ���������, ����������� ��� �������������
		
		#print '<pre>'.Dumper($opt->{attr}).'</pre>';
		foreach my $attr_name (@{$::params->{basket}->{$opt->{cookie_name}}->{attr_list}}){
			if($attr_string){$attr_string.=';;'}
			$attr_string.=$attr_name.'='.$opt->{attr}->{$attr_name}
		}
		
		
		push @values,qq{$opt->{record_id};$opt->{count};$attr_string};

		
	}

	# ����������� ���-�� �������
	#$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$opt->{count};
	
	# ��������� � ����
	my $price=$::params->{TMPL_VARS}->{basket}->{cur_record_price}=get_price($opt->{cookie_name},$opt->{record_id});
	$::params->{TMPL_VARS}->{basket}->{cur_record_total_price}=$::params->{TMPL_VARS}->{basket}->{cur_record_count}*$price;
	
	$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}+=$price*$opt->{count};
	#&pre($::params->{TMPL_VARS}->{basket});
	
# �������� � ����:
# ["$rec_id;$count", "$rec_id;$count", "$rec_id;$count",...]	
	my $cookie=new CGI::Cookie(
			-name=>$opt->{cookie_name},
			-value=>[
				@values
			]
	);
	print "Set-Cookie: $cookie\n";
	undef(@values);
	
	#print "$opt->{cookie_name}<br/>".Dumper($::params->{TMPL_VARS}->{basket});
}
sub del_from_basket{
	my $opt=shift;
	$opt->{cookie_name}='basket' unless($opt->{cookie_name});
	@old = cookie($opt->{cookie_name});
	@values=();
	my $i=0;
	#&::print_header;	
	$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}=0;
	$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}=0;
	foreach my $v (@old){
		my $exitsts=0;
		
		if($v=~m/^(.+?);(\d+);(.+)?$/){
			my ($rec_id,$count,$attr_string)=($1,$2,$3);
			my $attr_complete=1;
			if($::params->{basket}->{$opt->{cookie_name}}->{attr_list}){
				while($attr_string=~m/([^;]+)=([^;]+)/g){
					my ($attr_name,$attr_value)=($1,$2); # -- ��� �������� � �������� ��� ������ �� �������
					foreach my $name (@{$::params->{basket}->{$opt->{cookie_name}}->{attr_list}}){ # ������� �� ���� ���������
						if(($name eq $attr_name) && ($attr_value ne $opt->{attr}->{$name})){
							$attr_complete=0;
						}
					}
				}
			}

			my $price=get_price($opt->{cookie_name},$rec_id);
			$::params->{TMPL_VARS}->{basket}->{cur_record_price}=$price;
			if($attr_complete && $rec_id==$opt->{record_id}){ # ������� �������
				$exists=1;
				#print "del<br>";
				if($opt->{count}){
					$count=$count-$opt->{count};
					
					#print "Count: $count ($opt->{count})<br/>";
					if($count>0){
						$::params->{TMPL_VARS}->{basket}->{basket}->{cur_record_count}=$count;
						push @values,qq{$rec_id;$count;$attr_string};
						$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$count;
					}
					else{
						$::params->{TMPL_VARS}->{basket}->{cur_record_count}=0;
						#$::params->{TMPL_VARS}->{basket}->{cur_record_total_price}=0;
					}
				}
				$::params->{TMPL_VARS}->{basket}->{cur_record_total_price}=$price*$::params->{TMPL_VARS}->{basket}->{cur_record_count};
				
			}
			else{ # ���������� (�� �������) �������
				# ���������� ������ � ������� ������ �� ��������, ���. ������� �����
				push @values,qq{$rec_id;$count;$attr_string};
				$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$count;
				$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}+=$price*$count;
			}

		}		
		$i++;
	}
	#exit;
	unless($exists){
		$::params->{TMPL_VARS}->{basket}->{cur_record_count}=$::params->{TMPL_VARS}->{basket}->{cur_record_total_price}=0;
	}
	my $cookie=new CGI::Cookie(
			-name=>$opt->{cookie_name},
			-value=>[
				@values
			]
	);
	print "Set-Cookie: $cookie\n";
	undef(@values);	
	
}
sub clean_basket{ # �������� �������
=cut
&clean_basket([cookie_name])
=cut	
 my $name=shift;
 $name='basket' unless($name);
 my $cookie=new CGI::Cookie(
			-name=>$name,
			-value=>[]
 );
 $::params->{basket}->{$name}=(); 
 $::params->{TMPL_VARS}->{basket}->{$name}=
 {
	total_count=>0,
	total_price=>0
 }; 
 print "Set-Cookie: $cookie\n";
}


sub init_basket{
=cut
������ ��������� �������������� �������

 ��. ���������
	cookie_name=>[], # �� ��������� cookie
	struct=>[], # ���������, � ���. �������� ���������� � �������
	good_table=>[], # ��� �������
	good_table_id=>[], # ��� �������� ������� ��������� ���� � id
	attr_list=>[] # ������ ���������, ������� ����� �������������� ���  ������
 ���������� ��������� ������ � $params->{TMPL_VARS}->{BASKET}:
	{
		count_all=>[�����], # ����� ���-�� ������� (�������) � �������
		summa => [�����], # �����, �� ������� ������� �������
	}
=cut
	
	my $opt=shift;
	$opt->{cookie_name}='basket' unless($opt->{cookie_name});
	
	$::params->{basket}->{$opt->{cookie_name}}=$opt;
	$::params->{basket}->{$opt->{cookie_name}}->{attr_list}=$opt->{attr_list};
	

	if($opt->{good_table}){
		$::params->{basket}->{$opt->{cookie_name}}->{work_table}=$opt->{good_table};
		$::params->{basket}->{$opt->{cookie_name}}->{work_table_id}=$opt->{good_table_id};
	}
	else{
		$::params->{basket}->{$opt->{cookie_name}}->{work_table}=&::get_table_from_struct($opt->{struct});
		$::params->{basket}->{$opt->{cookie_name}}->{work_table_id}=$opt->{work_table_id};
		$::params->{basket}->{$opt->{cookie_name}}->{work_table_id}=&::get_work_table_id_for_struct($opt->{struct}) unless($opt->{work_table_id});
	}
	
	unless($::params->{basket}->{$opt->{cookie_name}}->{work_table}){
		&::print_header("�� ������� ���������� ������� � �������� � �� ��� ������������� ���������");		
	}
}

sub basket_info{
	my $cookie_name=shift;
	$cookie_name='basket' unless($cookie_name);
	@values = cookie($cookie_name);
	my $total_count=0; # ����� �������
	my $total_price=0; # �� �����
	my $unique_count=0; # ���������� ������������
	my $basket=$::params->{basket}->{$cookie_name};
	$basket->{field_price}='price' unless($basket->{field_price});
	
#	&::print_header;
	
 	my $sth=$::params->{dbh}->prepare(qq{
		SELECT $basket->{field_price} from $basket->{work_table} WHERE $basket->{work_table_id}=?
	});

	#print "Content-type: text/html\n\n";
	foreach my $v (@values){ # ���� ����� ����� ��� ������ ����� -- ������� ���-��		
#		print "v: $v<br>";
		if($v=~m/^([^;]+?);([^;]+)/){			
			my ($rec_id,$count)=($1,$2);
			#print "($rec_id,$count)<br>";
			$total_count+=$count;
			$unique_count++ if($count);
			$::params->{basket}->{$cookie_name}->{'rec_'.$rec_id}=$count;
			# �������� ���������
			if($basket->{field_price}){
				$sth->execute($rec_id);
				my $price=$sth->fetchrow();
				$total_price+=$price*$count;
			}

			
		}		
		
	}
	$sth->finish();
	
	$::params->{TMPL_VARS}->{basket}->{$cookie_name}=
	{
		total_count=>$total_count,
		total_price=>$total_price,
		unique_count=>$unique_count
	};
}

sub basket_full_info{
	# ��������� ���������� � �������
	my $cookie_name=shift;
	$cookie_name='basket' unless($cookie_name);
	@values = cookie($cookie_name);
	my $total_count=0;
	my $total_price=0;
	my $basket=$::params->{basket}->{$cookie_name};
	$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{LIST}=[];
	@values = cookie($cookie_name);
	#print "Content-type: text/html\n\n";
	#if($basket->{struct}){
	foreach my $v (@values){ 
		#print "$v<br>";
		if($v=~m/^(.+?);(\d+);(.+)?$/){			
			my ($id,$cnt,$good_attr)=($1,$2,$3);
			my $element;
			#print "attr: $good_attr<br>";
			#exit;
			if($basket->{struct}){
				if($id =~ m/^(\d+)$/){
					$element=&::GET_DATA({
						struct=>$basket->{struct},
						id=>$id,
						onerow=>1
					});
				}else{
					$element=&::GET_DATA({
#						debug=>1,
						struct=>$basket->{struct},
						onerow=>1,
						where=>$basket->{work_table_id}.'=?',
					},$id);
				}
				$element->{id}=$id;

			}
			elsif($basket->{good_table}){
				$element=&::GET_DATA({
					table=>$basket->{good_table},
					id=>$id,
					select_fields=>$basket->{good_select_fields},
					onerow=>1
				});
				$element->{id}=$id;
			}
			
			while($good_attr=~m/([^;]+)=([^;]+)/g){
				$element->{good_attr}->{$1}=$2;
			}
			$element->{count}=$cnt;
			#print '<pre>'.Dumper($element).'</pre>';
			$total_count+=$cnt;
			$total_price+=$element->{$::params->{basket}->{$cookie_name}->{field_price}}*$cnt;
			push @{$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{LIST}},$element;
		}
		
		
	}

	$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_count}=$total_count;
	$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_price}=$total_price;
}
	
sub get_price{	
	my ($cookie_name,$id)=@_;
	return '' unless($::params->{basket}->{$cookie_name}->{field_price});
	$cookie_name='basket' unless($cookie_name);
	
	my $basket=$::params->{basket}->{$cookie_name};	
		
	# ���������� ���� ������ �� id
	my $sth=$::params->{dbh}->prepare("SELECT 
			$::params->{basket}->{$cookie_name}->{field_price} FROM
			$::params->{basket}->{$cookie_name}->{work_table} WHERE
			$::params->{basket}->{$cookie_name}->{work_table_id}=?
 ");
 
	$sth->execute($id);
	my $r=$sth->fetchrow();
	$sth->finish();
	return $r;
}

return 1;
END { }
