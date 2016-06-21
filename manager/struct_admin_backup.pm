package struct_admin;
use Template;
BEGIN {
		use Exporter ();
		@ISA = "Exporter";
		@EXPORT = ('&out_form','&get_params_in_form','&insert_data_in_form', '&read_data', '&update', '&del_file', '&gen_field');
	}
	# ��������� ��� �������� �������� ����� (����� �������� � �������������� ��������)

sub read_data{
	my $form=@_[0];
	my $dbh=$form->{dbh};
	unless($form->{id}=~m/^\d+$/){
		print "errmod 8273";
		exit;
	}

	my $sth=$dbh->prepare("SELECT * from $form->{work_table} WHERE $form->{work_table_id}=?");
	$sth->execute($form->{id});
	unless($sth->rows()){
		print "������ � ��������������� $id ���������� �� �������!";
		exit;
	}
	my $items=$sth->fetchrow_hashref();
	foreach my $element (@{$form->{fields}}){
			if($element->{type} eq 'megaselect'){
				my $value='';
				foreach my $name ((split /;/, $element->{name})){
					if($value){$value.=';'}
					$value.=$items->{$name};

				}
				$element->{value}=$value;

			}
			else{
				$element->{value}=$items->{$element->{name}};
			}
	}
}
sub del_file{
=begun
		��� ��������� ����� ��� �������� �����
=cut
	my $form=shift;
	my $dbh=$form->{dbh};
	my $id=$form->{id};
	my $c=new CGI;
	my $field=$c->param('field');

	foreach my $element (@{$form->{fields}}){
		if($element->{name} eq $field){
			my $sth=$dbh->prepare("SELECT $element->{name} FROM $form->{work_table} WHERE $form->{work_table_id}=?");
			$sth->execute($id);
			if($element->{value}=$sth->fetchrow()){
				$sth->finish();
				if($element->{keep_orig_filename}){
					$element->{value}=~s|^(.+);.+$|$1|;
				}
				#print "�������: $element->{filedir}/$element->{value}";
				if($element->{before_delete_code}){
						eval($element->{before_delete_code});
						if ($@){print "died: $@";}
				}
				if($element->{keep_orig_file}){
					$element->{value}=~s|^(.+?);+$|$1|;
				}
				unlink("$element->{filedir}/$element->{value}");
				my $sth=$dbh->prepare("UPDATE $form->{work_table} SET $element->{name}='' WHERE $form->{work_table_id}=?");
				$sth->execute($id);
				if($element->{after_delete_code}){
						eval($element->{after_delete_code});
						if ($@){print "died: $@";}
				}
			}
			$sth->finish();
			last;
		}
	}
	return;
}
sub out_form{
=begin
	��� ��������� ������������ ����� �����
=cut
			my $form = shift;
			my $dbh=$form->{dbh};

			my $fields;
			my $ID_HIDDEN='';
			if($form->{id}=~m/^\d+$/){
				$ID_HIDDEN=qq{<input type='hidden' name='id' value='$id'>}
			}
			#print Dumper($form);
			my $TRS=''; # ������ �������
			foreach my $element (@{$form->{fields}}){
				my $field='';
				next if($element->{type}=~/^filter_/);
				#print "$element->{name} : $element->{value}<br/>";
				$form->{use_wysiwyg}=1 if($element->{type} eq 'wysiwyg');
				$form->{use_codelist}=1 if($element->{type} eq 'codelist');
				$form->{use_1_to_m}=1 if($element->{type} eq '1_to_m');
				$fields->{$element->{name}}=&gen_field($element,$dbh,$form);
			}

			$form->{fld}=$fields;

			if($form->{template_form}){
					my $template = Template->new({INCLUDE_PATH => './conf/templates'});
					$template -> process($form->{template_form}, {
						form=>$form
					});
			}
			else{
					my $template = Template->new({INCLUDE_PATH => './templates'});
					$template -> process('edit_form.tmpl', {
						form=>$form
					});
			}
}

sub get_params_in_form{
=begin
		 	��� ��������� ��������� �������� ��� ��������� �� ��������������� �����,
		 	����� ���������� �� ��������.
		 	� ������ ������ ����������� ������ � ��������� ������.
		 	� ������ ������ ���������� 0
=cut

		my $form = shift;
		my $dbh=$form->{dbh};
		my $id=$form->{id};
		my $c=new CGI;
		my $errors=$form->{errors};

		foreach my $element (@{$form->{fields}}){
			if($element->{type} eq 'multicheckbox'){
					$values='';
					while ($element->{extended}=~m/([^;]+);([^;]+)?/gs){
						my ($permission_name, $permission_description, $permission_checked)=($1,$2,$3);
						$permission_name=erase_spaces($permission_name);
						$permission_description=erase_spaces($permission_description);
						my $chk=$c->param("$element->{name}_$permission_name");
						 if ($chk){
							 $value.=qq{;$permission_name;};
							 $chk='1'
						 }
					}
					unless($value){
						$element->{value}='';
					}
					else{
						$element->{value}=$value;
					}
			}
			elsif($element->{type} eq 'multiconnect'){
				 my $sth=$dbh->prepare("SELECT $element->{relation_table_id} FROM $element->{relation_table}");
				 $sth->execute();
				 while(my $id=$sth->fetchrow()){
				 			$value=$c->param("$element->{name}_$id");
				 			if($value){
				 				$element->{value}.=qq{$id;}
				 			}
				 }
			}
			elsif($element->{type} eq 'megaselect'){
				my $values='';
				my @regexp=(split /;/, $element->{regexp});
				my @descriptions=(split /;/, $element->{description});
				my $i=0;
				foreach my $cur_name ((split /;/, $element->{name})){
					my $cur_value=$c->param($cur_name);
					$cur_value=0 unless($cur_value);
					if(length($values)){$values.=';'};
					$values.=$cur_value;
					if($regexp[$i] && !($cur_value=~m/$regexp[$i]/)){
						$errors.="���� '$descriptions[$i]' �� ��������� ��� ��������� �� �����<br>";
					}
					$i++;
				}
				$element->{value}=$values;
			}
			elsif($element->{type} eq 'checkbox'){
				$element->{value}=$c->param($element->{name});				
				if($element->{extended} eq 'enum'){
					if($element->{value}){$element->{value}='y'}
					else {$element->{value}='n'}
				}
				else{
					if($element->{value}){$element->{value}=1}
					else {$element->{value}=0}
				}
			}
			else{
				my $v=$c->param($element->{name});
				if (defined($v)){
					$element->{value}=$c->param($element->{name}) unless($element->{not_get_param});
				}
			}

			# � ��� ������, ���� ��� �������� ����� ������ ��������� ��� �������� -- ������������ ��� ��������:
			if($element->{regexp} && $element->{type} ne 'megaselect' && !$element->{readonly} && !$element->{read_only}){

				unless($element->{value}=~m/$element->{regexp}/gs){
					# �������� �������� �� ������������� ���������:
						if($element->{type} eq 'file' && $form->{action} eq 'update' && !$element->{value}){
							# ���� �� ����� ���� ��������� �����, �� �� ������� ��� ���� ����...
							# 1. ��������� ������� �����
								my $sth=$form->{dbh}->prepare("SELECT $element->{name} from $form->{work_table} where $form->{work_table_id}=?");
								$sth->execute($form->{id});
								my $old_value=$sth->fetchrow();
								# ���� �� ������ ���������� ����� ������ -- �������� �� ���� ������
								$old_value=~s|^(.[^;]+);.+$|$1| if($element->{keep_orig_filename});

								# ��� ������, ���� ����� ���������� ���� � ��� ������������� ���������
								next if($old_value=~m/$element->{regexp}/);
						}


						if($element->{error_regexp}){
							$errors.="$element->{error_regexp}<br>";
						}
						else{
							$errors.="���� '$element->{description}' �� ��������� ��� ��������� �� �����<br>";
						}

				}
			}

			if($element->{uniquew} && $dbh){ # ���� ������� ����������
					#print "�������� �� ������������";
					my $sql_query;
					if($id=~m/^\d+$/){ # ������������ ��� update
						$sql_query="SELECT count(*) from $form->{work_table} where $element->{name}=? AND $form->{work_table_id}<>$id";
					}
					else{ # ������������ ��� insert
						$sql_query="SELECT count(*) from $form->{work_table} where $element->{name}=?";
					}
				#print $sql_query;
					my $sth=$dbh->prepare($sql_query);
					$sth->execute($element->{value});
					if($sth->fetchrow()){
						$errors.="� ���� ������ ��� ���������� ������, ���� '$element->{description}' ������� ��������� �������� '$element->{value}'";
					}
			}
		}
		#print "e: $errors";
		if($errors){
			if($form->{action} eq 'insert'){ # ���� ��� ���������� ����� ��������� ������, ������������ ���� �� �������
				foreach my $element (@{$form->{fields}}){
					if($element->{type} eq 'file'){
						$element->{value}='';
					}
				}
			}
			$form->{errors}=$errors;
			return $errors;
		}

		return 0;
}

