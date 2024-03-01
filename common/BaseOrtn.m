classdef BaseOrtn
    % Singleton class containing the ortonormal base of sin functions
    %   Detailed explanation goes here
    
    properties
        CONFIG_PATH
        base_samples
        MAX_FREQ
        MIN_FREQ
        n_of_bases
        word_duration_t
    end
    
    methods
        function obj = BaseOrtn(varargin)
            %BASE_ORTN Construct an instance of this class based on the
            %configs in "root/configs/base_ortn.json"
            %   Optionally an alternative path can be specificied
            
            if isempty(varargin)
                obj.CONFIG_PATH = "../configs/base_ortn.json";
            else
                obj.CONFIG_PATH = varargin{1};
            end

            try
                fid = fopen(obj.CONFIG_PATH);
                str = char(fread(fid,inf)'); 
                fclose(fid); 
                val = jsondecode(str);
            catch ME
                disp("base_ortn.json NOT FOUND IN "+obj.CONFIG_PATH)
                disp(ME)
                return
            end
            %disp(val)
            obj.base_samples = zeros()

        end
        
        function outputArg = method1(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.CONFIG_PATH;
        end
    end

    methods(Static)
        function seno = sin_printer(t_sec, frec_muest, frec_sin ,ampl_sin)
            % Creates a sin sample array elapsing t seconds, with specific sample frec, at a specified
            % frecuency
            t_array = 0:1/frec_muest:t_sec;
            seno = ampl_sin*sin(2*pi*frec_sin*t_array);
        end
    end
end

