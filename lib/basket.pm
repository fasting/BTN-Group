package basket;
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
	#&::print_header;

	if($action eq 'add'){ # ���������� ������ � �������
		my $rec=param('rec');
		my $count=param('cnt');

		if($rec=~m/^\d+$/ && $count=~m/^\d+$/){
			#print "add<br/>";
			&add_to_basket(
			{
			  record_id=>$rec,
			  count=>$count,
			  cookie_name=>$cookie_name
			});
		}
	}
	elsif($action eq 'clean'){
		&clean_basket($cookie_name);
		return;
	}
	elsif($action eq 'del'){ # �������� �� ������� �������� �������
			my $rec=param('rec');
			my $count=param('cnt');
			print "Content-type: text/html\n\n";
			print "rec: $rec; count: $count";
			exit;
			&del_from_basket(
			{
			  record_id=>$rec,
			  count=>$count,
			  cookie_name=>$cookie_name
			});
	}
	elsif($action eq 'basket_update'){
		my @idlist=param('rec_id');
		my @counts=param('cnt');
		my @values=();
		my $i=0;

		$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_count}=0;
		$::params->{TMPL_VARS}->{basket}->{$cookie_name}->{total_price}=0;


		foreach my $id (@idlist){
			push @values, qq{$id;$counts[$i]};
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


	my $exists=0;
	my $i=0;
	foreach my $v (@values){ # ���� ����� ����� ��� ������ ����� -- ������� ���-��
		if($v=~m/^(.+?);(.+)$/){
			my ($rec_id,$count)=($1,$2);
			if($rec_id==$opt->{record_id}){
				$values[$i]=qq{$rec_id;}.($count+$opt->{count});
				$exists=1;

				last;
			}
		}
		$i++;
	}

	unless($exists){ # ������ ������ � ������� ���, ��������� � ������
		push @values,qq{$opt->{record_id};$opt->{count}};
	}

	# ����������� ���-�� �������
	$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$opt->{count};

	# ��������� � ����
 my $price=get_price($opt->{cookie_name},$opt->{record_id});
 $::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}+=$price*$opt->{count};


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

	#print "record_id: $opt->{record_id} $opt->{cookie_name}<br/>";
	$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}=0;
	$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}=0;

	foreach my $v (@old){
		if($v=~m/^(.+?);(.+)$/){
			my ($rec_id,$count)=($1,$2);


			#&::print_header;
			#print "$rec_id!=$opt->{record_id}<br/>";

			if($rec_id!=$opt->{record_id}){ # ���������� ������ � ������� ������ �� ��������, ���. ������� �����
				#print qq{$rec_id;$count<br/>};
				push @values,qq{$rec_id;$count};

				# ����������� ���-�� �������
				$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$count;

				# ��������� � ����
				my $price=get_price($opt->{cookie_name},$rec_id);
				#print "price: $price<br/>";
				$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_price}+=$price*$count;
			}
			else{
				if($opt->{count}){
					$count-=$opt->{count};
					#print "Count: $count ($opt->{count})<br/>";
					if($count>0){
						push @values,qq{$rec_id;$count};
						$::params->{TMPL_VARS}->{basket}->{$opt->{cookie_name}}->{total_count}+=$count;
					}
				}
			}
		}
		$i++;
	}
	#exit;
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
 ���������� ��������� ������ � $params->{TMPL_VARS}->{BASKET}:
	{
		count_all=>[�����], # ����� ���-�� ������� (�������) � �������
		summa => [�����], # �����, �� ������� ������� �������
	}
=cut

	my $opt=shift;
	$opt->{cookie_name}='basket' unless($opt->{cookie_name});

	$::params->{basket}->{$opt->{cookie_name}}=$opt;
	if($opt->{good_table}){
		$::params->{basket}->{$opt->{cookie_name}}->{work_table}=$opt->{good_table};
		$::params->{basket}->{$opt->{cookie_name}}->{work_table_id}=$opt->{good_table_id};
	}
	else{
		$::params->{basket}->{$opt->{cookie_name}}->{work_table}=&::get_table_from_struct($opt->{struct});
		$::params->{basket}->{$opt->{cookie_name}}->{work_table_id}=&::get_work_table_id_for_struct($opt->{struct});
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

 	my $sth=$::params->{dbh}->prepare(qq{
		SELECT $basket->{field_price} from $basket->{work_table} WHERE $basket->{work_table_id}=?
	});


	foreach my $v (@values){ # ���� ����� ����� ��� ������ ����� -- ������� ���-��
		if($v=~m/^(.+?);(.+)$/){
			my ($rec_id,$count)=($1,$2);

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
	@values = cookie($cookie_name);

	#if($basket->{struct}){
	foreach my $v (@values){
		if($v=~m/^(.+?);(.+)$/){
			my ($id,$cnt)=($1,$2);
			my $element;
			if($basket->{struct}){
				$element=&::GET_DATA({
					struct=>$basket->{struct},
					id=>$id,
					onerow=>1
				});
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
			$element->{count}=$cnt;
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
