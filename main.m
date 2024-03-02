%% INSTANCIATE SERDES

serdes = SerDes(SinesBase);

%% MANUAL TEST

word1 = serdes.encode_str("sfnsfad");
signal = serdes.apply_base(word1);
word2 = serdes.unapply_base(signal);
disp("Correctness Rate: "+serdes.get_word_correctness_rate(word1, word2))

%% AUTOMATED TEST
serdes.auto_test_base(SinesBase)

%% CLEANUP
clear
clc