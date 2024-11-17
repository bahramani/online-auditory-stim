classdef event_detector < handle    
    properties
        played_event
        buffer
        buffer_ts
        fs
        T
        audio_ch
        neurl_ch
        det_lag
%         psth
        ready_to_detect
        
        pending_log

        detection_callback

        colors = [0,  0,  0;
                  255, 96, 208; % pink - first neuron 2
                  0, 240, 240; % cyan 3
                  250, 250, 0; % yellow 4
                  250, 0, 250; % magenta 5
                  0, 250, 0]; % green 6
                                      
    end
    methods
        function obj = event_detector(fs, audio_channel, neural_channel, det_lag, ev_det_cb)
            obj.buffer    = dsp.AsyncBuffer(fs*(det_lag + 10));
            obj.buffer_ts = dsp.AsyncBuffer(fs*(det_lag + 10));
            obj.fs = fs;
            obj.T = 1/fs;
            obj.audio_ch = audio_channel;
            obj.neurl_ch = neural_channel;
            obj.det_lag = det_lag;            
%             obj.psth = psth;
            obj.colors = obj.colors/255;
            obj.ready_to_detect = false;
            obj.detection_callback = ev_det_cb;
            obj.pending_log = '';
        end

        function set_last_event(obj, played_event, pending_log)
% %             assert(obj.is_event_totally_finished == false, 'obj.is_event_totally_finished == false');
%             obj.is_event_totally_finished = true;
            obj.played_event = played_event;
            obj.pending_log = pending_log;
            obj.buffer.reset();
            obj.buffer_ts.reset();
            obj.ready_to_detect = true;
        end

        function res = step(obj, data, counter)
            channels = cell2mat(data(:, 1));
            ind = find(channels == obj.audio_ch);
            if (isempty(ind))
                error('Audio channel is empty - You must select correct channel in BLCKRCK Central');
            end
            [~, fs_, samples] = data{ind, :};
            assert(fs_ == obj.fs, 'Audio Channel fs is wrong');

            ind = find(channels == obj.neurl_ch);
            if (isempty(ind))
                error('Neural channel is empty - You must select correct channel in BLCKRCK Central');
            end
            [~, fs_, samples2] = data{ind, :};
            assert(fs_ == obj.fs, 'Neural Channel fs is wrong');
            
            assert(length(samples2) == length(samples), 'Two continuous channels length mismatch')
            
            ts = (counter+1):(counter+length(samples));
            obj.buffer.write(samples);
            obj.buffer_ts.write(ts');
            if (obj.ready_to_detect)
                if (obj.buffer.NumUnreadSamples/obj.fs > obj.det_lag)
                    obj.detect();
                end
            end
            res = counter + length(samples);
        end

        function detect(obj)
            x = obj.buffer.read(obj.buffer.NumUnreadSamples);
            ts = obj.buffer_ts.read(obj.buffer_ts.NumUnreadSamples);
            [r, lags] = xcorr(x, obj.played_event.detector_samples);
            [~, ind] = max(r);
            
%             figure; plot(x);
%             xline(lags(ind), 'color', 'r');
            

%             figure;
%             plot(ts, x);
%             
%             for i = 1:6
%                 ind = obj.psth.spikes_history(2, :) == i;
%                 if (any(ind))
%                     xline(obj.psth.spikes_history(1, ind), 'Color', obj.colors(i, :));
%                     hold on;
%                 end
%             end
% 
%             xlim([min(ts), max(ts)]);

            obj.buffer.reset();
            obj.buffer_ts.reset();
            obj.ready_to_detect = false;
            obj.detection_callback(obj.played_event.id,...
                double(ts(1) + lags(ind)), obj.pending_log);
%             obj.actual_time = ts(1) + lags(ind);
        end
    end
end