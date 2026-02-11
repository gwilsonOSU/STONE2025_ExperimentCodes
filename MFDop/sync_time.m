% load colorbars
load strbry_div.mat
load strbry_cont.mat

trial_name = 'f004_mobile_L1_R01'; % trial name for data
DD_file_start = '\DD.224.25.DragonDop.00000_'; % start of dragon dop file name

% extract data from files
[amp,corr,phase,time,r,u,w] = extract_mfdata(trial_name,DD_file_start,14.5);

% find times when wavemaker is started and when it ends, and data from when
% it is on
[start_time, end_time, on_time, on_corr, on_amp, on_phase, on_u, on_w] = wm_on_time(trial_name,amp,corr,phase,time,u,w,50);

% collect only data where correlations are above 60%
[qc_corr, qc_amp, qc_phase,qc_u,qc_w] = qc_data(on_corr,on_amp,on_phase,on_u,on_w,80);






%% calculate mean and std for vertical and horizontal velocities

mean_u = mean(abs(qc_u), 'all', 'omitnan');
mean_w = mean(abs(qc_w), 'all', 'omitnan');


std_u = std(qc_u, 0, 'all', 'omitnan');
std_w = std(qc_w, 0, 'all', 'omitnan');


terra_col = [
    0.2, 0.22, 0.2;
    0, 0.5, 0.3;
    0, 0.7, 0.6;
    0, 0.95, 0.8;
     1,    1,     0.91;
    0.95, 0.8, 0;
    0.85, 0.5, 0;
    0.7, 0.2, 0;
    0.4, 0.1, 0
];

arctic_col = [1,1,0.9;0.3,0.6,0.55;0.2, 0.1, 0.3];
arctic_col = flipud([
    0.00, 0.25, 0.00;
    0.00, 0.30, 0.30;
    0.25, 0.30, 0.50;
    0.50, 0.30, 0.50;
    0.80, 0.20, 0.20;
    0.70, 0.50, 0.00;
    0.65, 0.65, 0.40;
]);
terra_cont_col = [0.3,0,0.05;0.5,0.2,0.1; 0.3,0.55,0.1; 0.2,0.7,0.5;0,0.9,0.8;0.7,1,1];
arctic_col = flipud([
    0.00, 0.10, 0.00;
    0.00, 0.30, 0.20;
    0.50, 0.35, 0.70;
    0.90, 0.30, 0.90;
    1.00, 0.70, 0.50;
    1.00, 1.00, 0.90
]);

strbry_flds_frvr_div_col = [
    0.00, 0.125, 0.30;
    0.10, 0.35, 0.40;
    0.35, 0.60, 0.25;
    0.70, 0.80, 0.20;
    1, 1, 0.95;
    1.00, 0.60, 0.70;
    0.85, 0.30, 0.60;
    0.50, 0.10, 0.60;
    0.20, 0.00, 0.30
];

% Number of colors you want in the final colormap
N = 256;
% Positions of the original colors (normalized from 1 to N)
x_original = linspace(1, N, size(strbry_flds_frvr_div_col, 1));
% Positions to interpolate at (1 to N)
x_interp = 1:N;
% Preallocate for interpolated colors
strbry_div = zeros(N, 3);
% Interpolate each RGB channel separately using 'pchip' (shape-preserving)
for c = 1:3
    strbry_div(:, c) = interp1(x_original, strbry_flds_frvr_div_col(:, c), x_interp, 'pchip');
end

% Now colormap_interp is a Nx3 colormap MATLAB can use.
% Example: apply colormap to a figure
colormap(strbry_div);
colorbar;

%% plotting stacked velocities
index1 = on_time(on_time -min(on_time) <= 20);
index2 = on_time(on_time -min(on_time) >= 102);

start = length(index1);
% end_spot = length(on_time) - length(index2); % end at specified spot
end_spot = length(on_time)-2500; % end at the end

r_min = 0;
r_index1 = r(max(r)-r>=r_min);
r_end = length(r_index1);




figure
t = tiledlayout(2,1,"TileSpacing","compact","Padding","compact");
nexttile
pcolor(on_time(start:end_spot)-min(on_time),max(r)-r(1:r_end)-r_min,transpose(qc_u(start:end_spot,(1:r_end))))
shading flat
% caxis(cx_amp)
colormap(strbry_div);
caxis([-0.5 0.5])
% a=colorbar;
% a.Label.String = 'Velocity (m/s)';
% colorbar
axis tight
title(sprintf('Horizontal Velocity'),'Interpreter','none')
xlabel('Time (s)')
ylabel('Height (m)')
% set(gca,'ColorScale','log')

