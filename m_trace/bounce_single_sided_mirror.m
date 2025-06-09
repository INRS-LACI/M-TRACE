%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bounce_single_sided_mirror.m
% 
% Helper function for computing ray bounces from single-sided mirrors 
% (built-in). The function expects one argument (either the numbers  +1 or -1)
% to be specified in the SVG file. This is subsequently passed as the field 
% 'bounce_type_args' in the 'bounce_info.object' structure and used as a flag to
% orient the 'pass-thru' and 'bounce-off' surfaces of the path object. The
% meaning of this flag depends on the exact internal parameterization of the
% path, and may in general depend on how it's drawn by a user. Thus the
% orientaiton parameter should in practice just be toggled until the desired
% behaviour is found.
% 
% Signature of each bounce function follows:
%   [new_normal, possible_child_ray_normal, new_ray_data, continue_flag] = ...
%                                              funct(bounce_info, prev_ray_data)
% bounce_info is a struct containing the fields 'origin', 'incoming_normal', 
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
function [normal, ch_normal, data_out, cont] = bounce_single_sided_mirror( ...
    bounce_info, data_in)
    
    % Validation: this facet type must have a single argument:
    obj = bounce_info.object;
    issue_error = false;
    if numel(obj.bounce_type_args) ~= 1
        issue_error = true;
    end
    if issue_error
        error('single_sided_mirror must have an argument.');
    end
    
    dir_flag = obj.bounce_type_args(1); % Direction flag
    old_norm = bounce_info.incoming_normal;
    surf_norm = bounce_info.surface_normal;
    dprod = dot(old_norm, surf_norm);
    if dprod * dir_flag >= 0
        normal = old_norm;
    else
        normal = old_norm - 2*dprod*surf_norm;
    end

    ch_normal = [];
    data_out = data_in;
    cont = true;
end
