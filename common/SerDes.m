classdef SerDes
    %SERDES Serializer-Deserializer. Singleton.
    %   Handles the interaction between user and ortonormal base, acting as an
    %   interface of sorts
    
    properties
        word_length
        bits_per_symbol
        base
    end
    
    methods
        function obj = SerDes()
            %SERDES Builder. Does nothing for now
            obj.word_length = 256;
            obj.bits_per_symbol = 1;
            obj.base = BaseSines();
        end

        function word = encode_bytes(obj, bytes, padding)
            % Takes an array of bytes. Applies error correnction, etc and returns 
            % the word ready to be turned into a signal. Returns words of
            % length obj.word_length
            % aqui aplicariamos la correccion de errores y shannon y tal
            word = obj.add_padding(bytes, padding, obj.word_length);
        end

        function bytes = decode_word(~, word)
            % Takes a received signal and uses the error corr to fix errors
            % and such. Does nothing for now. Will format bytes in the
            % future
            bytes = word;
        end
        
        function word = encode_str(obj, raw_str)
            %expect less than 256 bits, placeholder. felipe we have to fix this asap
            char_matrix = dec2bin(char(raw_str), 8);
            data_string = reshape(char_matrix, 1, []);
            symbols = double(data_string)*2-97;
            word = obj.encode_bytes(symbols, -1);
        end
        
        function signal = apply_base(obj, word)
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
            new_array = zeros(1, desired_length);
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
                        "Only "+obj.get_n_of_matches(test_word, resulted_word)+" out of "+base.n_of_bases+" symbols were correct" + ...
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
        
        function rate = SerDes.get_word_correctness_rate(word1, word2)
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

