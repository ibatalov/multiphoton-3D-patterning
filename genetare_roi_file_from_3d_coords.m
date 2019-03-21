% size of the scan field in microscope.
area_size_x = 1023;
area_size_y = 1023;
laser_power = 100;
slice_distance_um = 1.2;
final_size_xy_px = 300;
crop_size = 1023;
px_per_um = 1;
final_file_number = '257521376-404738494';

inputTitles = {'file number', 'total image size (px)', 'max object size (px)', 'slice spacing (um)'};
defaultInputValues = {final_file_number, num2str(crop_size), num2str(final_size_xy_px), num2str(slice_distance_um)};

input_params = inputdlg(inputTitles,'Tell me things', [1, 50], defaultInputValues);
final_file_number = input_params{1};
crop_size = str2double(input_params{2});
final_size_xy_px = str2double(input_params{3});
final_size_xy_um = final_size_xy_px / px_per_um;
slice_distance_um = str2double(input_params{4});

%% open the original roi file
file_name1 = 's_261714864-527330';
file_name2 = '.roi';
fileID1 = fopen([file_name1, file_name2],'rt', 'n', 'unicode');
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

%% load 3D coordinates from a file
disp('loading 3D coordiantes...');
if ~exist('def_path', 'var')
	def_path = '/Users/ivan/Desktop';
end
[model_name, model_path] = uigetfile({'*.*'}, 'Open the 3D model (obj file).', def_path);
if ~isempty(model_path)
	def_path = model_path;
end

t0 = clock;
obj = load_3d_coords([model_path, model_name]);
fprintf('3D coordinates are loaded in %i sec! Now processing...\n', round(etime(clock,t0)));
t0 = clock;
triangle_nums = obj.f.v;
triangle_coords = zeros(size(triangle_nums, 1)*3, 3);
for row = 1 : size(triangle_nums, 1)
	for col = 1 : size(triangle_nums, 2)
		triangle_coords(3*(row-1) + col, :) = obj.v(triangle_nums(row, col), :);
	end
end
fprintf('3D coordinates are processed in %i msec!\n', round(1000*etime(clock,t0)));

