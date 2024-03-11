classdef (Abstract) AbstBase < handle
    %ABSTBASE Abstract class defining the interface of a valid Base
    %   Each property and method must have the behaviour/signature
    %   specified below:
    
    properties (Abstract)
        n_of_bases double
        word_duration_t double
        sampling_frec double
    end
    
    methods (Abstract)
        to_signal(obj, word)
        from_signal(obj, signal)
    end
end

