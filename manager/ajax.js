function init_ajax(){
    if (window.XMLHttpRequest) {
        try {
            return new XMLHttpRequest();
        } catch (e){}
    } else if (window.ActiveXObject) {
        try {
            return new ActiveXObject('Msxml2.XMLHTTP');
        } catch (e){
          try {
              return new ActiveXObject('Microsoft.XMLHTTP');
          } catch (e){}
        }
    }
    return null;
}

function loadDoc(link, id){
  req=init_ajax();

  if (req){
     req.onreadystatechange = function () {
        // ������ 4 �������� �������� ����������
        if (req.readyState == 4) {

          if (req.status == 200) {
             var response = req.responseText;
             document.getElementById(id).innerHTML = response;
          } else {
            alert('���������� �������� ������ � �������: ' + req.statusText);
          }
        }
     }

     if(/\?/.test(link))
      link = link  + '&' + Math.random();
     else
      link = link  + '?' + Math.random();


     req.open("GET", link, true);
     req.send(null);
  }
}

function loadDocAsync(link){

  //req=init_ajax();
  var req;
  if (window.XMLHttpRequest){
     req = new XMLHttpRequest();
  } else if (window.ActiveXObject) {
     // ���� ���, �� �������� � ��, ��� ��� �� ��� � �����
     req = new ActiveXObject("Microsoft.XMLHTTP");
  }

	if (req){

	req.onreadystatechange = function () {
        // ������ 4 �������� �������� ����������
        if (req.readyState == 4) {

          if (req.status != 200) {
            alert('���������� �������� ������ � �������: ' + req.statusText);
          }
        }
     }

     if(/\?/.test(link))
      link = link  + '&' + Math.random();
     else
      link = link  + '?' + Math.random();


     req.open("GET", link, false);
     req.send(null);
		 return req.responseText;

  }
}

 var plus_ico='/icon/plusx.gif';
 var minus_ico='/icon/minusx.gif';
 function switch_element(tree_id,element_name){
		if(document.getElementById('include_'+element_name+'_'+tree_id).style.display=='none'){
			document.getElementById('include_'+element_name+'_'+tree_id).style.display='';
			document.getElementById('ico_'+element_name+'_'+tree_id).src=minus_ico;
		}
		else{
			document.getElementById('include_'+element_name+'_'+tree_id).style.display='none';
			document.getElementById('ico_'+element_name+'_'+tree_id).src=plus_ico;
		}
	}