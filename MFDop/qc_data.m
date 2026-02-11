function [qc_corr, qc_amp, qc_phase,qc_u,qc_w] = qc_data(on_corr,on_amp,on_phase,on_u,on_w,cutoff)
% returns data where correlations are bigger than the cutoff percentage
    clear good_inds qc_amp qc_phase qc_corr qc_u qc_w

    % find inidcies where correlations are good
    good_inds = on_corr(:,:,:)>=cutoff;
    
    % intiialize arrays with nans
    qc_amp = nan(size(on_amp));
    qc_phase = nan(size(on_phase));
    qc_corr = nan(size(on_corr));
    qc_u = nan(size(on_u));
    qc_w = nan(size(on_w));
    
    % add in data fro when correlations are good
    qc_amp(good_inds) = on_amp(good_inds);
    qc_phase(good_inds) = on_phase(good_inds);
    qc_corr(good_inds) = on_corr(good_inds);
    qc_u(good_inds(1:end-1,:,3)) = on_u(good_inds(1:end-1,:,3));
    qc_w(good_inds(1:end-1,:,1)) = on_w(good_inds(1:end-1,:,1));
end


