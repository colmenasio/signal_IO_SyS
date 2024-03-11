%% INSTANCIATE SERDES

serdes = SerDes(SinesBase(), NoneEncScheme());

%% MANUAL TEST

message1 = 'AAAAAAAAAAAAAAAYUDAAAAAAAAAAAAa xd';
signal = serdes.from_str(message1);
message2 = serdes.to_str(signal);
assert(all(message1 == message2));

%% AUTOMATED TEST
SerDes.auto_test_base(SinesBase)

%% CLEANUP
clear
clc