nexttile
pcolor(on_time(start:end_spot)-min(on_time),max(r)-r(1:r_end)-r_min,transpose(qc_w(start:end_spot,(1:r_end))))
shading flat
% caxis(cx_amp)
colormap(strbry_div);
caxis([-0.5 0.5])

% colorbar
axis tight
title(sprintf('Vertical Velocity'),'Interpreter','none')
xlabel('Time (s)')
ylabel('Height (m)')
% set(gca,'ColorScale','log')

% link axes in plot
ax = findall(gcf, 'type', 'axes');
linkaxes(ax,'xy')
set(gcf,'paperposition',[0 0 11 8.5])
cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = 'Velocity (m/s)';

title(t, trial_name,'interpreter','none');
%% plotting stacked amplitudes




figure
t = tiledlayout(1,1,"TileSpacing","compact","Padding","compact");
nexttile
pcolor(on_time(start:1:end_spot)-min(on_time),max(r)-r(1:r_end)-r_min,log10(transpose(on_amp(start:1:end_spot,(1:r_end),1).^2))); % no smoothing
% pcolor(on_time(start:1:end_spot)-min(on_time),max(r)-r,smoothdata2(log10(transpose(on_amp(start:1:end_spot,:,1).^2)),"movmean",2)); % smooothing
hold on
% [M,c] = contour(on_time(start:1:end_spot)-min(on_time),max(r)-r(50:133),smoothdata2(log10(transpose(on_amp(start:1:end_spot,50:133,1).^2)),"gaussian",20),4);
% set(c,'LineColor','white','LineWidth',0.01)
shading flat
% caxis(cx_amp)
colormap(flipud(strbry_cont))
% set(gca,'ColorScale','log')

% a=colorbar;
% a.Label.String = 'Velocity (m/s)';
% colorbar
axis tight
title(sprintf('Concentration Proxy'),'Interpreter','none')
xlabel('Time (s)')
ylabel('Height (m)')
% set(gca,'ColorScale','log')



% link axes in plot
ax = findall(gcf, 'type', 'axes');
linkaxes(ax,'xy')
set(gcf,'paperposition',[0 0 11 8.5])
cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = 'log10((Range*Amp)^2)';
caxis([-5 -1])

title(t, trial_name,'interpreter','none');
%% 

% axes limits
cx_phs=[-1 1]*3.14;
cx_amp=[0 .01];
cx_cor=[60 100];

% create figure with tiledlayout for plotting
figure;
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

% figure title is trial name
title(t,trial_name,'Interpreter','none','FontWeight','bold')

% titles for plots
plottitle = {'Aux1_H','Aux2'};

% loops through plots
for i=1:2

% define new variable ia to index arrays properly without aux1_L
if i == 1
    ia = 1;
elseif i==2
    ia = 3;
end

% plot amplitudes
nexttile
pcolor(on_time-min(on_time),max(r)-r,transpose(on_amp(:,:,ia)).^2)
shading flat
caxis(cx_amp)
colormap(terra_cont);
colorbar
axis tight
title(sprintf('%s Amplitude ^2', plottitle{i}),'Interpreter','none')
set(gca,'ColorScale','log')

% plot phases
nexttile
pcolor(on_time-min(on_time),max(r)-r,transpose(on_phase(:,:,ia)))
shading flat
caxis(cx_phs)
colormap(terra_cont);
colorbar
axis tight
title(sprintf('%s Phase', plottitle{i}),'Interpreter','none')

% plot correlations
nexttile
pcolor(on_time-min(on_time),max(r)-r,transpose(on_corr(:,:,ia)))
shading flat
caxis(cx_cor)
colormap(terra_cont);
colorbar
axis tight
title(sprintf('%s Correlation', plottitle{i}),'Interpreter','none')
end

% Column labels on the bottom
nexttile(4); xlabel('Time (s)');
nexttile(5); xlabel('Time (s)');
nexttile(6); xlabel('Time (s)');

% Row labels on the left side
nexttile(1); ylabel('Range (cm)');
nexttile(4); ylabel('Range (cm)');