sub insert_data_in_form{
	# �������� ������� ������

	my $form = $_[0];
	my $dbh=$form->{dbh};
	my $errors=get_params_in_form($form);
	my @FIELDS=();
	my @VALUES=();
	my @VOPR=();

	unless($errors){
		my $id=0;
		foreach my $element (@{$form->{fields}}){
			next if($element->{readonly} || $element->{read_only});
			if(
					($element->{type}!~/^label|link|code|memo|file|multiconnect|1_to_m|relation_tree$/) &&
					!($element->{type} =~m/^filter_extend/) 
				){
						if(!$element->{name}){
							print "���� $element->{description} �� ����� �����";
						}
						if($element->{type} eq 'megaselect'){
							my @names=(split /;/, $element->{name});
							my @values=(split /;/, $element->{value});
							my $i=0;
							foreach my $name (@names){
								push @FIELDS, $name;
								push @VALUES, $values[$i];
								push @VOPR,'?';
								$i++;
							}
						}
						elsif((($element->{type} eq 'datetime') || ($element->{type} eq 'date')) && $element->{value} eq 'now()'){
							push @FIELDS, $element->{name};
							push @VOPR,'now()';
						}
						elsif($element->{type} eq 'memo' && $element->{method} eq 'single'){							

							
						}
						else{
							push @FIELDS, $element->{name};
							push @VALUES, $element->{value};
							push @VOPR,'?';
						}
				}
			#print "<b>$element->{name}</b>: $element->{value}<br><br><br>";
		}
		my $query="INSERT INTO $form->{work_table}(".join(',',@FIELDS).') VALUES('.join(',',@VOPR).')';
		if($form->{explain}){
			print "$query<br>";
			print join(',',@VALUES);
		}

		my $sth=$dbh->prepare($query);
		$sth->execute(@VALUES);
		$form->{id}=$sth->{mysql_insertid};
		$sth->finish();		
		&upload_files($form);
		&upload_memo($form);
		&update_multiconnect($form);
		&update_relation_tree($form);
		&ok($form);
		return $form->{id};
	}
	else{
		&out_form($form, $dbh);
	}
	return 0;
}

sub update{
	my $form = $_[0];
	my $dbh=$form->{dbh};
	unless($form->{id}=~m/^\d+$/){
		print "errmod 5232";
		exit;
	}

	if($form->{readonly} || $form->{read_only}){
		print "��������� ���������� ��� �����"; return 0;
	}
	my $errors=get_params_in_form($form);
	my @FIELDS=();
	my @VALUES=();
	my @VOPR=();
	unless($errors){
		foreach my $element (@{$form->{fields}}){
			next if($element->{readonly} || $element->{read_only});
			if(
					($element->{type}!~/^label|link|code|memo|file|multiconnect|1_to_m|relation_tree$/) &&
 					!($element->{type} =~m/^filter_extend/) &&
          !($element->{type} eq 'relation_tree') &&
          !(($element->{type}=~m/^date(time)?$/) && ($element->{default_value}))
				)
				{
						#print "$element->{name} : $element->{value}<br/>";
						if($element->{type} eq 'megaselect'){
							my @names=(split /;/, $element->{name});
							my @values=(split /;/, $element->{value});
							my $i=0;
							foreach my $name (@names){
								push @FIELDS, "$name=?";
								push @VALUES, $values[$i];
								$i++;
							}
						}
						else{
							push @FIELDS, "$element->{name}=?";
							push @VALUES, $element->{value};
						}
			  }
			#print "<b>$element->{name}</b>: $element->{value}<br><br><br>";
		}

		my $query="UPDATE $form->{work_table} SET ".join(',',@FIELDS)." WHERE $form->{work_table_id}=$form->{id}";		
		if($#FIELDS>-1){
			my $sth=$dbh->prepare($query);
			$sth->execute(@VALUES) || die($dbh->errstr());
		}
		&upload_files($form);
		&upload_memo($form);
		&update_multiconnect($form);
		&update_relation_tree($form);
		#&ok;
		return 1;
	}
	else{
		print $errors;
		return 0;
	}
}

