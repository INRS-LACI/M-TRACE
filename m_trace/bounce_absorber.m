%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bounce_absorber.m
% 
% Helper function for computing ray bounces from absorber objects (built-in).
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
function [normal, ch_normal, data_out, cont] = bounce_absorber(bounce_info, ...
    data_in)
    normal = bounce_info.incoming_normal;
    ch_normal = [];
    data_out = data_in;
    cont = false;           % Only behaviour: to halt further raytracing.
end
