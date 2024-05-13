classdef (Abstract) AbstSoundHeader < handle
    %ABSTBASE Abstract class defining the interface of a valid encoding
    %scheme
    %   Each property and method must have the behaviour/signature
    %   specified below:
    
    methods (Abstract, Access = public)
        play_header(obj)
        detect_header(obj, signal)
    end
end