sub get_remove_info{ # ���������� �� �������������� ������������ ��� �������� memo
		my $form=shift;
		my $element=shift;
		
		my $sth=$form->{dbh}->prepare("SELECT $element->{auth_id_field} remote_id, $element->{auth_name_field} remote_name FROM $element->{auth_table} WHERE $element->{auth_login_field}=?");
		#$sth->execute('root');
		$sth->execute($ENV{REMOTE_USER});
		return $sth->fetchrow_hashref();
}

sub upload_memo{
	my $form=shift;
	my $c=new CGI;
	foreach my $element (@{$form->{fields}}){
		
		if($element->{type} eq 'memo' && $element->{method} eq 'single'){
			if(my $v=$c->param($element->{name})){
				my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
				my $message;


				$element->{remote_info}=&get_remove_info($form,$element);

				$year+=1900; $mon++;
				#$message=~s/\[%datetime%\]/<datetime>$year\/$mon\/$mday $hour:$min:$sec<\/datetime>/gs;
				#$message=~s/\[%remote_name%\]/$element->{remote_info}->{remote_name}/gs;
				$v=~s/</&lt;/gs;
				$v=~s/>/&gt;/gs;
				$message=qq{<element_memo><ID>$element->{remote_info}->{remote_id}<\/ID><message>$v<\/message><year>$year</year><mon>}.sprintf('%02d',$mon).qq{</mon><mday>}.sprintf('%02d',$mday).qq{</mday><hour>}.sprintf('%02d',$hour).qq{</hour><min>}.sprintf('%02d',$min).qq{</min><sec>}.sprintf('%02d',$sec).qq{</sec></element_memo>};

				my $sth=$form->{dbh}->prepare(qq{UPDATE $form->{work_table} SET $element->{name}=concat($element->{name},?) WHERE $form->{work_table_id}=?});
				$sth->execute($message,$form->{id});
			}
		}
		elsif($element->{type} eq 'memo' && $element->{method} eq 'multitable'){
			if(my $v=$c->param($element->{name})){
				$element->{remote_info}=&get_remove_info($form,$element);
				my $sth=$form->{dbh}->prepare("INSERT INTO $element->{memo_table}($element->{memo_table_foreign_key},$element->{memo_table_auth_id},$element->{memo_table_comment},$element->{memo_table_registered}) VALUES(?,?,?,now())");
				$sth->execute($form->{id},$element->{remote_info}->{remote_id},$v);
			}
		}
	}
}

sub upload_files($form,$dbh,$id){
	my $form=$_[0];
	my $dbh=$form->{dbh};
	my $id=$form->{id};
	unless($id=~m/^\d+$/){
		print "ERROR 72eh";
	}
	my $j=0;
	foreach my $element (@{$form->{fields}}){
            if( ($element->{type} eq 'file')){
				  $j++;

					if($element->{value}=~m/([^\.]+)$/){
						my $orig_name=$element->{value};
						my $ext=$1;
						if($element->{value}=~m/\.(tar\.(gz|bz2))$/){
							$ext=$1
						}
						$ext=$element->{extension} if($element->{extension});
						my $filename_without_ext=(time)."_$j";
						my $filename="$filename_without_ext\.$ext";#$id.qq{_$j.$ext};
						my $full_filename=qq{$element->{filedir}/$filename};
						my $file=$element->{value};
						my $sth=$dbh->prepare("SELECT $element->{name} from $form->{work_table} WHERE $form->{work_table_id}=$id");
						$sth->execute();
						my $oldfile=$sth->fetchrow();
						if($oldfile=~m/^(.+);?/){
							unlink qq{$element->{filedir}/$1};
						}
						open F, ">$full_filename" || die("�� ���� ������� $full_filename �� ������");
							binmode F;
							print F while(<$file>);
						close F;
						my $sth=$dbh->prepare("UPDATE $form->{work_table} SET $element->{name}=? WHERE $form->{work_table_id}=$id");
						$filename=$filename.qq{;$orig_name} if($element->{keep_orig_filename});
						$sth->execute($filename);
						if($element->{converter}){
							$element->{converter}=~s/\[%filename%\]/$full_filename/;
							$element->{converter}=~s/\[%input%\]/$element->{filedir}\/$filename_without_ext/g;
							$element->{converter}=~s/\[%input_ext%\]/$ext/g;
							$element->{converter}=~s/\n/ /gs;
							$element->{converter}=~s/^\s+//gs;
							$element->{converter}=~s/\s+$//gs;
							$element->{converter}=~s/\s+/ /gs;
							#print "$element->{converter}<br/>";
							print `$element->{converter}`;
						}


					}
			}
	}
}

sub update_multiconnect{
	my $form=$_[0];
	my $dbh=$form->{dbh};
	my $id=$form->{id};
		unless($id=~m/^\d+$/){
			print "ERROR 7etx";exit;
		}

		foreach my $element (@{$form->{fields}}){
			if( $element->{type} eq 'multiconnect'){

				$element->{relation_save_table_id_relation}=$element->{relation_table_id} unless($element->{relation_save_table_id_relation});
				$element->{relation_save_table_id_worktable}=$form->{work_table_id} unless($element->{relation_save_table_id_worktable});

				my $exists_id='0';
				while($element->{value}=~m/(\d+);/g){$exists_id.=qq{,$1};}
				# ������� ������ �����, �� �������� � ������ ���, ��� ��������
				#print "DELETE FROM $element->{relation_save_table} WHERE $form->{work_table_id}=$id AND $form->{work_table_id} not in ($exists_id)";
				#print "DELETE FROM $element->{relation_save_table} WHERE $element->{relation_save_table_id_worktable}=$id AND $element->{relation_save_table_id_relation} not in ($exists_id)";
				# ������� ������ �� ������, ����� ��� ������� �� �������
				my $sth=$dbh->prepare("DELETE FROM $element->{relation_save_table} WHERE $element->{relation_save_table_id_worktable}=$id AND $element->{relation_save_table_id_relation} not in ($exists_id)");
				$sth->execute();
				$sth->finish();
				my $created_id='0';

				# �������� �� ������, ������� ��� �������
				my $sth=$dbh->prepare("SELECT $element->{relation_save_table_id_relation} FROM $element->{relation_save_table} WHERE $element->{relation_save_table_id_worktable}=$id");
				$sth->execute();
				while(my $cr_id=$sth->fetchrow()){
					$created_id.=','.$cr_id;
				}
				$sth->finish();

				# ��������� ����� �����:
				while($element->{value}=~m/(\d+);/g){
					my $relation_table_id=$1;
					unless($created_id=~m/(^|,)$relation_table_id(,|$)/){
						$dbh->do("INSERT INTO $element->{relation_save_table}($element->{relation_save_table_id_worktable},$element->{relation_save_table_id_relation}) values($id,$relation_table_id)");
					}
				}

			}
		}
}

