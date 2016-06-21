#!/usr/bin/perl

use warnings;
use diagnostics;
use strict;
use Data::Dumper;
use DBI;
use CGI qw(:standart);
use CGI::Carp qw{fatalsToBrowser};
use Template;
use Lingua::Translit;

# ���������� ������ ��� ������ � ��
do './connect';
use vars qw{$DBname $DBhost $DBuser $DBpassword $CMSpath};

# ����������� � ��
my $dbh = DBI->connect("DBI:mysql:$DBname:$DBhost", $DBuser, $DBpassword, , {RaiseError => 1}) || die($!);
#$dbh->do('SET names utf8');

print "Content-Type: text/html; charset=windows-1251\n\n";

# �������������� ������������ ��� ������
my $tmpl = Template->new({
	INCLUDE_PATH => './templates/url_generator/',
	COMPILE_EXT => '.tmpl',
	COMPILE_DIR => './parser_scripts/tmp',
	CACHE_SIZE => 512,
	PRE_CHOMP => 1,
	POST_CHOMP => 1,
	DEBUG_ALL => 1,
});

# ��������� ������
my $q = CGI->new();
my $p = {
	project_id => $q->param('pid')||$q->param('project_id'),
	action => $q->param('action') ? $q->param('action') : 'list',
};

if($p->{action} eq 'list'){
	$p->{TMPL_VARS}{LIST}=$dbh->selectall_arrayref("SELECT ug.*,s.* FROM url_generator ug INNER JOIN struct s ON s.struct_id = ug.struct_id AND s.project_id = ug.project_id WHERE ug.project_id = ?",{Slice=>{}},$p->{project_id});
}
else{
	$dbh->do("SET names utf8");
	if($p->{action} eq 'ajax'){
		if($q->param('struct_id')){
			my $struct = $dbh->selectrow_hashref("SELECT project_id,struct_id,header,table_name FROM struct WHERE project_id = $p->{project_id} AND struct_id = ?",undef,$q->param('struct_id'));
			my $rules = $dbh->selectrow_hashref("SELECT * FROM url_generator WHERE project_id = $p->{project_id} AND struct_id = ?",undef,$q->param('struct_id'));
			my $table = $struct->{table_name};
			my @where;
			push @where, "project_id = $p->{project_id}" if($struct->{table_name} !~ m/^struct/);
			my $sql = "SELECT $rules->{id_field},$rules->{header_field} FROM $table";
			$sql.=' WHERE '.join(' AND ',@where) if scalar(@where);
#			print "Content-Type: text/html;\n\n";
#			print "$sql";
			my $res_list = $dbh->selectall_arrayref($sql,{Slice=>{}});
			my $cnt = 0;
			foreach(@{$res_list}){
				my $obj = $_;
				my $ext_url = $rules->{base}.&generate_url({text=>$_->{"$rules->{header_field}"},opt=>eval($rules->{options})});
				my $in_url = $rules->{in_url}.$_->{"$rules->{id_field}"};
#				$sql = "SELECT count(*) as c FROM in_ext_url WHERE project_id = $p->{project_id} AND ext_url = '$ext_url'";
				$sql = "SELECT count(*) as c FROM in_ext_url WHERE project_id = ? AND ext_url = ?";
				
				if(my $rs = $dbh->selectrow_hashref($sql,undef,($p->{project_id},$ext_url))){
#					print "$rs->{c}<hr>" if $rs->{c} > 0;
					if(!$rs->{c}){
#						$sql = "INSERT INTO in_ext_url(project_id,in_url,ext_url) VALUES($p->{project_id},'$in_url','$ext_url')";
						$dbh->do(
							"REPLACE INTO in_ext_url(project_id,in_url,ext_url) VALUES(?,?,?)",undef,
							($p->{project_id},$in_url,$ext_url)
						);
						$cnt+=1;
					}
					elsif($q->param('type') eq '2' && $rs->{c} eq 1){
#						$sql = "UPDATE in_ext_url SET ext_url = '$ext_url' WHERE project_id = $p->{project_id} AND in_url = '$in_url'";
						$dbh->do(
							"UPDATE in_ext_url SET ext_url = ? WHERE project_id = ? AND in_url = ?",undef,
							($ext_url,$p->{project_id},$in_url)
						);
						$cnt+=1;
					}
					elsif($rs->{c} >= 1){
						my $orig = $dbh->selectrow_hashref("SELECT count(*) as c FROM in_ext_url WHERE project_id = ? AND in_url = ? AND ext_url = ?",undef,($p->{project_id},$in_url,$ext_url));
						if($orig->{c} eq '0'){
							my $orig2 = $dbh->selectrow_hashref("SELECT count(*) as c FROM in_ext_url WHERE project_id = ? and in_url = ? AND ext_url <> ?",undef,($p->{project_id},$in_url,$ext_url));
							if($orig2->{c} eq '0'){
#							$sql = "INSERT INTO in_ext_url(project_id,in_url,ext_url) VALUES($p->{project_id},'$in_url','$ext_url-$obj->{$rules->{id_field}}')";
								$dbh->do(
									#"REPLACE INTO in_ext_url(project_id,in_url,ext_url) VALUES(?,?,?)",undef,
									"INSERT INTO in_ext_url(project_id,in_url,ext_url) VALUES(?,?,?)",undef,
									($p->{project_id},$in_url,$ext_url.'-'.$obj->{$rules->{id_field}})
								);
								$cnt+=1;
							}
						}
					}
#					print "$sql\n" if $rs->{c} > 0;
				}
			}
			my $res_list_count = @{$res_list};
			$p->{TMPL_VARS}{msg}="�����: $res_list_count\n ���������: $cnt";
		}
	}
}


# ����� ������
$tmpl->process("$p->{action}.tmpl",$p->{TMPL_VARS}) || croak 'template error: '.$tmpl->error();

# ����������� �� �� � ��������� ������
$dbh->disconnect;

# ������� ��� ��������� � ��������� URL
sub generate_url {
	my $in = shift;
	my $t = new Lingua::Translit('GOST 7.79 RUS');
	my $txt = $t->translit($in->{text});
	my $url_lenght = $in->{opt}{lenght} ? $in->{opt}{lenght} : 200;#25; # unless($in->{opt}{lenght});
        my $space = $in->{opt}{space} ? $in->{opt}{space} : '-'; # unless($in->{opt}{space});
#        print Dumper($in);

	# �������� ������� �� -
#	$txt =~ s/ /$space/g;
	$txt =~ s/ /-/g;

	# �������� �� - ����� ��� �� 2 � ����� -
#	$txt =~ s/[-]{2,}/$space/g;
	$txt =~ s/[-]{2,}/-/g;

	# ������� ��� ������� ������� �� ������ � ������� ��������
	$txt =~ s/[^a-zA-Z0-9-]//g;

	# �������� ��������� ��� ��������������� URL
	my $result = $txt;
#	print $url_lenght;
	# ��������� ���-�� ��������
	if(length($txt) > $url_lenght){
		$result = '';
		my @str = split('-',$txt);
		my $i = 0;
		foreach(@str){
			$result .= $i == 0 ? $_ : '-'.$_;
			$i += length($_);
			last if $i >= $url_lenght;
		}	
	}

	# �� ������ ������ ������� � ����� ������ -, � ������ ������� ������� ���� � ���������
	$result =~ s/-$//;
	$result =~ tr/A-Z/a-z/;
	return $result;
}
