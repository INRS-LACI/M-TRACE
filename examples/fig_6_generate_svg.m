%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fig_6_generate_svg.m
% 
% Script for generating the SVG model of the Brendel & Lautenbacher double-Gauss
% lens, directly from perscription data.
% 
% Patrick Kilcullen (patrick.kilcullen@inrs.ca)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%#ok<*CLALL>    % Suppress clear all warning
%#ok<*UNRCH>    % Suppress unreachable code warning
close all;
clear all;
%path(pathdef.m)


%% Dashboard
nudge = 0.01;   % "nudge" distance to ensure the overlap of immediately adjacent
                % refractive elements.
n_LAF3   = 1.716998;    % Index values for Helium d line taken from 
n_SF5    = 1.672697;    % Zemax SCHOTT.AGF internal glass catalogue
n_BAFN11 = 1.666721;    % (Ansys Zemax OpticStudio R1.00)
s_LAF3   = 'fill: #5e81ac;fill-opacity: 0.5;stroke: #000000;stroke-width: 0.2;';
s_SF5    = 'fill: #a3be8c;fill-opacity: 0.5;stroke: #000000;stroke-width: 0.2;';
s_BAFN11 = 'fill: #bf616a;fill-opacity: 0.5;stroke: #000000;stroke-width: 0.2;';
    % CSS style formatting strings for each lens material type.

system(1).type = 'thick_lens';
system(1).R1 = 75.050;
system(1).R2 = 270.7000;
system(1).r1  = 33.0;
system(1).r2  = 33.0;
system(1).t  = 9.000;
system(1).n = n_LAF3;
system(1).style_str = s_LAF3;

system(2).type = 'gap';
system(2).t = 0.100;

system(3).type = 'thick_lens';
system(3).R1 = 39.270;
system(3).R2 = Inf;
system(3).r1  = 27.5;
system(3).r2  = 27.5;
system(3).t  = 16.510 + nudge;
system(3).n = n_BAFN11;
system(3).style_str = s_BAFN11;

system(4).type = 'gap';
system(4).t = -nudge;

system(5).type = 'thick_lens';
system(5).R1 = Inf;
system(5).R2 = 25.650;
system(5).r1  = 27.5;
system(5).r2  = 19.5;
system(5).t  = 2.000;
system(5).n = n_SF5;
system(5).style_str = s_SF5;

system(6).type = 'gap';
system(6).t = 10.990;

system(7).type = 'aperture';
system(7).r1 = 18.6;
system(7).r2 = 22.0;
system(7).style_str = 'fill: none;stroke: #000000;stroke-width: 1;';

system(8).type = 'gap';
system(8).t = 13.000;

system(9).type = 'thick_lens';
system(9).R1 = -31.870;
system(9).R2 = Inf;
system(9).r1  = 18.5;
system(9).r2  = 21.0;
system(9).t  = 7.030 + nudge;
system(9).n = n_SF5;
system(9).style_str = s_SF5;

system(10).type = 'gap';
system(10).t = -nudge;

system(11).type = 'thick_lens';
system(11).R1 = Inf;
system(11).R2 = -43.510;
system(11).r1  = 21.0;
system(11).r2  = 21.0;
system(11).t  = 8.980;
system(11).n = n_LAF3;
system(11).style_str = s_LAF3;

system(12).type = 'gap';
system(12).t = 0.100;

system(13).type = 'thick_lens';
system(13).R1 = 221.140;
system(13).R2 = -88.790;
system(13).r1  = 23.0;
system(13).r2  = 23.0;
system(13).t  = 7.980;
system(13).n = n_BAFN11;
system(13).style_str = s_BAFN11;

system(14).type = 'gap';
system(14).t = 61.418;

system(15).type = 'screen';
system(15).r1 = 20.0;
system(15).style_str = 'fill: none;stroke: #000000;stroke-width: 0.2;';


%% Run
[vx, vy] = m_trace_generate_system_svg('fig_6_generator_input.svg', system, ...
    'fig_6_generator_output.svg', [42.918, 39.7815]);
% Display front element's vertex coordinates:
disp([vx, vy]);
