%% SETUP

serdes = SerDes(PAMBase(), NoneEncScheme(), NoneSoundHeader());
message = 'Una matrioshka (en rusia-Ucrania: матрёшкa también llamada en español muñeca rusa, matrioska, mamushka o bábushka es un conjunto de muñecas tradicion...';

signal = serdes.from_str(message);
serdes.play_signal(signal);
%% TESTING

NSR_db = 0;
[og_bits, broken_bits] = serdes.noisyfy_bits(message, NSR_db);
disp("Received correctly "+100*serdes.get_correctness_rate_bits(og_bits, broken_bits)+" % of the bits")

%% 1)
NSR_db = 2;

[~, broken_components] = serdes.noisyfy_components(message, NSR_db);
serdes.do_error_scatter(broken_components)

clear broken_components NSR_db

%% 2)
nsr_range = -22:1.5:3;
iterations_n = 2;
serdes.do_rms_sweep_plot(message, nsr_range, iterations_n)

clear nsr_range iterations_n

%% 3)
serdes.str_from_m4a_file("Grabación_p.o.m4a")

%% Cleanup
clc
clear