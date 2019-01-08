% size of the scan field in microscope.
area_size_x = 1023;
area_size_y = 1023;
laser_power = 100;
sampling_dist = 10; % how many points to skip in the path

%% open the original roi file
file_name = 's_261714864-527330.roi';
fileID1 = fopen(file_name,'rt', 'n', 'unicode');
roi_template = textscan(fileID1, '%s', 'delimiter', '\n');
roi_template = roi_template{1};

%% split the roi file into parts: header, reference squares, and the polygon
n = 0; % number of '2D' encounters
last_i = 1;
for i = 1 : length(roi_template)
	if  strcmp(roi_template{i}, '[2D]')
		switch n
			case 0 % header
				header = roi_template(1:i-1);
			case 1 % first refecence square
				ref_square_1_part_1 = roi_template(last_i:i-1);
			case 2 % second reference square
				ref_square_2_part_1 = roi_template(last_i:i-1);
			case 3 % polygon to be used as the template for generated polygons
				poly_template_part_1 = roi_template(last_i:i-1);
			case 4 % first refecence square
				ref_square_1_part_2 = roi_template(last_i:i-1);
			case 5 % second reference square
				ref_square_2_part_2 = roi_template(last_i:i-1);
				% the last part goes till the end of the file
				poly_template_part_2 = roi_template(i:end);
		end
		last_i = i;
		n = n + 1;
	end
end

%% open the image, convert to border image
[pic_name, pic_path] = uigetfile({'*.*'; '*.bmp'; '*.png'; '*.tif'; '*.tiff'; '*.jpg'; '*.jpeg'}, 'Open the binary image');
path_name = pic_path;
image = imread([pic_path, pic_name]);
image = image/max(image(:));
image = image > 0.5;
image = image(:,:,1);

image_size_x = size(image, 2);
image_size_y = size(image, 1);
max_image_size = max(image_size_x, image_size_y);

image_border = bwmorph(image, 'remove');
endpoints = bwmorph(image_border, 'endpoints');
while(nnz(endpoints) > 0)
	image_border = image_border .* ~endpoints;
	endpoints = bwmorph(image_border, 'endpoints');
end
image_border = bwmorph(image_border, 'skel');
imshow(image_border);

%% trace the borders with polygons
opening_strings = []; % contains "absolute" (uncropped) coordinates

CC = bwconncomp(image_border);
final_paths = cell(CC.NumObjects, 1); % stores border paths for each isolated shape

for obj_num = 1 : CC.NumObjects
	obj_indices = CC.PixelIdxList{obj_num};
	if numel(obj_indices) > 30
		[rows, cols] = ind2sub(size(image_border), obj_indices);
		
		closed_paths = {};
		paths = cell(1,1);
		
		% find the first point that only has 2 neighbors to make it easier to
		% check if the path is closed
		first_index = 1;
		neighbors = get_neighbors([rows(first_index), cols(first_index)], [rows, cols], size(image), 8);
		while length(neighbors) ~= 2
			first_index = first_index + 1;
			neighbors = get_neighbors([rows(first_index), cols(first_index)], [rows, cols], size(image), 8);
		end
		paths{1} = [rows(first_index), cols(first_index); neighbors(1,:)];
		
		while ~isempty(paths)
			path_count = size(paths, 1);
			paths_to_remove = [];
			
			for path_num = 1: path_count
				path = paths{path_num};
				last_row = path(end, 1);
				last_col = path(end, 2);
				last_point = path(end, :);
				
				next_points = get_neighbors(last_point, [rows, cols], size(image), 8);
				indices_to_remove = [];
				for i = 1 : size(next_points, 1)
					match_array = min(path == next_points(i,:), [], 2);
					if ~isempty(find(match_array))
						indices_to_remove = [indices_to_remove, i];
					end
				end
				
				if ~isempty(indices_to_remove)
					next_points(indices_to_remove, :) = [];
				end
				
				if ~isempty(next_points)
					
					if size(next_points, 1) > 1
						%disp('branching');
						% create a new braching path for every alternative
						% route
						for i = 2 : size(next_points, 1)
							new_path = [path; next_points(i,:)];
							paths{length(paths) + 1} = new_path;
						end
						fprintf('1. path count: %i\n', length(paths));
					end
					% add the first neighbor to the current path
					path = [path; next_points(1,:)];
					paths{path_num} = path;
					
					paths = remove_shorter_paths(paths, path_num, 8);
					
				else
					% Remove path. If the path is closed, add it to the list
					paths_to_remove = [paths_to_remove, path_num];
					%disp(['removing path of length ', num2str(length(paths{path_num}))]);
					
					%path_test_image = zeros(size(image));
					%path_test_image(sub2ind(size(image), path(:,1), path(:,2))) = 1;
					%figure; imshow(path_test_image);
					
					adj_points = get_neighbors(last_point, [rows, cols], size(image), 8);
					match_array = min(adj_points == path(1, :), [], 2);
					if max(match_array(:)) > 0
						%disp('adding a closed path');
						closed_paths{size(closed_paths, 1) + 1} = path;
					end
				end
			end
			
			if ~isempty(paths_to_remove)
				paths(paths_to_remove) = [];
				fprintf('2. path count: %i\n', length(paths));
			end
		end
				
		% choose the longest closed path
		if ~isempty(closed_paths)
			path_lengths = cellfun(@numel, closed_paths);
			max_path_length = max(path_lengths(:));
			longest_path = closed_paths{find(path_lengths == max_path_length)};
			final_paths{obj_num} = longest_path;
		end
	end
