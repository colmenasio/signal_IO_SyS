classdef BaseOrtn
    % Singleton class containing the ortonormal base of sin functions
    %   Detailed explanation goes here
    
    properties
        Property1
    end
    
    methods
        function obj = BaseOrtn(varargin)
            %BASE_ORTN Construct an instance of this class based on the
            %configs in "root/configs/base_ortn"
            %   
            obj.Property1 = inputArg1 + inputArg2;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

