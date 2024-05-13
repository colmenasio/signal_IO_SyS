classdef SerDes < handle
    %SERDES Serializer-Deserializer. Singleton.
    %   Handles the interaction between user and ortonormal base, acting as an
    %   interface of sorts
    
    properties
        CONFIG_PATH string = "configs/serdes.json" %change this to accept path as argument

        bits_per_symbol double
        alphabet
        base AbstBase = NoneBase()
        encoding_scheme AbstEncScheme = NoneEncScheme()
        sound_header AbstSoundHeader = NoneSoundHeader()
        component_tolerance double
    end
    
    methods
        function obj = SerDes(BaseInstance, EncoderInstance, SoundHeaderInstance)
            %SERDES Builder. Ensures the provided base and encoding are
            %children of their respective abstract parents
            disp("--> INITIALIZING SinesBase")
            try 
                obj.base = BaseInstance;
                obj.encoding_scheme = EncoderInstance;
                obj.sound_header = SoundHeaderInstance;
                obj.load_configs();
                obj.bits_per_symbol = log2(length(obj.alphabet));
                obj.validate_params();
                obj.disp_summary();
            catch ME
                disp("An error occured when initializing SERDES")
                rethrow(ME)
            end
        end

        function obj = load_configs(obj)
            %LOAD_CONFIGS In-place load of the configs in obj.CONFIG_PATH
            %Excepts MATLAB:nonExistentField
            fid = fopen(obj.CONFIG_PATH);
            str = char(fread(fid,inf)'); 
            fclose(fid); 
            val = jsondecode(str);

            obj.alphabet = val.alphabet';
            obj.component_tolerance = val.component_tolerance;
            disp("--> LOADED serdes.json CORRECTLY")
        end

        function validate_params(obj)
            if ~isa(obj.base, 'AbstBase')
                error('Input base class must be an instance of a class inheriting from AbstBase.');
            end
            if ~isa(obj.encoding_scheme, 'AbstEncScheme')
                error('Input encoder class must be an instance of a class inheriting from AbstEcnScheme.');
            end
            %check if the amount of symbols in the alphabet is ower of 2
            if sum(dec2bin(length(obj.alphabet))=='1')~=1 
                error("The alphabet used in the SerDes must have a number of symbols that " + ...
                    "is a power of 2 (im waaaay to lazy to implement the generic solution)")
            end
        end

        function disp_summary(obj)
            disp("--> SerDes Summary:")
            disp("Alphabet:")
            disp(obj.alphabet)
            disp("Component tolerance: "+obj.component_tolerance)
            disp("-----------------------------------------")
        end

        function signal = from_str(obj, raw_str)
            %takes a string and returns an matrix in which each row
            % it should convert a string into an array of bits, then pass
            % that array of bits to obj.from_bits
            char_matrix = dec2bin(char(raw_str), 8);
            bits = reshape(char_matrix', 1, []);
            signal = obj.from_bits(bits);
        end

        function signal = from_bits(obj, raw_bits)
            %takes an array of bits and returns an matrix in which each row
            %is a singal corresponding to a single word
            words = obj.bits_to_words(raw_bits);
            signal = obj.apply_base(words);
        end

        function bits = to_bits(obj, full_signal)
            %takes an array of signals, each row corresponding to a single signal, 
            %and returns an array of bits
            words = zeros(height(full_signal), obj.base.n_of_bases);
            for word_i = 1:height(full_signal)
                words(word_i, :) = obj.unapply_base(full_signal(word_i,:));
            end
            bits = obj.words_to_bits(words);
        end

        function str = to_str(obj, full_signal)
            bits = obj.to_bits(full_signal);
            try
                str = char(bin2dec(reshape(bits, 8, [])')');
            catch ME
                disp(ME)
                disp("Deserializer error Could not parse bits to string (Im too tired to add propper error handling here)")
            end
        end

        function play_signal(obj, signal)
            for row_i = 1:height(signal)
                obj.sound_header.play_header();
                sound(signal(row_i, :), obj.base.sampling_frec);
                pause(6);
                disp("Reproducing the Next Part of the Signal:")
            end 
        end

        function [unaffected_components, affected_components] = noisyfy_components(obj, message, NSR_db)
            % Takes a message in str form and a target NSR value in db.
            % The first return argument is the components we expect to receive
            % The second return argument is the components we receive with the noise specified
            signal = obj.from_str(message);
            noisy_signal = obj.add_noise(signal, NSR_db);
            unaffected_components = obj.unapply_base(signal);
            affected_components = obj.unapply_base(noisy_signal);
        end

        function [unaffected_bits, affected_bits] = noisyfy_bits(obj, message, NSR_db)
            % Takes a message in str form and a target NSR value in db.
            % The first return argument is the bits we expect to receive (without decoding or trimming)
            % The second return argument is the bits we receive with the noise specified (without decoding or trimming)
            [unaffected_components, affected_components] = obj.noisyfy_components(message, NSR_db);
            unaffected_bits = obj.unpack_from_words(unaffected_components);
            affected_bits = obj.unpack_from_words(affected_components);
        end

        function do_rms_sweep_plot(obj, message, nsr_range, iterations_n)
            % Tests the average amount of errors obtained in a range of
            % values for the Noise to Signal Ratio and plots it
            correctness_rates = zeros([1, length(nsr_range)]);
            for i = 1:length(nsr_range)
                experiments_results = zeros([1, iterations_n]);
                for experiment_n = 1:iterations_n
                    disp("TESTING nsr = "+nsr_range(i)+" iteration number: "+experiment_n)
                    [og_bits, broken_bits] = obj.noisyfy_bits(message, nsr_range(i));
                    experiments_results(experiment_n) = 1-obj.get_correctness_rate_bits(og_bits, broken_bits);
                end
                correctness_rates(i) = mean(experiments_results);
            end
            semilogy(nsr_range, correctness_rates)
        end
    end

    methods (Access = private)
        function words = bits_to_words(obj, bits)
            % Takes an array of bits, and splits it into words. Returns a
            % matrix in which each row is a word of obj.base.n_of_bases
            % symbols
            word_capacity = obj.base.n_of_bases * obj.bits_per_symbol;
            if word_capacity <= 64
                error("Each word must have a capacity at least 64 bits. " + ...
                    "With the current configuration, each word only " + ...
                    "has a capacity of "+word_capacity+" bits")
            end
            length_indicator_length = ceil(log2(word_capacity));
            data_length = obj.encoding_scheme.get_data_length_in_word(word_capacity-length_indicator_length);
            number_of_words = ceil(width(bits)/data_length);
            if data_length <= 0
                error("Cannot apply the encoding schemes; Words are to short. With the current configuration" + ...
                    "a single word contains "+word_capacity+"bits. Either increase the number of symbols per word " + ...
                    "by increasing the number of vectors in the base or by increasing the number of bits per symbol." + ...
                    "Alternatively, apply less heavy encodings")
            elseif data_length/word_capacity <= 0.5
                warning("The encodings take "++" percent of the word's size, which is arguably a lot. " + ...
                    "Consider reducing the amount of encoding or increasing the amoun of bits per word")
            end
            decoded_bits = reshape(blanks(number_of_words*word_capacity), number_of_words, word_capacity);
            % processes the all but the last word. All of this words will
            % be of full length and need no padding
            for row_i = 1:number_of_words
                if row_i < number_of_words
                    curr_bits_indexes = (data_length*(row_i-1)+1):(data_length*row_i);
                    curr_row_bits = cat(2,dec2bin(word_capacity-1, length_indicator_length),bits(curr_bits_indexes));
                else
                    remaining_bits = bits((data_length*(number_of_words-1)+1):end);
                    last_group_length = length_indicator_length+length(remaining_bits);
                    padded_bits = obj.add_padding(remaining_bits, '0', data_length);
                    curr_row_bits = cat(2,dec2bin(last_group_length-1, length_indicator_length),padded_bits);
                end
                decoded_bits(row_i, :) = curr_row_bits;
            end
            %processes the last group of bits, adding padding to it
            encoded_bits = obj.encode_bits(decoded_bits);
            words = obj.pack_into_words(encoded_bits);
        end

        function words = pack_into_words(obj, encoded_bits)
            % Takes as an argument a matrix of bytes. Returns a matrix of
            % symbols eg:[-1, 1, 3, -3] using the obj.alphabet
            % trows an error if the parity is wrong
            if  mod(length(encoded_bits), obj.bits_per_symbol) ~= 0
                    error("AN ERROR OCCURED WHEN TRYING TO GROUP BITS INTO A WORD: " + ...
                    "THE NUMBER OF BITS IS NOT DIVISIBLE BY THE NUMBER OF BITS IN A SYMBOL")
            end
            n_of_symbols = length(encoded_bits)/obj.bits_per_symbol;
            words = zeros(height(encoded_bits), n_of_symbols);
            for row_i = 1:height(encoded_bits)
                groups = reshape(encoded_bits(row_i, :), obj.bits_per_symbol, [])';
                for symbol_i = 1:n_of_symbols
                    words(row_i, symbol_i) = obj.alphabet(bin2dec(groups(symbol_i, :))+1);
                end
            end
        end

        function bits = words_to_bits(obj, words)
            word_capacity = obj.base.n_of_bases * obj.bits_per_symbol;
            length_indicator_length = ceil(log2(word_capacity));
            
            encoded_bits = obj.unpack_from_words(words);
            decoded_bits = obj.decode_bits(encoded_bits);

            bits = '';
            for row_i = 1:height(words)
                curr_bits = decoded_bits(row_i, :);
                message_length = bin2dec(curr_bits(1:length_indicator_length))+1;
                data_bits_i = (length_indicator_length+1):(message_length);
                data_bits = curr_bits(data_bits_i);
                bits = cat(2, bits, data_bits);
            end
        end

        function encoded_bits = unpack_from_words(obj, words)
            % Takes as an argument a matrix of words (components). Returns a matrix of
            % bits using the obj.alphabet
            % trows an error if the parity is wrong
            bits_per_word = length(words) * obj.bits_per_symbol;
            total_n_of_bits = bits_per_word*height(words);
            encoded_bits = reshape(blanks(total_n_of_bits), height(words), bits_per_word);
            for row_i = 1:height(words)
                groups = reshape(blanks(bits_per_word), [], obj.bits_per_symbol);
                for symbol_i = 1:length(words)
                    groups(symbol_i, :) = dec2bin(obj.find_in_alphabet(words(row_i, symbol_i)), obj.bits_per_symbol);
                end
                encoded_bits(row_i, :) = reshape(groups', 1, []);
            end
        end
        
        function signal = apply_base(obj, words)
            % Takes a matrix of words and applies the base to it
            % returning a matrix of signals
            % TODO change the assert to propper error handling
            assert(length(words) == obj.base.n_of_bases)
            samples_per_signal = obj.base.word_duration_t * obj.base.sampling_frec;
            signal = zeros(height(words), samples_per_signal);
            for row_i = 1:height(words)
                signal(row_i,:) =  obj.base.to_signal(words(row_i,:));
            end
        end

        function words = unapply_base(obj, signal)
            % Takes a matrix of signals and unnaplies the base to it,
            % returning a matrix of words
            % TODO change the assert to propper error handling
            assert(length(signal) == obj.base.sampling_frec * obj.base.word_duration_t)
            words = zeros(height(signal), obj.base.n_of_bases);
            for word_i = 1:height(signal)
                words(word_i, :) = obj.base.from_signal(signal(word_i,:));
            end
        end

        function encoded_bits = encode_bits(obj, decoded_bits)
            % Takes a matrix of data(bits) and applies the encodings to it,
            % returning a matrix of encoded bits
            % TODO change the assert to propper error handling
            encoded_bits = [];
            for row_i = 1:height(decoded_bits)
                encoded_bits = cat(1, encoded_bits, obj.encoding_scheme.apply_scheme(decoded_bits(row_i, :)));
            end
        end

        function decoded_bits = decode_bits(obj, encoded_bits)
            % Takes a matrix of encoded bits and unnaplies the encodings to it,
            % returning a matrix of data(bits)
            % TODO change the assert to propper error handling
            decoded_bits = [];
            for row_i = 1:height(encoded_bits)
                decoded_bits = cat(1, decoded_bits, obj.encoding_scheme.unapply_scheme(encoded_bits(row_i, :)));
            end
        end

        function result = float_compare(obj, float1, float2)
            result = abs(float1-float2)<obj.component_tolerance;
        end

        function index = find_in_alphabet(obj, float1)
            if obj.component_tolerance>0
                index = find(arrayfun(@(x) obj.float_compare(float1, x), obj.alphabet), 1) - 1;
                if isempty(index)
                    error("Error Deserializing. One of the components from the signal wasnt found in the deserializers alphabet, " + ...
                    "probably due to noise. Either raise the tolerance or provide better encoding schemes. Alternatively, " + ...
                    "change the tolerance to 0 in the configs to just pick the nearest element in the alphabet")
                end
            else
                [~, index] = min(abs(obj.alphabet-float1));
                index = index-1;
            end
        end

%         function message = 
    end


    methods(Static)
        function new_array = add_padding(og_array, padding_symbol, desired_length)
            new_array = blanks(desired_length);
            new_array(:) = padding_symbol;
            new_array(1,1:length(og_array)) = og_array;
        end

        function auto_test_base(base, alphabet)
            % Test the interface of a base to see if it acts as a valid
            % 'Base' class
            if ~isa(base, "AbstBase")
                error('The class to be tested must be an instance of a class inheriting from AbstBase.');
            end
            disp("TESTING BASE: "+class(base))
            try
                disp("--> N of symbols per word: "+base.n_of_bases)
                disp("CORRECT"+newline)
            catch ME
                disp("MISSING base.n_of_bases"+newline)
                disp(ME)
                return
            end
            try
                disp("--> Duration of signal per word: "+base.word_duration_t)
                disp("CORRECT"+newline)
            catch ME
                disp("--> MISSING base.word_duration_t"+newline)
                disp(ME)
                return
            end
            try
                disp("--> Duration of signal per word: "+base.sampling_frec)
                disp("CORRECT"+newline)
            catch ME
                disp("--> MISSING base.sampling_frec"+newline)
                disp(ME)
                return
            end
            try
                disp("--> Testing base.to_word / base.to_signal")
                test_word = arrayfun(@(x) alphabet(x), randi(length(alphabet), [1, base.n_of_bases]));
                signal = base.to_signal(test_word);
                resulted_word = base.from_signal(signal);
                if length(resulted_word) ~= length(test_word)
                    error("The provided base is incosistent with word sizes")
                end
                max_dist = max(abs(test_word-resulted_word));
                disp("With the selected alphabet, the base has aproximately +-"+max_dist+" of error per symbol"+newline+ ...
                    "Some bases suffer from numeric error even in noiseless environments"+newline+ ...
                    "To reduce it, either lower the max frecuencies of the base or idk"+newline)
            catch ME
                disp("Somethiing went wrong when testing base.to_word / base.to_signal")
                rethrow(ME)
            end
            disp("ALL TESTS PASSED: VALID BASE")
        end

        function error_rate = get_correctness_rate_bits(bits_1, bits_2)
            % Get the percentage of bits in which 2 string differ
            assert(all(size(bits_1)==size(bits_2)))
            total_errors = sum(bits_1 ~= bits_2, "all");
            number_of_bits = numel(bits_1);
            error_rate = 1-total_errors/number_of_bits;
        end

        function noisy_signal = add_noise(signal, target_SNR_db)
            signal_power_db = 10* log10(rms(signal, "all")^2);
            noise_power_db = signal_power_db -target_SNR_db;
            noise_sample = wgn(height(signal), length(signal), noise_power_db);
            noisy_signal = signal+noise_sample;
        end

        function do_error_scatter(broken_components)
            scatter(reshape(broken_components, 1, []), 1)
        end
    end
end

