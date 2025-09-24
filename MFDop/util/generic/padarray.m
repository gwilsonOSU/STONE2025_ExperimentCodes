function B = padarray(A, padsize, padval, direction)
%PADARRAY  Lightweight replacement for IPT's padarray (numeric/logical).
%   B = PADARRAY(A, P) pads A by P on both sides with zeros.
%   B = PADARRAY(A, P, C) pads with constant C, or with one of:
%       'replicate' | 'symmetric' | 'circular'
%   B = PADARRAY(A, P, ..., DIR) where DIR is 'pre' | 'post' | 'both'
%
% Limitations:
% - Designed for numeric/logical arrays (works for char too).
% - No support for 'indexed'/'rgb' special cases (just raw arrays).

    if nargin < 2, error('padarray:NotEnoughInputs','Need at least A and padsize.'); end
    if ~isnumeric(padsize) || any(padsize(:) < 0) || any(padsize(:) ~= floor(padsize(:)))
        error('padarray:BadPadsize','padsize must be nonnegative integers.');
    end

    ndA = ndims(A);
    szA = size(A);

    % Normalize padsize length
    if isscalar(padsize)
        padsize = repmat(padsize, 1, ndA);
    else
        if numel(padsize) < ndA
            padsize = [padsize(:).' zeros(1, ndA - numel(padsize))];
        else
            % allow padding along new trailing dims
            extra = numel(padsize) - ndA;
            if extra > 0
                szA = [szA ones(1, extra)];
                ndA = numel(szA);
            end
            padsize = padsize(:).';
        end
    end

    % Defaults
    mode = 'constant';
    cval = 0;
    if nargin >= 3 && ~isempty(padval)
        if ischar(padval) || (isstring(padval) && isscalar(padval))
            mode = lower(string(padval));
            if mode ~= "replicate" && mode ~= "symmetric" && mode ~= "circular"
                error('padarray:UnknownMode','Unknown padding mode: %s', padval);
            end
            mode = char(mode);
        else
            mode = 'constant';
            cval = padval;
        end
    end

    if nargin < 4 || isempty(direction)
        direction = 'both';
    else
        direction = validatestring(direction, {'pre','post','both'});
    end

    switch direction
        case 'pre'
            pre = padsize; post = zeros(1, ndA);
        case 'post'
            pre = zeros(1, ndA); post = padsize;
        otherwise % 'both'
            pre = padsize; post = padsize;
    end

    % Build index vectors per dimension
    idx = cell(1, ndA);
    for d = 1:ndA
        n = szA(d);
        if strcmp(mode,'constant')
            % We'll place A into a pre-filled array; indices just place A.
            idx{d} = (pre(d)+1) : (pre(d)+n);
        else
            % Generate selection indices into A that realize the padding.
            i = (1 - pre(d)) : (n + post(d));
            switch mode
                case 'replicate'
                    j = min(max(i, 1), n);
                case 'circular'
                    if n == 0, j = i; else, j = mod(i-1, n) + 1; end
                case 'symmetric'
                    if n <= 1
                        j = ones(size(i));
                    else
                        per = 2*n - 2;                % reflection period
                        p = mod(i-1, per) + 1;
                        j = min(p, 2*n - p);
                    end
            end
            idx{d} = j;
        end
    end

    if strcmp(mode,'constant')
        % Allocate and place A
        newSz = szA + pre + post;
        B = repmat(cast(cval, 'like', A), newSz); % fills with cval
        % Build subs to assign A into the center block
        subs = arrayfun(@(d) (pre(d)+1):(pre(d)+szA(d)), 1:ndA, 'uni', 0);
        B(subs{:}) = A;
    else
        % Indexing-based padding for replicate/circular/symmetric
        % Note: if extra dims were added, expand A via singleton expansion.
        B = A;
        B = B(idx{:}); % relies on MATLAB's implicit expansion rules
    end
end
