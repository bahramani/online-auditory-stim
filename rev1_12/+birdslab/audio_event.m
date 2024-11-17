classdef audio_event < handle
    
    properties
        id
        nof_trigs = 0
        player
        duration

        detector_samples
    end
    
    methods
        function obj = audio_event(id, file_name, detector_fs)
            obj.id = id;
            [y, fs] = audioread(file_name);
            
            gc = gcd(fs, detector_fs);
            obj.detector_samples = resample(y, detector_fs/gc, fs/gc);
            obj.player = audioplayer(y, fs);
            obj.duration = obj.player.TotalSamples/obj.player.SampleRate;
        end
        
        function play(obj, add)
            if (add)
                obj.nof_trigs = obj.nof_trigs + 1;
            end
            obj.player.play();
        end

        function res = to_string(obj)
            res = sprintf('%d, %d', obj.id, obj.nof_trigs);
        end
    end
end

