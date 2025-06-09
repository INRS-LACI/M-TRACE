%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bounce_thin_lens.m
% 
% Helper function for computing ray bounces from thin lens objects (built-in).
% The function expects one argument (the focal length in document length units)
% to be specified in the SVG file. This is subsequently passed as the field 
% 'bounce_type_args' in the 'bounce_info.object' structure.
% 
% Signature of each bounce function follows:
%   [new_normal, possible_child_ray_normal, new_ray_data, continue_flag] = ...
%                                              funct(bounce_info, prev_ray_data)
% bounce_info is a struct containing the fields 'launch', 'incoming_normal', 
% 'surface_normal', and 'object', which together specify all the information 
% known about the found intersection point.
% 
% Note: surface normal rays may not point in the 'outwards' facing direction of
% the surface (i.e opposite to the normal of the incoming ray). Thus, a test and
% correction is typically needed.
% 
% Built-in bounce types:
% - `absorber`
% - `mirror`
% - `thin_lens` (1 arg)
% - `partial_mirror`
% - `single_sided_mirror` (1 arg)
% - `refract` (1 arg)
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [normal, ch_normal, data_out, cont] = bounce_thin_lens(bounce_info, ...
    data_in)
    % This calculation requires that the path consist of a single line segment
    % and carry a single bounce_type argument
    obj = bounce_info.object;
    issue_error = false;
    if numel(obj.subpaths)~=1
        issue_error = true;
    elseif numel(obj.subpaths(1).seg_data)~=1
        issue_error = true;
    elseif numel(obj.subpaths(1).seg_data(1).data)~=4
        issue_error = true;
    elseif obj.subpaths(1).seg_data(1).type~='B'
        issue_error = true;
    end
    if issue_error
        error('thin_lens must only be applied to line segments.');
    end
    if numel(obj.bounce_type_args) ~= 1
        error('thin_lens must have an argument.');
    end
    
    % If the segment is ok, we can calculate:
    r_n1 = bounce_info.incoming_normal;
    r_o2 = bounce_info.surface_intersection;

    focal_len = obj.bounce_type_args(1); % focal length
    sd = obj.subpaths(1).seg_data(1).data;
    mp = 0.5 * [sd(1)+sd(3), sd(2)+sd(4)];          % line midpoint
    dd = [r_o2(1)-mp(1), r_o2(2)-mp(2)];        
        % Midpoint to intersection vector
    D = norm(dd);
        % Ray intersetion to midpoint distance
    
    th = abs(D/focal_len); % Change in angle (absolute)
    
    ad = (dd(1)*r_n1(2) - dd(2)*r_n1(1));     
        % angle determinant (i.e. cross prod.)
    if ad*focal_len<0
        th = -th;
    end
    
    normal = [cos(th), -sin(th); sin(th), cos(th)] * r_n1(:);
    ch_normal = [];
    data_out = data_in;
    cont = true;
end
