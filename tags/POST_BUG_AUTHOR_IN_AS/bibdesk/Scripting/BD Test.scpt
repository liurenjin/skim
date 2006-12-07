FasdUAS 1.101.10   ��   ��    k             l      �� ��   ��
This is a sample script to show AppleScript support for BibDesk. 
When you run this script, it creates a new document. So any 
currently opened document in Bibdesk should not be affected.

If you want to inspect the return value of a particular 
line in this script, insert 'return result' after that line 
and run the script. 

You can inspect the supported classes and commands 
in the AppleScript library. In the Script Editor, choose 
File > Open Dictionary�, or Shift-Command-O, and 
select Bibdesk. 

For more information about BibDesk, including a collection of
AppleScripts, see the Bibdesk home page at 
http://bibdesk.sourgeforge.net
       	  l     ������  ��   	  
  
 l   � ��  O    �    k   �       l   �� ��      start BibDesk         I   	������
�� .miscactvnull��� ��� null��  ��        l  
 
������  ��        l  
 
�� ��       and create a new document         I  
 ���� 
�� .corecrel****      � null��    �� ��
�� 
kocl  m    ��
�� 
docu��        l   ������  ��       !   l   �� "��   " ; 5 get first, i.e. frontmost,  document and talk to it.    !  # $ # r     % & % 4   �� '
�� 
docu ' m    ����  & o      ���� 0 thedoc theDoc $  ( ) ( l   ������  ��   )  * + * l  { , - , O   { . / . k   z 0 0  1 2 1 l   ������  ��   2  3 4 3 l   �� 5��   5 + % GENERATING AND DELETING PUBLICATIONS    4  6 7 6 l   �� 8��   8 %  make some BibTeX record to use    7  9 : 9 l   �� ;��   ; #  let's make a new publication    :  < = < r    + > ? > I   )���� @
�� .corecrel****      � null��   @ �� A B
�� 
kocl A m     ��
�� 
bibi B �� C��
�� 
insh C l  ! % D�� D n   ! % E F E  ;   $ % F 2  ! $��
�� 
bibi��  ��   ? o      ���� 0 newpub newPub =  G H G l  , ,�� I��   I ? 9 this is initially empty, so fill it with a BibTeX string    H  J K J l  , ,�� L��   L > 8 note: this can only be set before doing any other edit!    K  M N M r   , 1 O P O m   , - Q Q s m@article{McCracken:2005, Author = {M. McCracken and A. Maxwell}, Title = {Working with BibDesk.},Year={2005}}    P n       R S R 1   . 0��
�� 
BTeX S o   - .���� 0 newpub newPub N  T U T l  2 2�� V��   V + % we can get the BibTeX record as well    U  W X W r   2 7 Y Z Y l  2 5 [�� [ n   2 5 \ ] \ 1   3 5��
�� 
BTeX ] o   2 3���� 0 newpub newPub��   Z o      ���� "0 thebibtexrecord theBibTeXRecord X  ^ _ ^ l  8 8�� `��   ` %  get rid of the new publication    _  a b a I  8 =�� c��
�� .coredelonull���     obj  c o   8 9���� 0 newpub newPub��   b  d e d l  > >�� f��   f / ) a shortcut to creating a new publication    e  g h g r   > Q i j i I  > O���� k
�� .corecrel****      � null��   k �� l m
�� 
kocl l m   @ A��
�� 
bibi m �� n o
�� 
prdt n K   B F p p �� q��
�� 
BTeX q o   C D���� "0 thebibtexrecord theBibTeXRecord��   o �� r��
�� 
insh r l  G K s�� s n   G K t u t  ;   J K u 2  G J��
�� 
bibi��  ��   j o      ���� 0 newpub newPub h  v w v l  R R������  ��   w  x y x l  R R�� z��   z !  MANIPULATING THE SELECTION    y  { | { l  R R�� }��   } L F Play with the selection and put styled bibliography on the clipboard.    |  ~  ~ r   R h � � � l  R d ��� � 6  R d � � � 2  R U��
�� 
bibi � E   X c � � � 1   Y ]��
�� 
ckey � m   ^ b � �  	McCracken   ��   � o      ���� 0 somepubs somePubs   � � � r   i r � � � o   i l���� 0 somepubs somePubs � l      ��� � 1   l q��
�� 
sele��   �  � � � I  s x������
�� .BDSKsbtcnull��� ��� obj ��  ��   �  � � � l  y y�� ���   �   get the selection    �  � � � r   y � � � � l  y ~ ��� � 1   y ~��
�� 
sele��   � o      ���� 0 theselection theSelection �  � � � l  � ��� ���   �   and get its first item    �  � � � r   � � � � � n   � � � � � 4   � ��� �
�� 
cobj � m   � �����  � o   � ����� 0 theselection theSelection � o      ���� 0 thepub thePub �  � � � l  � �������  ��   �  � � � l  � ��� ���   � , & ACCESSING PROPERTIES OF A PUBLICATION    �  � � � l  � � � � O   � � � � k   � � �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 1 + all properties give quite a lengthy output    �  � � � l  � ��� ���   �   get properties    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � I C plurals as well as accessing a whole array of things  work as well    �  � � � n   � � � � � 1   � ���
�� 
aunm � 2  � ���
�� 
auth �  � � � l  � �������  ��   �  � � � l  � ��� ���   � - ' as does access to the local file's URL    �  � � � l  � ��� ���   � � � This is nice but the whole differences between Unix and traditional AppleScript style paths seem to make it worthless => text item delimiters galore. See the arXiv download script for an example or, better even, suggest a nice solution.    �  � � � r   � � � � � 1   � ���
�� 
lURL � o      ���� 0 thelocalfile theLocalFile �  � � � l  � �������  ��   �  � � � l  � ��� ���   � #  we can easily set properties    �  � � � r   � � � � � m   � � � �  http://localhost/lala/    � o      ���� 0 theurl theURL �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 0 * we can access all fields and their values    �  � � � r   � � � � � 4   � ��� �
�� 
bfld � m   � � � �  Author    � o      ���� 0 thefield theField �  � � � e   � � � � n   � � � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Title    �  � � � r   � � � � � m   � � � �  SourceForge    � n       � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Journal    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � J D we can also get a list of all non-empty fields and their properties    �  � � � r   � � � � � n   � � � � � 1   � ���
�� 
pnam � 2  � ���
�� 
bfld � o      ����  0 nonemptyfields nonEmptyFields �  � � � l  � �������  ��   �  � � � l  � �� ��   �  
 CITE KEYS    �  �  � l  � ��~�~   8 2you can access the cite key and generate a new one      e   � � 1   � ��}
