%% INSTANCIATE SERDES

serdes = SerDes(SinesBase(), NoneEncScheme());

%% MANUAL TEST

signal = serdes.from_str("sfnsfad");
%word2 = serdes.unapply_base(signal);

%% AUTOMATED TEST
SerDes.auto_test_base(SinesBase)

%% CLEANUP
clear
clc
