%% INSTANCIATE SERDES

serdes = SerDes(SinesBase(), NoneEncScheme());

%% MANUAL TEST

word1 = serdes.encode_str("sfnsfad");
signal = serdes.apply_base(word1);
word2 = serdes.unapply_base(signal);
disp("Correctness Rate: "+serdes.get_word_correctness_rate(word1, word2))

%% AUTOMATED TEST
SerDes.auto_test_base(SinesBase)

%% CLEANUP
clear
clc
