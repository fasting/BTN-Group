# ��� ����� tinymce
$tiny_mce_www = '../../tinymce/';
do '../connect';
my $dbh=DBI->connect("DBI:mysql:$DBname:$DBhost",$DBuser,$DBpassword, , { RaiseError => 1 }) || die($!);
my $sth=$dbh->prepare("SELECT project_id from manager where login=?");
$sth->execute($ENV{REMOTE_USER});
my $project_id=$sth->fetchrow();

# ��� �� ������ ������ ��������
$upload_path = '/files/project_'.$project_id;#.'/wysiwyg';

# ���� �������� �����
$upload_root_path = '../../files/project_'.$project_id;#.'/wysiwyg';

# ���� ������ ��� ��������
@types_file = qw(7z rar zip doc docx pdf xls xlsx odt ods cer crl); 

# ���� �����������
@types_img = qw(gif jpg jpeg gif png bmp swf svg);

# ������������ ������ �����
$file_size_max = 26*1024*1024;

#���������� 1-�� ������� ��������, 2-�� ��������, 0 - ��� ����������
#���������� ������
$type_sort_file = 1;

#������� ���������� ������
$order_sort_file = 'desc';

#���������� ���������
$type_sort_dir = 2;

#������� ���������� ���������
$order_sort_dir = 'asc';
