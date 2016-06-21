
sub fcgi_loop{
	# ������������ ����� �� "������ ���"
	if($ENV{PATH_INFO}=~m/^\/(files|templates|admin|manager)\// || $ENV{PATH_INFO}=~m/\.(swf|jpg|gif|png|css|ico|pdf|doc|xls|js)$/i){
		print "Content-type: text/html\nStatus: 404\n\n<h1 align='center'>Page Not Found...</h1>";
		return;
	}
	
	# ����������, ������������ �� ������������� �� �������� � "������"	
	$system->{use_project}=1;	
	&db_connect;
	&get_project_info;
	
	exit if($params->{stop});
	&print_header; 
	$params->{TMPL_VARS}->{TEMPLATE_FOLDER}=$params->{project}->{template_folder};
	$params->{TMPL_VARS}->{TEMPLATE_FOLDER}=~s/^.\//\//;
	eval(q{	
	my $template = Template->new(
	{
		INCLUDE_PATH => $params->{project}->{template_folder},
		COMPILE_EXT => '.tt2',
		COMPILE_DIR=>'./tmp',
		CACHE_SIZE => 512,
		PRE_CHOMP  => 1,
		POST_CHOMP => 1,
		DEBUG_ALL=>1,
		#EVAL_PERL=>1,
		FILTERS=>{
			get_url=>\&filter_get_url
		}

	});
	$template -> process($params->{template_name}, $params->{TMPL_VARS}) || croak "output::add_template: template error: ".$template->error();
	});
	if($@){
		print $@;
	}
	
	undef $params;
	
}