�} 
ckey  r   � � 1   � ��|
�| 
gcky 1   � ��{
�{ 
ckey 	
	 l   �z�y�z  �y  
  l   �x�x     AUTHORS     l   �w�w   7 1 we can also query all authors in the publciation     r   
 4  �v
�v 
auth m  �u�u  o      �t�t 0 	theauthor 	theAuthor �s l �r�q�r  �q  �s   � o   � ��p�p 0 thepub thePub �   thePub    �  l �o�n�o  �n    l �m�m   !  work again on the document     l �l�k�l  �k    l �j �j      AUTHORS    !"! l �i#�i  # D > we can also query all authors present in the current document   " $%$ e  && 4  �h'
�h 
auth' m  ((  M. McCracken   % )*) l �g+�g  + $  and find all his publications   * ,-, r  !./. n  010 2 �f
�f 
bibi1 o  �e�e 0 	theauthor 	theAuthor/ o      �d�d 0 hispubs hisPubs- 232 l ""�c�b�c  �b  3 454 l ""�a6�a  6   OPENING WINDOWS   5 787 l ""�`9�`  9 _ Y we can open the editor window for a publication and the information window for an author   8 :;: I ")�_<�^
�_ .BDSKshownull��� ��� obj < o  "%�]�] 0 thepub thePub�^  ; =>= I *1�\?�[
�\ .BDSKshownull��� ��� obj ? o  *-�Z�Z 0 	theauthor 	theAuthor�[  > @A@ l 22�Y�X�Y  �X  A BCB l 22�WD�W  D   FILTERING AND SEARCHING   C EFE l 22�VG�V  G y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   F HIH l 22�UJ�U  J�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   I KLK Z  2SMN�TOM = 2;PQP 1  27�S
�S 
filtQ m  7:RR      N r  >GSTS m  >AUU  	McCracken   T 1  AF�R
�R 
filt�T  O r  JSVWV m  JMXX      W 1  MR�Q
�Q 
filtL YZY e  TZ[[ 1  TZ�P
�P 
dispZ \]\ e  [f^^ I [f�O�N_
�O .BDSKsrchlist    ��� obj �N  _ �M`�L
�M 
for ` m  _baa  	McCracken   �L  ] bcb l gg�Kd�K  d r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   c efe e  gxgg I gx�J�Ih
�J .BDSKsrchlist    ��� obj �I  h �Hij
�H 
for i m  knkk  	McCracken   j �Gl�F
�G 
cmpll m  qt�E
�E savoyes �F  f m�Dm l yy�C�B�C  �B  �D   / o    �A�A 0 thedoc theDoc -   theDoc    + non l ||�@�?�@  �?  o pqp l ||�>r�>  r $  work again on the application   q sts l ||�=�<�=  �<  t uvu l ||�;w�;  w � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   v xyx I |��:�9z
�: .BDSKsrchlist    ��� obj �9  z �8{�7
�8 
for { m  ��||  	McCracken   �7  y }~} I ���6�
�6 .BDSKsrchlist    ��� obj  4 ���5�
�5 
docu� m  ���4�4 � �3��2
�3 
for � m  ����  	McCracken   �2  ~ ��� l ���1��1  �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   � ��� O ����� r  ����� m  ����  	McCracken   � 1  ���0
�0 
filt� 2  ���/
�/ 
docu� ��� l ���.�-�.  �-  � ��� l ���,��,  �   GLOBAL PROPERTIES   � ��� l ���+��+  � 4 . you can get the folder where papers are filed   � ��� r  ����� l ����*� 1  ���)
�) 
pfol�*  � o      �(�( "0 thepapersfolder thePapersFolder� ��� l ���'��'  � � � it is a UNIX style path, so if we want to use it we should translate it into a Mac style path. Put 'my' in front as it is not a Bibdesk command.   � ��� O  ����� I ���&��%
�& .aevtodocnull  �    alis� n ����� 4  ���$�
�$ 
psxf� o  ���#�# "0 thepapersfolder thePapersFolder�  f  ���%  � m  �����null     ߀��  �
Finder.app��� ��L��� 2����@   Z �0   )       �(�K� ���` �MACS   alis    r  Macintosh HD               ��+GH+    �
Finder.app                                                       3��K� � 0 � �����  	                CoreServices    ��'      ��/�      �  
�  
�  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l ���"�!�"  �!  � ��� l ��� ��   � %  get all known types and fields   � ��� e  ���� 1  ���
� 
atyp� ��� e  ���� 1  ���
� 
afnm� ��� l �����  �  �    m     ��null     ߀�� ��Bibdesk.app�� ��L��� 2����� �� �   )       �(�K� ���0 �BDSK   alis    �  Macintosh HD               ��+GH+   ��Bibdesk.app                                                     K����h        ����  	                BuildProducts     ��'      ���8     �� X� X�  !�  GMacintosh HD:Users:christiaanhofman:Documents:BuildProducts:Bibdesk.app     B i b d e s k . a p p    M a c i n t o s h   H D  :Users/christiaanhofman/Documents/BuildProducts/Bibdesk.app  /    ��  ��    ��� l     ���  �  � ��� l     ���  �  �       ����  � �
� .aevtoappnull  �   � ****� �������
� .aevtoappnull  �   � ****� k    ���  
��  �  �  �  � B������
�	��� Q�������  ��������������������� ����� ��� ��� � ���������(������RUX����a��k����|���������������
� .miscactvnull��� ��� null
� 
kocl
� 
docu
� .corecrel****      � null�
 0 thedoc theDoc
�	 
bibi
� 
insh� � 0 newpub newPub
� 
BTeX� "0 thebibtexrecord theBibTeXRecord
� .coredelonull���     obj 
� 
prdt� �  
�  
ckey�� 0 somepubs somePubs
�� 
sele
�� .BDSKsbtcnull��� ��� obj �� 0 theselection theSelection
�� 
cobj�� 0 thepub thePub
�� 
auth
�� 
aunm
�� 
lURL�� 0 thelocalfile theLocalFile�� 0 theurl theURL
�� 
bfld�� 0 thefield theField
�� 
fldv
�� 
pnam��  0 nonemptyfields nonEmptyFields
�� 
gcky�� 0 	theauthor 	theAuthor�� 0 hispubs hisPubs
�� .BDSKshownull��� ��� obj 
�� 
filt
�� 
disp
�� 
for 
�� .BDSKsrchlist    ��� obj 
�� 
cmpl
�� savoyes 
�� 
pfol�� "0 thepapersfolder thePapersFolder
�� 
psxf
�� .aevtodocnull  �    alis
�� 
atyp
�� 
afnm����*j O*��l O*�k/E�O�_*���*�-6� E�O���,FO��,E�O�j O*�����l�*�-6� E�O*�-a [a ,\Za @1E` O_ *a ,FO*j O*a ,E` O_ a k/E` O_  x*a -a ,EO*a ,E` Oa E` O*a a  /E` !O*a a "/a #,EOa $*a a %/a #,FO*a -a &,E` 'O*a ,EO*a (,*a ,FO*a k/E` )OPUO*a a */EO_ )�-E` +O_ j ,O_ )j ,O*a -,a .  a /*a -,FY a 0*a -,FO*a 1,EO*a 2a 3l 4O*a 2a 5a 6a 7� 4OPUO*a 2a 8l 4O*�k/a 2a 9l 4O*�- a :*a -,FUO*a ;,E` <Oa = )a >_ </j ?UO*a @,EO*a A,EOPUascr  ��ޭ