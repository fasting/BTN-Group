package read_conf;
use DBI;
use CGI qw(:standard);
use CGI::Carp qw (fatalsToBrowser);
use Data::Dumper;
use auth;
BEGIN {
		use Exporter ();
		@ISA = "Exporter";
		@EXPORT = ('&read_config', '&connect','$dbh');
	}
use struct_admin;

# ������ ��������� ������������� ��������� ��� ������� ��� ����� �� �� �����-�������, � ���-������ �� ��, � ��������� ������ � �.�.
# ������� ����� ������������� ������� ��� ������ � ������������ ������� (��� ����� �������� ���, ��� ���� ������).
# read_data($config)
sub read_config{
	my $cgi=new CGI;
	my $config=param('config');

	do './connect';
	my $dbh = DBI->connect("DBI:mysql:$DBname:$DBhost",$DBuser,$DBpassword, , { RaiseError => 1 }) || die($!);
	$dbh->do("SET NAMES CP1251"); 
	# ������� ������ ����������:
	my $already_read=0;
	
	# ����������� project_id
	my $sth=$dbh->prepare("SELECT d.domain,m.project_id from manager m, domain d WHERE m.project_id = d.project_id and m.login=?");# AND d.domain=?");
	$sth->execute($ENV{REMOTE_USER});
#	$sth->execute($ENV{REMOTE_USER},$ENV{HTTP_HOST});
	my $project;
	$a = auth->new();
	if($a eq 'False'){print "Content-Type: text/html;\n Status: 401 Authorization required\n"; print "������ �����������"; exit;}
	unless($sth->rows()){
		print "���������� ������ �����������";
		exit;
	}
	$project=$sth->fetchrow_hashref();
	
	
	$sth->finish();
	

	
	# ������ ����� ��������, ���. ����� ������� ����������:

	#print "config: $config<br/>";
	if($config=~m/^[a-zA-Z0-9\_]+$/ && -e qq{./conf/$config}){
			my $code = &read_file("./conf/$config");
			$code=~s/\[%project_id%\]/$project->{project_id}/gs;
			#print "code: $code<br/>";
			eval($code);
			print @$ if(@$);	
			$already_read=1;
	}
	
	$form{project}=$project;
	$form{project_id}=$form{project}->{project_id};
	if(!$already_read){
		exit unless($config=~m/^\d+$/);
		my $sth=$dbh->prepare("select s.body from manager m ,struct s where m.login=? and m.project_id=s.project_id and struct_id=?");
		$sth->execute($ENV{REMOTE_USER},$config);
		unless($sth->rows()){
			print "������ �� ������ �� �������";
			exit;
		}
		my $conf=$sth->fetchrow();
		$sth->finish();
		
		$conf=~s/\[%project_id%\]/$project->{project_id}/gs;
		
		eval($conf);
		print $@ if($@);	
		#print $form;
	}
	$form{project}=$project;
	$form{project_id}=$form{project}->{project_id};

	$form{add_where}="wt.project_id=$project->{project_id}" unless($form{work_table}=~m/^struct/);
	
	# ---------

	$form{action}=$cgi->param('action');
	my $id=$cgi->param('id');
	if($id=~m/^\d+$/){
		$form{id}=$id;
	}
	$form{config}=$config;
	$form{dbh}=$dbh;



	# �������
	if($form{action} eq 'insert'){ # ��� ����������
		$form{events}->{before_insert}=&read_file('./conf/'.$config.'_before_insert') unless($form{events}->{before_insert});
		$form{events}->{after_insert}=&read_file('./conf/'.$config.'_after_insert') unless($form{events}->{after_insert});
	}
	if($form{action} eq 'update'){ # ��� ����������
		$form{events}->{before_update}=&read_file('./conf/'.$config.'_before_update') unless($form{events}->{before_update});
		$form{events}->{after_update}=&read_file('./conf/'.$config.'_after_update') unless($form{events}->{after_update});
	}
	if($ENV{SCRIPT_NAME} eq 'delete_element'){ # ��� ��������
		$form{events}->{before_delete}=&read_file('./conf/'.$config.'_before_delete') unless($form{events}->{before_delete});
		$form{events}->{after_delete}=&read_file('./conf/'.$config.'_after_delete') unless($form{events}->{after_delete});
	}
	our $form=\%form;
	# �����
	
	$form{events}->{permissions}=&read_file('./conf/'.$config.'_permissions') unless($form{events}->{permissions});
	#if(-f "./conf/$config\_permissions"){ # ����� ������������ ����� ������� � ��� ��� ���� ��������
	#	do './conf/'.$config.'_permissions';
	#}
	
	#$form{events}->{permissions}=&add_code_to_event($form{events}->{permissions},'my $xxw=sub{print "�������3<br/>";}; &$xxw;	');	
	
	# ����� ������� (������)
	$sth=$dbh->prepare("SELECT options FROM project where project_id=?");
	$sth->execute($form{project}->{project_id});
	my $project_options=$sth->fetchrow();
	while($project_options=~m/([^;]+)/gs){
		$plugname=$1;
		#print "qq{./plugins/svcms/$plugname}<br>";
		run_event(read_file(qq{./plugins/svcms/$plugname}));
		$form{project}->{options}->{$plugname}=1
	}

	run_event(read_file(qq{./plugins/svcms/promo}));
	run_event($form{events}->{permissions});

	return $form;
}
sub read_file{
	my $file=shift;
	if(-f $file){
		my $code='';
		open F, $file;
		while(<F>){
			$code.=$_;
		}
		close F;
		return $code;
	}
}



return 1;
END { }
