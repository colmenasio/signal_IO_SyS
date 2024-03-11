classdef NoneEncScheme < AbstEncScheme
    %ABSTBASE Concrete class acting as a placeholder for an encoding
    %scheme. The encoded word is the same as the plantext word
    
    properties
        next_layer
    end
    
    methods
        function obj = NoneEncScheme()
            obj.next_layer = 0;
        end
    end

    methods 
        function input_word_length = get_data_length_in_word(~, desired_length_bits) 
            %gets how many bits long should a plaintext word be so that the encoded word is of length "desired_word_bits"
            warning("The NoneEncScheme is being used. It is only meant as a placeholder and shouldt be used")
            input_word_length = desired_length_bits;
        end
        function encoded_word = apply_scheme(~, plaintext_word)
            warning("The NoneEncScheme is being used. It is only meant as a placeholder and shouldt be used")
            encoded_word = plaintext_word;
        end
        function plaintext_word = unapply_scheme(~, encoded_word)
            warning("The NoneEncScheme is being used. It is only meant as a placeholder and shouldt be used")
            plaintext_word = encoded_word;
        end
    end

    methods (Access = protected)
        function get_data_length_in_word_current(~, ~)
            error("NoneEncScheme has no 'current' methods")
        end
        function apply_current_scheme(~, ~)
            error("NoneEncScheme has no 'current' methods")
        end
        function unapply_current_scheme(~, ~)
            error("NoneEncScheme has no 'current' methods")
        end
    end
end

