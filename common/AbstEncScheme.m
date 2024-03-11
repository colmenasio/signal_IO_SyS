classdef (Abstract) AbstEncScheme < handle
    %ABSTBASE Abstract class defining the interface of a valid encoding
    %scheme
    %   Each property and method must have the behaviour/signature
    %   specified below:
    
    properties (Abstract) 
        next_layer
    end
    
    methods
        function data_bits_length = get_data_length_in_word(obj, desired_length_bits)
            if isa(obj.next_layer, "AbstEncScheme")
                desired_length_bits = obj.next_layer.get_data_length_in_word(desired_length_bits);
            end
            data_bits_length = obj.get_data_length_in_word_current(desired_length_bits);
        end

        function encoded_word = apply_scheme(obj, plaintext_word)
            encoded_word = obj.apply_current_scheme(plaintext_word);
            % if obj.get_data_length_in_word(length(encoded_word)) ~=
            %   length(plaintext) -> something went wrong with the encoding
            if isa(obj.next_layer, "AbstEncScheme")
                encoded_word = obj.next_layer.apply_scheme(encoded_word);
            end
        end

        function plaintext_word = unapply_scheme(obj, encoded_word)
            if isa(obj.next_layer, "AbstEncScheme")
                encoded_word = obj.next_layer.unapply_scheme(encoded_word);
            end
            plaintext_word = obj.unapply_current_scheme(encoded_word);
            % if obj.get_data_length_in_word(length(encoded_word)) ~=
            %   length(plaintext) -> something went wrong with the encoding
        end
        
    end
    methods (Abstract, Access = protected)
        get_data_length_in_word_current(obj, desired_length_bits) 
        %gets how many bits long should a plaintext word be so that the encoded word is of length "desired_word_bits"
        %for example, if in a 256-bit word this enconding scheme has 10
        %redundancy bits, leaving 246 bits for information, then this
        %function would return 246.
        apply_current_scheme(obj, plaintext_word)
        unapply_current_scheme(obj, encoded_word)
    end
end



