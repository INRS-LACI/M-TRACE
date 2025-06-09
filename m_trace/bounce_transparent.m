%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bounce_transparent.m
% 
% Helper function for computing ray bounces for transparent objects. This
% function does not alter the path of a ray, nor any of its data. However using
% this bounce type may be useful for reporting ray intersections using scripts
% that report data derived from an M-TRACE simulation.
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
function [normal, ch_normal, data_out, cont] = bounce_transparent( ...
    bounce_info, data_in)
    % Simply preserve the incoming ray direction, and preserve all data.
    normal = bounce_info.incoming_normal;
    ch_normal = [];
    data_out = data_in;
    cont = true;
end
