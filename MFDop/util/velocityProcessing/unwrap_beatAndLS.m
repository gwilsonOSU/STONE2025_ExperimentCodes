function [PHI_unwrapped, Vhat, vstd, iters, dbg] = unwrap_beatAndLS_optimized(PHI, F, tau, c, correl, v_bounds, opts)
% UNWRAP_BEATANDLS_OPTIMIZED  Memory-optimized parallel version
% Same interface as unwrap_beatAndLS but optimized for parallel execution
% with minimal memory copying to workers

  if nargin<7, opts=struct; end
  if ~isfield(opts,'kappa'),      opts.kappa=1.345; end
  if ~isfield(opts,'max_iter'),   opts.max_iter=12; end
  if ~isfield(opts,'tol'),        opts.tol=1e-6; end
  if ~isfield(opts,'min_correl'), opts.min_correl=40; end
  if ~isfield(opts,'max_w'),      opts.max_w=1/(1e-3^2); end
  if ~isfield(opts,'median3x3'),  opts.median3x3=false; end
  if ~isfield(opts,'use_huber'),  opts.use_huber=true; end
  if ~isfield(opts,'hybrid_mode'), opts.hybrid_mode=false; end
  if ~isfield(opts,'despike_hf'), opts.despike_hf=false; end
  if ~isfield(opts,'despike_pass1_thresh'), opts.despike_pass1_thresh=1.2; end
  if ~isfield(opts,'despike_pass2_thresh'), opts.despike_pass2_thresh=0.6; end
  if ~isfield(opts,'despike_force_thresh'), opts.despike_force_thresh=0.4; end

  % Handle case where B=1 (singleton beam dimension may be missing)
  if ndims(PHI) == 3
      PHI = PHI(:,:,:,1);
  end
  [R,T,M,B] = size(PHI);
  F = F(:).';

  % Pre-compute ALL shared constants (these will be broadcast to workers)
  alpha = 4*pi*tau/c;
  V_i = (c ./ (2 * F * tau));        % 1 x M
  K = reshape(c ./ (4*pi*tau*F), 1,1,M,1);  % [1 1 M 1]
  Fgrid = reshape(F, 1,1,M,1);
  Vi_reshaped = reshape(V_i, 1,1,M);
  K_vec = c ./ (4*pi*tau*F);         % 1 x M vector for efficiency

  % Frequency indices
  [~, idxSort] = sort(F, 'ascend');
  iL = idxSort(1); iM = idxSort(2); iH = idxSort(3);

  % Correlation handling
  if isempty(correl)
      correl = 100*ones(1,1,M,1, 'like', PHI);
  end
  if ndims(correl) == 3 && B == 1
      correl = correl(:,:,:,1);
  end
  correl = min(100, max(1, correl));

  % Pre-compute correlation-derived quantities
  invalid_pixels = correl(:,:,end,:) < opts.min_correl;
  phsstd = sqrt(-2*log(correl/100));
  sigv = bsxfun(@times, phsstd, K);
  W0 = 1 ./ max(sigv.^2, eps('like',PHI));
  W0 = min(W0, opts.max_w);
  vtilde = bsxfun(@times, PHI, K);
  E = exp(1j*PHI);

  % Helper function (defined as variable for parfor)
  wrapV = @(x,Vi) mod(x + Vi/2, Vi) - Vi/2;

  % Pre-allocate outputs
  PHI_unwrapped = zeros(R,T,M,B, 'like', PHI);
  Vhat = zeros(R,T,B, 'like', PHI);
  vstd = zeros(R,T,B, 'like', PHI);
  iters = zeros(R,T,B, 'like', PHI);

  % MAIN PARALLEL LOOP - properly scoped variables
  parfor b = 1:B
      % Extract beam-specific data (parfor can handle simple array slicing)
      PHI_b = PHI(:,:,:,b);           % R x T x M
      W0_b = W0(:,:,:,b);             % R x T x M
      vtilde_b = vtilde(:,:,:,b);     % R x T x M
      sigv_b = sigv(:,:,:,b);         % R x T x M
      E_b = E(:,:,:,b);               % R x T x M
      invalid_pixels_b = invalid_pixels(:,:,b);  % R x T

      % Beat frequency seeds
      phiL = PHI_b(:,:,iL);
      phiM = PHI_b(:,:,iM);
      phiH = PHI_b(:,:,iH);
      dphi_HM = mod(phiH - phiM + pi, 2*pi) - pi;
      dphi_HL = mod(phiH - phiL + pi, 2*pi) - pi;

      v_seed_HM = (c/(4*pi*tau)) * (dphi_HM / (F(iH)-F(iM)));
      v_seed_HL = (c/(4*pi*tau)) * (dphi_HL / (F(iH)-F(iL)));

      % Choose better seed (inline to avoid function call issues in parfor)
      VphaseA = exp(-1j * (alpha * bsxfun(@times, v_seed_HM, Fgrid)));
      VphaseB = exp(-1j * (alpha * bsxfun(@times, v_seed_HL, Fgrid)));
      Sa = sum((W0_b .* E_b) .* VphaseA, 3);
      Sb = sum((W0_b .* E_b) .* VphaseB, 3);
      chooseA = abs(Sa) >= abs(Sb);
      v = v_seed_HL;
      v(chooseA) = v_seed_HM(chooseA);

      % IRLS iterations
      W_final = W0_b; % Initialize
      final_iter = 1;

      for iter = 1:opts.max_iter
          % Vectorized residual calculation
          r = wrapV(bsxfun(@minus, v, vtilde_b), Vi_reshaped);

          % Huber weights
          if opts.use_huber
              z = r ./ max(sigv_b, eps(class(r)));
              u = min(1, opts.kappa ./ max(abs(z), eps(class(z))));
              W = W0_b .* u;
          else
              W = W0_b;
          end

          % Weighted least squares update
          vunw = v - r;
          num = sum(W .* vunw, 3);
          den = sum(W, 3);
          v_new = num ./ max(den, eps(class(num)));

          % Apply bounds
          if ~isempty(v_bounds)
              v_new = min(v_bounds(2), max(v_bounds(1), v_new));
          end

          % Convergence check
          final_iter = iter;
          if all(abs(v_new(:) - v(:)) < opts.tol)
              v = v_new;
              W_final = W;
              break;
          end
          v = v_new;
          W_final = W;
      end

      % Apply QC for standard mode
      if ~opts.hybrid_mode
          v(invalid_pixels_b) = NaN;
      end

      % Store velocity result
      Vhat_b = v;

      % HYBRID MODE processing
      if opts.hybrid_mode
          % Median filter for wrap detection
          v_filtered = v;
          if opts.median3x3
              v_filtered = medfilt2(v, [3 3], 'symmetric');
          end

          % High-frequency processing
          v_hf_raw = vtilde_b(:,:,iH);
          V_hf_ambig = V_i(iH);
          wrap_correction = round((v_filtered - v_hf_raw) / V_hf_ambig) * V_hf_ambig;
          v_hybrid = v_hf_raw + wrap_correction;

          % Interpolation for invalid pixels (if needed)
          if any(invalid_pixels_b, 'all')
              valid_mask = ~invalid_pixels_b & ~isnan(wrap_correction);
              if any(valid_mask, 'all')
                  [Y, X] = ndgrid(1:R, 1:T);
                  invalid_mask = invalid_pixels_b;

                  if any(invalid_mask, 'all')
                      valid_Y = Y(valid_mask);
                      valid_X = X(valid_mask);
                      valid_wraps = wrap_correction(valid_mask);
                      invalid_Y = Y(invalid_mask);
                      invalid_X = X(invalid_mask);

                      F_interp = scatteredInterpolant(valid_Y, valid_X, valid_wraps, 'nearest', 'nearest');
                      interp_wraps = F_interp(invalid_Y, invalid_X);
                      v_hybrid(invalid_mask) = v_hf_raw(invalid_mask) + interp_wraps;
                  end
              end
          end

          Vhat_b = v_hybrid;
      end

      % Standard deviation calculation
      Wsum = sum(W_final, 3);
      vstd_b = sqrt(1 ./ max(Wsum, eps(class(Wsum))));

      if opts.hybrid_mode && any(invalid_pixels_b, 'all')
          median_vstd = median(vstd_b(~invalid_pixels_b), 'omitnan');
          if isnan(median_vstd), median_vstd = 0.05; end
          vstd_b(invalid_pixels_b) = median_vstd * 2;
      elseif ~opts.hybrid_mode
          vstd_b(invalid_pixels_b) = NaN;
      end

      % Calculate unwrapped phases efficiently
      PHI_unwrapped_b = zeros(R,T,M, 'like', PHI_b);
      for m = 1:M
          phase_from_velocity = Vhat_b / K_vec(m);
          phi_wrapped = PHI_b(:,:,m);
          phase_diff = phase_from_velocity - phi_wrapped;
          n_wraps = round(phase_diff / (2*pi));
          PHI_unwrapped_b(:,:,m) = phi_wrapped + n_wraps * 2*pi;
      end

      % SPIKE DETECTION (if hybrid mode)
      if opts.hybrid_mode
          PHI_unwrapped_b = spikeDetectionInline(PHI_unwrapped_b, PHI_b, invalid_pixels_b, ...
                                                 iH, R, T, M, opts);

          % Update velocity from corrected phase
          K_hf = K_vec(iH);
          Vhat_b = PHI_unwrapped_b(:,:,iH) * K_hf;

          % Update other frequencies to maintain consistency
          for m = 1:M
              if m ~= iH
                  phase_from_velocity = Vhat_b / K_vec(m);
                  phi_wrapped = PHI_b(:,:,m);
                  phase_diff = phase_from_velocity - phi_wrapped;
                  n_wraps = round(phase_diff / (2*pi));
                  PHI_unwrapped_b(:,:,m) = phi_wrapped + n_wraps * 2*pi;
              end
          end
      end

      % Store results in output arrays (parfor can handle simple assignment)
      PHI_unwrapped(:,:,:,b) = PHI_unwrapped_b;
      Vhat(:,:,b) = Vhat_b;
      vstd(:,:,b) = vstd_b;
      iters(:,:,b) = final_iter;
  end

  % Optional median filtering (standard mode only)
  if opts.median3x3 && ~opts.hybrid_mode
      for b = 1:B
          Vhat(:,:,b) = medfilt2(Vhat(:,:,b), [3 3], 'symmetric');
      end
  end

  if nargout > 4
      dbg.F_sorted = F(idxSort);
      dbg.iL = iL; dbg.iM = iM; dbg.iH = iH;
  end
