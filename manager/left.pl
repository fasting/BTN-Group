#!/usr/bin/perl
use DBI;
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use Template;

print "Content-type: text/html; charset=windows-1251\n\n";
do './connect';

#/*******************************************************#


my $params;
$params->{template_name} = 'leftside_admin.tmpl';
$params->{project}->{template_folder} = $CMSpath.'/manager/templates/';
my $_____options;


#/******************************************************/#

our $dbh = DBI->connect("DBI:mysql:$DBname:$DBhost",$DBuser,$DBpassword, , { RaiseError => 1 }) || die($!);
$dbh->do("SET names CP1251");
# �����, ��� ��, ��� ��...
my $sth=$dbh->prepare('SELECT project_id,manager_id from manager where login=?');
$sth->execute($ENV{REMOTE_USER});
my $manager=$sth->fetchrow_hashref();
$sth->finish();
unless($sth->rows()){
	print "������ �����������";
	exit;
}

#$sth=$dbh->prepare(qq{
#	SELECT m.header, m.url, i.photo FROM manager_menu m
#	LEFT join manager_menu_icons i ON (i.id=m.photo_id)
#	where m.manager_id = ? order by sort
#	});
#$sth->execute($manager->{manager_id});

# 1. ���������, ���� �� ���������� � ����������� ����
#if($sth->rows())
if(0){
	my $addons;
	
	while(my $item=$sth->fetchrow_hashref){
		if($item->{photo}){
			$addons.=qq{<a href="$item->{url}"><img src="./menu_icons/$item->{photo}" target="main"/></a><br>};
		}
		$addons.=qq{<b><a href="$item->{url}" target="main">$item->{header}</a><br></b><br>}
	}
	
	$content=qq{
		<div class="head">&nbsp;</div>
		<div style="padding-left: 20px; line-height: 20px; text-align: center;">
		$addons		
		</div>
		
	};
}
else{
	# ���������, �������� �� ������ � �������� �������?
	$sth=$dbh->prepare("SELECT options from project_group_site where project_id=?");
	$sth->execute($manager->{project_id});

	if(my $options=$sth->fetchrow()){
	my $out='<li><a href="./change_promoblock.pl" target="main">������� �����-����</a></li>';	
		# ���������� ������������ ����� � �����������
		$keys={
			service_promo=>['admin_table.pl?config=promo','Promo'],
			service_searchfiles=>['./admin_table.pl?config=files','����� ��� �����������'],
			service_const=>['./template_const.pl','���������'],
			service_text_page=>['admin_table.pl?config=content','��������� ��������'],
			service_top_menu=>['./admin_tree.pl?config=top_menu_tree','������� ����'],
			service_bottom_menu=>['./admin_tree.pl?config=bottom_menu','������ ����'],
			service_news=>['admin_table.pl?config=news_ct1','�������'],
			service_articles=>['admin_table.pl?config=articles_ct1','������'],
			service_goodkat=>[
				'admin_tree.pl?config=rubricator_ct1','���������� �������',
				'admin_tree_move.pl?config=rubricator_ct1','����������� ������',
				'admin_table.pl?config=good_ct1','������',
				'pxls/pxls.pl','������ XLS',
				'fast_load_photo_good.pl?action=start','������� �������� ���� ��� �������',
			],
			service_service=>['admin_tree.pl?config=service_rubricator_ct1','������'],
			
		};
		$options.=';service_searchfiles;';
		while($options=~m/;([^;]+);/gs){
			my $o=$1;
			my $i=0;
			while($i<scalar(@{$keys->{$o}})){
				my $url=$keys->{$o}->[$i];
				my $description=$keys->{$o}->[$i+1];
				$out.=qq{<li><a href="$url" target="main">$description</a></li>};
				$i+=2;
			}
			#foreach my ($link,$description) = ($keys->{$o}){
			#	print "$link ; $description<br/>";
			#}
		}
		
		$content=qq{
					<div class="head">������� �����</div>
						<ul class="spec list9">
							$out
						</ul>	
				};

	}
	else{
		
		
		#/************************************************
		#/* �������� ����� �������
		#/* �� �� ������ ���� ��� ���� ����. �������.
		
		my $addons;
		
				#��������� � ����� ������������� ������ CSV
				$sth=$dbh->prepare('SELECT options from project where project_id=?');
				$sth->execute($manager->{project_id});
				
				$_____options = $sth->fetchrow();
				
				
		
		#/************************************************
		#/* ���������� ����� ����������� �������
		if ( $_____options =~ /new_client_backend_style/ ) {
			
			$params->{TMPL_VARS}->{STANDART} = $dbh->selectall_arrayref("select header,link FROM struct_public, project_struct_public WHERE struct_public.struct_public_id=project_struct_public.struct_public_id and project_struct_public.project_id=$manager->{project_id}", {Slice=>{}});
				
			#�������� ������ ��� ������������ ���������
			#  
			#� ������� ������ ����� ����:
			#	1. �� ������ (����)
			#	2. ���� �����������
			#
			# ����� ������ ������ �������� ����� �������������� ��� �� ��� ���������� ������ ��������
			
				my $icons = $dbh->selectall_hashref("SELECT  *, id as id, concat('/files/project_3306/icons/',photo) as photo_and_path , concat('/files/project_3306/icons/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1 , concat('/files/project_3306/icons/',substring_index(photo,'.',1),'_mini2','.',substring_index(photo,'.',-1)) as photo_and_path_mini2 , concat('/files/project_3306/icons/',substring_index(photo,'.',1),'_mini3','.',substring_index(photo,'.',-1)) as photo_and_path_mini3 FROM struct_icons", "id");
				my $groups = $dbh->selectall_hashref("SELECT  *, rubricator_id as id, concat('/files/project_3306/types_icons/',photo) as photo_and_path , concat('/files/project_3306/types_icons/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1 , concat('/files/project_3306/types_icons/',substring_index(photo,'.',1),'_mini2','.',substring_index(photo,'.',-1)) as photo_and_path_mini2 , concat('/files/project_3306/types_icons/',substring_index(photo,'.',1),'_mini3','.',substring_index(photo,'.',-1)) as photo_and_path_mini3 FROM struct_groups WHERE path='' ", "rubricator_id");
				
				
#				print "SELECT  *, rubricator_id as id, concat('/files/project_3306/types_icons/',photo) as photo_and_path , concat('/files/project_3306/types_icons/',substring_index(photo,'.',1),'_mini1','.',substring_index(photo,'.',-1)) as photo_and_path_mini1 , concat('/files/project_3306/types_icons/',substring_index(photo,'.',1),'_mini2','.',substring_index(photo,'.',-1)) as photo_and_path_mini2 , concat('/files/project_3306/types_icons/',substring_index(photo,'.',1),'_mini3','.',substring_index(photo,'.',-1)) as photo_and_path_mini3 FROM struct_groups WHERE project_id=$manager->{project_id}";
				
				$$params{TMPL_VARS}{ICONS} = $icons;
				$$params{TMPL_VARS}{GROUPS} = $groups;
				
				
				# �������, ����� ���. ������� ��������� � ���� �������
				$params->{TMPL_VARS}->{ADDONS} = $dbh->selectall_arrayref("SELECT struct_id,header,admin_script, struct_type, struct_icon as struct_icon_id from struct where project_id=$manager->{project_id} and enabled order by header", {Slice=>{}});

				foreach ( @{ $$params{TMPL_VARS}{ADDONS} } ) {
					#$_->{struct_icon} = $cons->{struct_icon_id}->{photo_and_path};
				}
				
				#/*********************************************************
				
				if ( $_____options =~ /promo_loader/  ) {					
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./promo_parser_dev.pl?project_id=$$manager{project_id}" target="main"><b>��������� promo �� XLS</b></a></li>};
				}
				if ( $options =~ /redirect_loader/ ){
					$addons.=qq{<li><a href="./redirect_parser_dev.pl?project_id=$$manager{project_id}" target="main"><b>��������� ���������</b></a></li>};
				}
				
				
				#/*********************************************************
				
				if ( $_____options =~ /goods_pic_loader/  ) {					
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./artikulTools.pl?project_id=$$manager{project_id}" target="main"><b>��������� ���� �� ��������</b></a></li>};
				}
				
				#/*********************************************************
				
				if ( $_____options =~ /use_csv_parser_uploader/  ) {					
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./parserConnector.pl?project_id=$$manager{project_id}&type=csv" target="main"><b>������ CSV</b></a></li>};
				}
			
				if ( $_____options =~ /use_xml_parser_uploader/  ) {
					$addons.=qq{<li><a href="./parserConnector.pl?project_id=$$manager{project_id}&type=xml" target="main"><b>������ XML</b></a></li>};
				}
			
				#/**********************************************************
				
				# ���� ���������� ������� -- ������� � ��:
				$sth=$dbh->prepare('SELECT id,header from pxls where project_id=?');
				$sth->execute($manager->{project_id});

				while(my ($id,$header)=$sth->fetchrow()){
					$addons.=qq{<li><a href="./pxls/pxls.pl?config_id=$id" target="main">$header</a></li>}
				}
				
				#/*********************************************************
				
				
			
		}
		else {
		#/************************************************
		#/* ���������� ����������� �������
			
		
				# ����� ����������� ������� ����������?
				$sth=$dbh->prepare('select header,link FROM struct_public, project_struct_public WHERE struct_public.struct_public_id=project_struct_public.struct_public_id and project_struct_public.project_id=?');
				$sth->execute($manager->{project_id});
				my $standart='';
				while(my ($header,$link)=$sth->fetchrow()){
					$standart.=qq{<li><a href="$link" target="main">$header</a></li>}
				}

				# �������, ����� ���. ������� ��������� � ���� �������
				#my $addons='';
				$sth=$dbh->prepare('SELECT struct_id,header,admin_script from struct where project_id=? and enabled order by header');
				$sth->execute($manager->{project_id});
				while(my ($struct_id,$header,$admin_script)=$sth->fetchrow()){
					$addons.=qq{<li><a href="./$admin_script?config=$struct_id" target="main">$header</a>};
					if($admin_script eq 'admin_tree.pl'){
							$addons.=qq{<br><i><span class="f-10 gray"><a href="./admin_tree_move.pl?config=$struct_id" target="main">(�����������)</a></span></i></br>}
					}
					$addons.=q{</li>}
				}
				#/********************************************************

				if ( $_____options =~ /url_generator/ ){
					$addons.=qq{<li><a href="/manager/generator_url.pl?pid=$$manager{project_id}" target="main"><b>��������� ���</b></li>};
				}
				
				#/*********************************************************
				
				if ( $_____options =~ /promo_loader/  ) {					
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./promo_parser_dev.pl?project_id=$$manager{project_id}" target="main"><b>��������� promo �� XLS</b></a></li>};
				}
				if ( $_____options =~ /redirect_loader/ ){
					$addons.=qq{<li><a href="./redirect_parser_dev.pl?project_id=$$manager{project_id}" target="main"><b>�������� ����������</b></a></li>};
				}
				
				
				
				#/*********************************************************
				
				if ( $_____options =~ /goods_pic_loader/  ) {					
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./artikulTools.pl?project_id=$$manager{project_id}" target="main"><b>��������� ���� �� ��������</b></a></li>};
				}
				
				#/*********************************************************

				if ( $_____options =~ /use_csv_parser_uploader/  ) {
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./parserConnector.pl?project_id=$$manager{project_id}&type=csv" target="main"><b>������ CSV</b></a></li>};
				}
				
				if ( $_____options =~ /use_xml_parser_uploader/  ) {
					#$addons.=qq{<li><a href="./parser_scripts/$$manager{project_id}.pl?project_id=$$manager{project_id}" target="main"><b>������ CSV</b></a></li>};
					$addons.=qq{<li><a href="./parserConnector.pl?project_id=$$manager{project_id}&type=xml" target="main"><b>������ XML</b></a></li>};
				}
				
				# ���� ���������� ������� -- ������� � ��:
				$sth=$dbh->prepare('SELECT id,header from pxls where project_id=? and enabled=1');
				$sth->execute($manager->{project_id});

				while(my ($id,$header)=$sth->fetchrow()){
					$addons.=qq{<li><a href="./pxls/pxls.pl?config_id=$id" target="main">$header</a></li>}
				}
				$url_generator=qq{<li><a href="./generator_url.pl?pid=$manager->{project_id}" target="main">��������� ��� (����)</a></li>};
				$url_generator='' unless($manager->{project_id} == 4275);
				$exit_btn = '<li><b><a href="http://log:out@'.$ENV{HTTP_HOST}.'/manager/?action=logout" title="�����" target="_top">�����</a></b></li>';
				$content=qq{
					<div class="head">����������</div>
						<ul class="spec list9">
							$exit_btn
							$standart
							$url_generator
						</ul>	
						<div class="head">������� � �������</div>		
						<ul  class="spec list9">
							$addons		
					</ul>
				};
				
				
		}		
				
				
				
				
				
				
				
	}
}
if ( $_____options =~ /new_client_backend_style/ ) {

       eval(q{ 
        my $template = Template->new(
        {
            INCLUDE_PATH => $params->{project}->{template_folder},
            COMPILE_EXT => '.tt2',
            COMPILE_DIR=>$CMSpath.'/tmp',
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
	
}
else {
print qq{
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ru" lang="ru">
<head>
<meta http-equiv="content-type" content="text/html; charset=windows-1251" />
<meta http-equiv="description" content="" />
<meta http-equiv="keywords" content="" />
<title>Untitled Document</title>
<link href="css/style.css" rel="stylesheet" type="text/css" media="screen, projection" />
<!--// ���������� ����������� � ����� ���� � ������ � � ����� ie.css  //-->
<!--[if lte IE 8]>
<link href="css/ie.css" rel="stylesheet" type="text/css" media="screen, projection" />
<script type="text/jscript" src="javascript/ie.pack.js"></script>
<![endif]-->
</head>
<body>
<div class="wrapper">
	<div class="header">
		<div class="logo"><a href="http://www.designb2b.ru" target='_blank'>designb2b</a></div>
	</div>
	$content
	<!-- $manager->{project_id} -->
	<div class="undfoot"></div>
	<div class="footer"></div>
</div>
</body>
</html>
};
}
