classdef SineSoundHeader < AbstSoundHeader

    properties
        duration double
        padding_duration double
        frequency double
        header 

        % heredada de serdes
        sampling_frec double
    end
    methods
        
        function obj = SineSoundHeader(obj)
            obj.duration = 0.6;
            obj.padding_duration = 0.4;
            obj.sampling_frec = 8192;
            obj.frequency = 800;
            obj.header = obj.get_header();
        end

        function header = get_header(obj)
            t = 0:1/obj.sampling_frec:obj.duration;
            header = cat(2, 100*cos(2*pi*obj.frequency*t), zeros(1, ceil(obj.sampling_frec*obj.padding_duration)));
        end

        function play_header(obj)
            sound(obj.header, obj.sampling_frec)
        end
        
        % index es el ultimo indice del header, donde empieza el mensaje
        function message_start_index = detect_header(obj, signal)
            cor = xcorr(signal, obj.header);
            [~, cor_idx] = max(cor);
            message_start_index = cor_idx-ceil(length(cor)/2) + length(obj.header) + 1;
            
        end
    end

end