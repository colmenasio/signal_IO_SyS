classdef NoneSoundHeader < AbstSoundHeader
    methods
        function obj = NoneSoundHeader()
            warning("Sound header not specified")
        end
        function play_header(obj)
            %Play the header sound
        end
        function start_time = listen_header(obj, signal)
            %Detect when the header occurs in a signal
        end
    end
end