sub GET_DATA{
	my $opt=shift;
	my @val=@_;

	# ��� ������ � �������:
	my $table;
	
	# �������� ����� ������������ � ��� where (���� ���������� ��������� �������� � if ��������
	my @names=(); my @values=@val;
	# ���������� ����������� � ��
	my $connect; 
	unless($opt->{connect}){
		$opt->{connect}=$::params->{dbh};
	}

	if($opt->{select_fields}){
		$table->{select_fields}=$opt->{select_fields};	
	}
	else{
		$table->{select_fields}='*';
	}

	if($opt->{table}){
		$table->{from_table}=$opt->{table};
	}
	elsif($opt->{struct}){
		$table->{from_table}=&get_table_from_struct($opt->{struct});		

		if(!$opt->{onevalue} && !$opt->{select_fields}){
			my $sth=$opt->{connect}->prepare("SELECT body FROM struct WHERE project_id=? and table_name=?");
			$sth->execute($::params->{project}->{project_id}, $table->{from_table});
			my $body=$sth->fetchrow();						
			$body=~s/^.*(^|\n)\s*our\s*\%form/my \%form/gs;

			$body=~s/\$form->{project}->{project_id}/$::params->{project}->{project_id}/gs;

			# ��� ��������� ���������� ��������� ������
			$body.=q{$table->{work_table_id}=$form{work_table_id};};
			
			$body.=q{$table->{select_fields}.=qq{, $table->{work_table_id} as id};} unless($opt->{onevalue});
			
			$body.=q{				
				foreach my $field (@{$form{fields}}){
					if($field->{type} eq 'file'){
						my $fd=$field->{filedir};
						$fd=~s/^\.\.\//\//;
						$table->{select_fields}.=qq{, concat('$fd/',$field->{name}) as $field->{name}_and_path };
						my $i=1;
						while($field->{converter}=~m/output_file=['"](.+?)['"]/gs){							
							my $out=$1;
							next if ($out eq '[%input%].[%input_ext%]');
							$out=~s/\.\[%input_ext%\]/\[%input_ext%\]/;
							$out=~s/(\]|^)([^\[]+)\[/$1,'$2',\[/;
							
							$out=~s/\[%input%\]/substring_index($field->{name},'.',1)/;
							$out=~s/\[%input_ext%\]/'\.',substring_index($field->{name},'.',-1)/;
							$table->{select_fields}.=qq{, concat('$fd/',$out) as $field->{name}_and_path_mini$i };
							$i++;
						}
						
					}
				}
			};
			
			eval($body);
			if($@){
				$body=~s/\t/&nbsp;&nbsp;/gs;
				$body=~s/\n/<br\/>/gs;
				&::print_error ("��������� ������ ��� ������� �� ��������� $opt->{struct}<br/>=====<br/>$body<br/>=====<br/>".$@);
				return ;
			}				
		}	
		else{	
			$table->{work_table_id}=&get_work_table_id_for_table($table->{from_table});					
		}
	}

	
	if($opt->{url}){
		push @names,'url=?';
		push @values,$opt->{url};
	}
	
	if($opt->{id}=~m/^\d+$/){
		my $id=$opt->{id};
		unless($id=~m/^\d+$/){
			&::print_error ("id ������ ���� ������!");
			return ;
		}
		$table->{work_table_id}=&get_work_table_id_for_table($opt->{table}) if($opt->{table});
		push @names,"$table->{work_table_id}=?";
		push @values,$id;
	}
	
	if($opt->{where}){
		push @names,$opt->{where};		
	}

	if($opt->{order}){
		$table->{order}=qq{ ORDER BY $opt->{order}};
	}
	
	if(( 
				$table->{from_table}!~/^struct_\d+/ &&
				$::system->{use_project} &&
				!defined($opt->{not_use_project})
		 )
	)
	{
		push @names,"project_id=$::params->{project}->{project_id}";
	}

	if($opt->{tree_use} && $opt->{where}!~/path=\S+/){
		# ���� ������� �� ������ �� ������� �����
		if($opt->{where}=~m/parent_id\s*(=|is)\s*/i){
			# ���� ������ parent_id, �� � �������� ��������� ���������� ����� parent_id
			$opt->{tree_use}='parent_id';			
		}
		else{
			push @names, 'path=?';
			push @values,''
		}
	}

	$table->{where}=join(' AND ',@names); $table->{where}=qq{WHERE $table->{where}} if($table->{where});
	if($opt->{perpage}=~m/^\d+$/){ # � �ר��� ����������������
			$opt->{maxpage}=&SQL_row(qq{SELECT CEILING(count(*) / $opt->{perpage}) FROM $table->{from_table} $table->{where}},$opt->{connect},(@values));
			my $limit1=($::params->{TMPL_VARS}->{page}-1)*($opt->{perpage});
			$opt->{limit}=qq{$limit1, $opt->{perpage}};	
	}

	if($opt->{limit}=~m/(\d+)\s*(,\s*\d+)?/s){
		$table->{limit}=qq{ LIMIT $1$2};
	}
	
	# ������, ���. ����� �����������
	my $q=qq{SELECT $table->{select_fields} FROM $table->{from_table} $table->{where} $table->{order} $table->{limit} };
	
	if(defined($opt->{debug})){
		&::print_header;
		print "<hr>DUMPER<hr>SQL: $q<br>VALUES: ".Dumper(@values)."<br><br>";
	}		
	
	if(defined($opt->{onerow})){	
		my $r=&::SQL_hash($q,$opt->{connect},@values);				
		if($opt->{to_tmpl}){
				$::params->{TMPL_VARS}->{$opt->{to_tmpl}}=$r;
				return;
		}		
		return $r;
	}
	elsif(defined($opt->{onevalue})){
		my $r=&SQL_row($q,$opt->{connect},@values);
		if($opt->{to_tmpl}){
				$::params->{TMPL_VARS}->{$opt->{to_tmpl}}=$r;
				return;
		}		
		return $r;
	}
	else{
		my $r=&SQL_hash_all($q,$opt->{connect},@values);
		if($opt->{perpage}){ # ��� ���������������� ������ ������� ���������� ����. ��������
			if($opt->{to_tmpl}){
				$::params->{TMPL_VARS}->{$opt->{to_tmpl}}=$r;
				return $opt->{maxpage};
			}
			else{
				return ($r, $opt->{maxpage});
			}
		}
		elsif($r && $opt->{tree_use}){ # �������� (�������� �� ������)
			my $work_table_id=&get_work_table_id_for_table($table->{from_table});
			foreach my $rec (@{$r}){

				my @v=();
				if($opt->{tree_use} eq 'parent_id'){
					$opt->{where}=~s/parent_id\s*=\s*(\d+|\?)/parent_id=$rec->{$work_table_id}/;
				}
				else{
					$opt->{where}=qq{path='$rec->{path}/$rec->{$work_table_id}'};
				}

				# ������ "to_tmpl", ����� ��� �������� &GET_DATA �������� ��������
				my $to_tmpl=$opt->{to_tmpl}; $opt->{to_tmpl}='';
				$rec->{child}=&GET_DATA($opt,(@val,@v));
				if(@{$rec->{child}}){
					$rec->{href}=qq{/rubricator/$rec->{id}};
				}
				else{
					$rec->{href}=qq{/goods/$rec->{id}};
				}
				$opt->{to_tmpl}=$to_tmpl;
				if($opt->{debug}){
					print "<hr>CHILD: <hr>SQL: $rec->{child}<br><br>";
				}
			}
		}
		
		# ���������  ���-�� ������� ��� ������ �����
		if($opt->{good_calculate}){
			$opt->{hi_href}='/rubricator/[%id%]' unless($opt->{hi_href});
			$opt->{low_href}='/goods/[%id%]' unless($opt->{low_href});
			
			$opt->{good_calculate_struct}='good' unless($opt->{good_calculate_struct});
			foreach my $el (@{$r}){ 
				$el->{count}=&GET_DATA({
					struct=>$opt->{good_calculate_struct},
					select_fields=>'count(*)',
					where=>'rubricator_id=?',
					onevalue=>1,
				},$el->{id});
				if($el->{count}){
					my $href=$opt->{low_href};
					$href=~s/\[%id%\]/$el->{id}/g;
					$el->{href}=$href
				}
				else{
					my $href=$opt->{hi_href};
					$href=~s/\[%id%\]/$el->{id}/g;
					$el->{href}=$href
				}
			}
		}
		
		if($opt->{to_tmpl}){
			$::params->{TMPL_VARS}->{$opt->{to_tmpl}}=$r;
			return;
		}
		else{
			return $r;
		}
	}
}
sub SQL_hash_all{
  my $sql = shift;
  my $connect=shift;
  $connect=$::params->{dbh} unless($connect);
  my @vars = @_;
  my $sth = $connect->prepare($sql);
  eval q{$sth->execute(@vars) or die "�� ���� ���������: [$sql] $DBI::errstr\n";};	
  if($@){
		&::print_error (qq{
			SQL Error:<br>
			$sql<br/>
			$@
		});
		return;
	}
	my @a=();
	return \@a unless ($sth->rows());
  return $sth->fetchall_arrayref({}); 
  
}
sub SQL_hash{
  my $sql = shift;
  my $connect=shift;
  if(!$connect){
		$connect=$::params->{dbh};
	}
  my @vars=@_;
  my $sth = $connect->prepare($sql);
  eval(q{$sth->execute(@vars) or print "�� ���� ���������: [$sql] $DBI::errstr\n";});
   if($@){
		&::print_error (qq{
			SQL Error:<br>
			$sql<br/>
			$@
		});
		return;
	}
  return $sth->fetchrow_hashref();
}
sub get_work_table_id_for_struct{

	# ���������� Primary key ��� ���������
	my $struct=shift;	
	my $table=&get_table_from_struct($struct);
	my $work_table_id=&get_work_table_id_for_table($table);
	return $work_table_id;
}
sub get_work_table_id_for_table{
	# ���������� Primary KEY ��� �������
	my $table=shift;
	
	my $sth=$::params->{dbh}->prepare("show tables like ?");
	$sth->execute($table);
	if($sth->rows()){
	
		$sth=$::params->{dbh}->prepare("desc $table");
		$sth->execute();
	}
	else{
		return 0;
	}
	
	while(my $h=$sth->fetchrow_hashref()){
			return $h->{Field} if($h->{Key} eq 'PRI');
	}
	return 0;
}
sub SQL_row{
  my $sql = shift;
  my $connect=shift;
  $connect=$::params->{dbh} unless($connect);  
  my @vars=@_;
  my $sth = $connect->prepare($sql);
  eval q{$sth->execute(@vars) or warn "�� ���� ���������: [$sql] $DBI::errstr\n";};
	if($@){
		&::print_error (qq{
			SQL Error:<br>
			$sql<br/>
			$@
		});
		return;
	}
  return $sth->fetchrow();
}

# ===============================
# ��������� ������ � ���������
# ===============================
sub get_table_from_struct{
	my $struct=shift;
	# 1. ��� ��������� ����� ��������� � ������ ����� ������
	my $sth=$::params->{dbh}->prepare("SELECT count(*) FROM struct WHERE project_id=? AND table_name=?");
	$sth->execute($::params->{project}->{project_id},$struct);
	if(my $r=$sth->fetchrow()){ # ��
		return $struct;
	}
	else{ # ��������� ��������� ��� �������:
		return 'struct_'.$::params->{project}->{project_id}.'_'.$struct;
	}
}
sub db_connect{
	use vars qw($::params);
	if(!$::system->{dbh}){
		$::system->{dbh}=DBI->connect("DBI:mysql:$::system->{DBname}:$::system->{DBhost}",$::system->{DBuser},$::system->{DBpassword})|| die($::system->{dbh}->{errstr});#,{ RaiseError => 1 } );# || die($!);
		$::system->{dbh}->do("SET lc_time_names = 'ru_RU'");
		$::system->{dbh}->do("SET names CP1251");
		$::system->{dbh}->{mysql_auto_reconnect} = 1;
	}
	$::params->{dbh}=$::system->{dbh};
}

sub get_project_info{
	use vars qw($::params);
	my $domain=$::ENV{SERVER_NAME};
	$domain=~s/^www\.//;
	$::params->{project}=SQL_hash
	(
		q{
			SELECT 
				d.template_id,d.project_id,
				t.folder as template_folder,
				d.domain,d.domain_id,p.options,t.options template_options
			FROM domain d, project p, template t
			WHERE d.project_id=p.project_id AND d.domain=? AND d.template_id =t.template_id
		},
		undef,
		$domain
	);
	
	unless(index($::params->{project}->{options},';cache_in_nginx;')>=1){
		print "Cache-Control: no-cache\n";
	}
	
	# �������, ���� � ������� ������������� ���� � './templates'
	# ===
	if($::params->{project}->{template_folder}!~/^$::system->{TEMPLATE_DIR}/){
		$::params->{project}->{template_folder}=qq{$::system->{TEMPLATE_DIR}/$::params->{project}->{template_folder}};
	}
	# ===

	
	unless($::params->{project}->{project_id}){
		print_error('������ ����� �� ������');
		return ;
	}
	
### !!!! ������

	# ��������� ��������� ������� URL'��	
	Encode::from_to($::params->{PATH_INFO}, 'utf8', 'cp1251');
	
	# ������ �� XSS
	$ENV{PATH_INFO}=~s/>/&gt;/gs;
	$ENV{PATH_INFO}=~s/</&lt;/gs;
	
	# ���������� URL'�
	$::params->{PATH_INFO}=$ENV{PATH_INFO};
	$::params->{PATH_INFO}='/' unless($::params->{PATH_INFO});
	
	# ������������ URL'�
	if(index($::params->{project}->{options},';ex_links;')>=0){
					# ���� �� �������� ����� �� ��������, ��� ������� ������� ��� ������ ������������ url
					my $sth=$::params->{dbh}->prepare("SELECT ext_url FROM in_ext_url WHERE project_id=? and in_url=?");
					$sth->execute($::params->{project}->{project_id},$::params->{PATH_INFO});
					if($sth->rows()){
						my $newurl=$sth->fetchrow();
						print "Location: http://$::params->{project}->{domain}$newurl\n\n";
						$::params->{stop}=1;
						return ;
					}
					
					$sth=$::params->{dbh}->prepare("SELECT in_url FROM in_ext_url WHERE project_id=? and ext_url=?");
					$sth->execute($::params->{project}->{project_id},$::params->{PATH_INFO});
					$::params->{PATH_INFO}=$sth->fetchrow() if($sth->rows());
					$sth->finish();
	}

	sub get_const{
		my $q=qq{SELECT name,value from const};
		$q.=qq{ WHERE project_id=$::params->{project}->{project_id}} if($system->{use_project});
		my $sth=$::params->{dbh}->prepare($q); $sth->execute();
		while(my ($name,$value)=$sth->fetchrow()){$::params->{TMPL_VARS}->{const}->{$name}=$value;}
	}
	
# !!!! ����
	if(0 && index($::params->{project}->{options},';cache_const;')>=0){
		if(defined($CACHE->{$::params->{project}->{project_id}}->{cache_const})){
			$::params->{TMPL_VARS}->{const}=$CACHE->{$::params->{project}->{project_id}}->{cache_const};
		}
		else{
			&get_const;
			$CACHE->{$::params->{project}->{project_id}}->{cache_const}=$::params->{TMPL_VARS}->{const};
		}
	}
	else{
		# �������� ���������
		&get_const;
	}
	
	# ����������������....
	if($::params->{PATH_INFO}=~m/^(.+?)(\/page=(\d+))?$/){		
		$::params->{TMPL_VARS}->{const}->{PATH_INFO}=$1;
		my $page=$3;
		unless($page){
			$page=param('page');
			$page=1 unless($page);
		}
		$::params->{TMPL_VARS}->{page}=$page;
	}
	
	# ��� �������� b2b (�� ������� �����)
	$::params->{TMPL_VARS}->{const}->{b2bcounter}=q{<script type="text/javascript">document.write('<scr'+'ipt type="text/javascript" src="http://b2bcontext.ru/analytics/catch?&'+Math.random()+'"></scr'+'ipt>');</script>};
	
	# ��������� PROMO
	if(0 && index($::params->{project}->{options},';cache_promo;')>=0 && defined($CACHE->{$::params->{project}->{project_id}}->{cache_promo}->{$ENV{PATH_INFO}})){
		$::params->{TMPL_VARS}->{promo}=$CACHE->{$::params->{project}->{project_id}}->{cache_promo}->{$ENV{PATH_INFO}};
		#`echo "get_promo_from cache ($ENV{PATH_INFO})" >> log`;
	}
	else{
		$::params->{TMPL_VARS}->{promo}=&SQL_hash
			("SELECT 
				promo_title as title, promo_description as description, promo_keywords as keywords,
				promo_body as body, add_tags
			FROM promo WHERE url='$::params->{PATH_INFO}' AND project_id=$::params->{project}->{project_id}");
		#`echo "get_promo_from db $::params->{project}->{project_id} ($ENV{PATH_INFO})" >> log`;
		if(0 && index($::params->{project}->{options},';cache_promo;')>=1){
			#`echo "save to cache" >> log`;
			unless(defined($::params->{TMPL_VARS}->{promo})){
				#$CACHE->{$::params->{project}->{project_id}}->{cache_promo}->{$ENV{PATH_INFO}}='';
			}
			else{
				$CACHE->{$::params->{project}->{project_id}}->{cache_promo}->{$ENV{PATH_INFO}}=$::params->{TMPL_VARS}->{promo};
			}
		}
	}
	
	
	# --	
	# � ����������� �� �������� URL'� ��������� ��� ��� ���� ���
	my $rules_list=undef;
	if(0 && index($::params->{project}->{options},';cache_rules;')>=1){
		if(defined($CACHE->{$::params->{project}->{project_id}}->{cache_rules})) # $CACHE->{$::params->{project}->{project_id}}->{cache_rules}
		{
			$rules_list=$CACHE->{$::params->{project}->{project_id}}->{cache_rules};
		}
		else{
			$rules_list=&SQL_hash_all("SELECT * from url_run_code WHERE template_id=? order by sort",undef,$::params->{project}->{template_id});
			$CACHE->{$::params->{project}->{project_id}}->{cache_rules}=$rules_list;
		}
		
	}
	else{


		if(0 && index($::params->{project}->{temlpate_options},';run_code_on_fs;')>=-1){
			# ������ ������ ��� ����� �� �������� ������� 
			my $dir='./admin/develop_rules/'.$::params->{project}->{template_id};
			opendir D,$dir || &print_error(qq{�� ���� ������� ������� '$dir'});
			foreach my $file (grep { /^\d+$/} readdir D){
				open F, qq{$dir/$file};
				my $element=undef; my $str=0;
				while(<F>){
					my $line=$_;
					$str++;
					if(($str==1 || $str==2) && $line=~m/^#header:(.+)$/){
						$element->{header}=$1;
					}
					if(($str==1 || $str==2) && $line=~m/^#url_regexp:(.+)$/){
						$element->{url_regexp}=$1;
					}
					else{
						$element->{run_code}.=$line;
					}
					
				}
				close F;
				
				push @{$rules_list},$element;
				$element=undef;$str=undef;
			}
			
			closedir D;
		}
		else{
			# ������ ������ ��� ����� �� �� (�����������)
			$rules_list=&::SQL_hash_all("SELECT * from url_run_code WHERE template_id=? order by sort",undef,$::params->{project}->{template_id});
		}
	}
	
	foreach my $rul (@{$rules_list}){	

		if($::params->{TMPL_VARS}->{const}->{PATH_INFO}=~m/$rul->{url_regexp}/){ # URL ��������
			
			#print "$rul->{url_regexp}<br>\n";
			
			eval($rul->{run_code});
			return if($::params->{stop});
			if($@){ # ��� ������ ���������� ����
				$rul->{run_code}=~s/ /&nbsp;/gs;
				my $i=0;
				$rul->{run_code}=join('<br>',map {$i++; s/^(.+)$/$i&nbsp;$1/gs; $_} split /\n/,$rul->{run_code});
				my $i=1;
				
				&::print_error(qq{
					<p><b>$ENV{REQUEST_METHOD} http://$ENV{SERVER_NAME}/$ENV->{PATH_INFO}</b></p>
					��� ���������� ���� $rul->{header}:<br/>
					<hr>
					<div style='font-size: 10pt;'>
					$rul->{run_code}<br/>
					</div>
					</hr>
					��������� ������:
					$@;
				});
				$::params->{stop}=1;
				return ;
			}
			
		}
		last if(defined($::params->{TMPL_VARS}->{page_type}));
	}
	$rules_list=undef;
	#print Dumper($::params->{TMPL_VARS}); exit;
	if(!$::params->{TMPL_VARS}->{page_type}){
		# ��������� ����... ����� �  files
		my $sth=$params->{dbh}->prepare("SELECT body from files where project_id=? and url=?");
		$sth->execute($::params->{project}->{project_id}, $::params->{TMPL_VARS}->{const}->{PATH_INFO});
		if($sth->rows()){
			my $default_type='text/plain';
			if($::params->{TMPL_VARS}->{const}->{PATH_INFO}=~m/\.html$/){
				$default_type='text/html';
			}
			my $body=$sth->fetchrow();
			print "Content-type: $default_type\n\n";
			print $body;
			&end;
		}
		elsif($::params->{TMPL_VARS}->{const}->{PATH_INFO} eq '/robots.txt'){ # ���� ������������ robots.txt -- ����� ����������
			print "Content-type: text/plain\n\n";
			print "User-agent: *\nDisallow:\n";
			&end;
		}
		else{
			print "Status: 404 Not Found\n";
			my $html404 = qq{
				<h1>������ 404 - ����� �������� �� ���������� ($ENV{REQUEST_URI})</h1>
				<p>���������� <a href="/">��������� �� �������</a> ��� ������ ������� ��� �������.</p>
			};
			&::print_error($html404);
			&::end;
		}
	}
	return if($::params->{stop});
	# ����������, � ����������� �� URL'�, ����� ������ ������������
	# !!! ����� ���� ����� ��������������
	my $template_rules_list;

	$template_rules_list=&::SQL_hash_all("SELECT * from url_rules WHERE template_id=? order by sort",undef,($::params->{project}->{template_id}));
	
	
	foreach my $rul (@{$template_rules_list}){
		my $reg_true;
		eval(q{$reg_true=($::params->{TMPL_VARS}->{const}->{PATH_INFO}=~m/$rul->{url_regexp}/)});
		if($@){
			&::print_error("������ � ���������� ��������� $rul->{url_regexp}<br>".$@);
			return;
		}
		if($reg_true){ # URL �������� ��� �������?
			$::params->{template_name}=$rul->{template_name};
			return;
		}
	}
	$template_rules_list=undef;
	
	# ���� �� �������� ������, � ������� �������� -- �����
	if(!$::params->{template_name}){
		print "Status: 404 Not Found\n";
		&::print_error("Error 404\n�� ����� ���������� ������� ��� $ENV{PATH_INFO} ");
		return ;
	}

}

sub get_system{
	# ������ ��������� ��������� (��� ������������ � �� � ��.)	
	use vars qw($DBname $DBhost $DBuser $DBpassword);
	my $system; my $s='';
	open F,'./manager/connect';
	while(<F>){$s.=$_;}
	close F;
	$s.=q{$system->{DBname}=$DBname;$system->{DBhost}=$DBhost;$system->{DBuser}=$DBuser;$system->{DBpassword}=$DBpassword;};
	eval($s);
	print $@ if($@);
	$system->{TEMPLATE_DIR}='./templates';
	$system->{DEBUG}=1;
	return $system;
}

sub GET_CONTENT{
	my $p=shift;
	$p=$::ENV{PATH_INFO} unless($p);
	return &::SQL_hash(q{SELECT body from content WHERE project_id=? and url=?},$::params->{project}->{project_id},$p);
}

sub GET_PATH{
	# ���������� ���� ��� ������������� ������� (������� ��� ���. ������ ���� "������� ������"
	
	my $opt=shift;
	$opt->{connect}=$::params->{dbh} unless($opt->{connect});
	my $table;
	my $table_id='rubricator_id';
	if($opt->{table}){
		$table=$opt->{table};
		$table_id=&get_work_table_id_for_table($opt->{table});
	}
	elsif($opt->{struct}){
		$table=&get_table_from_struct($opt->{struct});
		$table_id=&get_work_table_id_for_struct($opt->{struct});
	}
	
	my $path=&SQL_row("SELECT path FROM $table WHERE $table_id = ?", $opt->{connect},$opt->{id});
	$path.=qq{/$opt->{id}} unless($opt->{not_last});

	my $path_string;
	
	if($opt->{good_calculate} && !$opt->{good_calculate_struct}){
		$opt->{good_calculate_struct}='good';
	}
	
	while($path=~m/(\d+)/g){
		my $rub_id=$1;
		my $header=&SQL_row("SELECT header FROM $table WHERE $table_id = ?", $opt->{connect},$rub_id);
		my $element={header=>$header, id=>$rub_id};
		if($opt->{good_calculate}){
				$element->{count}=&GET_DATA({
					struct=>$opt->{good_calculate_struct},
					select_fields=>'count(*)',
					where=>'rubricator_id=?',
					onevalue=>1,
				},$rub_id);
				if($element->{count}){
					$element->{href}=qq{/goods/$element->{id}}
				}
				else{
					$element->{href}=qq{/rubricator/$element->{id}}
				}
		}
		elsif($opt->{create_href}){
			$element->{href}=$opt->{create_href};
			$element->{href}=~s/\[%id%\]/$element->{id}/gs
		}
		push @{$path_string}, $element;
	}
	if($opt->{to_tmpl}){
		$::params->{TMPL_VARS}->{$opt->{to_tmpl}}=$path_string;
	}
	else{
		return $path_string;
	}
}

sub CONTEXT_SEARCH{
	# ���������, ���������� �� ����� �� ���������� �������� ������
	my $opt=shift;

	my $query='';
	my $i=0;
	
	foreach my $part (@{$opt->{info}}){ # ���������� ������� ��� �������
				
		unless($part->{header}){
			print_error("�� ������ header! (CONTEXT_SEARCH)");
			return ;
		}

		unless($part->{table}){
			print_error("�� ������ table! (CONTEXT_SEARCH)");
			return ;
		}

		unless($part->{s_part}){
			print_error("�� ������ s_part! (CONTEXT_SEARCH)");
			return ;
		}
		
		unless($part->{s_part}){
			print_error("�� ������ url! (CONTEXT_SEARCH)");
			return ;
		}
		
		$query.=" UNION \n" if($i);
		$query.=qq{ ( SELECT $part->{header} as header, $part->{s_part} as s_part, $part->{url} as url FROM $part->{table}  WHERE $part->{s_part} like ?\n};
		$query.=qq{ AND ($part->{where})} if($part->{where});
		$query.=' )';
		$i++;
	}

	$opt->{connect}=$::params->{dbh} unless($opt->{connect});
  my @like=();;  
  
  # ��������� xss
  $opt->{pattern}=~s/</&lt;/gs;
  $opt->{pattern}=~s/>/&gt;/gs;
  
  push @like, '%'.$opt->{pattern}.'%' foreach(1..$i);	
  
	if($opt->{perpage}=~m/^\d+$/){ # ��������� ����������������
		my $query_count="SELECT CEILING(count(*) / $opt->{perpage}) from ($query) as xcnt";
		if($opt->{debug}){
			&print_header;
			print "SEARCH DUMPER: <pre>$query_count</pre><br>";
			print join(';',@like)
		}
		my $sth=$opt->{connect}->prepare($query_count);	
		$sth->execute(@like) || die ($::params->{dbh}->{errorstr});
		$opt->{maxpage}=$sth->fetchrow();
		my $limit1=($::params->{TMPL_VARS}->{page}-1)*($opt->{perpage});

		$query=qq{select SQL_CALC_FOUND_ROWS * from ($query) as res limit $limit1, $opt->{perpage}};
	}
	
  
  
	if($opt->{debug}){
	  &print_header;
	  print "SEARCH DUMPER: <pre>$query</pre><br>";
	  print join(';',@like)
	}
  
  
  my $sth=$opt->{connect}->prepare($query);
  $sth->execute(@like) || die ("query: $query<br>".$!);
  
  my $result=$sth->fetchall_arrayref({});
  my $s_regexp=$opt->{pattern};
  $s_regexp=~s/\s+/\\s\+/gs;
  foreach my $r (@{$result}){# before_symbols  after_symbols mark_tag_begin mark_tag_end
		$r->{s_part}=~s/<.+?>//gs;
		$r->{s_part}=~s/\s\s+/ /gs;
		$r->{s_part}=~s/^.*?\s*(.{0,100})?($s_regexp)(.{0,100}\S)?\s*.*$/$1<strong>$2<\/strong>$3/gs;
	}
  
  $::params->{TMPL_VARS}->{GET_CONTENT_COUNT}=$opt->{connect}->selectrow_array("SELECT FOUND_ROWS()");
  
  if($opt->{to_tmpl}){
		$::params->{TMPL_VARS}->{$opt->{to_tmpl}}=$result;
		return $opt->{maxpage} if($opt->{perpage}=~m/^\d+$/);
	}
	else{
		return $result;
	}
	
}

sub GET_MULTIMENU{
	foreach my $element (@{&SQL_hash_all("SELECT * from multimenu WHERE project_id=?",undef,$::params->{project}->{project_id})})
	{
		if($::ENV{PATH_INFO}=~/$element->{url}/){
			# ��� ������
			$::params->{TMPL_VARS}->{MULTIMENU}=
				&SQL_hash_all("SELECT * from multimenu_list WHERE multimenu_id=? order by sort",undef, $element->{multimenu_id});
				last;
		}
	}
}

sub GET_FORM{
	my $form=shift;
	$form->{connect}=$::params->{dbh} unless($form->{connect});
	$form->{action_field}='action' unless($form->{action_field});
	my $work_table;
	if($form->{struct}){
		$work_table=&get_table_from_struct($form->{struct})
	}
	elsif($form->{table}){
		$work_table=$form->{table};
	}
	
	my $action=param($form->{action_field});
	
	$form->{work_table_id}=&get_work_table_id_for_struct($form->{struct});	
	if($action ne 'form_send'){
		if($form->{record_method} eq 'update'){
			#print "������ ������";
			my $form_values=&SQL_hash("SELECT * from $work_table where $form->{work_table_id}=?",$form->{connect},($form->{struct_id}));
			return ('0',$form_values);
		}
		return 0;
	}
	else{ # ����� ������������, ���������
	  $form->{record_method}='insert'
			unless($form->{record_method});
			
		my @names=();	my @values=(); my @vopr=();
		my $errors; my $form_values;
    if($form->{use_capture}){ # �������� ������������� �����, ���������
      my $str_key=param('capture_key');
      my $str=param('capture_str');
			unless(&SQL_row("SELECT count(*) from capture WHERE project_id=? and str_key=? and str=?",undef,
				(
					$::params->{project}->{project_id},
					$str_key,
					$str
				)
			)){ # ����� �� �������
					push @{$errors},
					"����������� �������� ��� ����� �� �����";
			}
		}
		foreach my $field (@{$form->{fields}}){
			next if($field->{read_only} || $field->{readonly});
			my $value=&html_strip(param($field->{name}));
			$value=~s/^\s+//;
			$value=~s/\s+$//;
			$value=~s/\s\s+/ /gs;
			#--- sanman -- encode=>'utf8;cp1251' ---
			if($form->{encode}){
				my ($trom,$to) = split ';',$form->{encode};
				if($trom && $to){
					Encode::from_to($value, $trom, $to);
				}
			}
			#----------------
			$value=~s/</&lt;/gs; $value=~s/>/&gt;/gs; # html-������			
			if($field->{value}=~m/^func::(.+?)$/){ # � ��������� ������� Mysql
				my $fname=$1;
				if($form->{record_method} eq 'insert'){ # ���� Insert
					push @names, $field->{name};
					push @vopr, $fname;
				}
				elsif($form->{record_method} eq 'update'){ #
					push @names,qq{$field->{name}=$fname}
				}
			}
			else{
				$field->{value}=$value unless($field->{value});
				if($field->{s}){
					$field->{value}=~s/${$field->{s}}[0]/${$field->{s}}[1]/gs;
				}
				$form_values->{$field->{name}}=$value;
				if($form->{record_method} eq 'insert'){
					push @names, $field->{name};
					push @vopr, '?'
				}
				elsif($form->{record_method} eq 'update'){
					push @names, qq{$field->{name}=?};
				}
				push @values, $field->{value};
				
			}
			if($field->{uniquew}){ # ���� ���� ������ ���� ����������:
				my $query="SELECT count(*) FROM $work_table WHERE $field->{name}=?";
				$query.=qq{ and $form->{work_table_id}<>$form->{struct_id}} if($form->{record_method} eq 'update');
				my $sth=$form->{connect}->prepare($query);
				$sth->execute($field->{value});
				my $c=$sth->fetchrow();
		
				if($c){
					push @{$errors},
					"��� ���������� ������ � ����� '$field->{description}',  '$field->{value}' ";
				}
				
			}
			if($field->{regexp} && !($field->{value}=~m/$field->{regexp}/)){
				my $err;
				
				if($field->{error_regexp}){
					$err=$field->{error_regexp};
				}
				else{
					$err="���� $field->{description} �� ��������� ��� ��������� �� �����";
				}
				push @{$errors},$err;
			}
		}
		
		
		if($#{$errors}>=0){ # ��������� ������
			return ($errors,$form_values);
		}
		else{ # ������ ���
			if($form->{use_capture}){ # �������� ������������� �����, ���������
				my $str_key=param('capture_key');
				my $str=param('capture_str');
				my $sth=$::params->{dbh}->prepare("DELETE from capture WHERE project_id=? and str_key=? and str=?");
				$sth->execute(
						$::params->{project}->{project_id},
						$str_key,
						$str
				);
			}
			if($work_table){ # ���� ������� ��������� -- ����� � ��
					unless($work_table){
						print_error ("������! �� ��������, � ����� ������� ���������� ������ �����");
						return;
						
					}

					if($form->{record_method} eq 'insert'){ #INSERT
						my $vopr=join ',',(split //,('?' x ($#names+1)));
						if($form->{debug}){
							&print_header;
							print "<br>INSERT INTO $work_table(".join(',',@names).') VALUES('.join(',',@values).')';
							print "<br>".join(',',@values)."<br/>";
						}
						my $sth=$form->{connect}->prepare("INSERT INTO $work_table(".join(',',@names).') VALUES('.join(',',@vopr).')');
						$sth->execute(@values) || die($sth->errstr);
						if($form->{insert_id_ref}){
							${$form->{insert_id_ref}}=$form->{insert_id}=$sth->{mysql_insertid};
						}
					}
					elsif($form->{record_method} eq 'update'){ #UPDATE
						unless($form->{struct_id}=~m/^\d+$/){
							&print_error('<br/>struct_id ������ ���� ������<br/>');
							return
						}
						my $q="UPDATE $work_table SET ".join(', ',@names)." WHERE $form->{work_table_id}=$form->{struct_id}";
						if($form->{debug}){
							&print_header;
							print "<br>$q<br/>";
							print "<br>".join(',',@values)."<br/>";
						}
						my $sth=$form->{connect}->prepare($q);
						$sth->execute(@values);
					}
			}
			foreach my $mail_send (@{$form->{mail_send}}){
				#print "���������� ��������� �� ����� $form->{mail_send}->{to}";
				$mail_send->{from}='no-reply@'.$::params->{project}->{domain} unless($mail_send->{from});
				my $filelist;
				foreach my $field (@{$form->{fields}}){
					my $value;
					
					if($field->{type} eq 'file'){
						# ��������� ����, ���������� ��� ��� � ������ ���� � �����
						my $orig_filename=param($field->{name});
						if($orig_filename=~m/([^.]+)$/){
							my $ext=$1;
							# ������� ��������� ��� �����:
							my $a='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
							my $filename='';
							foreach my $k (1..50){
								$filename.=substr($a,int(rand(length($a))),1)
							}
							$filename.='.'.$ext;
							open F,qq{>./temp/$filename};
							binmode F;
							print F while(<$orig_filename>);
							close F;
							push @{$filelist},{
								full_path=>qq{./temp/$filename},
								filename=>$orig_filename
							};
							
							# foreach my $f (@{$mail_send->{files}}){
							foreach my $f (@$filelist){
								$f->{full_path}=~s/\[%$field->{name}.full_path%\]/\.\/temp\/$filename/;
								$f->{filename}=~s/\[%$field->{name}.filename%\]/$orig_filename/
							}

							$$mail_send{files}=$filelist;
						}
					}
					
					if($field->{values}){
						while($field->{values}=~m/(\d+)=>([^;]+)/g){
							my ($k,$v)=($1,$2);
							if($k eq $field->{value}){
								$value=$v;
								last;
							}
						}
					}
					else{
						$value=$field->{value};
					}
					
					$value=~s/\n/<br\/>/gs;
					$mail_send->{message}=~s/\[%$field->{name}%\]/$value/gs;
					$mail_send->{from}=~s/\[%$field->{name}%\]/$value/gs;
					$mail_send->{to}=~s/\[%$field->{name}%\]/$value/gs;
				}
				
				$mail_send->{message}=~s/\[%insert_id%\]/$form->{insert_id}/gs;				
				&send_mes($mail_send);

				foreach my $f (@{$filelist}){
					unlink($f->{full_filename});
				}
				$filelist=undef;
			}
			return (1,$form_values);
		}
		
			return ($errors,$form_values);
		}
	}

sub START_SESSION{
	use vars qw($::params);
# ���������, �������� �� ������
  my $sess=shift;
  my $user_id=cookie('auth_user_id');
  my $key=cookie('auth_key');
	$sess->{session_table}='session'
			unless($sess->{session_table});	

	my $c=&SQL_row("SELECT count(*) FROM $sess->{session_table} WHERE project_id=? and auth_id=? and session_key=?",
		undef,
		($::params->{project}->{project_id}, $user_id, $key)
	);

	if($c){ # ���� ������ �����
		$sess->{auth_table}=&get_table_from_struct($sess->{auth_struct})
			if($sess->{auth_struct});
		$::params->{TMPL_VARS}->{login_info}=&SQL_hash("SELECT * from $sess->{auth_table} WHERE $sess->{auth_id_field}=?",$sess->{connect},($user_id));
	}
	else{
		$::params->{TMPL_VARS}->{login_info}=undef;
	}
}

sub DROP_SESSION{
	use vars qw($::params);
	my $sess=shift;
	
	$sess->{session_table}='session'
			unless($sess->{session_table});
			
  my $user_id=cookie('auth_user_id');
  my $key=cookie('auth_key');

  if($user_id=~m/^\d+$/ && $key){		
		my $sth=$::params->{dbh}->prepare("DELETE FROM $sess->{session_table} WHERE project_id=? and auth_id=? and session_key=?");
		$sth->execute($::params->{project}->{project_id}, $user_id, $key);
		
	}
	$::params->{TMPL_VARS}->{login_info}=0;	
}

sub CREATE_SESSION{
	my $sess=shift;

	if(!$sess->{auth_struct} && !$sess->{auth_table}){
		print_error('��� �������� �����: �� ������� �� auth_struct, �� auth_table');
		return;
	}
	
	if(!$sess->{login}){
		$sess->{login}=param('login');
		unless(defined($sess->{login})){
			print_error('��� �������� ������ (�� ������ login)');
			return;
		}
	}
	
	if(!$sess->{password}){
		$sess->{password}=param('password');
		unless(defined($sess->{password})){
			print_error('��� �������� ������ (�� ������ password)');
			return ;
		}	
	}
	
	if(!$sess->{auth_id_field}){
		print_error('��� �������� ������ (�� ������ auth_id_field)');
		return;
	}

	# �������, �� ���. ����� ��������� ����� � ������
	$sess->{auth_table}=&get_table_from_struct($sess->{auth_struct})
		if($sess->{auth_struct});
	
	$sess->{aut_log_field}='login' unless($sess->{aut_log_field});
	$sess->{aut_pas_field}='password' unless($sess->{aut_pas_field});	
	$sess->{session_table}='session' unless($sess->{session_table});	
	
	# 1. ����� ������������� ������ ����, ��� ���������:
	my $add_where='';
	if($sess->{where}){
		$add_where=qq{ AND $sess->{where}};
	}

	if($sess->{debug}){
		&print_header;
		print "SELECT $sess->{auth_id_field} FROM $sess->{auth_table} WHERE $sess->{auth_log_field}='$sess->{login}' AND $sess->{auth_pas_field}='$sess->{password}' $add_where<br>";
	}
	my $user_id=&SQL_row("SELECT $sess->{auth_id_field} FROM $sess->{auth_table} WHERE $sess->{auth_log_field}=? AND $sess->{auth_pas_field}=? $add_where",$sess->{connect},($sess->{login}, $sess->{password}));
	
	if($user_id=~m/^\d+$/){ # ������������
		
		# 3. ���������� ���� ������
		my $a='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
		my $key='';
		foreach my $k (1..200){
			$key.=substr($a,int(rand(length($a))),1)
		}
	
		# 4. ������ ������ � ������� ������
		my $sth=$::params->{dbh}->prepare(qq{
				INSERT INTO $sess->{session_table}(project_id, auth_id, registered, session_key)
				VALUES(?,?,now(),?)}
		);
	
		$sth->execute($::params->{project}->{project_id},$user_id, $key);
		
		# 5. ������ ����
		my $auth_user_id=new CGI::Cookie(
			-name=>'auth_user_id',
			-value=>$user_id
		);
		my $auth_key=new CGI::Cookie(
			-name=>'auth_key',
			-value=>$key
		);
		
		$::params->{TMPL_VARS}->{login_info}=&SQL_hash("SELECT * from $sess->{auth_table} WHERE $sess->{auth_id_field}=?",$sess->{connect},($user_id));
		
		print "Set-Cookie: $auth_user_id\nSet-Cookie: $auth_key\n";
		return;
	}
	else{
		$::params->{TMPL_VARS}->{login_info}='0';
		return;
	}	
}

sub send_mes{
	my $opt=shift;
	if($opt->{to}!~/@/){
		&print_error(qq{���������� �������� ��������� �� ����� '$opt->{to}'});
		return;
	}
	$opt->{subject} = MIME::Base64::encode($opt->{subject},"");
    $opt->{subject} = "=?windows-1251?B?".$opt->{subject}."?=";
    my $letter = MIME::Lite->new(
		From => $opt->{from},
        To => $opt->{to},
        Subject => $opt->{subject},
        Type=> 'multipart/mixed',
    ) || &print_error("Can't create $!");
    
    # attach body
    $letter->attach (
		Type => 'text/html; charset=windows-1251',
		Data => $opt->{message}
	) or warn "Error adding the text message part: $!\n";

#	&print_header;
#	print Dumper($opt);

	foreach my $f (@{$opt->{files}}){

			$letter->attach(
				Type => 'AUTO',
				Disposition => 'attachment',
				Filename => $f->{filename},
				Path => $f->{full_path},
			);
		
	}

    $letter->send() || &print_error("Can't send $!");
}
sub print_header{
	#&print_last_modified if($::params->{project}->{project_id}<80);
	print "Content-type: text/html; charset=windows-1251\n\n" unless($::params->{print_header});
	$::params->{print_header}=1;
}

sub print_error{
	my $err=shift;
	&print_header;
	print $err;
	
	#my ($sec,$min,$hour,$day,$mon,$year)=(localtime(time-3600))[0..5];
	#$mon++;
	#$year+=1900;
	
	#if($system->{DEBUG}){
	#	open F, '>>log';
	#	print F qq{$year-$mon-$day $hour:$min:$sec project: $::params->{project}->{project_id}<br>$::params->{project}->{domain} $ENV{REQUEST_METHOD} $ENV{REQUEST_URI})}.$err.qq{<hr>};
	#	close F;
	#}
	&to_error_log(qq{$::params->{project}->{project_id}<br>$::params->{project}->{domain} $ENV{REQUEST_METHOD} $ENV{REQUEST_URI})}.$err);
	$::params->{stop}=1;
	&end;
	#exit;
}

sub urldecode{
	my $val=shift;
	$val=~s/\+/ /g;
	$val=~s/%([0-9a-hA-H]{2})/pack('C',hex($1))/ge;
	return $val;
}

sub pre{
	my $data=shift;
	eval(q{
	&print_header;
	print '<br>=====<br>pre:<br><pre>'.Dumper($data).'</pre>=====<br>';
	});
}

sub print_last_modified{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time-(3600*12));
	my @MON=qw(Jan  Feb  Mar  Apr  Mai  Jun  Jul  Aug  Sep  Oct  Nov  Dec);
	my @W=qw(Mon Tue Wed Thu Fri Sat Sun);
	$hour=sprintf("%02d",$hour);
	$mday=sprintf("%02d",$mday);
	$year+=1900;
	#print "Content-type: text/html\n\n";
	print "Last-Modified: $W[$wday], $mday $MON[$mon] $year $hour:00:00 GMT\n";
}

sub filter_get_url{ 
	# ������ ��� �������, ����������� ���������� url CMS �� ����������
	# �������� URL'� �� ������� CMS �  ������ ������������
	my $u=shift;
	if($::params->{project}->{options} =~m/;ex_links;/){
		my $sth=$::params->{dbh}->prepare("SELECT ext_url FROM in_ext_url WHERE project_id=? and in_url=?");
		$sth->execute($::params->{project}->{project_id},$u);
		$u=$sth->fetchrow() if($sth->rows());
		$sth->finish();
	}
	return $u;
}


sub end{
	$::params->{stop}=1;
}

sub html_strip{
	my $s=shift;
	$s=~s/</&lt;/gs;
	$s=~s/>/&gt;/gs;
	return $s;
}

sub to_error_log{
	
	if($::system->{debug}){
	open F,'>>'.$::system->{logname};
	print F `date`."\t$_[0]\n";
	close F;
	}
}

return 1;
END { }
