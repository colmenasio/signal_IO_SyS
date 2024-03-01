fs = 8192;
t = 0:1/fs:5;
n = 256*2;
wi = (n)*pi/5;
Ai = sqrt(2/5);
Base_ortonormal = zeros(256,40961);
for i=1:256
    Base_ortonormal(i,:) = Sin_printer(t,wi(i),Ai);
end

%%
text = 'awer';
text2 = "aodnaend";
cosa = char(text2);
data_matrix2 = dec2bin( cosa , 8);
done_data = reshape(data_matrix2, 1, []);
a = double(done_data)*2-97;
%%
done_data = De_bin_a_unos(data_string);
signal = done_data * Base_ortonormal;

sound(signal, fs)

%%






function Seno = Sin_printer(t,wi,Ai)
%     Seno_we = sin(wi*t);
%     Seno = Seno_we/sqrt(trapz(Seno_we));
      Seno = Ai*sin(wi*t);
end
function data_string = concatenate(data)
    [n,m]=size(data);
    data_string = [data(1,:), data(2,:)];
    for j = 3:n
        data_string = [data_string,data(j,:)];
    end
end
function done_data = De_bin_a_unos(reshaped_data)
    done_data = zeros(1,length(reshaped_data));
    for j=1:length(reshaped_data)
        done_data(j) = str2num(reshaped_data(j)).*2-1;
    end
    if length(reshaped_data)>256
        error('mensaje demasiado largo')
    end
    null_vector = -ones(1,256-length(reshaped_data));
    done_data = [done_data,null_vector];
end