sub update_relation_tree{
	my $form=$_[0];
	my $dbh=$form->{dbh};
	my $id=$form->{id};

	unless($form->{id}=~m/^\d+$/){print "ERROR 7etx"; exit;}
	foreach my $element (@{$form->{fields}}){
		if($element->{type} eq 'relation_tree'){
			unless($element->{relation_save_table}=~m/^[a-z_0-9]+$/i){
				print "�� ������� relation_table";
				exit;
				}
				my $cgi=new CGI;
				my @values=$cgi->param($element->{name});
				$dbh->do("DELETE FROM $element->{relation_save_table} where $form->{work_table_id}=$id");
				my $sth=$dbh->prepare("INSERT INTO $element->{relation_save_table}($element->{relation_table_id},$form->{work_table_id}) values(?,?)");
				foreach my $v (@values){
					$sth->execute($v,$form->{id}) if($v=~m/^\d+$/);
				}
			}
		}
}

sub erase_spaces{
	my $s=$_[0];
	$s=~s/(^[\n\s]+|[\n\s]+$)//gs;
	return $s;
}

sub gen_field{
	my ($element,$dbh,$form)=@_;
	my $field='';
	my $sth;
	my $id=$form->{id};
	if($element->{type} eq 'select_values'){ # SELECT_VALUES_FIELD
		if($element->{readonly} || $element->{read_only}){

				while($element->{values}=~m/(.+?)=>(.+?)(;|$)/gs){
					my ($k,$v)=($1,$2);
					if($element->{value}==$1){
						$field=$2; next;
					}
				}
		}
		else{
				if($element->{default_label_empty}){
						$label_empty=$element->{default_label_empty};
				}
				else{
						$label_empty="�������� �������� ��� ���� $element->{description}";
				}
				$field=qq{<SELECT name='$element->{name}'};
				if($element->{onchange}){
					$field.=qq{ onchange="$element->{onchange}"} 
				}
				$field.=qq{ id='$element->{name}'><option value='$element->{default_value_empty}'};
				my @colors=split(';',$element->{colors});

				$field.=qq{ style='background-color: $colors[0]'} if($colors[0]);
				$field.=qq{>$label_empty</option>};
				my $i=1;
				$element->{values}=~s|\n[\t\s]+||gs;
				while($element->{values}=~m/([^;]+)/gs){
					$el=$1;
					if($el=~m/^(.+?)=>(.+?)$/){						
						my($id,$header)=($1,$2);
						my $selected='';
						if($id eq $element->{value}){
							 	 $selected=' selected';
						}

						my $background='';
						if($colors[$i]){
								$background=qq{ style=' background-color: $colors[$i]'}
						}
						$field.=qq{<option value='$id'$selected$background>$header</option>}
					}
					$i++;
				}
				$field.=qq{</select>}
		}
	}
	elsif($element->{type} eq 'text'){ # TEXT FIELD
		$element->{value}=~s/'/&rsquo;/g;
		if($element->{read_only} || $element->{readonly}){
				$field=$element->{value};
		}
		else{
			$field=qq{<input type='text' name='$element->{name}' id='$element->{name}' class='txt' value='$element->{value}'>};
		}
	}
	elsif($element->{type} eq 'textarea'){ # TEXTAREA FIELD
		if($element->{read_only} || $element->{readonly}){
				$field=$element->{value};
				$field=~s/\n/<br>/g;
		}
		else{
			my $html_id='';
			$html_id=qq{id='$element->{html_id}'} if($element->{html_id});
			my $style='';
			$style=qq{style='$element->{style}'} if($element->{style});
			$field=qq{<textarea name='$element->{name}' $html_id $style>$element->{value}</textarea>};
		}
	}
	elsif($element->{type} eq 'hidden'){ # HIDDEN_FIELD
		$element->{value}=~s/"/&quot;/g;
		$element->{id}||=$element->{name}.'_id';
		$field=qq{<input type='hidden' name='$element->{name}' id='$element->{id}' value="$element->{value}" class='input'>};
	}
	elsif($element->{type} eq 'select_from_table'){ # SELECT_FROM TABLE
		my $label_empty;
		if($element->{default_label_empty}){
			$label_empty=$element->{default_label_empty};
		}
		else{
			$label_empty="�������� �������� ��� ���� $element->{description}";
		}

		if($element->{readonly} || $element->{read_only}){ # ���� ������ ������ ��� ������ -- ������� ������ ��������
			my $sth_query="SELECT $element->{header_field} as header FROM $element->{table} WHERE $element->{value_field}=?";
			my $sth=$dbh->prepare($sth_query);
			$sth->execute($element->{value}) || die($dbh->errstr());
			my $header=$sth->fetchrow();
			$header='�� �������' unless($header);
			$sth->finish();
			$field=$header;
		}
		else{
			my $order=qq{order by $element->{order}} if($element->{order});
			$element->{where}=qq{where $element->{where}} if(!($element->{where}=~m/\s*where/i) && $element->{where});
			
			if($element->{tree_use}){
					if($element->{sort}){
						$element->{sortfield}='sort'
					}
					else{
						$element->{sortfield}=$element->{header_field};
					}
					$field=qq{<SELECT name='$element->{name}' id='$element->{name}'};
					$field.=qq{ onchange="$element->{onchange}"};
					$field.="><option value='$element->{default_value_empty}'>$label_empty</option>".&get_branch('',$element).'</select>';
					sub get_branch{
							my ($path,$element)=@_;
							my $optlist='';
							my $where=$element->{where};
							$where.=' AND ' if($where);
							$where.=qq{path=?};
					
							$where=qq{WHERE $where} unless($where=~m/^\s*where/i);
							my $level=0;
							while($path=~m/\d+/g){$level++};
							my $sth=$form->{dbh}->prepare(qq{
								SELECT $element->{value_field} as id, $element->{header_field} as header 
								FROM $element->{table}
								$where
								ORDER BY $element->{sortfield}
							});
							$sth->execute($path);
							while(my ($id,$header)=$sth->fetchrow()){
								my $selected='';
								if($id eq $element->{value}){
									$selected=' selected';
								}
								$optlist.=qq{<option value='$id'$selected>}.('&nbsp;&nbsp;'x$level).qq{$header</option>};
								$optlist.=&get_branch(qq{$path/$id},$element);
							}
							return $optlist;
					}
				
				
				
				
				
			}
			else{
					my $sth_query="SELECT $element->{value_field} as id, $element->{header_field} as header $element->{optgroup} FROM $element->{table} $element->{where} $order";
					my $sth=$dbh->prepare($sth_query);			
					$sth->execute() || die($sth_query.'<br>'.$dbh->errstr());
			
					$field=qq{<SELECT name='$element->{name}'};
					if($element->{onchange}){								
						$field.=qq{ onchange="$element->{onchange}"};
					}
					$field.=qq{ id='$element->{name}'><option value='$element->{default_value_empty}'>$label_empty</option>};
			
					while(my ($id, $header, $optgroup)=$sth->fetchrow()){ # �������� ����
						if( $element->{optgroup} && $optgroup ) {
							$field.=qq{<optgroup label="$header">};
						}else{
							my $selected='';
							if($id eq $element->{value}){
								$selected=' selected';
							}
							$field.=qq{<option value='$id'$selected>$header</option>};
						}
					}
					$field.=qq{</select>};
			}
		}
	}
	elsif($element->{type} eq 'checkbox'){ # CHECKBOX FIELD
		my $checked='';
		if($element->{extended} eq 'enum' && $element->{value} eq 'y'){
			$checked='checked';
		}
		elsif($element->{extended} ne 'enum' && $element->{value}) {$checked='checked'}
		
		$field=q{<input type='checkbox'};
		if($element->{onchange}){								
				$field.=qq{ onchange="$element->{onchange}"};
		}
		$field.=qq{ name='$element->{name}' $checked>};
	}
	elsif($element->{type} eq 'multicheckbox'){ # MULTICHECKBOX FIELD
		my $i=0;
		my @chk_mas=split /;/, $element->{value};
		while ($element->{extended}=~m/([^;]+);([^;]+)?/gs){
			my ($permission_name, $permission_description, $permission_checked)=($1,$2,$3);
			$permission_name=erase_spaces($permission_name);
			$permission_description=erase_spaces($permission_description);
			my $checked='';
			if($element->{value}=~m/;$permission_name;/){
				$checked=' checked';
			}
			$field.=qq{<input type='checkbox' name='$element->{name}_$permission_name'$checked> $permission_description<br>};
				$i++;
			}
			$field=qq{<div style='padding-left: 20px;'><small>$field</small></div>};
	}
	elsif($element->{type} eq 'multiconnect'){ # MULTICONNECT
		# ������� ����� "������ �� ������"
		my $i=0;
		$element->{relation_save_table_id_relation}=$element->{relation_table_id} unless($element->{relation_save_table_id_relation});
		$element->{relation_save_table_id_worktable}=$form->{work_table_id} unless($element->{relation_save_table_id_worktable});
		# �������� ��� ���������� ������
		my %on=();
		if($form->{id}=~m/^\d+$/){
			my $sth=$dbh->prepare("SELECT $element->{relation_save_table_id_relation}  from $element->{relation_save_table} WHERE $element->{relation_save_table_id_worktable}=$form->{id}");
			$sth->execute();

			while(my $f=$sth->fetchrow()){$on{$f}=1}
				$sth->finish();
			}

			$sth=$dbh->prepare("SELECT $element->{relation_table_id} as id, $element->{relation_table_header} as header from $element->{relation_table} order by $element->{relation_table_header}");
			$sth->execute();
			while (my ($relation_id, $relation_header)=$sth->fetchrow()){
				my $checked='';
				if($on{$relation_id}){
					$checked=' checked';
				}
				$field.=qq{<input type='checkbox' name='$element->{name}_$relation_id'$checked> $relation_header<br>};
				$i++;
			}
			$field=qq{<div style='padding-left: 20px;'><small>$field</small></div>};
	}
	elsif($element->{type} eq 'megaselect'){ # MEGASELECT
		my @descriptions=(split /;/, $element->{description});
		my @names=(split /;/, $element->{name});
		my @tables=(split /;/, $element->{table});
		my @headers=(split /;/, $element->{table_headers});
		my @indexes=(split /;/, $element->{table_indexes});
		my @despendences=(split /;/, $element->{despendence});
		my @values=(split /;/, $element->{value});

		my $default_value=$values[0];
		my $nameparam=$element->{name};
		$nameparam=~s/;/\//g;
		my $add_change='';
		if ($#names>2){
			my $i=2;
			while($i<=$#names){
				my $prev=$i-1;
				$add_change.=qq{document.getElementById('megaselect_$names[$i]').innerHTML='��� ������ ���� "$descriptions[$i]" �������� �������� � ���� "$descriptions[$prev]"'\n};
				$i++;
			}

		}
		$field=qq{
			<script>
				function change_select_$names[0](v){
					loadDoc('./edit_form?config=$form->{config}&action=load_megaselect&position=1&name=$nameparam&despendence_value='+v, 'megaselect_$names[1]');
					$add_change
				}
			</script>
		};

		$field.=qq{<b>$descriptions[0]</b>:<br/><select name='$names[0]' OnChange="change_select_$names[0](this.value)"><option value='0'>�������� �������� ��� ���� $descriptions[0]</option>};
		my $WHERE='';
		if($despendences[0]){
			$WHERE=qq{WHERE $despendences[0]};
		}

		my $sth=$dbh->prepare("SELECT $headers[0],$indexes[0] FROM $tables[0] $WHERE  order by $headers[0]");
		$sth->execute();
		while(my ($h,$i)=$sth->fetchrow()){
			my $selected='';
			if($default_value==$i){
				$selected=' selected';
			}
			$field.=qq{<option value="$i"$selected>$h</option>};
		}
		$field.=q{</select>};
		my $i=1;
		while($descriptions[$i]){
			$field.=qq{<br/><br/><b>$descriptions[$i]</b>:<div id='megaselect_$names[$i]'>��� ������ ���� "$descriptions[$i]" �������� �������� � ���� "$descriptions[$i-1]"</div>};
			if($values[$i]){
				my $prev=$values[$i-1];
				$field.=qq{
					<script>
					 document.getElementById('megaselect_$names[$i]').innerHTML=loadDocAsync('./edit_form?config=$form->{config}&action=load_megaselect&position=$i&name=$nameparam&despendence_value=$prev&cur_value=$values[$i]')
					</script>
				}
			}
			$i++;
		}
	}
	elsif($element->{type} eq '1_to_m'){# ����� "���� �� ������"

		if($form->{action} eq 'insert'){
			$field=q{��� ���� �������� ������ ��� ��������� ��� ������������� �������<br/>��� �������� ������� ������������� ���� ������}
		}
		else{
			$field=qq{
				<div id='1_to_m_$element->{name}'></div>
				<script>
					document.getElementById('1_to_m_$element->{name}').innerHTML=loadDocAsync('./load_1_to_m.pl?config=$form->{config}&field=$element->{name}&id=$id')
				</script>
			};
		}
	}
	elsif($element->{type} eq 'code'){
		foreach my $r (@{$form->{fields}}){
			$element->{code}=~s/\[%$r->{name}%\]/$r->{value}/gs;
		}
		if(ref($element->{code}) eq 'CODE'){
			
			$field=&{$element->{code}};
		}
		else{
			eval($element->{code});
		}
		if ($@){print "died: $@";}
	}
	elsif($element->{type} eq 'relation_tree'){
		$field=qq{
			<div id='relation_tree_$element->{name}'></div>
				<script>document.getElementById('relation_tree_$element->{name}').innerHTML=loadDocAsync('./load_relation_tree.pl?config=$form->{config}&field=$element->{name}&key=$id');</script>
		}
	}
	elsif($element->{type} eq 'wysiwyg'){
		my $html_id='';
		$html_id=qq{id='$element->{html_id}'} if($element->{html_id});
		$field=qq{<textarea name='$element->{name}' class='mce' convert_this=true $html_id>$element->{value}</textarea>};
	}
	elsif($element->{type} eq 'codelist'){
		$field=qq{<textarea id='$element->{name}' name='$element->{name}' class='codepress perl' style='$element->{style}'>$element->{value}</textarea>
		<script>
					editAreaLoader.init({
						id : "$element->{name}"		// textarea id
						,syntax: "perl"			// syntax to be uses for highgliting
						,start_highlight: true		// to display with highlight mode on start-up
					});
					
			</script>
		}
	}
	elsif($element->{type} eq 'date'){
		my $div_name=$element->{name}.'_d';
		unless($element->{value}=~m/[123456789]/){
			$element->{value}='0-0-0';
		}
		if($element->{readonly} || $element->{read_only}){
			$field=$element->{value};
		}
		elsif($element->{default_value} eq 'now()'){
			my $pr_val='-';
			$pr_val=$element->{value} if($element->{value} ne '0-0-0');
			$field=qq{<input type="hidden" name="$element->{name}" value="now()">$pr_val};
		}
		else{
			$field=qq{
				<input type='hidden' name='$element->{name}' id='$element->{name}' value='$element->{value}'>
				<div id='$div_name'></div>
				<div id='empty_$div_name'><a href="" OnCLick="document.getElementById('$element->{name}').value=save_$element->{name}; document.getElementById('$div_name').style.display='';  document.getElementById('empty_$div_name').style.display='none'; return false">���������</a></div>
				<script>
					init_calendar('$element->{name}','$div_name',0);
					var v='$element->{value}'
					if(v != '0-0-0'){
						document.getElementById('empty_$div_name').style.display='none';
					}
					else{
						var save_$element->{name}=document.getElementById('$element->{name}').value;
						document.getElementById('$element->{name}').value=v
						document.getElementById('$div_name').style.display='none';
					}
				</script>
			};
		}
	}
	elsif($element->{type} eq 'datetime'){
		my $div_name=$element->{name}.'_d';
		unless($element->{value}=~m/[123456789]/){
			$element->{value}='0-0-0 0:0:0';
		}
		if($element->{readonly} || $element->{read_only}){
			$field=$element->{value};
		}
		elsif($element->{default_value} eq 'now()'){
			my $pr_val='-';
			$pr_val=$element->{value} if($element->{value} ne '0-0-0 0:0:0');
			$field=qq{<input type="hidden" name="$element->{name}" value="now()">$pr_val};
		}
		else{
			$field=qq{
				<input type='hidden' name='$element->{name}' id='$element->{name}' value='$element->{value}'>
				<div id='$div_name'></div>
				<div id='empty_$div_name'><a href="" OnCLick="document.getElementById('$element->{name}').value=save_$element->{name}; document.getElementById('$div_name').style.display='';  document.getElementById('empty_$div_name').style.display='none'; return false">���������</a></div>
				<script>
					init_calendar('$element->{name}','$div_name',1);
					var v='$element->{value}'
					if(v != '0-0-0 0:0:0'){
						document.getElementById('empty_$div_name').style.display='none';
					}
					else{
						var save_$element->{name}=document.getElementById('$element->{name}').value;
						document.getElementById('$element->{name}').value=v
						document.getElementById('$div_name').style.display='none';
					}
				</script>
			};
		}
	}
	elsif($element->{type} eq 'file'){ # �������� ��� ���� ���� file
		$field=qq{<input type='file' name='$element->{name}'>};
		if($element->{value}){
			$element->{filedir}.='/' unless($element->{filedir}=~m/\/$/);
# !@!

			if($element->{keep_orig_filename}){
				$field.=qq{&nbsp;<a href="file_download.pl?config=$form->{config}&name=$element->{name}&id=$id">�������</a> <a href="javascript: if(confirm('�� ������������� ������ ������� ����?')) document.location.href='$script?action=del_file&id=$id&config=$form->{config}&field=$element->{name}'">�������</a>}
			}
			else{
				$field.=qq{&nbsp;<a href="javascript: openWindow('$element->{filedir}$element->{value}', 300, 300)">�������</a> <a href="javascript: if(confirm('�� ������������� ������ ������� ����?')) document.location.href='$script?action=del_file&id=$id&config=$form->{config}&field=$element->{name}'">�������</a>}
			}
		}
	}
	elsif($element->{type} eq 'label'){ # �������� ��� ���� ���� lebel
		$TRS.=qq{<tr class='label'><td colspan='2'>$element->{description}:</td></tr>};
	}
	elsif($element->{type} eq 'megaselect'){ # �������� ��� ���� ���� megaselect
		$TRS.=qq{<tr><td class='description'>$element->{megaselect_description}:</td><td>$field</td></tr>};
	}
	elsif($element->{type} eq 'link'){
		$element->{url}=~s/\[%id%\]/$id/;
		if($id=~m/\d+/){
			my $target='';
			if($element->{target}){
				$target=qq{ target='$element->{target}'}
			}
			$field=qq{<a href='$element->{url}'$target>$element->{description}</a>};
		}
	}
	elsif($element->{type} eq 'memo'){
		print_error(qq{�� ������ ������� auth_table}) unless($element->{auth_table});
		print_error(qq{�� ������ ������� auth_login_field}) unless($element->{auth_login_field});
		print_error(qq{�� ������ ������� auth_id_field}) unless($element->{auth_id_field});
		print_error(qq{�� ������ ������� auth_name_field}) unless($element->{auth_id_field});
		
		if($element->{method} eq 'single'){
			# 1. ���������� �� ���������������

			
			my $sth=$form->{dbh}->prepare(qq{
				SELECT 
					$element->{auth_name_field},
					$element->{auth_login_field},
					$element->{auth_id_field}
				FROM
					$element->{auth_table} 
				WHERE $element->{auth_id_field}=?
			});
			$field='<hr>';
			while($element->{value}=~m/<element_memo>(.+?)<\/element_memo>/gs){				
				my $tags=&parse_memo_tags($1);
				$sth->execute($tags->{ID});
				($remote_name, $remote_login, $remote_id)=$sth->fetchrow();
				$tags->{remote_name}=$remote_name;
				$tags->{remote_login}=$remote_login;
				$tags->{remote_id}=$remote_id;
				my $mes=$element->{format};
				while($element->{format}=~m/\[%(.+?)%\]/gs){
					my $tagname=$1;					
					$mes=~s/\[%$tagname%\]/$tags->{$tagname}/gs;
				}
				$field.=$mes;
			}
			# ��������
			$field.="<textarea name='$element->{name}'></textarea>";
		}
		elsif($element->{method} eq 'multitable'){
			$field=qq{<hr>
				<div id='memo_$element->{name}'></div>
				<script>loadDoc('./memo.pl?config=$form->{config}&name=$element->{name}&key=$form->{id}', 'memo_$element->{name}')</script><br>
				<b>�������� �����������</b>:<br/>
				<textarea name='$element->{name}' id='$element->{name}'></textarea><br/>
				<input type="button" Onclick="loadDoc('./memo.pl?config=$form->{config}&name=$element->{name}&key=$form->{id}&action=add&message='+document.getElementById('$element->{name}').value, 'memo_$element->{name}')" value="�������� �����������">
			};
=cut
			my $sth=$form->{dbh}->prepare(qq{
				SELECT 
					m.$element->{memo_table_id} memo_id,
					a.$element->{auth_name_field} remote_name,
					m.$element->{memo_table_comment} message,
					m.$element->{memo_table_registered} registered
				FROM 
					$element->{memo_table} m, $element->{auth_table} a					
				WHERE
					m.$element->{memo_table_foreign_key}=? && m.$element->{memo_table_auth_id}=a.$element->{auth_id_field}
			});
			# memo.id, manager name, comment
			$sth->execute($form->{id});
			
			while(my $tags=$sth->fetchrow_hashref()){
				
				my $mes=$element->{format};
				if($tags->{registered}=~m/^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)$/){
					($tags->{year},$tags->{mon},$tags->{mday},$tags->{hour},$tags->{min},$tags->{sec})=($1,$2,$3,$4,$5,$6);
				}
				
				while($element->{format}=~m/\[%(.+?)%\]/gs){
					my $tagname=$1;	
					$mes=~s/\[%$tagname%\]/$tags->{$tagname}/gs;
				}
				$field.=$mes;
			}
=cut	
		}
	
#		$field.="";
	}
	return $field;
}

