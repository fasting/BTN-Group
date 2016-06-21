package typesite;
#use CGI::Fast qw(:standard);
#use CGI::Cookie;
#use CGI::Carp qw/fatalsToBrowser/;
#use Data::Dumper;
#use DBI;
#use cms_struct;
BEGIN {
		use Exporter ();
		@ISA = "Exporter";
		@EXPORT =
		(
			'&go'
		);
}
my $params=$::params;
# ��������� �� ��������� ������
sub go {
	my $url=shift;
	# 0.
		my $data=&::GET_DATA({
			#select_fields=>'options,logo',
			table=>'project_group_site',
			limit=>1,
			onerow=>1,

		#	debug=>1
		});
		$::params->{TMPL_VARS}->{LOGO}='/files/project_'.$::params->{project}->{project_id}.'/'.$::params->{TMPL_VARS}->{const}->{logo} if($::params->{TMPL_VARS}->{const}->{logo});
#			&::print_header;
#			print &::pre($data);
		if($data->{promoblock_id}){

			my $sth=$::params->{dbh}->prepare("SELECT file from template_group_promoblock where id=?");
			$sth->execute($data->{promoblock_id});
			if(my $file=$sth->fetchrow()){ # ��������� ������

				$::params->{TMPL_VARS}->{PROMOBLOCK}='/files/typesites/promoblock/'.$file;
			}
		}

		while ($data->{options}=~m/;(.+?);/g){
			$::params->{project_services}->{$1}=1 if($1);
		}
		$::params->{TMPL_VARS}->{project_services}=$::params->{project_services};
		#&pre($::params->{TMPL_VARS}->{project_services});
		$::params->{project_logo}=$::params->{project_logo}=$data->{logo};

	# 10. (init_basket)
	if($::params->{project_services}->{service_basket}){
		&::init_basket({
			cookie_name=>'basket',
			good_table=>'good',
			good_table_id=>'good_id',
			good_select_fields=>qq{
				good_id id,
				rubricator_id,
				header,
				price,
				anons,
				photo,
				concat('/files/project_$::params->{project}->{project_id}/good/',photo) as photo_and_path ,
				concat('/files/project_$::params->{project}->{project_id}/good/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
			},
			field_header=>'header',
			field_price=>'price',
		});
		&::basket_info;
	}

	# 20. (basket_info)
	if($url=~m/^\/basket_info$/ && $::params->{project_services}->{service_basket}){
		$::params->{TMPL_VARS}->{page_type}='basket_info';
		&::processing_basket;
	}

	# 30. ��� ���� �������... ��������� ����
	# ������ ����
	&allpages;



	# 40
	&mainpage($url);
	&rubricator($url);
	&good($url);
	&news($url);
        &articles($url);
	&feedback($url);
	&basket($url);
	&zakaz($url);
	&service($url);
	&text_page($url);
	# 50.

}
sub allpages{

	# �������� �������� �� ����� ������� ������
	if($ENV{HTTP_HOST}=~m/selt$::params->{project}->{project_id}\.designb2b\.ru$/){
		if($::params->{project}->{project_id} == 407){
			my $sth=$params->{dbh}->prepare("SELECT domain FROM domain WHERE project_id = ?");
			$sth->execute($::params->{project}->{project_id});
			while(my $d=$sth->fetchrow()){
				unless($d=~m/selt$::params->{project}->{project_id}\.designb2b\.ru/){
					print "Location: http://$d$ENV{PATH_INFO}\n\n";
					&::end;
					return;
				}
			}
		}

	}
	# / �������� �������� �� ����� ������� ������


	&::GET_DATA(
	{
	  table=>'bottom_menu',
	  order=>'sort',
	  to_tmpl=>'bottom_menu'
	});
	# ������� ����
	&::GET_DATA(
	{
	  table=>'top_menu_tree',
	  order=>'sort',
	  tree_use=>1,
	  to_tmpl=>'top_menu',
	  #debug=>1,
	  select_fields=>"top_menu_tree_id, url, header, if(url=?,1,0) as act, ''",
	}, $::params->{PATH_INFO});

	# ���� "���������������"
	&::GET_DATA({
		table=>'content',
		url=>'__specpredl',
		select_fields=>'body',
		onevalue=>1,
		to_tmpl=>'specpredl'
	}); #if($::params->{project_services}->{service_goodkat});

	if($::params->{project_services}->{service_goodkat}){
	# ��������� �������
	&::GET_DATA({
		table=>'rubricator',
		#tree_use=>1,
		where=>q{path = ''},
		select_fields=>qq{
			rubricator_id id,
			header,
			anons,
			photo,
			concat('/files/project_$::params->{project}->{project_id}/rubricator/',photo) as photo_and_path ,
			concat('/files/project_$::params->{project}->{project_id}/rubricator/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
		},
		order=>'sort',
		where=>q{parent_id is null},
		to_tmpl=>'rub_list'
	});
	}

	if($::params->{project_services}->{service_service}){
	# ��������� ������� �����
	&::GET_DATA({
		table=>'service_rubricator',
		where=>q{path = ''},
		select_fields=>qq{
			id,
			header
		},
		order=>'sort',
		to_tmpl=>'service_rub_list',
		tree_use=>1
	});
	}

	#made by pmk get name of valuta
	$::params->{TMPL_VARS}->{const}->{valuta}||=810;
	&::GET_DATA({
		table=>'valuta',
		where=>'valuta_id = ?',
		not_use_project=>1,
		select_fields=>qq{
			rus
		},
		onevalue=>1,
		to_tmpl=>'valuta_name'
	},$::params->{TMPL_VARS}->{const}->{valuta});
}
sub mainpage{
		my $url = shift;
		# 40. �������
		if($url eq '/')
		{
				$::params->{TMPL_VARS}->{page_type}='main';
				# ���� "���� ������������"
				&::GET_DATA({
					table=>'content',
					url=>'__preim_main',
					select_fields=>'body',
					onevalue=>1,
					to_tmpl=>'preim_main'
				});

				# ���� "� ��������"
				&::GET_DATA({
					table=>'content',
					url=>'__about_main',
					select_fields=>'body',
					onevalue=>1,
					to_tmpl=>'about_main'
				});



				# ������ ���������������
				&::GET_DATA({
					table=>'good',
					select_fields=>qq{
						good_id id,
						header, anons,price,photo,
						concat('/files/project_$::params->{project}->{project_id}/good/',photo) as photo_and_path ,
						concat('/files/project_$::params->{project}->{project_id}/good/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
					},
					to_tmpl=>'specpredl_list',
					where=>'specpredl=1'
				});

				$::params->{TMPL_VARS}->{promo}->{title}='������� ��������'
					unless($::params->{TMPL_VARS}->{promo}->{title});
				#&::pre($::params->{TMPL_VARS}->{PROMOBLOCK});
		}
}
sub rubricator{
	my $url=shift;
	if($url=~m/^\/rubricator(\/(\d+))?$/){
		return unless($::params->{project_services}->{service_goodkat});
		my $rubricator_id=$2;

		if($rubricator_id=~m/^\d+$/){ # ������ ������ �����������
		  $::params->{TMPL_VARS}->{page_type}='catalog';
			# ��������� �������
			&::GET_DATA({
				table=>'rubricator',
				where=>q{parent_id = ?},
				select_fields=>qq{
					rubricator_id,
					rubricator_id id,
					header,
					anons,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/rubricator/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/rubricator/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
				order=>'sort',
				to_tmpl=>'LIST',
				perpage=>$::params->{TMPL_VARS}->{const}->{rub_perpage}
			},$rubricator_id);

		  unless(scalar(@{$::params->{TMPL_VARS}->{LIST}})){
		  # ������ ������ ��� -- ������� ������� ������ �������
			$::params->{TMPL_VARS}->{maxpage}=&::GET_DATA({
				where=>'rubricator_id=?',
				table=>'good',
				select_fields=>qq{
					good_id id,
					header,
					price,
					anons,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/good/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/good/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
				to_tmpl=>'LIST',
				perpage=>$::params->{TMPL_VARS}->{const}->{good_perpage}

			},$rubricator_id);
			$::params->{TMPL_VARS}->{page_type}='goodlist';

		  }

		  # ������� ������
		  &::GET_PATH({
			table=>'rubricator',
			id=>$rubricator_id,
			to_tmpl=>'PATH_INFO',
			create_href=>'/rubricator/[%id%]'
		  });

		  # ������������ ������� �������
		  &::GET_DATA({
			table=>'rubricator',
			select_fields=>qq{
			rubricator_id,
			header,
			anons,
			photo,
			body,
			concat('/files/project_$::params->{project}->{project_id}/rubricator/',photo) as photo_and_path ,
			concat('/files/project_$::params->{project}->{project_id}/rubricator/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
			},
			to_tmpl=>'cur_rub',
			onerow=>1,
			id=>$rubricator_id
		  });


		  $::params->{TMPL_VARS}->{promo}->{title}=
		  '������� ��������� : '.$::params->{TMPL_VARS}->{cur_rub}->{header}
			unless($::params->{TMPL_VARS}->{promo}->{title});


		}
		else{
			$::params->{TMPL_VARS}->{page_type}='catalog';

			# ��������� �������
			&::GET_DATA({
				table=>'rubricator',
				where=>q{path = ''},
				select_fields=>qq{
					rubricator_id,
					rubricator_id id,
					header,
					anons,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/rubricator/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/rubricator/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
				order=>'sort',
				tree_use=>1,
				to_tmpl=>'LIST'
			});

			$::params->{TMPL_VARS}->{promo}->{title}='������� ���������'
			unless($::params->{TMPL_VARS}->{promo}->{title});

		}
	}
}
sub good{
	my $url = shift;
	if($url=~m/^\/good\/(\d+)$/){
		return unless($::params->{project_services}->{service_goodkat});

		$::params->{TMPL_VARS}->{page_type}='good';
		&::GET_DATA({
			table=>'good',
			select_fields=>qq{
					good_id id,
					rubricator_id,
					header,
					price,
					body,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/good/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/good/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
			},
			id=>$1,
			onerow=>1,
			to_tmpl=>'content'
		});

		  # ������� ������
		  &::GET_PATH({
			table=>'rubricator',
			id=>$::params->{TMPL_VARS}->{content}->{rubricator_id},
			to_tmpl=>'PATH_INFO',
			create_href=>'/rubricator/[%id%]'
		  });

		$::params->{TMPL_VARS}->{promo}->{title}=$::params->{TMPL_VARS}->{content}->{header}
			unless($::params->{TMPL_VARS}->{promo}->{title});

	}
}
sub news{
	my $url=shift;
	if($url=~m/^\/news(\/(\d+))?$/){
		return unless($::params->{project_services}->{service_news});
		my $id=$2;
		if($id){ # �������� �������
			&::GET_DATA({
				table=>'news',
				to_tmpl=>'content',
				id=>$id,
				onerow=>1,
				select_fields=>qq{
					news_id id,
					header,
					anons,
					registered,
					body,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/news/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/news/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
			});
			$::params->{TMPL_VARS}->{page_type}='news_in';
			$::params->{TMPL_VARS}->{promo}->{title}='������� :: '.$::params->{TMPL_VARS}->{content}->{header}
			unless($::params->{TMPL_VARS}->{promo}->{title});

		}
		else{
			$::params->{TMPL_VARS}->{maxpage}=&::GET_DATA({
				table=>'news',
				to_tmpl=>'LIST',
				perpage=>$::params->{TMPL_VARS}->{const}->{news_perpage},
				order=>'registered desc',
				select_fields=>qq{
					news_id id,
					header,
					anons,
					registered,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/news/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/news/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
			});
			$::params->{TMPL_VARS}->{page_type}='news';
		}
	}
}
sub articles{
	my $url=shift;
	if($url=~m/^\/articles(\/(\d+))?$/){
		return unless($::params->{project_services}->{service_articles});
		my $id=$2;
		if($id){ # �������� �������
			&::GET_DATA({
				table=>'article',
				to_tmpl=>'content',
				id=>$id,
				onerow=>1,
				select_fields=>qq{
					article_id id,
					header,
					anons,
					registered,
					body,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/articles/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/articles/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
			});
			$::params->{TMPL_VARS}->{page_type}='article_in';
			$::params->{TMPL_VARS}->{promo}->{title}='������ :: '.$::params->{TMPL_VARS}->{content}->{header}
			unless($::params->{TMPL_VARS}->{promo}->{title});

		}
		else{
			$::params->{TMPL_VARS}->{maxpage}=&::GET_DATA({
				table=>'article',
				to_tmpl=>'LIST',
				perpage=>$::params->{TMPL_VARS}->{const}->{article_perpage},
				order=>'registered desc',
				select_fields=>qq{
					article_id id,
					header,
					anons,
					registered,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/articles/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/articles/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
			});
			$::params->{TMPL_VARS}->{page_type}='articles';
		}
	}
}
sub feedback{
	my $url=shift;

#Khabusev Phanis [pmk@trade.su] 5.04.2012+
	my $good_id=$1 if($ENV{QUERY_STRING}=~/(\d+)/);
	my $good_header;
	if($good_id){
		$good_header=&::GET_DATA({
				table=>'good',
				select_fields=>'header',
				id=>$good_id,
				onevalue=>1,
		});
	}
#Khabusev Phanis [pmk@trade.su] 5.04.2012-

	if($url=~m/^\/feedback$/){
		next unless($::params->{project_services}->{service_feedback});
		unless($::params->{TMPL_VARS}->{const}->{message_for_feedback})
		{
			$::params->{TMPL_VARS}->{const}->{message_for_feedback} = &get_message_for_feedback;
		}

		#-- PV: 22.08.2012
		do '/www/connectDB.conf';
		use vars qw/$DBhost_rosexport/;
		my $dbh_rosexport = DBI->connect("DBI:mysql:rosexport:$DBhost_rosexport",'rosexport','',{ RaiseError => 1 }) || die($!);

		my $card_id = $dbh_rosexport->selectrow_array('SELECT card_id FROM selt_card_2011 WHERE svcms_id = ?', undef, $::params->{project}->{project_id});
		if ($card_id)
		{
			$::params->{TMPL_VARS}->{const}->{message_for_feedback} .= "<br><br><a href='http://ivan.opt.ru/moderator/crm2011/edit_form.pl?action=edit&config=selt_card&id=$card_id'>�������� ����</a>";
		}
		#--

		$::params->{TMPL_VARS}->{page_type}='feedback';
		my $form={
			use_capture=>1,
			mail_send=>[
			{
				to=>$::params->{TMPL_VARS}->{const}->{email_for_feedback},
				message=>$::params->{TMPL_VARS}->{const}->{message_for_feedback},
				subject=>'��������� � ����� http://'.$::params->{project}->{domain}
			}
			],
			fields=>[
				{
					name=>'name',
					description=>'���',
					regexp=>'.+'
				},
				{
					name=>'phone',
					description=>'�������',
					regexp=>'^((8|\+7)[\- ]?)?(\(?\d{3}\)?[\- ]?)?[\d\- ]{7,10}$'
				},
				{
					name=>'email',
					description=>'Email',
					regexp=>'.+',
				},
				{
					name=>'message',
					description=>'��� ������',
					regexp=>'.+'
				}
			]

		};

		($::params->{TMPL_VARS}->{form_errors},$::params->{TMPL_VARS}->{form_vls})=&::GET_FORM($form);

#Khabusev Phanis [pmk@trade.su] 5.04.2012+
		$::params->{TMPL_VARS}->{form_vls}->{message}=$good_header if(!$::params->{TMPL_VARS}->{form_vls}->{message} && $good_header);
#Khabusev Phanis [pmk@trade.su] 5.04.2012-

		if($::params->{TMPL_VARS}->{form_errors}==1){
			my $v=$::params->{TMPL_VARS}->{form_vls};
			use lib "/www/SELT_II/htdocs/modules";
			require common;

					&common::request_collector({
						portal	=> 3,
						fio	=> $v->{name},
						phone	=> $v->{phone},
						email	=> $v->{email},
						message	=> $v->{message},
						url=>$::params->{project}->{domain}
					});
		}
		$::params->{TMPL_VARS}->{promo}->{title}='�������� �����'
			unless($::params->{TMPL_VARS}->{promo}->{title});
	}
}
sub basket{
	my $url = shift;
	if($url=~m/^\/basket$/){
		return unless($::params->{project_services}->{service_basket});
		$::params->{TMPL_VARS}->{page_type}='basket';
		&::basket_full_info;
	}
}
sub zakaz{
	my $url=shift;
	if($url eq '/zakaz'){
		$::params->{TMPL_VARS}->{page_type}='zakaz';
		my $message_for_zakaz;

		my $zakaz_summ=0;
		if(&::param('action') eq 'form_send'){
			&::basket_full_info('basket');


			foreach my $b (@{$::params->{TMPL_VARS}->{basket}->{basket}->{LIST}}){
		#			"$b->{header} $b->{count} $b->{price}<br>";
				if($b->{price}>0){
				my $summ=$b->{price}*$b->{count};
				$message_for_zakaz.=qq{
				<tr>
					<td>$b->{header}</td>
					<td>$b->{price}</td>
					<td>$b->{count}</td>
					<td>$summ</td>
				</tr>
				};
				}
			}

		};
		my $form={
		use_capture=>1,
		#	mail_send=>[

		#	],
			fields=>[
				{
					name=>'name',
					description=>'���',
					regexp=>'.+'
				},
				{
					name=>'phone',
					description=>'�������',
					regexp=>'.+'
				},
				{
					name=>'email',
					description=>'Email',
					regexp=>'.+@.+',
				},
				{
					name=>'more',
					description=>'�������������� ����������',
					#regexp=>'.+'
				}
			]

		};

		($::params->{TMPL_VARS}->{form_errors},$::params->{TMPL_VARS}->{form_vls})=&::GET_FORM($form);

		my $zakaz_id;
		if(0){ # ������ ���������� � ������ � ��
			# � ������ ��������� ������ ��������� ���������� � �� � ��
			my $sth=$::params->{dbh}->prepare("INSERT INTO struct_125_zakaz(user_id,registered) values(?,now())");
			$sth->execute($::params->{TMPL_VARS}->{login_info}->{id});
			$zakaz_id=$sth->{mysql_insertid};
			$sth->finish();
			$sth=$::params->{dbh}->prepare("INSERT INTO struct_125_zakaz_info(zakaz_id,good_id,cnt) values($zakaz_id,?,?)");
			foreach my $b (@{$::params->{TMPL_VARS}->{basket}->{basket}->{LIST}}){
				$sth->execute($b->{id},$b->{count});
			#			"$b->{header} $b->{count} $b->{price}<br>";

			}

		}

		if($::params->{TMPL_VARS}->{form_errors} eq '1'){

			if($message_for_zakaz){
				$message_for_zakaz=qq{
				<p><b>���������� � ������:</b></p>
				<table>
				<tr>
					<td>������������ ������</td>
					<td>����</td>
					<td>����������</td>
					<td>�����</td>
				</tr>
					$message_for_zakaz
				</table>
				<p><b>�����: </b>$::params->{TMPL_VARS}->{basket}->{basket}->{total_price} ���.</p>
				}
			}

			my $message=qq{
				<style>
					td {border: 1px solid black;}
				</style>
				<p>������ ��� �� ����� <a href="http://$::params->{project}->{domain}">http://$::params->{project}->{domain}</a> ��� ������ �����.</p>
				<p>���������� � ���������:</p>
				<table>
					<tr><td><b>���:</b></td><td>$::params->{TMPL_VARS}->{form_vls}->{name}</td></tr>
					<tr><td><b>�������:</b></td><td>$::params->{TMPL_VARS}->{form_vls}->{phone}</td></tr>
					<tr><td><b>Email:</b></td><td>$::params->{TMPL_VARS}->{form_vls}->{email}</td></tr>
					<tr><td><b>���. ����������:</b></td><td>$::params->{TMPL_VARS}->{form_vls}->{more}</td></tr>
				</table>
				$message_for_zakaz

				};
			if($zakaz_id){
				$message="<p><b>����� ������: $zakaz_id</b></p>$message";
			}
			#&::print_header;
			#print "to: $::params->{TMPL_VARS}->{const}->{email_for_zakaz}";
			#&print_header;
			#print ("message: $message");
			# ������ �������������� �����
			&::send_mes(
			{
				to=>$::params->{TMPL_VARS}->{const}->{email_for_zakaz},
				message=>$message,
				subject=>'��������� � ����� http://'.$::params->{project}->{domain}
			});

			#if($zakaz_id){
			#	$message_for_zakaz="<p><b>����� ������: $zakaz_id</b></p>$message";
			#}

			&::clean_basket;
		}
		$::params->{TMPL_VARS}->{promo}->{title}='���������� ������'
			unless($::params->{TMPL_VARS}->{promo}->{title});
	}
}
sub service{
	my $url=shift;
	if($url=~m/^\/service(\/(\d+))?$/){
		return unless($::params->{project_services}->{service_service});
		my $service_id=$2;

		if($service_id=~m/^\d+$/){ # ������ ������ �����������
		  $::params->{TMPL_VARS}->{page_type}='service_list';
			# ��������� �������
			&::GET_DATA({
				table=>'service_rubricator',
				where=>q{parent_id = ?},
				select_fields=>qq{
					id,
					header,
					anons,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/service/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/service/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
				order=>'sort',
				to_tmpl=>'LIST',
				perpage=>$::params->{TMPL_VARS}->{const}->{rub_perpage}
			},$service_id);

		  unless(scalar(@{$::params->{TMPL_VARS}->{LIST}})){
		  # ������ ��������� ���, ������������� ��� �������� �����.
		  # ������� �������� ������
			$::params->{TMPL_VARS}->{page_type}='service_in';

		  }

		  # ������� ������
		  &::GET_PATH({
			table=>'service_rubricator',
			id=>$service_id,
			to_tmpl=>'PATH_INFO',
			#debug=>1,
			create_href=>'/service/[%id%]'
		  });

		  # ���������� � ���. �������
		  &::GET_DATA({
			table=>'service_rubricator',
			select_fields=>qq{
			id,
			header,
			anons,
			photo,
			body,
			concat('/files/project_$::params->{project}->{project_id}/service/',photo) as photo_and_path ,
			concat('/files/project_$::params->{project}->{project_id}/service/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
			},
			to_tmpl=>'cur_rub',
			onerow=>1,
			id=>$service_id
		  });
		  $::params->{TMPL_VARS}->{content}=$::params->{TMPL_VARS}->{cur_rub};

		  $::params->{TMPL_VARS}->{promo}->{title}=
		  '������ : '.$::params->{TMPL_VARS}->{cur_rub}->{header}
			unless($::params->{TMPL_VARS}->{promo}->{title});
		  #&::pre($::params->{TMPL_VARS}->{PATH_INFO});

		}
		else{
			$::params->{TMPL_VARS}->{page_type}='service_list';

			# ��������� �������
			&::GET_DATA({
				table=>'service_rubricator',
				where=>q{path = ''},
				select_fields=>qq{
					id,
					header,
					anons,
					photo,
					concat('/files/project_$::params->{project}->{project_id}/service/',photo) as photo_and_path ,
					concat('/files/project_$::params->{project}->{project_id}/service/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1
				},
				order=>'sort',
				tree_use=>1,
				to_tmpl=>'LIST'
			});

			$::params->{TMPL_VARS}->{promo}->{title}='������'
			unless($::params->{TMPL_VARS}->{promo}->{title});

		}
	}
}
sub text_page{
	my $url=shift;
	if(!$::params->{TMPL_VARS}->{page_type}){ # ���������, ���� �� ��������� �������� �� ������� url'�
		if(
			$::params->{TMPL_VARS}->{content}=&::GET_DATA({
				table=>'content',
				url=>$url,
				onerow=>1
			})
		){
			$::params->{TMPL_VARS}->{page_type}='text_page';
			$::params->{TMPL_VARS}->{promo}->{title}=$::params->{TMPL_VARS}->{content}->{header}
				unless($::params->{TMPL_VARS}->{promo}->{title});
		}
	}
}

sub get_message_for_feedback{
	return q{
<p>������������!</p>
<p>������ ��� ���� ���������� � ����� ��������� ���������:</p>
<table>
<tr><td>���:</td><td>[%name%]</td></tr>
<tr><td>�������:</td><td>[%phone%]</td></tr>
<tr><td>Email:</td><td>[%email%]</td></tr>
</table>
[%message%]
	}
}
return 1;
END { }