end

%% remove empty paths and paths with less than 3 points
final_paths(cellfun(@(x) length(x) <= 2, final_paths)) = [];
%% sort paths in the descending order based on the area they enclose
[final_paths, path_colors, paths_inner_pixels] = sort_paths(final_paths, image);

%% smooth polygons
sigma = 3;
sz = 20;    % length of gaussFilter vector
x = linspace(-sz / 2, sz / 2, sz);
gaussFilter = exp(-x .^ 2 / (2 * sigma ^ 2));
gaussFilter = gaussFilter / sum (gaussFilter); % normalize
gaussFilter = gaussFilter(:);

path_test_image = zeros(size(image));
final_overlay = zeros([size(image) 3]);
final_overlay(:,:,1) = image_border;

smoothed_final_paths = cell(size(final_paths));
final_paths_for_removal = [];

for i = 1 : length(final_paths)
	path = final_paths{i};
	smoothed_path = imfilter(path, gaussFilter, 'circular');
	%smoothed_path = path;
	% for short paths decrease sampling distance to have at least 3 points
	% in the path
	curr_smapling_dist = max(1, min(floor(size(smoothed_path, 1)/3), sampling_dist));
	
	smoothed_path = smoothed_path(1:curr_smapling_dist:end, :);
	
	% convert row/col to x/y. Gladly, in microscope (0,0) is in the top left corner
	% also, adjust the scale
	smoothed_final_path = [smoothed_path(:,2)*area_size_x/max_image_size, smoothed_path(:, 1)*area_size_y/max_image_size];
	smoothed_final_paths{i} = smoothed_final_path;
	path_test_image(sub2ind(size(image), round(smoothed_path(:,1)), round(smoothed_path(:,2)))) = 1;
end

final_overlay(:,:,2) = path_test_image;
figure; imshow(final_overlay);

%% generate multiphoton file pieces for each path
roi_text_1 = [];
% header and the first 2 shapes don't need to be modified
roi_text_1 = [roi_text_1, generate_shape_config_text(header)];
roi_text_1 = [roi_text_1, generate_shape_config_text(ref_square_1_part_1)];
roi_text_1 = [roi_text_1, generate_shape_config_text(ref_square_2_part_1)];

shape_number = 2;
for i = 1 : length(final_paths)
	path = smoothed_final_paths{i};
	shape_number = shape_number + 1;
	name_1 = [num2str(shape_number), 'S'];
	text_1 = generate_shape_config_text(poly_template_part_1, 'Name', name_1, 'ID', name_1, 'LASERPOWER', 100*path_colors(i), 'SHAPE', 8, 'X', path(:, 1), 'Y', path(:,2));
	roi_text_1 = [roi_text_1, text_1];
end

%% second piece of text for the ROIs
roi_text_2 = [];
shape_number = shape_number + 1;
name = num2str(shape_number);
roi_text_2 = [roi_text_2, generate_shape_config_text(ref_square_1_part_2, 'Name', name, 'ID', name)];
shape_number = shape_number + 1;
name = num2str(shape_number);
roi_text_2 = [roi_text_2, generate_shape_config_text(ref_square_2_part_2, 'Name', name, 'ID', name)];

for i = 1 : length(final_paths)
	path = smoothed_final_paths{i};
	if size(path, 1) > 0
		shape_number = shape_number + 1;
		name_2 = num2str(shape_number);
		text_2 = generate_shape_config_text(poly_template_part_2, 'Name', name_2, 'ID', name_2, 'LASERPOWER', 100*path_colors(i), 'SHAPE', 8, 'X', path(:, 1), 'Y', path(:,2));
		roi_text_2 = [roi_text_2, text_2];
	end
end

%% Create file for results
filename_index = 0;
final_file_name = file_name;
while(exist([path_name final_file_name], 'file') == 2)
	filename_index = filename_index + 1;
	final_file_name = [file_name(1:end-4), '_', num2str(filename_index), '.roi'];
end

fileID = fopen([path_name, final_file_name], 'a');
fprintf(fileID, roi_text_1);
fprintf(fileID, roi_text_2);
fclose(fileID);

%% draw the final path the way it should be seen in multiphoton software
% to draw correctly, need to transpose the image to convert (x,y) to (row,col)
image_to_show = zeros([area_size_y, area_size_x, 3]);
background = imresize(image_border, max(area_size_x, area_size_y)/max_image_size);
%background = zeros(area_size_y, area_size_x);
shape_layer = zeros(area_size_y, area_size_x);
for i = 1 : length(smoothed_final_paths)
	path = smoothed_final_paths{i};
	path = round(path);
	path = [path(:,2), path(:,1)];
	
	curr_shape = draw_path(path, 'fill', true);
	dim = size(curr_shape);
	
	shape_image = curr_shape(:,:,2);
	%inner_indices = get_closed_shape_inner_pixels(shape_image);
	%[inner_rows, inner_cols] = ind2sub(size(shape_image), inner_indices);
	%new_inner_indices = sub2ind(size(shape_layer), inner_rows, inner_cols);
	%shape_layer(new_inner_indices) = path_colors(i);
	shape_layer(1:dim(1), 1:dim(2)) = shape_layer(1:dim(1), 1:dim(2)) | curr_shape(:,:,2);
	
	image_to_show(1:dim(1), 1:dim(2), 3) = image_to_show(1:dim(1), 1:dim(2), 3) | curr_shape(:,:,3);
end

image_to_show(:,:,2) = shape_layer;
figure; imshow(image_to_show);
