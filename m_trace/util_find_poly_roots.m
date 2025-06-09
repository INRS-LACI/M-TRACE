%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% util_find_poly_roots.m
% 
% M-TRACE helper function for finding roots of polynomials on the unit interval 
% [0, 1].
% 
% coeffs store poly coefficients in order of decreasing exponents. Function
% is specialized to only work for 1st degree, 2nd degree, and 3rd degree
% polynomials. This is detected by the size of coeffs:
%   [a]          ->                       a = 0
%   [a, b]       ->                 a*t + b = 0
%   [a, b, c]    ->         a*t^2 + b*t + c = 0
%   [a, b, c, d] -> a*t^3 + b*t^2 + c*t + d = 0
% Function works by finding critical points, and seeing how they divide the
% [0, 1] interval. Roots are searched for by Newton's method after that. It
% is also assumed that a~=0 in each case. Thus when numel(coeffs)==1, an
% empty array is returned.
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function roots = util_find_poly_roots(coeffs)
    ord = numel(coeffs);
    roots = [];
    
    if coeffs(1)==0
        error('coeffs(1)==0');
    end
    
    % Handle base cases:
    switch ord
        case 1
            return;
        case 2
            x = -coeffs(2) / coeffs(1);
            if x>=0 && x<=1
                roots = x;
            end
            return;
    end
    
    % Otherwise, we need to find critical points (crits) in [0, 1]:
    % These are found as the roots of lesser-order polynomial (recursive
    % call).
    switch ord
        case 3
            coeffs_crit = [2*coeffs(1), coeffs(2)];
        case 4
            coeffs_crit = [3*coeffs(1), 2*coeffs(2), coeffs(3)];
    end
    crits = [0, 1, util_find_poly_roots(coeffs_crit)];   % Append endpoints!
    crits = unique(crits);      % Eliminate duplicate values of 0 or 1
    
    % Evaluations at critical points:
    crit_vals = polyval(coeffs, crits);     % MATLAB internal function
    
    % Check that the maxima straddle zero. If not, return no roots.
    max_crit = max(crit_vals);
    min_crit = min(crit_vals);
    if max_crit*min_crit>0
        return;
    end
    
    % Otherwise, we can now sort the critical values and prune them:
    [crits, i_s] = sort(crits, 'ascend');
    crit_vals = crit_vals(i_s);
    
    % Now we can find a unique root in each interval that straddles zero:
    for i=1:(numel(crits)-1)
        if crit_vals(i)*crit_vals(i+1) <= 0
            x = find_mono_root(coeffs, crits(i), crits(i+1));
            roots = [roots, x]; %#ok<AGROW>
        end
    end
    
    % Sub-helper function: finds a unique root guaranteed to exist on an
    % interval [a, b]. Uses a binary search.
    function x = find_mono_root(coeffs, a, b)
        dx_max = 1e-40;
        w = 0.5*(b-a);      % Tracks interval width
        X = [a, 0.5*(a+b), b];
        n = numel(coeffs);
        while w > dx_max
            x1 = 1.0;
            x2 = 1.0;
            x3 = 1.0;
            y1 = 0.0;
            y2 = 0.0;
            y3 = 0.0;
            for k=1:n
                y1 = y1 + coeffs(n-k+1)*x1;
                y2 = y2 + coeffs(n-k+1)*x2;
                y3 = y3 + coeffs(n-k+1)*x3;
                
                x1 = x1 * X(1);
                x2 = x2 * X(2);
                x3 = x3 * X(3);
            end
            Y = [y1, y2, y3];
            
            if Y(1)==0
                x = X(1);
                return;
            elseif Y(3)==0
                x = X(3);
                return;
            elseif Y(1)*Y(2)<=0  
                X = [X(1), 0.5*(X(1)+X(2)), X(2)];
            else
                X = [X(2), 0.5*(X(2)+X(3)), X(3)];
            end
            w = 0.5*w;      % Diminish interval width by half
        end
        x = X(2);
    end
end