FasdUAS 1.101.10   ��   ��    k             l     �� ��    O I Install in bundle/Contents/Scripts so it's visible from the Scripts menu       	  l     �� 
��   
 e _ This script was shipped with OmniWeb5.  Stefan K. from Omni said that we can treat this script    	     l     �� ��    9 3 as if it is covered under the Omni Source License.         l     ������  ��        j     �� �� 0 appname AppName  m         BibDesk         l     ������  ��        l    	    r     	    I    ��  
�� .earsffdralis        afdr  m        
 asup     �� ��
�� 
from  m    ��
�� fldmfldu��    o      ���� 0 
asupfolder 
asupFolder  B < "asup" = application support folder... buggy standard osax.        !   l  
  "�� " r   
  # $ # b   
  % & % n   
  ' ( ' 1    ��
�� 
psxp ( o   
 ���� 0 
asupfolder 
asupFolder & o    ���� 0 appname AppName $ o      ����  0 asupfolderpath asupFolderPath��   !  ) * ) l     ������  ��   *  + , + l   1 -�� - r    1 . / . b    / 0 1 0 b    - 2 3 2 b    ' 4 5 4 b    % 6 7 6 b     8 9 8 b     : ; : m     < < 0 *This menu contains AppleScripts to extend     ; o    ���� 0 appname AppName 9 m     = = � �'s functionality; to run a script, select it in the menu. To add scripts to the menu, save them in your Library/Application Support/    7 o    $���� 0 appname AppName 5 m   % & > >  /Scripts folder. See     3 o   ' ,���� 0 appname AppName 1 m   - . ? ?   Help for more info.    / o      ���� 0 
dialogtext 
dialogText��   ,  @ A @ l     ������  ��   A  B C B l  2 E D�� D I  2 E�� E F
�� .sysodlogaskr        TEXT E o   2 3���� 0 
dialogtext 
dialogText F �� G H
�� 
btns G J   4 9 I I  J K J m   4 5 L L  Show Sample Script    K  M N M m   5 6 O O  Open Scripts Folder    N  P�� P m   6 7 Q Q  OK   ��   H �� R��
�� 
dflt R m   < ? S S  OK   ��  ��   C  T U T l  F Q V�� V r   F Q W X W l  F M Y�� Y n   F M Z [ Z 1   I M��
�� 
bhit [ l  F I \�� \ 1   F I��
�� 
rslt��  ��   X o      ����  0 buttonreturned buttonReturned��   U  ] ^ ] l     ������  ��   ^  _ ` _ l  Rq a�� a Z   Rq b c d�� b =  R Y e f e o   R U����  0 buttonreturned buttonReturned f m   U X g g  Open Scripts Folder    c k   \ h h  i j i l  \ \������  ��   j  k l k l  \ \�� m��   m ? 9 find out if the folder exists or if we have to create it    l  n o n r   \ a p q p m   \ ]��
�� boovfals q o      ���� (0 shouldcreatefolder shouldCreateFolder o  r s r r   b k t u t b   b g v w v o   b c����  0 asupfolderpath asupFolderPath w m   c f x x  /Scripts    u o      ���� &0 scriptsfolderpath scriptsFolderPath s  y z y Q   l � { | } { n   o � ~  ~ 1   { ��
�� 
asdr  l  o { ��� � I  o {�� ���
�� .sysonfo4asfe       **** � 4   o w�� �
�� 
psxf � o   s v���� &0 scriptsfolderpath scriptsFolderPath��  ��   | R      ������
�� .ascrerr ****      � ****��  ��   } r   � � � � � m   � ���
�� boovtrue � o      ���� (0 shouldcreatefolder shouldCreateFolder z  � � � l  � �������  ��   �  � � � l  � ��� ���   � n h ask if we should create the folder, and create it via the shell for quick rescursive directory creation    �  � � � Z   � � � ����� � o   � ����� (0 shouldcreatefolder shouldCreateFolder � k   � � � �  � � � I  � ��� ���
�� .sysodlogaskr        TEXT � m   � � � � � |That Scripts folder doesn't exist yet. Would you like to create it now? (You may be prompted for an administrator password.)   ��   �  ��� � Q   � � � � � � k   � � � �  � � � I  � ��� ���
�� .sysoexecTEXT���     TEXT � b   � � � � � b   � � � � � m   � � � �  
mkdir -p '    � o   � ����� &0 scriptsfolderpath scriptsFolderPath � m   � � � �  '   ��   �  ��� � r   � � � � � m   � ���
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder��   � R      ������
�� .ascrerr ****      � ****��  ��   � Q   � � � � � � k   � � � �  � � � I  � ��� � �
�� .sysoexecTEXT���     TEXT � b   � � � � � b   � � � � � m   � � � �  	mkdir -p     � o   � ����� &0 scriptsfolderpath scriptsFolderPath � m   � � � �  '    � �� ���
�� 
badm � m   � ���
�� boovtrue��   �  � � � r   � � � � � m   � ���
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder �  ��� � l  � �������  ��  ��   � R      ������
�� .ascrerr ****      � ****��  ��   � I  � ��� � �
�� .sysodlogaskr        TEXT � m   � � � � F @You do not have sufficent user privileges to create this folder.    � �� � �
�� 
btns � m   � � � �  OK    � �� ���
�� 
dflt � m   � � � �  OK   ��  ��  ��  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   � ] W open the folder for the user using the Finder (or user's preferred Finder replacement)    �  � � � Z  � � ����� � H   � � � � o   � ����� (0 shouldcreatefolder shouldCreateFolder � I �� ���
�� .sysoexecTEXT���     TEXT � b   � � � b   � � � m   � �  open '    � o  ���� &0 scriptsfolderpath scriptsFolderPath � m   � �  '   ��  ��  ��   �  ��� � l ������  ��  ��   d  � � � =   � � � o  ����  0 buttonreturned buttonReturned � m   � �  Show Sample Script    �  ��� � k  #m � �  � � � l ##������  ��   �  � � � r  #, � � � b  #( � � � o  #$����  0 asupfolderpath asupFolderPath � m  $' � �  /BD Test.scpt    � o      ����  0 testscriptpath testScriptPath �  � � � Q  -k � � � � I 0@�� ���
�� .aevtodocnull  �    alis � c  0< � � � l 08 ��� � 4  08�� �
�� 
psxf � o  47����  0 testscriptpath testScriptPath��   � m  8;��
�� 
alis��   � R      ������
�� .ascrerr ****      � ****��  ��   � Q  Hk � ��� � k  Kb � �  � � � l KK�� ���   � M G first block won't work under Tiger, and this one won't work on Panther    �  �� � O  Kb � � � I Qa�~ ��}
�~ .aevtodocnull  �    alis � c  Q] � � � l QY ��| � 4  QY�{ �
�{ 
psxf � o  UX�z�z  0 testscriptpath testScriptPath�|   � m  Y\�y
�y 
alis�}   � m  KN � � fnull     ߀                                                                      ToyS   psn        �   � R      �x�w�v
�x .ascrerr ****      � ****�w  �v  ��   �  ��u � l ll�t�s�t  �s  �u  ��  ��  ��   `  ��r � l     �q�p�q  �p  �r       �o �  ��o   � �n�m�n 0 appname AppName
�m .aevtoappnull  �   � **** � �l ��k�j �i
�l .aevtoappnull  �   � **** � k    q       +  B  T  _�h�h  �k  �j      2 �g�f�e�d�c�b < = > ?�a�` L O Q�_ S�^�]�\�[�Z g�Y x�X�W�V�U�T�S � � ��R � ��Q � � � � � � ��P�O�N �
�g 
from
�f fldmfldu
�e .earsffdralis        afdr�d 0 
asupfolder 
asupFolder
�c 
psxp�b  0 asupfolderpath asupFolderPath�a 0 
dialogtext 
dialogText
�` 
btns
�_ 
dflt�^ 
�] .sysodlogaskr        TEXT
�\ 
rslt
�[ 
bhit�Z  0 buttonreturned buttonReturned�Y (0 shouldcreatefolder shouldCreateFolder�X &0 scriptsfolderpath scriptsFolderPath
�W 
psxf
�V .sysonfo4asfe       ****
�U 
asdr�T  �S  
�R .sysoexecTEXT���     TEXT
�Q 
badm�P  0 testscriptpath testScriptPath
�O 
alis
�N .aevtodocnull  �    alis�ir���l E�O��,b   %E�O�b   %�%b   %�%b   %�%E�O�����mva a a  O_ a ,E` O_ a   �fE` O�a %E` O *a _ /j a ,EW X  eE` O_  fa  j O a !_ %a "%j #OfE` W @X    a $_ %a %%a &el #OfE` OPW X  a '�a (a a )a  Y hO_  a *_ %a +%j #Y hOPY Z_ a ,  O�a -%E` .O *a _ ./a /&j 0W *X   a 1 *a _ ./a /&j 0UW X  hOPY hascr  ��ޭ