end

function PHI_unwrapped = spikeDetectionInline(PHI_unwrapped, PHI, invalid_pixels, iH, R, T, M, opts)
  % Inline spike detection to avoid function call issues in parfor

  phi_hf = PHI_unwrapped(:,:,iH);
  window_size = 7;
  half_window = floor(window_size/2);

  % Create boundary mask (avoid edges)
  boundary_mask = false(R, T);
  boundary_mask(1:half_window, :) = true;
  boundary_mask(end-half_window+1:end, :) = true;
  boundary_mask(:, 1:half_window) = true;
  boundary_mask(:, end-half_window+1:end) = true;

  % Process only interior pixels
  interior_mask = ~boundary_mask & ~invalid_pixels;

  if ~any(interior_mask, 'all')
      return;
  end

  % Two-pass spike detection
  for pass = 1:2
      if pass == 1
          threshold = opts.despike_pass1_thresh;
      else
          threshold = opts.despike_pass2_thresh;
      end

      % Find spike candidates using local statistics
      phi_padded = padarray(phi_hf, [half_window, half_window], 'symmetric');

      % Use sliding window to find candidates (vectorized approximation)
      kernel = ones(window_size, window_size);
      kernel(half_window+1, half_window+1) = 0; % Exclude center
      kernel = kernel / sum(kernel(:));

      local_avg = conv2(phi_padded, kernel, 'valid');
      diff_from_local = abs(phi_hf - local_avg);
      spike_candidates = interior_mask & (diff_from_local > threshold);

      if ~any(spike_candidates, 'all')
          continue;
      end

      % Process detected spikes with actual median calculation
      [spike_i, spike_j] = find(spike_candidates);

      for idx = 1:length(spike_i)
          i = spike_i(idx);
          j = spike_j(idx);

          % Extract neighborhood
          i_range = (i-half_window):(i+half_window);
          j_range = (j-half_window):(j+half_window);
          neighborhood = phi_hf(i_range, j_range);

          % Calculate true median of neighbors
          neighbors = neighborhood(:);
          center_idx = half_window * window_size + half_window + 1;
          neighbors(center_idx) = [];
          valid_neighbors = neighbors(~isnan(neighbors));

          if length(valid_neighbors) >= 10
              neighbor_median = median(valid_neighbors);
              center_val = phi_hf(i, j);
              phase_diff = center_val - neighbor_median;

              if pass == 1 || abs(phase_diff) <= opts.despike_force_thresh
                  % Try wrap corrections
                  adjustments = [-1, 0, 1] * 2*pi;
                  best_diff = inf;
                  best_val = center_val;

                  for adj = adjustments
                      adjusted_val = center_val + adj;
                      diff_from_median = abs(adjusted_val - neighbor_median);
                      if diff_from_median < best_diff
                          best_diff = diff_from_median;
                          best_val = adjusted_val;
                      end
                  end

                  % Apply correction if significant improvement
                  if best_diff < abs(phase_diff) * 0.7
                      phi_hf(i, j) = best_val;
                  end
              else
                  % Force replacement with median
                  phi_hf(i, j) = neighbor_median;
              end
          end
      end
  end

  PHI_unwrapped(:,:,iH) = phi_hf;
end
