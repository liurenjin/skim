FasdUAS 1.101.10   ��   ��    k             l   C ��  O    C  	  k   B 
 
     l   �� ��    ; 5 Get first, i.e. frontmost,  document and talk to it.         r    
    4   �� 
�� 
docu  m    ����   o      ���� 0 d        l   ������  ��        l      O       k          l   �� ��    - ' we can use whose right out of the box!          r      ! " ! n     # $ # 4    �� %
�� 
cobj % m    ����  $ l    &�� & 6    ' ( ' 2   ��
�� 
bibi ( E     ) * ) 1    ��
�� 
ckey * m     + +  DG   ��   " o      ���� 0 p      , - , l  ! !������  ��   -  . / . l  ! !�� 0��   0 * $ THINGS WE CAN DO WITH A PUBLICATION    /  1 2 1 l  ! Q 3 4 3 O   ! Q 5 6 5 k   % P 7 7  8 9 8 l  % %�� :��   : 1 + all properties give quite a lengthy output    9  ; < ; l  % %�� =��   =   get properties    <  > ? > l  % %������  ��   ?  @ A @ l  % %�� B��   B � � we can access all fields, but this has to be done in a two-step process for some AppleScript reason (see http://earthlingsoft.net/ssp/blog/2004/07/cocoa_and_applescript#810). The keys have to be surrounded by pipes.    A  C D C r   % * E F E 1   % (��
�� 
flds F o      ���� 0 f   D  G H G e   + / I I n   + / J K J o   , .���� 0 Journal   K o   + ,���� 0 f   H  L M L l  0 0������  ��   M  N O N l  0 0�� P��   P I C plurals as well as accessing a whole array of things  work as well    O  Q R Q n   0 6 S T S 1   3 5��
�� 
aunm T 2  0 3��
�� 
auth R  U V U l  7 7������  ��   V  W X W l  7 7�� Y��   Y - ' as does access to the local file's URL    X  Z [ Z l  7 7�� \��   \ � � This is nice but the whole differences between Unix and traditional AppleScript style paths seem to make it worthless => text item delimiters galore. See the arXiv download script for an example or, better even, suggest a nice solution.    [  ] ^ ] r   7 < _ ` _ 1   7 :��
�� 
lURL ` o      ���� 0 lf   ^  a b a l  = =������  ��   b  c d c l  = =�� e��   e #  we can easily set properties    d  f g f r   = F h i h m   = @ j j  http://localhost/lala/    i 1   @ E��
�� 
rURL g  k l k l  G G������  ��   l  m n m l  G G�� o��   o + % and get the underlying BibTeX record    n  p�� p r   G P q r q 1   G L��
�� 
BTeX r o      ���� 0 bibtexrecord BibTeXRecord��   6 o   ! "���� 0 p   4   p    2  s t s l  R R������  ��   t  u v u l  R R�� w��   w + % GENERATING AND DELETING PUBLICATIONS    v  x y x l  R R�� z��   z   let's make a new record    y  { | { r   R h } ~ } I  R d���� 
�� .corecrel****      � null��    �� � �
�� 
kocl � m   V W��
�� 
bibi � �� ���
�� 
insh � l  Z ^ ��� � n   Z ^ � � �  ;   ] ^ � 2  Z ]��
�� 
bibi��  ��   ~ o      ���� 0 n   |  � � � l  i i�� ���   � ? 9 this is initially empty, so fill it with a BibTeX string    �  � � � r   i t � � � o   i l���� 0 bibtexrecord BibTeXRecord � n       � � � 1   o s��
�� 
BTeX � o   l o���� 0 n   �  � � � l  u u�� ���   �    get rid of the new record    �  � � � I  u |�� ���
�� .coredelonull��� ��� obj  � o   u x���� 0 n  ��   �  � � � l  } }������  ��   �  � � � l  } }�� ���   � !  MANIPULATING THE SELECTION    �  � � � l  } }�� ���   � L F Play with the selection and put styled bibliography on the clipboard.    �  � � � r   } � � � � 6  } � � � � 2  } ���
�� 
bibi � E   � � � � � 1   � ���
�� 
ckey � m   � � � �  DG    � o      ���� 0 ar   �  � � � r   � � � � � o   � ����� 0 ar   � 1   � ���
�� 
sele �  � � � I  � �������
�� .BDSKsbtcnull��� ��� obj ��  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   AUTHORS    �  � � � l  � ��� ���   � D > we can also query all authors present in the current document    �  � � � e   � � � � 4  � ��� �
�� 
auth � m   � �����  �  � � � r   � � � � � 4   � ��� �
�� 
auth � m   � � � �  Murray, M. K.    � o      ���� 0 a   �  � � � r   � � � � � n   � � � � � 2  � ���
�� 
bibi � o   � ����� 0 a   � o      ���� 	0 apubs   �  � � � l  � �������  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   OPENING WINDOWS    �  � � � l  � ��� ���   � _ Y we can open the editor window for a publication and the information window for an author    �  � � � I  � ��� ���
�� .BDSKshownull��� ��� obj  � o   � ����� 0 a  ��   �  � � � I  � ��� ���
�� .BDSKshownull��� ��� obj  � o   � ����� 	0 apubs  ��   �  � � � l  � �������  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   FILTERING AND SEARCHING    �  � � � l  � ��� ���   � y s We can get and set the filter field of each document and get the list of publications that is currently displayed.    �  � � � l  � ��� ���   ���In addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.    �  � � � Z   � � � ��� � � =  � � � � � 1   � ���
�� 
filt � m   � � � �       � r   � � � � � m   � � � �  gerbe    � 1   � ���
�� 
filt��   � r   � � � � � m   � � � �       � 1   � ���
�� 
filt �  � � � e   � � � � 1   � ���
�� 
disp �  � � � e   � � � � I  � ����� �
�� .BDSKsrchlist    ��� obj ��   � �� ���
�� 
for  � m   � � � �  gerbe   ��   �  � � � l   �� ���   � r l When writing an AppleScript for completion support in other applications use the 'for completion' parameter    �  � � � e    � � I  ���� �
�� .BDSKsrchlist    ��� obj ��   � �� � 
�� 
for  � m    gerbe     ����
�� 
cmpl m  
��
�� savoyes ��   � � l �~�}�~  �}  �    o    �|�| 0 d      d      l �{�z�{  �z    l �y�y   � � The search command works also at application level. It will either search every document in that case, or the one it is addressed to.    	
	 I "�x�w
�x .BDSKsrchlist    ��� obj �w   �v�u
�v 
for  m    gerbe   �u  
  I #1�t
�t .BDSKsrchlist    ��� obj  4 #'�s
�s 
docu m  %&�r�r  �q�p
�q 
for  m  *-  gerbe   �p    l 22�o�o    y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.     l 22�n�m�n  �m   �l O 2B r  8A m  8; 
 chen    1  ;@�k
�k 
filt 2  25�j
�j 
docu�l   	 m       �null     ߀�� KvBibdesk.app�`  S������ �0       � � ���� 8��� ����  BDSK   alis    b  Kalle                      |%�JH+   KvBibdesk.app                                                     �r�Z;^        ����  	                builds    |%�:      �Z>     Kv d� %�  "E  ,Kalle:Users:ssp:Developer:builds:Bibdesk.app    B i b d e s k . a p p    K a l l e  &Users/ssp/Developer/builds/Bibdesk.app  /    
��  ��    !"! l     �i�h�i  �h  " #�g# l     �f�e�f  �e  �g       �d$%&'()*+,-.�c�b�a�`�_�^�d  $ �]�\�[�Z�Y�X�W�V�U�T�S�R�Q�P�O�N
�] .aevtoappnull  �   � ****�\ 0 d  �[ 0 p  �Z 0 f  �Y 0 lf  �X 0 bibtexrecord BibTeXRecord�W 0 n  �V 0 ar  �U 0 a  �T 	0 apubs  �S  �R  �Q  �P  �O  �N  % �M/�L�K01�J
�M .aevtoappnull  �   � ****/ k    C22  �I�I  �L  �K  0  1 0 �H�G�F3�E +�D�C�B�A�@�?�>�=�< j�;�:�9�8�7�6�5�4�3 ��2�1�0 ��/�.�-�, � � ��+�* ��)�(�'
�H 
docu�G 0 d  
�F 
bibi3  
�E 
ckey
�D 
cobj�C 0 p  
�B 
flds�A 0 f  �@ 0 Journal  
�? 
auth
�> 
aunm
�= 
lURL�< 0 lf  
�; 
rURL
�: 
BTeX�9 0 bibtexrecord BibTeXRecord
�8 
kocl
�7 
insh�6 
�5 .corecrel****      � null�4 0 n  
�3 .coredelonull��� ��� obj �2 0 ar  
�1 
sele
�0 .BDSKsbtcnull��� ��� obj �/ 0 a  �. 	0 apubs  
�- .BDSKshownull��� ��� obj 
�, 
filt
�+ 
disp
�* 
for 
�) .BDSKsrchlist    ��� obj 
�( 
cmpl
�' savoyes �JD�@*�k/E�O�*�-�[�,\Z�@1�k/E�O� -*�,E�O��,EO*�-�,EO*�,E�Oa *a ,FO*a ,E` UO*a �a *�-6a  E` O_ _ a ,FO_ j O*�-�[�,\Za @1E` O_ *a ,FO*j O*�k/EO*�a /E` O_ �-E`  O_ j !O_  j !O*a ",a #  a $*a ",FY a %*a ",FO*a &,EO*a 'a (l )O*a 'a *a +a ,a  )OPUO*a 'a -l )O*�k/a 'a .l )O*�- a /*a ",FUU& 44  �&5
�& 
docu5 �66  B D   t e s t . b i b' 77 8�%�$8  �#9
�# 
docu9 �::  B D   t e s t . b i b
�% 
bibi�$ ( �";<�" 0 Url  ; �== , h t t p : / / l o c a l h o s t / l a l a /< �!>?�! 0 Journal  > �@@ & C o m m u n .   M a t h .   P h y s .? � AB�  	0 Title  A �CC f { H i g g s   f i e l d s ,   b u n d l e   g e r b e s   a n d   s t r i n g   s t r u c t u r e s }B �DE� 0 Year  D �FF  2 0 0 3E �GH� 	0 Pages  G �II  5 4 1 - - 5 5 5H �JK� 0 Rss-Description  J �LL  K �MN� 0 Abstract  M �OO  N �PQ� 0 Keywords  P �RR  Q �ST� 	0 Month  S �UU  T �VW� 
0 Number  V �XX  W �YZ� 0 	Local-Url  Y �[[ X / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d fZ �\]� 
0 Eprint  \ �^^ * a r X i v : m a t h . D G / 0 1 0 6 1 7 9] �_`� 
0 Volume  _ �aa  2 4 3` �bc� 
0 Annote  b �dd  c �e�� 
0 Author  e �ff : M .   K .   M u r r a y   a n d   D .   S t e v e n s o n�  ) �gg X / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f* �hh� @ a r t i c l e { m a t h . D G / 0 1 0 6 1 7 9 , 
 	 A u t h o r   =   { M .   K .   M u r r a y   a n d   D .   S t e v e n s o n } , 
 	 E p r i n t   =   { a r X i v : m a t h . D G / 0 1 0 6 1 7 9 } , 
 	 J o u r n a l   =   { C o m m u n .   M a t h .   P h y s . } , 
 	 L o c a l - U r l   =   { / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f } , 
 	 P a g e s   =   { 5 4 1 - - 5 5 5 } , 
 	 T i t l e   =   { { H i g g s   f i e l d s ,   b u n d l e   g e r b e s   a n d   s t r i n g   s t r u c t u r e s } } , 
 	 U r l   =   { h t t p : / / l o c a l h o s t / l a l a / } , 
 	 V o l u m e   =   { 2 4 3 } , 
 	 Y e a r   =   { 2 0 0 3 } }+ ii j��j  �k
� 
docuk �ll  B D   t e s t . b i b
� 
bibi� , �m� m  non pp q��q  �r
� 
docur �ss  B D   t e s t . b i b
� 
bibi� o tt u��
u  �	v
�	 
docuv �ww  B D   t e s t . b i b
� 
bibi�
 - xx y�zy  �{
� 
docu{ �||  B D   t e s t . b i b
� 
authz �}}  M u r r a y ,   M .   K .. �~� ~               �� ����  ��
� 
docu� ���  B D   t e s t . b i b
� 
bibi� �c  �b  �a  �`  �_  �^  ascr  ��ޭ