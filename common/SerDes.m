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
        component_tolerance double
    end
    
    methods
        function obj = SerDes(BaseInstance, EncoderInstance)
            %SERDES Builder. Ensures the provided base and encoding are
            %children of their respective abstract parents
            disp("--> INITIALIZING SinesBase")
            try 
                obj.base = BaseInstance;
                obj.encoding_scheme = EncoderInstance;
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
            
            samples_per_signal = obj.base.word_duration_t * obj.base.sampling_frec;
            signal = zeros(height(words), samples_per_signal);
            for row_i = 1:height(words)
                signal(row_i,:) = obj.apply_base(words(row_i,:));
            end
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
                disp("Catched"+ME)
                disp("Deserializer error Could not parse bits to string (Im too tired to add propper error handling here)")
            end
        end

        function play_signal(obj, signal)
            for row_i = 1:height(signal)
                sound(signal(row_i, :), obj.base.sampling_frec);
                pause(6);
                disp("Reproducing the Next Part of the Signal:")
            end
                
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
            words = zeros(number_of_words, obj.base.n_of_bases);
            % processes the all but the last word. All of this words will
            % be of full length and need no padding
            for row_i = 1:(number_of_words-1) 
                curr_bits_indexes = (data_length*(row_i-1)+1):(data_length*row_i);
                curr_bits = cat(2,dec2bin(word_capacity-1, length_indicator_length),bits(curr_bits_indexes));
                encoded_bits = obj.encoding_scheme.apply_scheme(curr_bits);
                words(row_i,:) = obj.pack_into_word(encoded_bits);
            end
            %processes the last group of bits, adding padding to it
            remaining_bits = bits((data_length*(number_of_words-1)+1):end);
            last_group_length = length_indicator_length+length(remaining_bits);
            padded_bits = obj.add_padding(remaining_bits, '0', data_length);
            curr_bits = cat(2,dec2bin(last_group_length-1, length_indicator_length),padded_bits);
            encoded_bits = obj.encoding_scheme.apply_scheme(curr_bits);
            words(number_of_words,:) = obj.pack_into_word(encoded_bits);
        end

        function word = pack_into_word(obj, encoded_bits)
            % Takes as an argument an array of bytes. Returns an array of
            % symbols eg:[-1, 1, 3, -3] using the obj.alphabet
            % trows an error if the parity is wrong
            try
                groups = reshape(encoded_bits, obj.bits_per_symbol, [])';
            catch ME
                warning("AN ERROR OCCURED WHEN TRYING TO GROUP BITS INTO A WORD: " + ...
                    "THERE NUMBER OF BITS IS NOT DIVISIBLE BY THE NUMBER OF BITS IN A SYMBOL")
                rethrow(ME)
            end
            n_of_symbols = height(groups);
            word = zeros(1, n_of_symbols);
            for symbol_i = 1:n_of_symbols
                word(1, symbol_i) = obj.alphabet(bin2dec(groups(symbol_i, :))+1);
            
            end
        end

        function bits = words_to_bits(obj, words)
            word_capacity = obj.base.n_of_bases * obj.bits_per_symbol;
            length_indicator_length = ceil(log2(word_capacity));
            bits = '';
            for row_i = 1:height(words)
                encoded_bits = obj.unpack_from_word(words(row_i,:));
                curr_bits = obj.encoding_scheme.unapply_scheme(encoded_bits);
                message_length = bin2dec(curr_bits(1:length_indicator_length))+1;
                data_bits_i = (length_indicator_length+1):(message_length);
                data_bits = curr_bits(data_bits_i);
                bits = cat(2, bits, data_bits);
            end
        end

        function encoded_bits = unpack_from_word(obj, word)
            % Takes as an argument an array of bytes. Returns an array of
            % symbols eg:[-1, 1, 3, -3] using the obj.alphabet
            % trows an error if the parity is wrong
            n_of_bits = length(word) * obj.bits_per_symbol;
            groups = reshape(blanks(n_of_bits), [], obj.bits_per_symbol);
            for symbol_i = 1:length(word)
                groups(symbol_i, :) = dec2bin(obj.find_in_alphabet(word(1, symbol_i)), obj.bits_per_symbol);
            end
            encoded_bits = reshape(groups', 1, []);
        end
        
        function signal = apply_base(obj, word)
            % Takes a word and applies the base to it
            % TODO change the assert to propper error handling
            assert(length(word) == obj.base.n_of_bases)
            signal = obj.base.to_signal(word);
        end

        function word = unapply_base(obj, signal)
            % TODO change the assert to propper error handling
            assert(length(signal) == obj.base.sampling_frec * obj.base.word_duration_t)
            word = obj.base.from_signal(signal);
        end

        function result = float_compare(obj, float1, float2)
            result = abs(float1-float2)<obj.component_tolerance;
        end

        function index = find_in_alphabet(obj, float1)
            index = find(arrayfun(@(x) obj.float_compare(float1, x), obj.alphabet), 1)- 1;
            if isempty(index)
                error("Error Deserializing. One of the components from the signal wasnt found in the deserializers alphabet, " + ...
                    "probably due to noise. Either raise the tolerance or provide better encoding schemes")
            end
        end
    
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
        
        function rate = get_word_correctness_rate(word1, word2)
            rate = SerDes.get_n_of_matches(word1, word2)/length(word1);
        end

        function n_of_matches = get_n_of_matches(word1, word2, tolerance)
            if length(word1) ~= length(word2)
                error("The words provided are of different size")
            end
            n_of_matches = sum(abs(word1-word2)<tolerance);
        end

    end
end

