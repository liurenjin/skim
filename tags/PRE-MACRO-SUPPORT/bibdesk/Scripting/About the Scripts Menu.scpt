FasdUAS 1.101.10   ��   ��    k             l     �� ��    O I Install in bundle/Contents/Scripts so it's visible from the Scripts menu       	  l     �� 
��   
 e _ This script was shipped with OmniWeb5.  Stefan K. from Omni said that we can treat this script    	     l     �� ��    9 3 as if it is covered under the Omni Source License.         l     ������  ��        j     �� �� 0 appname AppName  m         BibDesk         l     ������  ��        l     ��  r         b         b         b          b      ! " ! b     	 # $ # b      % & % m      ' ' 0 *This menu contains AppleScripts to extend     & o    ���� 0 appname AppName $ m     ( ( � �'s functionality; to run a script, select it in the menu. To add scripts to the menu, save them in your Library/Application Support/    " o   	 ���� 0 appname AppName   m     ) )  /Scripts folder. See      o    ���� 0 appname AppName  m     * *   Help for more info.     o      ���� 0 
dialogtext 
dialogText��     + , + l     ������  ��   ,  - . - l   ( /�� / I   (�� 0 1
�� .sysodlogaskr        TEXT 0 o    ���� 0 
dialogtext 
dialogText 1 �� 2 3
�� 
btns 2 J    " 4 4  5 6 5 m     7 7  Open Scripts Folder    6  8�� 8 m      9 9  OK   ��   3 �� :��
�� 
dflt : m   # $ ; ;  OK   ��  ��   .  < = < l     ������  ��   =  >�� > l  )� ?�� ? Z   )� @ A���� @ =  ) . B C B n   ) , D E D 1   * ,��
�� 
bhit E l  ) * F�� F 1   ) *��
�� 
rslt��   C m   , - G G  Open Scripts Folder    A k   1� H H  I J I l  1 1������  ��   J  K L K l  1 @ M N M r   1 @ O P O I  1 <�� Q R
�� .earsffdralis        afdr Q m   1 2 S S 
 asup    R �� T��
�� 
from T m   5 8��
�� fldmfldu��   P o      ����  0 userasupfolder userAsupFolder N B < "asup" = application support folder... buggy standard osax.    L  U V U r   A R W X W I  A N�� Y Z
�� .earsffdralis        afdr Y m   A D [ [ 
 asup    Z �� \��
�� 
from \ m   G J��
�� fldmfldl��   X o      ���� "0 localasupfolder localAsupFolder V  ] ^ ] Q   S v _ ` a _ l  V g b c b r   V g d e d I  V c�� f g
�� .earsffdralis        afdr f m   V Y h h 
 dlib    g �� i��
�� 
from i m   \ _��
�� fldmfldn��   e o      ���� &0 networkdlibfolder networkDlibFolder c E ? "dlib" = library folder, since asup folder might not exist yet    ` R      ������
�� .ascrerr ****      � ****��  ��   a r   o v j k j m   o r l l       k o      ���� &0 networkdlibfolder networkDlibFolder ^  m n m l  w w������  ��   n  o p o Z   w � q r�� s q =  w ~ t u t o   w z���� &0 networkdlibfolder networkDlibFolder u m   z } v v       r k   � � w w  x y x I  � ��� z {
�� .sysodlogaskr        TEXT z m   � � | | � �There are two different folders you can put scripts into, depending on whether you want to keep them to yourself or share them with other people who have user accounts on this computer. Which do you want to open?    { �� }��
�� 
btns } J   � � ~ ~   �  m   � � � �  	My Folder    �  ��� � m   � � � �  Computer Folder   ��  ��   y  ��� � r   � � � � � n   � � � � � 1   � ���
�� 
bhit � l  � � ��� � 1   � ���
�� 
rslt��   � o      ���� 0 dialogreply dialogReply��  ��   s k   � � � �  � � � I  � ��� � �
�� .sysodlogaskr        TEXT � m   � � � � � �There are three different folders you can put scripts into, depending on whether you want to keep them to yourself, share them with users on this computer, or share them with all users on your network. Which do you want to open?    � �� ���
�� 
btns � J   � � � �  � � � m   � � � �  	My Folder    �  � � � m   � � � �  Computer Folder    �  ��� � m   � � � �  Network Folder   ��  ��   �  ��� � r   � � � � � n   � � � � � 1   � ���
�� 
bhit � l  � � ��� � 1   � ���
�� 
rslt��   � o      ���� 0 dialogreply dialogReply��   p  � � � Z   � � � � � � � =  � � � � � o   � ����� 0 dialogreply dialogReply � m   � � � �  	My Folder    � r   � � � � � o   � �����  0 userasupfolder userAsupFolder � o      ���� 0 chosenfolder chosenFolder �  � � � =  � � � � � o   � ����� 0 dialogreply dialogReply � m   � � � �  Computer Folder    �  ��� � r   � � � � � o   � ����� "0 localasupfolder localAsupFolder � o      ���� 0 chosenfolder chosenFolder��   � r   � � � � � o   � ����� &0 networkdlibfolder networkDlibFolder � o      ���� 0 chosenfolder chosenFolder �  � � � l  � �������  ��   �  � � � l  � ��� ���   � ? 9 find out if the folder exists or if we have to create it    �  � � � r   � � � � � m   � ���
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder �  � � � Z   �) � ��� � � =  � � � � � o   � ����� 0 chosenfolder chosenFolder � o   � ����� &0 networkdlibfolder networkDlibFolder � r   � � � � b   � � � � b   �	 � � � b   � � � � n   � � � � � 1   � ���
�� 
psxp � o   � ����� 0 chosenfolder chosenFolder � m   � � �  Application Support/    � o  ���� 0 appname AppName � m  	 � �  /Scripts    � o      ���� &0 scriptsfolderpath scriptsFolderPath��   � r  ) � � � b  % � � � b  ! � � � n   � � � 1  ��
�� 
psxp � o  ���� 0 chosenfolder chosenFolder � o   ���� 0 appname AppName � m  !$ � �  /Scripts    � o      ���� &0 scriptsfolderpath scriptsFolderPath �  � � � Q  *K � � � � n  -> � � � 1  9=��
�� 
asdr � l -9 ��� � I -9�� ���
�� .sysonfo4asfe       **** � 4  -5�� �
�� 
psxf � o  14���� &0 scriptsfolderpath scriptsFolderPath��  ��   � R      ������
�� .ascrerr ****      � ****��  ��   � r  FK � � � m  FG��
�� boovtrue � o      ���� (0 shouldcreatefolder shouldCreateFolder �  � � � l LL������  ��   �  � � � l LL�� ���   � n h ask if we should create the folder, and create it via the shell for quick rescursive directory creation    �  � � � Z  L� � ����� � o  LO���� (0 shouldcreatefolder shouldCreateFolder � k  R� � �  � � � I RY�� ���
�� .sysodlogaskr        TEXT � m  RU � � � |That Scripts folder doesn't exist yet. Would you like to create it now? (You may be prompted for an administrator password.)   ��   �  ��� � Q  Z� � � � � k  ]r � �  � � � I ]l�� ���
�� .sysoexecTEXT���     TEXT � b  ]h � � � b  ]d � � � m  ]`    
mkdir -p '    � o  `c���� &0 scriptsfolderpath scriptsFolderPath � m  dg  '   ��   � �� r  mr m  mn��
�� boovfals o      ���� (0 shouldcreatefolder shouldCreateFolder��   � R      �����
�� .ascrerr ****      � ****��  �   � Q  z� k  }� 	
	 I }��~
�~ .sysoexecTEXT���     TEXT b  }� b  }� m  }�  	mkdir -p     o  ���}�} &0 scriptsfolderpath scriptsFolderPath m  ��  '    �|�{
�| 
badm m  ���z
�z boovtrue�{  
  r  �� m  ���y
�y boovfals o      �x�x (0 shouldcreatefolder shouldCreateFolder �w l ���v�u�v  �u  �w   R      �t�s�r
�t .ascrerr ****      � ****�s  �r   I ���q
�q .sysodlogaskr        TEXT m  �� F @You do not have sufficent user privileges to create this folder.    �p
�p 
btns m  ��  OK    �o�n
�o 
dflt m  ��    OK   �n  ��  ��  ��   � !"! l ���m�l�m  �l  " #$# l ���k%�k  % ] W open the folder for the user using the Finder (or user's preferred Finder replacement)   $ &'& Z ��()�j�i( H  ��** o  ���h�h (0 shouldcreatefolder shouldCreateFolder) I ���g+�f
�g .sysoexecTEXT���     TEXT+ b  ��,-, b  ��./. m  ��00  open '   / o  ���e�e &0 scriptsfolderpath scriptsFolderPath- m  ��11  '   �f  �j  �i  ' 2�d2 l ���c�b�c  �b  �d  ��  ��  ��  ��       �a3 4�a  3 �`�_�` 0 appname AppName
�_ .aevtoappnull  �   � ****4 �^5�]�\67�[
�^ .aevtoappnull  �   � ****5 k    �88  99  -::  >�Z�Z  �]  �\  6  7 > ' ( ) *�Y�X 7 9�W ;�V�U�T�S G S�R�Q�P�O [�N�M h�L�K�J�I l v | � ��H � � � � ��G ��F�E � ��D ��C�B�A � �@�? 01�Y 0 
dialogtext 
dialogText
�X 
btns
�W 
dflt�V 
�U .sysodlogaskr        TEXT
�T 
rslt
�S 
bhit
�R 
from
�Q fldmfldu
�P .earsffdralis        afdr�O  0 userasupfolder userAsupFolder
�N fldmfldl�M "0 localasupfolder localAsupFolder
�L fldmfldn�K &0 networkdlibfolder networkDlibFolder�J  �I  �H 0 dialogreply dialogReply�G 0 chosenfolder chosenFolder�F (0 shouldcreatefolder shouldCreateFolder
�E 
psxp�D &0 scriptsfolderpath scriptsFolderPath
�C 
psxf
�B .sysonfo4asfe       ****
�A 
asdr
�@ .sysoexecTEXT���     TEXT
�? 
badm�[��b   %�%b   %�%b   %�%E�O����lv��� O��,� ��a a l E` Oa a a l E` O a a a l E` W X  a E` O_ a   a �a a  lvl O��,E` !Y a "�a #a $a %mvl O��,E` !O_ !a &  _ E` 'Y _ !a (  _ E` 'Y 	_ E` 'OfE` )O_ '_   _ 'a *,a +%b   %a ,%E` -Y _ 'a *,b   %a .%E` -O *a /_ -/j 0a 1,EW X  eE` )O_ ) ba 2j O a 3_ -%a 4%j 5OfE` )W <X    a 6_ -%a 7%a 8el 5OfE` )OPW X  a 9�a :�a ;� Y hO_ ) a <_ -%a =%j 5Y hOPY h ascr  ��ޭ