model_fileID = fopen([model_path, model_name]);
model_text = textscan(model_fileID, '%s', 'delimiter', newline);
model_text = model_text{1};
vertex_text = model_text(cellfun(@(x) (x(1) == 'v'), model_text));
vertex_coords = cellfun(@(x) textscan(x(2:end), '%f'), vertex_text);
vertex_coords = cell2mat(cellfun(@(x) x.', vertex_coords, 'UniformOutput', false));

face_text = model_text(cellfun(@(x) (x(1) == 'f'), model_text));

%% slice 3D model, generating polygons for each slice
disp('slicing the model...');
image_size = [1024, 1024];
center = (max(obj.v(:,1:2), [], 1) + min(obj.v(:,1:2), [], 1))/2;
center = center(:);
model_size = max(obj.v, [], 1) - min(obj.v, [], 1);
size_xy = max(model_size(1:2), [], 2);

range = [center - 1.2*size_xy/2, center + 1.2*size_xy/2];
slice_distance = slice_distance_um * (size_xy/final_size_xy_um);
[slice_paths, path_colors] = slice_3d_model_into_polygons(triangle_coords, slice_distance, 'imagesize', image_size./4, 'range', range);
disp('model is sliced!');

%% draw slices, one by one
slice_movie = zeros([image_size, 3, length(slice_paths)]);
for slice_num = 1 : length(slice_paths)
	paths = slice_paths{slice_num};
	if ~isempty(paths)
		slice = zeros([image_size, 3]);
		for path_num = 1 : length(paths)
			[shape_image, converted_polygon] = draw_path(paths{path_num}, 'pixelsize', image_size, 'range', range, 'fill', false);
			slice = slice | shape_image;
			inner_px = get_closed_shape_inner_pixels(shape_image(:,:,2), converted_polygon);
			if ~isempty(inner_px)
				inner_px = inner_px + image_size(1)*image_size(2); % shift linear indices  so they correspond to the second channel
				slice(inner_px) = path_colors{slice_num}(path_num);
			end
		end
		slice_movie(:,:,:,slice_num) = slice;
	end
end
implay(slice_movie);

% save video
[v_name v_path] = uiputfile({'*.avi'}, 'Save video file', [def_path 'slice_video.avi']);
v = VideoWriter([v_path v_name]);
v.FrameRate = 24;
open(v);
writeVideo(v, slice_movie);
close(v);

%% convert path coordiante range into image's pixel range [1 : imagesize]

%coord_range = [min(triangle_coords(:,1)), max(triangle_coords(:,1)); min(triangle_coords(:,2)), max(triangle_coords(:,2))];
%coord_range = coord_range + [-1, 1; -1, 1] * size_xy*(crop_size - final_size_xy_px)/final_size_xy_px/2; % expand the range

coord_range = [0, area_size_x; 0, area_size_y];

new_slice_paths = cell(size(slice_paths));
for slice_num = 1 : length(slice_paths)
	paths = slice_paths{slice_num};
	if ~isempty(paths)
		for path_num = 1 : length(paths)
			path = paths{path_num};
			path_x = (path(:,1) - coord_range(1,1))/(coord_range(1,2) - coord_range(1,1))*(crop_size);
			path_y = crop_size - (path(:,2) - coord_range(2,1))/(coord_range(2,2) - coord_range(2,1))*(crop_size);
			paths{path_num} = [path_x, path_y];
		end
		new_slice_paths{slice_num} = paths;
	end
end

disp('generating roi files...');
for slice_num = 1 : length(new_slice_paths)
	paths = new_slice_paths{slice_num};
	%% generate multiphoton file pieces for each path
	roi_text_1 = [];
	% header and the first 2 shapes don't need to be modified 
	% (except the file name now)
	roi_text_1 = [roi_text_1, generate_shape_config_text(header, 'Name', final_file_number)];
	roi_text_1 = [roi_text_1, generate_shape_config_text(ref_square_1_part_1)];
	
	if crop_size ~= area_size_x
		roi_text_1 = [roi_text_1, generate_shape_config_text(ref_square_2_part_1, 'X', [crop_size-5; crop_size-1], 'Y', [crop_size-5; crop_size-1])];
	else
		roi_text_1 = [roi_text_1, generate_shape_config_text(ref_square_2_part_1)];
	end
	
	shape_number = 2;
	for i = 1 : length(paths)
		path = paths{i};
		shape_number = shape_number + 1;
		name_1 = [num2str(shape_number), 'S'];
		text_1 = generate_shape_config_text(poly_template_part_1, 'Name', name_1, 'ID', name_1, 'LASERPOWER', 100*path_colors{slice_num}(i), 'SHAPE', 8, 'X', path(:, 1), 'Y', path(:,2));
		roi_text_1 = [roi_text_1, text_1];
	end
	
	%% second piece of text for the ROIs
	roi_text_2 = [];
	shape_number = shape_number + 1;
	name = num2str(shape_number);
	roi_text_2 = [roi_text_2, generate_shape_config_text(ref_square_1_part_2, 'Name', name, 'ID', name)];
	shape_number = shape_number + 1;
	name = num2str(shape_number);
	
	if crop_size ~= area_size_x
		roi_text_2 = [roi_text_2, generate_shape_config_text(ref_square_2_part_2, 'Name', name, 'ID', name, 'X', [crop_size-5; crop_size-1], 'Y', [crop_size-5; crop_size-1])];
	else
		roi_text_2 = [roi_text_2, generate_shape_config_text(ref_square_2_part_2, 'Name', name, 'ID', name)];
	end
	
	for i = 1 : length(paths)
		path = paths{i};
		shape_number = shape_number + 1;
		name_2 = num2str(shape_number);
		text_2 = generate_shape_config_text(poly_template_part_2, 'Name', name_2, 'ID', name_2, 'LASERPOWER', 100*path_colors{slice_num}(i), 'SHAPE', 8, 'X', path(:, 1), 'Y', path(:,2));
		roi_text_2 = [roi_text_2, text_2];
	end
	
	%% Create file for results
	if slice_num == 1
		if ~exist([model_path model_name(1:end-4) '_roi_files/'], 'dir')
			path_name = [model_path model_name(1:end-4) '_roi_files/'];
		else
			folder_index = 1;
			path_name = sprintf([model_path model_name(1:end-4) '_roi_files_%i/'], folder_index);
			while exist(path_name, 'dir')
				folder_index = folder_index + 1;
				path_name = sprintf([model_path model_name(1:end-4) '_roi_files_%i/'], folder_index);
			end
		end
		mkdir(path_name);
	end
	file_name = sprintf(['s_' final_file_number '_s_%i' file_name2], slice_num);
	
	fileID = fopen([path_name, file_name], 'w');
	fprintf(fileID, roi_text_1);
	fprintf(fileID, roi_text_2);
	fclose(fileID);
	fprintf('roi file for slice %i generated!\n', slice_num);
end
disp('all roi files generated!');