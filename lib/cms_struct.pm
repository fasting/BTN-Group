package cms_struct;
use CGI::Fast qw(:standard);
use CGI::Cookie;
use CGI::Carp qw/fatalsToBrowser/;
use Data::Dumper;
use DBI;
BEGIN {
		use Exporter ();
		@ISA = "Exporter";
		@EXPORT = ('&get_table_from_struct','&get_work_table_id_for_struct','&get_work_table_id_for_table');
}
# ��������� �� ��������� ������
my $m = {};
bless($m, "main");
my $dref = $m->can("_BEGIN"); 

our $params;

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
		return 'struct_'.$params->{project}->{project_id}.'_'.$struct;
	}
}

sub get_work_table_id_for_struct{
	# ���������� Primary key ��� ���������

	my $struct=shift;
	my $table=&get_table_from_struct($struct);
	my $sth=$::params->{dbh}->prepare("SELECT body FROM struct WHERE project_id=? AND table_name=?");
	$sth->execute($::params->{project}->{project_id},$table);
	unless($sth->rows()){
		&::print_error("�� ������� ������� ��������� $struct");
	}
	my $body=$sth->fetchrow();
			
	$body=~s/our\s*\%form/my \%form/sg;

	# ��� ��������� ���������� ��������� ������
	my $work_table_id;
	$body.=q{
		$work_table_id=$form{work_table_id};
	};

	eval($body);
	if($@){
		&print_error ($@);
	}		
	return $work_table_id;
}

sub get_work_table_id_for_table{
	# ���������� Primary KEY ��� �������
	my $table=shift;
	print "Content-type: text/html\n\n";
	my $sth=$::params->{dbh}->prepare("desc $table");
	$sth->execute();
	while(my $h=$sth->fetchrow_hashref()){
		return $h->{Field} if($h->{Key} eq 'PRI');
	}
	return 0;
}

return 1;
END { }