% link axes in plot
ax = findall(gcf, 'type', 'axes');
linkaxes(ax,'xy')
set(gcf,'paperposition',[0 0 11 8.5])





%% Wave orbital calculation

function [u_orb, w_orb] = orb_vels(freq1,freq2,a1,a2,h,z)

    H = 2*(a1+a2);
    freq = (freq1+freq2)/2;

 
    omega = 2*pi*freq;
    g = 9.81;
    
    % dispersion relation
    % Initial guess: deep-water approximation
    k0 = omega / sqrt(g*h);
    
    % Define the dispersion function
    fun = @(k) omega^2 - g * k .* tanh(k * h);

    % fsolve options
    opts = optimoptions('fsolve','TolFun', 1e-12, 'TolX', 1e-12);
    
    % Solve using fsolve
    [k_sol, ~, exitflag] = fsolve(fun, k0, opts);



    u_orb = g*H*k_sol/2/omega*cosh(k_sol*(h+z))/cosh(k_sol*h);
    w_orb = H/2*omega*sinh(k_sol*(h+z))/sinh(k_sol*h);
end


[u_orb,w_orb] = orb_vels(0.5,0.43,0.07,0.07,0.4,-0.4);

%%  



%% get rid of correlations less than 60



% 
% % axes limits
% cx_phs=[-1 1]*3.14;
% cx_amp=[0 .01];
% cx_cor=[80 100];
% 
% % create figure with tiledlayout for plotting
% figure
% t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
% 
% % figure title is trial name
% title(t,trial_name,'Interpreter','none','FontWeight','bold')
% 
% % titles for plots
% plottitle = {'Aux1_H','Aux2'};
% 
% % loops through plots
% for i=1:2
% 
% % define new variable ia to index arrays properly without aux1_L
% if i == 1
%     ia = 1;
% elseif i==2
%     ia = 3;
% end
% 
% % plot amplitudes
% nexttile
% pcolor(on_time-min(on_time),max(r)-r,transpose(good_amp(:,:,ia)).^2)
% shading flat
% caxis(cx_amp)
% colorbar
% axis tight
% title(sprintf('%s Amplitude ^2', plottitle{i}),'Interpreter','none')
% set(gca,'ColorScale','log')
% 
% % plot phases
% nexttile
% pcolor(on_time-min(on_time),max(r)-r,transpose(good_phase(:,:,ia)))
% shading flat
% caxis(cx_phs)
% colorbar
% axis tight
% title(sprintf('%s Phase', plottitle{i}),'Interpreter','none')
% 
% % plot correlations
% nexttile
% pcolor(on_time-min(on_time),max(r)-r,transpose(good_corr(:,:,ia)))
% shading flat
% caxis(cx_cor)
% colorbar
% axis tight
% title(sprintf('%s Correlation', plottitle{i}),'Interpreter','none')
% end
% 
% % Column labels on the bottom
% nexttile(4); xlabel('Time (s)');
% nexttile(5); xlabel('Time (s)');
% nexttile(6); xlabel('Time (s)');
% 
% % Row labels on the left side
% nexttile(1); ylabel('Range (cm)');
% nexttile(4); ylabel('Range (cm)');
% 
% 
% % link axes in plot
% ax = findall(gcf, 'type', 'axes');
% linkaxes(ax,'xy')
% set(gcf,'paperposition',[0 0 11 8.5])



%% past scratch work


