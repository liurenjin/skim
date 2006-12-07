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
docu��        l   ������  ��       !   l   �� "��   " ; 5 get first, i.e. frontmost,  document and talk to it.    !  # $ # r     % & % e     ' ' 4   �� (
�� 
docu ( m    ����  & o      ���� 0 thedoc theDoc $  ) * ) l   ������  ��   *  + , + l   - . - O    / 0 / k   ~ 1 1  2 3 2 l   ������  ��   3  4 5 4 l   �� 6��   6 + % GENERATING AND DELETING PUBLICATIONS    5  7 8 7 l   �� 9��   9 %  make some BibTeX record to use    8  : ; : l   �� <��   < #  let's make a new publication    ;  = > = r    , ? @ ? I   *���� A
�� .corecrel****      � null��   A �� B C
�� 
kocl B m     !��
�� 
bibi C �� D��
�� 
insh D l  " & E�� E n   " & F G F  ;   % & G 2  " %��
�� 
bibi��  ��   @ o      ���� 0 newpub newPub >  H I H l  - -�� J��   J ? 9 this is initially empty, so fill it with a BibTeX string    I  K L K l  - -�� M��   M > 8 note: this can only be set before doing any other edit!    L  N O N r   - 2 P Q P m   - . R R s m@article{McCracken:2005, Author = {M. McCracken and A. Maxwell}, Title = {Working with BibDesk.},Year={2005}}    Q n       S T S 1   / 1��
�� 
BTeX T o   . /���� 0 newpub newPub O  U V U l  3 3�� W��   W + % we can get the BibTeX record as well    V  X Y X r   3 9 Z [ Z e   3 7 \ \ n   3 7 ] ^ ] 1   4 6��
�� 
BTeX ^ o   3 4���� 0 newpub newPub [ o      ���� "0 thebibtexrecord theBibTeXRecord Y  _ ` _ l  : :�� a��   a %  get rid of the new publication    `  b c b I  : ?�� d��
�� .coredelonull���     obj  d o   : ;���� 0 newpub newPub��   c  e f e l  @ @�� g��   g / ) a shortcut to creating a new publication    f  h i h r   @ S j k j I  @ Q���� l
�� .corecrel****      � null��   l �� m n
�� 
kocl m m   B C��
�� 
bibi n �� o p
�� 
prdt o K   D H q q �� r��
�� 
BTeX r o   E F���� "0 thebibtexrecord theBibTeXRecord��   p �� s��
�� 
insh s l  I M t�� t n   I M u v u  ;   L M v 2  I L��
�� 
bibi��  ��   k o      ���� 0 newpub newPub i  w x w l  T T������  ��   x  y z y l  T T�� {��   { !  MANIPULATING THE SELECTION    z  | } | l  T T�� ~��   ~ L F Play with the selection and put styled bibliography on the clipboard.    }   �  r   T j � � � l  T f ��� � 6  T f � � � 2  T W��
�� 
bibi � E   Z e � � � 1   [ _��
�� 
ckey � m   ` d � �  	McCracken   ��   � o      ���� 0 somepubs somePubs �  � � � r   k t � � � o   k n���� 0 somepubs somePubs � l      ��� � 1   n s��
�� 
sele��   �  � � � I  u z������
�� .BDSKsbtcnull��� ��� obj ��  ��   �  � � � l  { {�� ���   �   get the selection    �  � � � r   { � � � � l  { � ��� � 1   { ���
�� 
sele��   � o      ���� 0 theselection theSelection �  � � � l  � ��� ���   �   and get its first item    �  � � � r   � � � � � e   � � � � n   � � � � � 4   � ��� �
�� 
cobj � m   � �����  � o   � ����� 0 theselection theSelection � o      ���� 0 thepub thePub �  � � � l  � �������  ��   �  � � � l  � ��� ���   � , & ACCESSING PROPERTIES OF A PUBLICATION    �  � � � l  � � � � O   � � � � k   � � �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 1 + all properties give quite a lengthy output    �  � � � l  � ��� ���   �   get properties    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � I C plurals as well as accessing a whole array of things  work as well    �  � � � n   � � � � � 1   � ���
�� 
aunm � 2  � ���
�� 
auth �  � � � l  � �������  ��   �  � � � l  � ��� ���   � . ( as does access to the local file's path    �  � � � r   � � � � � e   � � � � 1   � ���
�� 
lURL � o      ���� 0 thepath thePath �  � � � l  � ��� ���   � Note this is a POSIX style path, unlike the value of the field "Local-URL". To use it in AppleScript, e.g. to open the file with Finder, translate it into an AppleScript style path as in the next line. AppleScript's is added because 'POSIX file' is not a Bibdesk command.    �  � � � l  � ��� ���   � &  AppleScript's POSIX file thePath    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � #  we can easily set properties    �  � � � r   � � � � � m   � � � �  http://localhost/lala/    � o      ���� 0 theurl theURL �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 0 * we can access all fields and their values    �  � � � r   � � � � � e   � � � � 4   � ��� �
�� 
bfld � m   � � � �  Author    � o      ���� 0 thefield theField �  � � � e   � � � � n   � � � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Title    �  � � � r   � � � � � m   � � � �  SourceForge    � n       � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Journal    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � J D we can also get a list of all non-empty fields and their properties    �  � � � r   � � � � � e   � � � � n   � �   1   � ���
�� 
pnam 2  � ���
�� 
bfld � o      ����  0 nonemptyfields nonEmptyFields �  l  � �������  ��    l  � ���    
 CITE KEYS     l  � ��~	�~  	 8 2you can access the cite key and generate a new one    

 e   � � 1   � ��}
�} 
ckey  r   � e   �  1   � �|
�| 
gcky 1   �{
�{ 
ckey  l �z�y�z  �y    l �x�x     AUTHORS     l �w�w   7 1 we can also query all authors in the publciation     r   e   4 �v
�v 
auth m  �u�u  o      �t�t 0 	theauthor 	theAuthor  !  l �s"�s  " E ? this is the normalized name of the form 'von Last, First, Jr.'   ! #$# n  %&% 1  �r
�r 
pnam& o  �q�q 0 	theauthor 	theAuthor$ '�p' l �o�n�o  �n  �p   � o   � ��m�m 0 thepub thePub �   thePub    � ()( l �l�k�l  �k  ) *+* l �j,�j  , !  work again on the document   + -.- l �i�h�i  �h  . /0/ l �g1�g  1   AUTHORS   0 232 l �f4�f  4 � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.   3 565 r  ,787 e  (99 4  (�e:
�e 
auth: m  #&;;  McCracken, M.   8 o      �d�d 0 	theauthor 	theAuthor6 <=< l --�c>�c  > $  and find all his publications   = ?@? r  -7ABA e  -3CC n  -3DED 2 02�b
�b 
bibiE o  -0�a�a 0 	theauthor 	theAuthorB o      �`�` 0 hispubs hisPubs@ FGF l 88�_�^�_  �^  G HIH l 88�]J�]  J   OPENING WINDOWS   I KLK l 88�\M�\  M _ Y we can open the editor window for a publication and the information window for an author   L NON I 8?�[P�Z
�[ .BDSKshownull��� ��� obj P o  8;�Y�Y 0 thepub thePub�Z  O QRQ I @G�XS�W
�X .BDSKshownull��� ��� obj S o  @C�V�V 0 	theauthor 	theAuthor�W  R TUT l HH�U�T�U  �T  U VWV l HH�SX�S  X   FILTERING AND SEARCHING   W YZY l HH�R[�R  [ y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   Z \]\ l HH�Q^�Q  ^�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   ] _`_ Z  Hiab�Pca = HQded 1  HM�O
�O 
filte m  MPff      b r  T]ghg m  TWii  	McCracken   h 1  W\�N
�N 
filt�P  c r  `ijkj m  `cll      k 1  ch�M
�M 
filt` mnm e  jpoo 1  jp�L
�L 
dispn pqp e  q|rr I q|�K�Js
�K .BDSKsrch****  @     obj �J  s �It�H
�I 
for t m  uxuu  	McCracken   �H  q vwv l }}�Gx�G  x r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   w yzy l }}�F{�F  { 3 -get search for "McCracken" for completion yes   z |�E| l }}�D�C�D  �C  �E   0 o    �B�B 0 thedoc theDoc .   theDoc    , }~} l ���A�@�A  �@  ~ � l ���?��?  � $  work again on the application   � ��� l ���>�=�>  �=  � ��� l ���<��<  � � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   � ��� I ���;�:�
�; .BDSKsrch****  @     obj �:  � �9��8
�9 
for � m  ����  	McCracken   �8  � ��� I ���7��
�7 .BDSKsrch****  @     obj � 4 ���6�
�6 
docu� m  ���5�5 � �4��3
�4 
for � m  ����  	McCracken   �3  � ��� l ���2��2  �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   � ��� O ����� r  ����� m  ����  	McCracken   � 1  ���1
�1 
filt� 2  ���0
�0 
docu� ��� l ���/�.�/  �.  � ��� l ���-��-  �   GLOBAL PROPERTIES   � ��� l ���,��,  � 4 . you can get the folder where papers are filed   � ��� r  ����� l ����+� 1  ���*
�* 
pfol�+  � o      �)�) "0 thepapersfolder thePapersFolder� ��� l ���(��(  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� O  ����� I ���'��&
�' .aevtodocnull  �    alis� c  ����� l ����%� 4  ���$�
�$ 
psxf� o  ���#�# "0 thepapersfolder thePapersFolder�%  � m  ���"
�" 
alis�&  � m  �����null     ߀��  �
Finder.app��P    �H��L�����p   � P   )       �:(�G���Ѡ�MACS   alis    r  Macintosh HD               �2�H+    �
Finder.app                                                       Cp�g�        ����  	                CoreServices    �1��      �gą      �  �  �  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l ���!� �!  �   � ��� l �����  � %  get all known types and fields   � ��� e  ���� 1  ���
� 
atyp� ��� e  ���� 1  ���
� 
afnm� ��� l �����  �  �    m     ���null     ߀�� ��BibDesk.app��   �HD̙L�����    ��܀�L�����   � (  ���ܰ  BDSK   alis    j  Macintosh HD               �2�H+   ��BibDesk.app                                                     %����i�        ����  	                Desktop     �1��      ��Mq     �� ��  k�  -Macintosh HD:Users:hofman:Desktop:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D   Users/hofman/Desktop/BibDesk.app  /    ��  ��    ��� l     ���  �  � ��� l     ���  �  �       ����  � �
� .aevtoappnull  �   � ****� �������
� .aevtoappnull  �   � ****� k    ���  
��  �  �  �  � @�����
�	���� R����� ��� ��������������������� ����� ��� ��� � ���������;������fil����u��������������������
� .miscactvnull��� ��� null
� 
kocl
� 
docu
�
 .corecrel****      � null�	 0 thedoc theDoc
� 
bibi
� 
insh� � 0 newpub newPub
� 
BTeX� "0 thebibtexrecord theBibTeXRecord
� .coredelonull���     obj 
� 
prdt�  �  
�� 
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
lURL�� 0 thepath thePath�� 0 theurl theURL
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
�� .BDSKsrch****  @     obj 
�� 
pfol�� "0 thepapersfolder thePapersFolder
�� 
psxf
�� 
alis
�� .aevtodocnull  �    alis
�� 
atyp
�� 
afnm����*j O*��l O*�k/EE�O�b*���*�-6� E�O���,FO��,EE�O�j O*�����l�*�-6� E�O*�-a [a ,\Za @1E` O_ *a ,FO*j O*a ,E` O_ a k/EE` O_  �*a -a ,EO*a ,EE` Oa E` O*a a  /EE` !O*a a "/a #,EOa $*a a %/a #,FO*a -a &,EE` 'O*a ,EO*a (,E*a ,FO*a k/EE` )O_ )a &,EOPUO*a a */EE` )O_ )�-EE` +O_ j ,O_ )j ,O*a -,a .  a /*a -,FY a 0*a -,FO*a 1,EO*a 2a 3l 4OPUO*a 2a 5l 4O*�k/a 2a 6l 4O*�- a 7*a -,FUO*a 8,E` 9Oa : *a ;_ 9/a <&j =UO*a >,EO*a ?,EOPUascr  ��ޭ