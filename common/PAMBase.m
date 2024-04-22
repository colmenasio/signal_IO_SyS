classdef PAMBase < AbstBase
    % Singleton class containing the ortonormal base of sin functions
    %   The current approach is shit, instead of storing the samples of
    %   bases, its better to generate them at runtime on request
    
    properties
        CONFIG_PATH string
        
        MAX_FREQ double
        MIN_FREQ double
        n_of_bases double 
        word_duration_t double
        sampling_frec double
        carrier_frequency double
        time_axis
        base_samples
    end
    
    methods



        function obj = PAMBase(varargin)
            %BASEORTN Construct an instance of this class based on the
            %configs in "root/configs/base_sines.json"
            %   Optionally an alternative path can be specificied
            
            disp("--> INITIALIZING PAMBase")
            if isempty(varargin)
                obj.CONFIG_PATH = "configs/PAM_base.json";
            else
                obj.CONFIG_PATH = varargin{1};
            end
            try
                obj.load_configs();
                obj.validate_configs();
                obj.initilize_bases();
%                 obj.disp_summary();
                warning("TODO: implement summary")
            catch ME
                switch ME.identifier
                    case 'MATLAB:FileIO:InvalidFid'
                        disp("base_ortn.json NOT FOUND IN "+obj.CONFIG_PATH)
                    case 'MATLAB:nonExistentField'
                        disp("base_ortn.json WAS MISSING SOME FIELDS")
                    otherwise
                        rethrow(ME)
                end
                disp(ME)
                return
            end
            %disp(val)
        end
        
        function bw = get_bandwidth(obj)
            bw = obj.MAX_FREQ-obj.MIN_FREQ;
        end

        function n_max = get_max_n_of_bases_in_bw(obj)
            warning("get_max_n_of_bases_in_bw not inolemented correctly")
            %Compute how many bases can fit withing the badwidth of the 
            % bases with the current values of the parameters of obj
            n_max = 2*obj.get_bandwidth*obj.word_duration_t-1;
        end


        function obj = load_configs(obj)
            %LOAD_CONFIGS In-place load of the configs in obj.CONFIG_PATH
            %Excepts MATLAB:nonExistentField
            fid = fopen(obj.CONFIG_PATH);
            str = char(fread(fid,inf)'); 
            fclose(fid); 
            val = jsondecode(str);

            obj.MAX_FREQ = floor(val.MAX_FREQ);
            obj.MIN_FREQ = ceil(val.MIN_FREQ);
            obj.n_of_bases = val.n_of_bases;
            obj.sampling_frec = val.sampling_frec;
            obj.word_duration_t = val.word_duration_t;
            obj.carrier_frequency = val.carrier_frec;
            disp("--> LOADED base_ortn.json CORRECTLY")
        end

        function validate_configs(obj)
            positive_bw = obj.MAX_FREQ > obj.MIN_FREQ;
            satisfies_nilquist = obj.MAX_FREQ < 2*obj.sampling_frec;
            if ~positive_bw
                error("ERROR WHEN LOADING CONFIGS IN PAMBase; INVALID BANDWIDTH; max_freq < min_freq")
            end
            if ~satisfies_nilquist
                error("ERROR: with the current settings in sines_base, nilqist is not satisfied."+newline+ ...
                    "The base may produce singals with aliasing")
            end
        end
        
        function obj = initilize_bases(obj)
            %INITIALIZE_BASES In-place initilizes the bases according to the
            % parameters of obj
            %   The bases are stored in obj.base_samples
            if obj.get_max_n_of_bases_in_bw()<obj.n_of_bases
                error("BaseOrtn:bases_dont_fit_in_bw", "The bandwith is too small to fit that many bases")
            end
            
            obj.base_samples =  zeros(obj.n_of_bases, obj.word_duration_t * obj.sampling_frec);
            obj.time_axis = (0:(obj.word_duration_t * obj.sampling_frec)-1)/obj.sampling_frec;

            for row_i=1:obj.n_of_bases
                obj.base_samples(row_i,:)=sqrt(2*get_bandwidth(obj))*sinc(get_bandwidth(obj)*obj.time_axis-(row_i+99)).*cos(2*pi*obj.carrier_frequency*obj.time_axis);
            end
        end
        
        function signal = to_signal(obj, word) 
            signal = word * obj.base_samples;
        end

        function word = from_signal(obj, signal)
            % Takes the samples of a signal and calculates the components of said 
            % signal over the current ortonormal base
            % Returns an array of reals (the components)
            word = zeros(1, obj.n_of_bases);
            for i = 1:obj.n_of_bases
                word(1, i) = obj.prod_esc(signal, obj.base_samples(i, :));
            end
        end

        function result = prod_esc(obj, signal1, signal2)
            if length(signal1) ~= length(signal2)
                error("BaseOrtn:InvalidSignal", "Cannot do the scalar product of two different sized signals")
            end
            result = trapz(1/obj.sampling_frec, signal1.*signal2);
        end
    end
end