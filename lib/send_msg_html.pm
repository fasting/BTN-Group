package send_msg_html;
use MIME::Lite::TT::HTML;
use CGI;

BEGIN {
	use Exporter ();
	@ISA = "Exporter";
	@EXPORT = ('&send_msg_html');
}

our $params;

# �������� ������ �� HTML �������
sub send_msg_html {
	my($in) = @_;

	# ����� � �������
	my $prj = $::params->{project};
	
	# �������� �� ���������
	my $from = 'no-reply@'.$prj->{domain};
	my $mail_tmpl = '/templates/mail_tmpl/';
	my $fld = $ENV{DOCUMENT_ROOT}.$mail_tmpl;
	my $subject = $in->{Subject} ? $in->{Subject} : '��������� � ����� '.$prj->{domain};
	my $tmpl = $in->{tmpl} ? $in->{tmpl} : 'default.tmpl';
	my $tmpl_vars = {
		fields=>$in->{fields},
		site=>$prj->{domain},
		LIST=>$in->{LIST},
		ORDER=>$in->{ORDER},
		TEMPLATE_FOLDER=>'http://'.$prj->{domain}.$mail_tmpl,
		alt=>$in->{alt},
		const=>$::params->{TMPL_VARS}{const},
		tv=>$::params->{TMPL_VARS},
	};
	
	# ���� ����� ������ ������
	my @errors;
	
	push @errors,'�� ������ ����������' if(!$in->{To} || $in->{To} eq '');
	
	if(!$in->{tmpl} && $in->{tmpl_type}){
		$tmpl='order.tmpl';
		$ubject = '����� � ����� '.$tmpl_vars->{site} unless $in->{Subject};
	}

	if($in->{tmpl}){
		$fld = $prj->{template_folder};
		$fld =~ s/^\.//;
		$tmpl_vars->{TEMPLATE_FOLDER}='http://'.$prj->{domain}.$fld.'/mail';
		$fld = $ENV{DOCUMENT_ROOT}.$fld.'/mail/';
	}

#	push @errors,$fld.$tmpl;
	return @errors if(scalar(@errors));

	my $msg = MIME::Lite::TT::HTML->new(
		From => $in->{From} ? $in->{From} : $from,
		To => $in->{To},
		Subject => $subject,
		TimeZone => 'Europe/Moscow',
		Encoding => 'quoted-printable',
		Template => { html=> $tmpl },
#		Type=>'multipart/mixed',
		Charset => 'windows-1251',
		TmplOptions => {INCLUDE_PATH => $fld},
		TmplParams=>$tmpl_vars,
	);


# ���������� �������� �������� ������.	
	if(scalar(@{$in->{files}})){
		foreach(@{$in->{fields}}){
		if($_->{type} eq 'file'){
			push @errors,$_;
			
			#return @errors if(scalar(@errors));
			$msg->attach(
				Path=>$_->{full_path},
				Filename=>$_->{filename},
				Disposition=>'attachment',
			);
		}}
	}
	return @errors if(scalar(@errors));
	return $msg->send;
}

return 1;

END {}
