%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% util_intersect_path_E.m
% 
% M-TRACE helper function for computing line/ellipse path intersections.
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

function [pt, nn] = util_intersect_path_E(line_p, line_d, data, MIN_D)
    % Unpack
    d = data;
    r_x = d(1);
    r_y = d(2);
    c_x = d(3);
    c_y = d(4);
    phi = d(5);
    t_1 = d(6);
    t_2 = d(7);
    
    M = [cos(phi), sin(phi); -sin(phi), cos(phi)];
    t1 = M * [line_d(1); line_d(2)];
    t2 = M * [line_p(1)-c_x; line_p(2)-c_y];
    a_x = t1(1);
    a_y = t1(2);
    b_x = t2(1);
    b_y = t2(2);
    
    % setup quadratic coefficients:
    c1 = (r_y*a_x)^2 + (r_x*a_y)^2;
    c2 = 2*(a_x*b_x*r_y*r_y + a_y*b_y*r_x*r_x);
    c3 = (b_x*r_y)^2 + (b_y*r_x)^2 - (r_x*r_y)^2;
    c4 = c2^2 - 4*c1*c3;    % discriminant
    
    if c4<0
        alpha = [];
    else
        alpha = (-c2 + sqrt(c4)*[1, -1])/(2*c1);
    end
    
    A = (alpha*a_x + b_x)/r_x;
    B = (alpha*a_y + b_y)/r_y;
    theta = atan2(B, A);
    test_1 = (t_1-theta)/(2*pi);
    test_2 = (t_2-theta)/(2*pi);
    if t_1<=t_2
        test = ceil(test_1)<=floor(test_2);
    else
        test = ceil(test_2)<=floor(test_1);
    end
    test = test & alpha>MIN_D;
    
    [a, ind] = min( alpha(test) );
    if isempty(a)
        pt = line_p;
        nn = line_d;
    else
        th = theta(test);
        th = th(ind);
        
        pt = line_p + a * line_d;     % Old method (low accuracy?)

        tangent = (M') * [-r_x*sin(th); r_y*cos(th)];
        nn = [0, -1; 1, 0] * tangent;
        nn = nn / sqrt(nn(1)^2 + nn(2)^2);
    end
end
