#!/bin/sh

### 1차 정리 ###
sed -i 's/<createdBy>/\n<createdBy>/g' $1
sed -i '1d' $1
sed -i 's/<createdBy>/<createdBy>생성계정 : /g' $1
sed -i 's/<createdDate>/<createdDate>생성날짜 : /g' $1
sed -i 's/<lastModifiedBy>/<lastModifiedBy>마지막 답변자 : /g' $1
sed -i 's/<lastModifiedDate>/<lastModifiedDate>마지막 수정 일자 : /g' $1
sed -i 's/<id>/<id>id : /g' $1
sed -i 's/<\/id>/<\/id>======================<br>/g' $1
sed -i 's/<uri>/\n<uri>/g' $1
sed -i 's/<\/uri>/\n/g' $1
sed -i '/<uri>/d' $1
sed -i 's/<summary>/<summary><font size=15>제목  : /g' $1
sed -i 's/<\/summary>/<\/font><\/summary><br>======================<br>/g' $1
sed -i 's/<description>/<description>사전문의<br><\/b>/g' $1
sed -i 's/<\/description>/<br>=======================<br>/g' $1
sed -i 's/<status>/<status>상태 : /g' $1
sed -i 's/<product>/<product>제품명  : /g' $1
sed -i 's/<version>/<version>버젼  : /g' $1
sed -i 's/<type>/<type>타입  : /g' $1
sed -i 's/<accountNumber>/<accountNumber>계정 번호  : /g' $1
sed -i 's/<escalated>/\n<escalated>/g' $1
sed -i 's/<\/owner>/\n/g' $1
sed -i '/<escalated>/d' $1
sed -i 's/<severity>/<severity>심각도  : /g' $1
sed -i 's/<firstCase/\n<firstCase/g' $1
sed -i 's/createdBy>/b>/g' $1
sed -i 's/createdDate>/b>/g' $1
sed -i 's/lastModifiedBy>/b>/g' $1
sed -i 's/summary>/b>/g' $1
sed -i 's/description>/b>/g' $1
sed -i 's/status>/b>/g' $1
sed -i 's/product>/b>/g' $1
sed -i 's/version>/b>/g' $1
sed -i 's/severity>/b>/g' $1
sed -i 's/accountNumber>/b>/g' $1
sed -i 's/id>/b>/g' $1
sed -i 's/type>/b>/g' $1
sed -i 's/lastModifiedDate>/b>/g' $1
sed -i 's/<text>/<br>/g' $1
sed -i 's/<\/text>/<br>/g' $1
sed -i 's/<\/b>/<\/b><br>/g' $1
sed -i 's/<firstCase/\n<firstCase/g' $1
sed -i 's/tags\/>/tags\/>\n/g' $1
sed -i '/<firstCase/d' $1
sed -i 's/<public>/\n<public>/g' $1
sed -i 's/<\/draft>/<\/draft>\n/g' $1
sed -i 's/<comments>/<br>/g' $1
sed -i 's/<\/comment>/<br>/g' $1
sed -i '/<public>/d' $1
sed -i 's/<notified/\n<notified/g' $1
sed -i '/<notified/d' $1
sed -i 's/\n/<br>/g' $1
cat $1 | tr -t '\n' '\t' > ${1}.tmp
rm -f $1
mv ${1}.tmp $1

### 2차 정리 ###
sed -i 's/\t/<br>/g' $1
sed -i 's/<br><br><b>심각도/<br><b>심각도/g' $1
sed -i 's/<br><br><br><br>/<br>======================<br>/g' $1
sed -i 's/<b>생성계정/======================<br><b>생성계정/g' $1
sed -i 's/<\/createdByType>/<\/createdByType><br>======================/g' $1
sed -i 's/제목/\n제목/g' $1
sed -i 's/<\/font>/\n<\/font>/g' $1

### 파일 저장 ###
#TITLE=`sed -n '/제목/p' $1 | awk -F ":" '{print $2}' | tr -t ' ' '_' | tr -t '/' '\/'`
#CASENU=`echo $1 | awk -F "." '{print $1}'`
#mv $1 "[${CASENU}]${TITLE}.html"
