%% INSTANCIATE SERDES

serdes = SerDes(PAMBase(), NoneEncScheme(), NoneSoundHeader());

%% MANUAL TEST

message1 = 'AAAshshsshshsssssssssssssssssssssssssssssssssssssssssssssssssssAAAAAAAAAAAAYUDAAAAAAAAAAAAa xd';
signal = serdes.from_str(message1);
message2 = serdes.to_str(signal);
assert(all(message1==message2))

%% PLAY SOUND
serdes.play_signal(signal)

%% AUTOMATED TEST
base = SinesBase();
SerDes.auto_test_base(base, [-3, -1, 1, 3])

%% CLEANUP
clear
clc


