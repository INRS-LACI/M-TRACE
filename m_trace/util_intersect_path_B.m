%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% util_intersect_path_B.m
% 
% M-TRACE helper function for computing line/bezier path intersections.
% 
% Line is parameterized by a location b and a direction vector d
% Returns empty if no intersection is found. For raytracing purposes, only
% the closest point to the ray origin is returned.
%   pt = 2-vector [x,y] of intersetion point
%   nn = 2-vector of surface normal at point of intersetion (normalized)
% Note: nn is not adjusted to point in any particular direction, and
% depends on parameterization. Later ray-tracing steps which update ray
% directions (e.g. for reflection) may need to use the negative of this
% vector.
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [pt, nn] = util_intersect_path_B(line_p, line_d, data, MIN_D)
    q_1 = line_d(:);
    q_2 = line_p(:);
    ord = round( numel(data)/2 );
    d = reshape(data, [2, ord]);
    switch ord
        case 2
            p_1 = [0; 0];
            p_2 = [0; 0];
            p_3 = d(:,2) - d(:,1);
            p_4 = d(:,1);
        case 3
            p_1 = [0; 0];
            p_2 = d(:,1) - 2*d(:,2) + d(:,3);
            p_3 = -2*d(:,1) + 2*d(:,2);
            p_4 = d(:,1);
        case 4
            p_1 = -d(:,1) + 3*d(:,2) - 3*d(:,3) + d(:,4);
            p_2 = 3*d(:,1) - 6*d(:,2) + 3*d(:,3);
            p_3 = -3*d(:,1) + 3*d(:,2);
            p_4 = d(:,1);
    end
    
    M = [p_1, p_2, p_3, p_4-q_2, -q_1];
    coeffs1 = [M(1,1)*M(2,5) - M(2,1)*M(1,5), ...
              M(1,2)*M(2,5) - M(2,2)*M(1,5), ...
              M(1,3)*M(2,5) - M(2,3)*M(1,5), ...
              M(1,4)*M(2,5) - M(2,4)*M(1,5)];
    col_1 = find(coeffs1, 1);
    coeffs = coeffs1(col_1:end);
    
    if isempty(coeffs)  % ill-formed problem, no intersection found.
        pt = line_p;
        nn = line_d;
        return;
    end
    
    t = util_find_poly_roots(coeffs);
    
    if M(1,5)~=0
        alpha = -polyval(M(1,1:4), t)/M(1,5);
    elseif M(2,5)~=0
        alpha = -polyval(M(2,1:4), t)/M(2,5);
    else
        alpha = [];
    end
    
    test = alpha>MIN_D;
    [a, ind] = min( alpha(test) );      % Use minimum positive element;
    if isempty(a)
        pt = line_p;
        nn = line_d;
    else
        ta = t(test);
        ta = ta(ind);
        
        pt = line_p + a * line_d;
%         pt = p_1*ta^3 + p_2*ta^2 + p_3*ta + p_4;  % Alternate method

        tangent = 3*p_1*ta^2 + 2*p_2*ta + p_3;
        nn = [0, 1; -1, 0] * [tangent(1); tangent(2)];
        nn = nn / sqrt(nn(1)^2 + nn(2)^2);
    end
end