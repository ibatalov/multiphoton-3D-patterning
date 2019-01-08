function [slice_paths, slice_colors] = slice_3d_model_into_polygons(coords, slice_distance, varargin)
%%
% slice_paths - cell array containing paths in descending order based on
% the inner area

%% This is a test array of a cube. Change cube rotation by anjusting the 'angle'. Comment it out if want to test the function.
% square_coords = [1,1,1; -1,1,1; 1,-1,1; -1,-1,1; 1,1,-1; -1,1,-1; 1,-1,-1; -1,-1,-1];
% triangle_points = [1,2,4; 1,3,4; 5,6,8; 5,7,8; 1,5,7; 1,7,3; 3,7,8; 3,8,4; 4,8,6; 4,6,2; 1,5,6; 1,6,2];
% triangles_coords = zeros(numel(triangle_points), 3);
% for row = 1 : size(triangle_points,1)
% 	for col = 1 : size(triangle_points, 2)
% 		triangles_coords(col + (row-1)*3, :) = square_coords(triangle_points(row, col),:);
% 	end
% end
% angle = pi()/6; % in radians
% rotM = [1, 0, 0; 0, cos(angle), -sin(angle); 0, sin(angle), cos(angle)];
% triangles_coords = (rotM * (triangles_coords.')).';
% coords = triangles_coords;
% slice_distance = 0.1;

%% Start of the function itself
if ~isempty(varargin)
	image_size = [400, 400];
	range = [-1, 1; -1, 1]*1.5;
	for i = 1 : length(varargin)/2
		switch varargin{2*i-1}
			case 'imagesize'
				image_size = varargin{2*i};
			case 'range'
				range = varargin{2*i};
		end
	end
end

%%
min_coords = min(coords, [], 1);
max_coords = max(coords, [], 1);
slice_count = ceil((max_coords(3) - min_coords(3))/slice_distance) - 1;
slice_z_positions = linspace(min_coords(3) + slice_distance/2, max_coords(3) - slice_distance/2, slice_count);
slice_z_positions = slice_z_positions(:);

slice_coords = cell(slice_count, 1);
slice_paths = cell(slice_count, 1);
slice_colors = cell(slice_count, 1);

%threshold = 0.000001;
temp_array = zeros(size(coords));
temp_array(1:3:end,:) = coords(2:3:end,:);
temp_array(2:3:end,:) = coords(3:3:end,:);
temp_array(3:3:end,:) = coords(1:3:end,:);
threshold = min(0.00005, min(sum((coords - temp_array).^2, 2).^0.5)/100);
fprintf('z dist threshold: %d\n', threshold);
areas_video = zeros([image_size, 3, slice_count]);

for slice_num = 1 : slice_count
	curr_z = slice_z_positions(slice_num);
	slice_points = [];
	% find triangles intersecting the z-plane
	for triangle_num = 1 : (size(coords, 1)/3)
		triangle_coords = coords(3*(triangle_num - 1) + 1 : 3*triangle_num, :);
		z_deltas = triangle_coords(:, 3) - curr_z;	
		z_deltas = sign(z_deltas) .* (abs(z_deltas) > threshold);
		if min(z_deltas) < 0 && max(z_deltas) > 0
			% this triangle does cross the current z-plane
			% now finding the intersection of the triangle and the plane
			sum_deltas = sum(z_deltas);
			if sum_deltas ~= 0
				if sum_deltas > 0
					% 2 points are above, 1 - below
					start_point_number = find(z_deltas < 0);
				else
					if sum_deltas < 0
						% 1 point is above, 2 - below
						start_point_number = find(z_deltas > 0);
					end
				end
				finish_point_numbers = [1,2,3];
				finish_point_numbers(start_point_number) = []; % remove the starting point
				
				dirs = triangle_coords(finish_point_numbers, :) - triangle_coords(start_point_number, :);
				coeffs = (curr_z - triangle_coords(start_point_number, 3)) ./ dirs(:, 3);
				coeffs = coeffs(:);
				
				if max(abs(coeffs)) > 1
					disp('coeffs are > 1!!!!');
					coeffs
				end
				
				intersection_points = repmat(triangle_coords(start_point_number, :), 2, 1) + repmat(coeffs, 1, 3) .* dirs;
				slice_points = [slice_points; intersection_points];
			else
				disp('one point was above, one - below, one - in the plane!');
				% one point above, one - below, one - in the plane
				start_point_number = find(z_deltas > 0);
				finish_point_number = find(z_deltas < 0);
				start_point = triangle_coords(start_point_number, :);
				finish_point = triangle_coords(finish_point_number, :);
				
				dir = finish_point - start_point;
				coeff = (curr_z - start_point(3)) / dir(3);
				intersection_point = start_point + coeff * dir;
				slice_points = [slice_points; triangle_coords(z_deltas == 0, :); intersection_point];
			end
		else
			% the only other case to consider is when 2 vertices are in the
			% plane and one vertex - outside of the plane. The rest of
			% cases can be ignored.
			if min(abs(z_deltas)) == 0 && sum(abs(z_deltas)) == 1
				%disp('2 verctices are in the plane!');
				% 2 vertices of this triangle lay in the plane
				touching_point_numbers = find(z_deltas == 0);
				p = triangle_coords(touching_point_numbers, :);
				p = sortrows(p, [1, 2, 3]);
				if ~isempty(slice_points)
					match_array_1 = sum((slice_points(1:2:end,:) - p(1,:)).^2, 2).^0.5 < threshold;
					match_array_2 = sum((slice_points(2:2:end,:) - p(2,:)).^2, 2).^0.5 < threshold;
					match_array = match_array_1 .* match_array_2;
					if max(match_array(:)) == 0
						slice_points = [slice_points; p];
					end
				else
					slice_points = [slice_points; p];
				end
			end
		end
	end
	slice_coords{slice_num} = slice_points;
	%figure;
	%slice_range = [min(slice_points(:,1:2), [], 1).', max(slice_points(:,1:2), [], 1).'];
	%imshow(visualize_pairs(slice_points, 'pixelsize', [2048, 2048], 'range', slice_range);
	[polygons, colors] = convert_to_polygons(slice_points, 'pixelsize', image_size,'range', range, 'fill', true);
	%areas_video(:,:,:,slice_num) = areas_image;
	slice_colors{slice_num} = colors;
	
	fprintf('Slice %i contains %i polygons\n', slice_num, length(polygons));
	slice_paths{slice_num} = polygons;
end

%implay(areas_video);
%% visualize slices
% slice_num = 63;
% figure;
% plot(slice_coords{slice_num}(:,2), -slice_coords{slice_num}(:,1), 'o');
