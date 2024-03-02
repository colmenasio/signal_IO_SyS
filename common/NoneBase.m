classdef NoneBase < AbstBase
    %BASENONE Placeholder AbstBase child class.
    % No purpose other than being a placeholder, defined methods have no
    % functionality, only the bare minimum to pass as a valid base
    
    properties
        n_of_bases double 
        word_duration_t double
        sampling_frec double
    end
    
    methods
        function obj = NoneBase()
        end


        function signal = to_signal(~, word)
            warning("The NoneBase is being used. It is only meant as a placeholder and shouldt be used")
            signal = word;
        end
        
        function word = from_signal(~, signal)
            warning("The NoneBase is being used. It is only meant as a placeholder and shouldt be used")
            word = signal;
        end
    end
end

