%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bounce_mirror.m
% 
% Helper function for computing ray bounces from mirror objects (built-in).
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
function [normal, ch_normal, data_out, cont] = bounce_mirror(bounce_info, ...
    data_in)
    old_norm = bounce_info.incoming_normal;
    surf_norm = bounce_info.surface_normal;
    % We determine a normal direction that will be guaranteed to point outwards
    % relative to the incoming ray direction:
    if dot(surf_norm, old_norm) > 0
        surf_norm = -surf_norm;
    end
        
    normal = old_norm - 2*dot(old_norm, surf_norm)*surf_norm;
    ch_normal = [];
    data_out = data_in;
    cont = true;
end
