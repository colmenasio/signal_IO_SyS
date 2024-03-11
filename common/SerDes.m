classdef SerDes
    %SERDES Serializer-Deserializer. Singleton.
    %   Handles the interaction between user and ortonormal base, acting as an
    %   interface of sorts
    
    properties
        bits_per_symbol double
        alphabet = [-1, 1]
        base AbstBase = NoneBase()
        encoding_scheme AbstEncScheme = NoneEncScheme()
    end
    
    methods
        function obj = SerDes(BaseInstance, EncoderInstance)
            %SERDES Builder. Ensures the provided base and encoding are
            %children of their respective abstract parents
            if ~isa(BaseInstance, 'AbstBase')
                error('Input base class must be an instance of a class inheriting from AbstBase.');
            end
            obj.base = BaseInstance;
            if ~isa(EncoderInstance, 'AbstEncScheme')
                error('Input encoder class must be an instance of a class inheriting from AbstEcnScheme.');
            end
            obj.encoding_scheme = EncoderInstance;
            %check if the amount of symbols in the alphabet is ower of 2
            if sum(dec2bin(length(obj.alphabet))=='1')~=1 
                error("The alphabet used in the SerDes must have a number of symbols that " + ...
                    "is a power of 2 (im waaaay to lazy to implement the generic solution)")
            end
            obj.bits_per_symbol = log2(length(obj.alphabet));
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
            bits_per_signal = obj.base.n_of_bases * obj.bits_per_symbol;
            words = zeros(height(full_signal), bits_per_signal);
            for word_i = 1:height(full_signal)
                words(word_i, :) = obj.unapply_base(words(word_i,:));
            end
            bits = obj.words_to_bits(words);
        end

        function play_signal(obj, signal)
            sound(signal, obj.base.sampling_frec)
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
                curr_bits = cat(2,dec2bin(word_length, length_indicator_length),bits(curr_bits_indexes));
                encoded_bits = obj.encoding_scheme.apply_scheme(curr_bits);
                words(row_i,:) = obj.group_into_word(encoded_bits);
            end
            %processes the last group of bits, adding padding to it
            remaining_bits = bits((data_length*(number_of_words-1)+1):end);
            last_group_length = length_indicator_length+length(remaining_bits);
            padded_bits = obj.add_padding(remaining_bits, '0', data_length);
            curr_bits = cat(2,dec2bin(last_group_length, length_indicator_length),padded_bits);
            encoded_bits = obj.encoding_scheme.apply_scheme(curr_bits);
            words(number_of_words,:) = obj.group_into_word(encoded_bits);
        end

        function word = group_into_word(obj, encoded_bits)
            % Takes as an argument an array of bytes. Returns an array of
            % symbols eg:[-1, 1, 3, -3] using the obj.alphabet
            % trows an error if the parity is wrong
            try
                groups = reshape(encoded_bits, [], obj.bits_per_symbol);
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
            
        end

        function bytes = decode_word(~, word)
            % Takes a received signal and uses the error corr to fix errors
            % and such. Does nothing for now. Will format bytes in the
            % future
            bytes = word;
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
    
    end


    methods(Static)
        function new_array = add_padding(og_array, padding_symbol, desired_length)
            new_array = blanks(desired_length);
            new_array(:) = padding_symbol;
            new_array(1,1:length(og_array)) = og_array;
        end

        function auto_test_base(Base)
            % Test the interface of a base to see if it acts as a valid
            % 'Base' class
            base = Base();
            try
                disp("N of symbols per word: "+base.n_of_bases)
                disp("CORRECT")
            catch ME
                disp("MISSING base.n_of_bases")
                disp(ME)
                return
            end
            try
                disp("Duration of signal per word: "+base.word_duration_t)
                disp("CORRECT")
            catch ME
                disp("MISSING base.word_duration_t")
                disp(ME)
                return
            end
            try
                disp("Duration of signal per word: "+base.sampling_frec)
                disp("CORRECT")
            catch ME
                disp("MISSING base.sampling_frec")
                disp(ME)
                return
            end
            try
                disp("Testing base.to_word / base.to_signal")
                test_word = randi(2, [1, base.n_of_bases]);
                signal = base.to_signal(test_word);
                resulted_word = base.from_signal(signal);
                if SerDes.get_n_of_matches(test_word, resulted_word) < base.n_of_bases
                    disp("when coverting from word to signal and then back to singal, the word changes." + ...
                        "Only "+SerDes.get_n_of_matches(test_word, resulted_word)+" out of "+base.n_of_bases+" symbols were correct" + ...
                        "INVALID BASE")
                    return
                end
                disp("CORRECT")
            catch ME
                disp("Somethiing went wrong when testing base.to_word / base.to_signal")
                rethrow(ME)
            end
            disp("ALL TESTS PASSED: VALID BASE")
        end
        
        function rate = get_word_correctness_rate(word1, word2)
            rate = SerDes.get_n_of_matches(word1, word2)/length(word1);
        end

        function n_of_matches = get_n_of_matches(word1, word2)
            if length(word1) ~= length(word2)
                error("The words provided are of different size")
            end
            n_of_matches = sum(abs(word1-word2)<0.001);
        end
    end
end