% % function that extracts amp, phase, cor, and timestamp
% % for aux1H, aux1L, aux2
% % concatenates all files for a trial
% function[phs,amp,cor,time,r] = extract_mfdata(trial_name,DD_file_start)
% 
%     clear phs amp cor time sphs samp scor stime
%     n=1;
% 
%     while true
%         % read in MF data and time sync data
%         mf_data = load(['Data\MFdata\',trial_name,DD_file_start,num2str(n),'.mat']);
% 
%         data = mf_data;
%         % concatenate data struct-array
%         clear p a c timestamp slant_timestamp
% 
% 
%         % extract vert and slant ensembles
%         vert_ensemble = data.Data.DragonDop1_Ensemble;
%         slant_ensemble = data.Data.DragonDop2_Ensemble;
% 
%         min(vert_ensemble) - min(slant_ensemble)
%         max(vert_ensemble) - max(slant_ensemble)
% 
%         % find start and end ensemble numbers featured in both
%         start_ensemble = max(min(slant_ensemble),min(vert_ensemble));
%         end_ensemble = min(max(slant_ensemble),max(vert_ensemble));
% 
%         % find indices between these ensembles
%         slant_inds = slant_ensemble >= start_ensemble & slant_ensemble <= end_ensemble;
%         vert_inds = vert_ensemble >= start_ensemble & vert_ensemble <= end_ensemble;
% 
%         % p(:,:,1)=data.Data.DragonDop1_Phase_Aux_1H_1600kHz;
%         % a(:,:,1)=data.Data.DragonDop1_Amp_Aux_1H_1600kHz ...
%         %        .*data.Data.DragonDop1_Range;
%         % c(:,:,1)=data.Data.DragonDop1_Cor_Aux_1H_1600kHz;
%         % p(:,:,2)=data.Data.DragonDop1_Phase_Aux_1L_1600kHz;
%         % a(:,:,2)=data.Data.DragonDop1_Amp_Aux_1L_1600kHz ...
%         %        .*data.Data.DragonDop1_Range;
%         % c(:,:,2)=data.Data.DragonDop1_Cor_Aux_1L_1600kHz;
%         % timestamp = data.Data.DragonDop1_TimeStamp;
%         % 
%         % % interpolate slant beam onto vert beam timestamp
%         % slant_timestamp = data.Data.DragonDop2_TimeStamp;
%         % p(:,:,3)=interp1(slant_timestamp,data.Data.DragonDop2_Phase_Aux_2_1600kHz,timestamp);
%         % a(:,:,3)=interp1(slant_timestamp,data.Data.DragonDop2_Amp_Aux_2_1600kHz,timestamp) ...
%         %        .*data.Data.DragonDop2_Range;
%         % c(:,:,3)=interp1(slant_timestamp,data.Data.DragonDop2_Cor_Aux_2_1600kHz,timestamp);
% 
%         % 
%         % % concatenate all data
%         % if(n==1)
%         %     phs=p;
%         %     amp=a;
%         %     cor=c;
%         %     time = timestamp;
%         % 
%         % else
%         %     phs=cat(1,phs,p);
%         %     amp=cat(1,amp,a);
%         %     cor=cat(1,cor,c);
%         %     time = cat(1,time,timestamp);
% 
%         % end
%         r = data.Data.DragonDop2_Range;
%         if exist(['Data\MFdata\',trial_name,DD_file_start,num2str(n+1),'.mat'])
%             n = n+1;
%         else
%             break
%         end
%     end
% end



% % end
% % [nt,nr,nb]=size(amp);
% % 
% % % define time and range for all variables
% % r=data(1).Data.DragonDop2_Range;
% % dt=diff(data(1).Data.DragonDop2_TimeStamp(1:2));
% % t=([1:nt]-1)*dt;
% % 
% % % plotting params
% % cx_phs=[-1 1]*3.14;
% % cx_amp=[0 .01];
% % cx_cor=[40 100];
% % 
% % % plots
% % beamname = {'Vertical Beam','Slant Beam'};
% % for beam=1:2
% %   subplot(3,2,0+beam)  % amp
% %   pcolor(t,r,amp(:,:,beam)'.^2), shading flat
% %   caxis(cx_amp)
% %   title(['(Range*Amp)^2 (Concentration Proxy), ' beamname{beam}])
% %   subplot(3,2,2+beam)  % phase
% %   pcolor(t,r,phs(:,:,beam)'),shading flat
% %   caxis(cx_phs)
% %   title(['Phase (Velocity Proxy), ' beamname{beam}])
% %   subplot(3,2,4+beam)  % cor
% %   pcolor(t,r,cor(:,:,beam)'),shading flat
% %   caxis(cx_cor)
% %   title(['Correlation (Velocity Quality), ' beamname{beam}])
% %   for i=[0 2 4]
% %     subplot(3,2,i+beam)
% %     colorbar
% %     xlabel('Time [sec]')
% %     ylabel('Range [m]')
% %     set(gca,'ydir','rev')
% %   end  
% % end
% % ax = findall(gcf, 'type', 'axes');
% % linkaxes(ax,'xy')
% % set(gcf,'paperposition',[0 0 11 8.5])
% % 
% % 
% % 