sub parse_memo_tags{
		my $tags=shift;
		my $hash;
		while($tags=~/<(.+?)>(.+?)<\//gs){			
			$hash->{$1}=$2;
		}
		return $hash;
}
sub ok{
	my $form=$_[0];
    my $edit_link = $form->{edit_form} || "./edit_form.pl?action=edit&id=$form->{id}&config=$form->{config}";
    $edit_link =~ s/<\%id\%>/$form->{id}/;
                
	print qq{
		<html>
			<head>
				<title></title>
			</head>
			<body OnLoad="loaded_document=1">
				<center>
					<p>������ ���� ������� ���������</p>
					<p><a href='$edit_link'>[������� � ��������������]</a></p>
					<p><a href='javascript: window.close()'>[�������]</a></p>
				</center>
			</body>
		</html>
	}
}

	return 1;
END { }

=description_mudu;
	������ ���������:
my %manager_form=(
	'title'=>'�������� ����������� ������������',
	^^^^
	��������� �����
	'action'=>'insert',
	#^^^^
	#������� ���� action.
	#��� ���������� ����� ������ -- ��� insert, � ��� ��������� -- update

	'work_table' => 'manager',
	^^^
	#�������, � ������� ��������

	'work_table_id'=>'manager_id',
	#^^
	#����-������������� ��� ���� �������



	'make_delete'=>'1',
	# ����������� ������� ������� (��������� ��������).

	'readonly'=>'1',
	# ����������� ������������� ������� (��������� ��������).

	'default_find_filter'=>'position',
	# ������, ������� ����� ������������ �� ��������� � ��� ������, ���� �� ��� ������ �� ���� �� ��������

	#����� ��� ������ �����, ����������� ��� ���� ������ �����
	'fields'=>
	[
		{
			'description'=>'�����',
			'name'=>'login',
			'type'=>'text',
			'uniquew'=>1, # ���� login ������ ���� ���������
			'regexp'=>'^[0-9a-zA-Z\-_]+$'
		},
		{
			'description'=>'������',
			'name'=>'password',
			'type'=>'text',
			'regexp'=>'^([a-z]+[A-Z]+[0-9]+|[a-z]+[0-9]+[A-Z]+|[A-Z]+[a-z]+[0-9]+|[A-Z]+[0-9]+[a-z]+|[0-9]+[A-Z]+[a-z]+|[0-9]+[a-z]+[A-Z]+)$',
			'error_regexp'=>'���� "������" ����������� ������ ��������� �������� ��������� �����,<br>��������� ��������� �����, ����� � �����������.<br>�� ����������� ������������� ������������ ������������������� � �������� ����� 3-� ��������'
		},
		{
			'description'=>'Email',
			'name'=>'email',
			'regexp'=>'^.+$'
			'type'=>'text',
                       'filter_code'=>q{
                $value=~s/(\S+@\S+)/<a href="mailto: $1">$1<\/a>/gs;
            }
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^6
                ��� ������ ����������� ������ �������� ���������� �������� ���� � ������� �������� filter_code
		},
		{
			'description'=>'����� ������������',
			'name'=>'permissions',
			'type'=>'multicheckbox',
			'extended'=>q{
											news ; ������ � ���������;
											lists ; �������������� �������;
											create_managers ; �������� ������� ������� ��� ���������� ������������� �������
									  }

		}
	]

	������������� ����� ����� (type):
	1. text -- � ������ ������ ����� ������������� ���� <input type='text'....>
	2. multicheckbox -- ������������� checkbox
			����� ��� �������� ������� � ����� ���� ����� ������� ����� ������ ������

	    ������:
		  {
			  'description'=>'����� ������������',
			  'name'=>'permissions',
			  'type'=>'multicheckbox',
			  'extended'=>q{
											news ; ������ � ���������;
											lists ; �������������� �������;
											create_managers ; �������� ������� ������� ��� ���������� ������������� �������
									  }

		  }

		  ����� ��������� �������� 3 ��������
		  � ��� ������, ���� �������� ����������, � ��������������� ���� (��) ����� ����������� � ����:
		  ;�������� �����X;�������� �����Y;�������� �����Z;
		  �� ����, ��� ������� �������������� ����� �������� ������ � ��� ������, ���������� � 2-� ������ ������� � �������

	3. file -- ����� ��� �������� ��� ��������� ���� �� ���� � ��� ����� � �����

			������:
			{
				'description'=>'������',
				'name'=>'resume_file',
				'type'=>'file',
				'filedir'=>'./resume'
			}


	4. select_from_table -- ������� ������� select � �����, �������� � ���� select ����������� �� �����-���� ������� ��.
	   ������:
			{
				'description'=>'�������� ���������',
				'name'=>'manager_id',
				'type'=>'select_from_table',
				'table'=>'manager',
				'header_field'=>'fio',
				'value_field'=>'manager_id',
				'default_value_empty'=>'0',
				'default_label_empty'=>'--- �������� �� ������ ---',
				'regexp'=>'(^[1-9]$|^\d\d)'
			}

			�����:
			'table'=>'manager' -- �������, �� ������� ����� ������� �������
			'header_field'=>'fio' -- � �������� ������������ ������� �������� select ����� ������������� �������� ���� fio
			'value_field'=>'manager_id' -- � �������� �������� -- ���� manager_id
			'default_value_empty'=>'0' -- �� ��������� ����� ������� ���� �� ��������� 0
			'default_label_empty'=>'--- �������� �� ������ ---' -- ���������� ��� ����� "�������� �� ������"


	5. textarea -- ���, �����, �������� ���� �� ������
	6. wysiwyg -- ����� ������� ���� � wysiwyg ����������
	7. data -- js-��������� � ������������ ������ ����
	8. datetime -- js-��������� � ������������ ������ ���� � �������
		(���� �������� ������� default_value=>'now()', �� ��� �������� � �� ����� ������������ ���������� � ���� � ������� ��������, � ��� �������������� ���� ����� �� �������������)

	9. select_values --
		{
			'description'=>'�����������',
			'name'=>'education',
			'type'=>'select_values',
			'values'=>'1=>������-�����������;2=>�� ������ ������;3=>������',
			'default_value_empty'=>'0',
			'default_label_empty'=>'--- ����������� �� �������',
			'regexp'=>'^\d+$'
		}

		����� ����������� ��������� ������������� select-����, � ������� �������� ����� ������� ������������� ��������.

	10. megaselect --
		{
			'megaselect_description'=>'������ / ������',
			'description'=>'������;������',
			'type'=>'megaselect',
			'table'=>'katalog_2;katalog_2',
			'name'=>'country;region',
			'table_headers'=>'header;header',
			'table_indexes'=>'brand;linehi',
			'despendence'=>'brand>0 and linehi=0;brand=? AND linehi>0',
			'regexp'=>'\d+;\d+'
		},

	��������� ��������� ��������� ���� �� ����� select'�
	� ���������� ���� ��������� ��� ������ ������ ����������� ���� ������ �������

	11. code --
		{
			'description'=>'������',
			'type'=>'code',
			'code'=>q{
					my $dbh_semc=DBI->connect("DBI:mysql:semc_kru:192.168.0.101",'rosexport','') || die($dbh->errstr());
					my $sth=$dbh_semc->prepare("SELECT password, password_kru from owner where login=?");
					$sth->execute('[%semc_link%]');
					my ($password, $password_kru)=$sth->fetchrow();
					$sth->finish();
					$dbh_semc->disconnect();
					$field="������: $password ; ������ ���: $password_kru";
			},
		}
		� ������� ����� ����������� ���������� ��������� �������� ��������� ������ � �������� �� � ��������������� ������ ��������

	12. hidden -- hidden ���� � �����
    13. 1_to_m -- ����� "���� �� ������" ������
    14  relation_tree -- ����� � ������� ���������� ������ "������ �� ������"
    15	filter_extend_select

	������
                {
                        type=>'filter_extend_select',
                        description=>'������',
                        name=>'id',
                        tree=>'1',
                        filter_table=>'managers_groups',
                        header_field=>'name',
                        value_field=>'id',
                        db_name=>'id',
                        order=>'name',
                        extend_tables=>'managers',
                        extend_where=>'selt_card.manager_id=managers.id AND managers.group_id=managers_groups.id'
                },


	==============================================================================
	| ��������� ������������
	==============================================================================
	��� ������������ ����� ������������� � �������� (� �������� ./conf):
	"$work_table".'_before_update' (�� �������)
	"$work_table".'_after_update'  (����� �������)
	"$work_table".'_before_insert' (�� �������)
	"$work_table".'_after_insert' (����� �������)

	��� ���� ��� ������������� ������������ � ��, �.�. ����������:
	$dbh, $work_table, %form_link ����� ��������� ��������������

    ��� ��������� ������������ ����� ����������� ���� "�� ����":
        my @rand_chars = (0..9, 'a'..'z', 'A'..'Z');
        my $rand_str = join('', map { $rand_chars[rand @rand_chars] } (1..20));
        push(@{$form{fields}},
        {
            description	=>'��������',
            type	=>'multiconnect',
            name	=>'article_host_list',
            relation_save_table	=>'article_host',
            relation_table	=>'partner_host_by_news',
            relation_table_header=>'host',
            relation_table_id	=>'id'
        });
        push(@{$form{fields}},
        {
	        description	=>'random number',
    	    type	=>'text',
            not_get_param=>1,
    	    name	=>'partner_news_key',
    	    value	=>$rand_str,
    	    default_value=>$rand_str
    	});

    � ���� ������, ������� not_get_param ������� ��� � ���, ����� �� �� �������� �������� �� ����� ��� ��������.
);
=cut
