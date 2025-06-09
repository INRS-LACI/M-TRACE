%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bounce_refract.m
% 
% Helper function for computing ray bounces from single-sided mirrors 
% (built-in). The function expects one argument (the refractive index) to be
% specified in the SVG file. This is subsequently passed as the field 
% 'bounce_type_args' in the 'bounce_info.object' structure.
% 
% Interactions with multiple overlapping refractive objects is implemented using
% a 'stack' of so-far encountered objects that is passed and modified using the
% 'data_in' and 'data_out' structures. Precedence is determined by z-order in
% the SVG drawing. Paths that model refractive objects need not be closed, but
% this can lead to unexpected behaviour, as there may not be a way for a ray to
% 'exit' the propagation medium as there would be for a closed shape.
% 
% Signature of each bounce function follows:
%   [new_normal, possible_child_ray_normal, data_out, continue_flag] = ...
%                                              funct(bounce_info, data_in)
% bounce_info is a struct containing the fields 'origin', 'incoming_normal', 
% 'surface_normal', and 'object', which together specify all the information 
% known about the found intersection point.
% 
% Note: surface normal rays may not point in the 'outwards' facing direction of
% the surface (i.e opposite to the normal of the incoming ray). Thus, a test and
% correction is typically needed.
% 
% Patrick Kilcullen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [normal, ch_normal, data_out, cont] = bounce_refract(bounce_info, ...
    data_in, ambient_refractive_index, min_bounce_distance)

    % Validation: this facet type must have a single argument:
    obj = bounce_info.object;
    if numel(obj.bounce_type_args) ~= 1
        error('refract must have an argument.');
    end

    % We first update (or create) two rstacks (refractive object stacks). Each
    % works as follows:
    % If the object matching the z_order is on the stack, it's
    % removed. Otherwise, it's inserted (along with it's refractive
    % index) at the position such that the stack is in descending
    % order by z-order. z_order fields are guaranteed to be unique (see
    % p_get_svg_data() function).
    % We maintain two rstacks to handle the two possible cases of total internal
    % refraction (the ray does not enter into the new medium), and transmission.
    % These are rstack_r and rstack_t respectively.
    obj_z = obj.z_order;
    obj_rindex = abs(obj.bounce_type_args(1));   % Refractive index

    if isfield(data_in, 'rstack')  % Handles case if data_in is empty
        rstack_r = data_in.rstack;
    else
        % To begin, if the input r_stack does not exist, we must create it by
        % inspecting the set of closed path shapes with a 'refract' bounce type
        % that contain the point from which the incoming ray is being bounced.
        % Internal status to a closed subpath is checked based on the number of
        % computed intersections with the continued ray being odd. Internal
        % status to the overall path (being possibly comprised of several closed
        % subpaths) is checked by if it is internal to an odd number of closed
        % subpaths.
        rstack_r = [];
        ax_h = bounce_info.m_trace_axis_handle;
        obj_set = ax_h.UserData.m_trace_data.path_data;
        num_obj = numel(obj_set);

        % Determine if the ray origin point is contained in a closed
        % refractive shape:
        for k=1:num_obj
            test_obj = obj_set{k};
            % Check if this path is a refractive object (indicated by the
            % 'bounce_type = refract(n) attribute
            if ~isfield(test_obj, 'bounce_type') ...
                || ~strcmp(test_obj.bounce_type, 'refract')
                continue;
            end
            % Check if the current launch point is within a closed subpath
            % of this object:
            num_internal_subpaths = 0;
            for kk=1:numel(test_obj.subpaths)
                if ~test_obj.subpaths(kk).is_closed
                    continue;
                end
    
                num_intersected_segments = 0;
                for jj=1:numel(test_obj.subpaths(kk).seg_data)
                    path_type = test_obj.subpaths(kk).seg_data(jj).type;
                    data      = test_obj.subpaths(kk).seg_data(jj).data;
                    
                    switch path_type
                        case 'B'
                            [pp, ~] = util_intersect_path_B(...
                                bounce_info.incoming_launch, ...
                                bounce_info.incoming_normal, ...
                                data, min_bounce_distance);    
                        case 'E'
                            [pp, ~] = util_intersect_path_E(...
                                bounce_info.incoming_launch, ...
                                bounce_info.incoming_normal, ...
                                data, min_bounce_distance);
                    end
                    if norm(pp - bounce_info.incoming_launch) > 0
                        % The intersect path functions return the input
                        % point if no intersection is found
                        num_intersected_segments = num_intersected_segments + 1;
                    end
                end
                if mod(num_intersected_segments, 2) ~= 0
                    num_internal_subpaths = num_internal_subpaths + 1;
                end
            end
    
            if mod(num_internal_subpaths, 2) ~= 0
                % Here, we've determined that the initial ray launch point
                % is indeed internal to the path. We therefore update the
                % initial rstack:
                test_obj_z = test_obj.z_order;
                test_obj_rindex = abs(test_obj.bounce_type_args(1));
                ii = 1;
                while ii <= size(rstack_r, 1) && rstack_r(ii, 1) > obj_z 
                    ii = ii + 1;
                end
                if ii > size(rstack_r, 1)
                    % create stack entry at end:
                    rstack_r = [rstack_r; ...
                        test_obj_z, test_obj_rindex]; %#ok<AGROW> 
                else
                    % create stack entry (before end):
                    rstack_r = [rstack_r(1:(ii-1), :); ...
                                test_obj_z, test_obj_rindex; ...
                                rstack_r(ii:end, :)];
                end
            end
        end
    end
    k = 1;
    while k <= size(rstack_r, 1) && rstack_r(k, 1) > obj_z 
        k = k + 1;
    end
    if k > size(rstack_r, 1)
        % create stack entry at end:
        rstack_t = [rstack_r; obj_z, obj_rindex];
    elseif rstack_r(k, 1) == obj_z
        % delete stack entry:
        rstack_t = rstack_r;
        rstack_t(k, :) = [];
    else
        % create stack entry (before end):
        rstack_t = [rstack_r(1:(k-1), :); ...
                    obj_z, obj_rindex; ...
                    rstack_r(k:end, :)];
    end

    % Now we compute reflection from a refractive interface.
    % Take the rindex from the object at the top (i.e. start) of
    % the rstack. If empty, use 1.00 as the index.
    if isempty(rstack_r)
        old_rindex = ambient_refractive_index;
    else
        old_rindex = rstack_r(1, 2);
    end
    if isempty(rstack_t)
        new_rindex = ambient_refractive_index;
    else
        new_rindex = rstack_t(1, 2);
    end
    
    old_norm = bounce_info.incoming_normal;
    surf_norm = bounce_info.surface_normal;
    % We determine a normal direction that will be guaranteed to point outwards
    % relative to the incoming ray direction:
    if dot(surf_norm, old_norm) > 0
        surf_norm = -surf_norm;
    end

    % Compute cross prod of incoming ray direction with surface
    % normal (used for determining outgoing ray direction later). This will
    % equal sin(th_1) since the vectors are normalized.
    surf_norm = surf_norm/norm(surf_norm);
    old_norm = old_norm/norm(old_norm);
    cross_prod = surf_norm(1)*old_norm(2) - surf_norm(2)*old_norm(1);
    s_th1 = abs(cross_prod);

    s_th2 = (old_rindex / new_rindex) * s_th1;  % Application of Snell's Law

    % Determination of new data:
    data_out = data_in;
    if abs(s_th2) > 1.0
        % This is the case of total internal refraction. We treat
        % this case the same as a mirror. This also requires
        % reverting the rstack:
        normal = old_norm - 2*dot(old_norm, surf_norm)*surf_norm;
        data_out.rindex = old_rindex;
        data_out.rstack = rstack_r;
    else
        % This is the case of ray transmission.
        % We compute the normal of the refracted ray. This will be calculated by
        % rotating the surface normal multiplied by -1 so as to point inwards.
        % To cover all possible cases succinctly, we compute both clockwise and
        % counter-clockwise rotations and choose the correct one based on a test
        % of the cross product's sign.

        c_th2 = sqrt(1 - s_th2*s_th2);          % cos(theta_2)
        Ma = [c_th2, -s_th2;  s_th2, c_th2];    % Rotation matrices for each of
        Mb = [c_th2,  s_th2; -s_th2, c_th2];    % the cw and ccw cases
        r_na = -Ma * [surf_norm(1); surf_norm(2)];  % -ve signs produce rotated
        r_nb = -Mb * [surf_norm(1); surf_norm(2)];  % inwards-pointing normals
        
        % The test is that the cross product of the outward-facing surface
        % normal with both the old and new ray normals should have the same
        % sign. This indicates that both rays are on the same 'side' of the
        % normal ray.
        r_na_cross = surf_norm(1)*r_na(2) - surf_norm(2)*r_na(1);
        if r_na_cross * cross_prod >= 0              
            normal = r_na;
        else           
            normal = r_nb;
        end
        data_out.rindex = new_rindex;
        data_out.rstack = rstack_t;
    end

    ch_normal = [];
    cont = true;
end
