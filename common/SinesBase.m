classdef SinesBase < AbstBase
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

        base_samples
    end
    
    methods
        function obj = SinesBase(varargin)
            %BASEORTN Construct an instance of this class based on the
            %configs in "root/configs/base_sines.json"
            %   Optionally an alternative path can be specificied
            
            disp("INITIALIZING SinesBase")
            if isempty(varargin)
                obj.CONFIG_PATH = "configs/sines_base.json";
            else
                obj.CONFIG_PATH = varargin{1};
            end
            try
                obj.load_configs();
                obj.initilize_bases();
                obj.disp_summary();
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
            disp("LOADED base_ortn.json CORRECTLY")
        end
        
        function obj = initilize_bases(obj)
            %INITIALIZE_BASES In-place initilizes the bases according to the
            %parameters of obj
            %   The bases are stored in obj.base_samples
            if obj.get_max_n_of_bases_in_bw()<obj.n_of_bases
                error("BaseOrtn:bases_dont_fit_in_bw", "The bandwith is too small to fit that many bases")
            end
            obj.base_samples =  zeros(obj.n_of_bases, obj.word_duration_t * obj.sampling_frec);
            frec_step = 1/(2*obj.word_duration_t);
            frecuencies = obj.MIN_FREQ+(0:frec_step:(obj.n_of_bases-1)/(2*obj.word_duration_t));
            A = obj.get_amplitude();
            for i=1:obj.n_of_bases
                obj.base_samples(i,:) = obj.sin_printer(obj.word_duration_t, obj.sampling_frec, frecuencies(i), A);
            end
        end

        function bw = get_badwidth(obj)
            bw = obj.MAX_FREQ-obj.MIN_FREQ;
        end

        function n_max = get_max_n_of_bases_in_bw(obj)
            %Compute how many bases can fit withing the badwidth of the 
            % bases with the current values of the parameters of obj
            n_max = 2*obj.get_badwidth*obj.word_duration_t-1;
        end

        function A = get_amplitude(obj)
            %Compute the amplitude the sins of the base should have.
            A = sqrt(2/obj.word_duration_t);
        end

        function signal = to_signal(obj, word)
            signal = obj.old_arcaic_shitty_to_signal(word);

        end

        function encoded_message = old_arcaic_shitty_to_signal(obj, word)
            encoded_message = word * obj.base_samples;
        end

        function word = from_signal(obj, signal)
            word = old_arcaic_shitty_from_signal(obj, signal);
        end

        function word = old_arcaic_shitty_from_signal(obj, signal)
            %decoded_bytes = rowfun(extract_compon, obj.base_samples, 'SeparateInputs ', false);
            word = zeros(1, obj.n_of_bases);
            for i = 1:obj.n_of_bases
                %esto es horrible pero rowfun no funciona so...
                word(1, i) = obj.prod_esc(signal, obj.base_samples(i, :));
            end
        end

        function result = prod_esc(obj, signal1, signal2)
            if length(signal1) ~= length(signal2)
                error("BaseOrtn:InvalidSignal", "Cannot do the scalar product of two different sized signals")
            end
            result = trapz(1/obj.sampling_frec, signal1.*signal2);
        end

        function disp_summary(obj)
            disp("BaseSines Summary:")
            disp("Bandwidth: "+obj.get_badwidth()+ "Hz")
            disp("Used "+obj.n_of_bases+" out of "+obj.get_max_n_of_bases_in_bw()+" bases available in current bandwidth")
            disp("fs : "+obj.sampling_frec+", word duration: "+obj.word_duration_t)
        end
    end

    methods(Static)
        function seno = sin_printer(t_sec, frec_muest, frec_sin ,ampl_sin)
            % Creates a sin sample array elapsing t seconds, with specific sample frec, at a specified
            % frecuency
            n_array = 0:(t_sec*frec_muest-1);
            seno = ampl_sin*sin(2*pi*frec_sin*n_array/frec_muest);
        end
    end
end

