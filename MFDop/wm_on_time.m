function [start_time, end_time, on_time, on_corr, on_amp, on_phase,on_u,on_w] = wm_on_time(trial_name,amp,corr,phase,time,u,w,offset_time)
% given the wavemaker sync data, returns times when the wavemaker
% is started and ends. can handle multple wms files
% returns data in arrays for when time is on
% offset_time is delay from time wavemaker turns off until approximate time
% last wave reaches the instrument (50s seems good)
    n=0;
    clear wms_time

    while true
        % load in data from wms file
        wms_data = load(['wms\',trial_name,'\wms_mf_',num2str(n),'.dat']);
        
        % extract time and voltage data
        t = wms_data(:,1);
        v = wms_data(:,2);


        % concatenate all data
        if(n==0)
            wms_time = t;
            voltage = v;
        else
            wms_time = cat(1,wms_time,t);
            voltage = cat(1,voltage,v);
        end

        % if there is more than one wms file, keep cycling through them
        if exist(['Data\wms\',trial_name,'\wms_mf_',num2str(n+1),'.dat'])
            n = n+1;
        else
            break
        end

      
    end

    % convert from 1904 to 1970 epoch
    wms_time = wms_time  -2082844800;

    % find when voltage becomes large
    on_inds = voltage>=4.7;

    % record voltages and times when wavemaker is on
    start_time = min(wms_time(on_inds));
    end_time = max(wms_time(on_inds));


    % find timestamps from mfdop when the wavemaker is on
    on_inds = time >= start_time & time <= end_time+offset_time;

    % find variables when wavemaker is on
    on_time = time(on_inds);
    on_corr = corr(on_inds,:,:);
    on_amp = amp(on_inds,:,:);
    on_phase = phase(on_inds,:,:);
    on_u = u(on_inds(1:end-1),:);
    on_w = w(on_inds(1:end-1),:);


end