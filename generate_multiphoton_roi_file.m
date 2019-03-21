% size of the scan field in microscope.
area_size_x = 1024;
area_size_y = 1024;
laser_power = 100;
sampling_dist = 2; % how many points to skip in the path

%% open the original roi file
file_name = 's_261714864-527330.roi';
fileID1 = fopen(file_name,'r', 'n', 'unicode');
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

%%%%%%%%%%%%%%%%%%%%
% for windows
%poly_template_part_2 = poly_template_part_2(1:end-1);
%%%%%%%%%%%%%%%%%%%%

%% open the image, convert to border image
[pic_name, pic_path] = uigetfile({'*.*'; '*.bmp'; '*.png'; '*.tif'; '*.tiff'; '*.jpg'; '*.jpeg'}, 'Open the binary image');
path_name = pic_path;

% re-run starting from this line if need to readjust image processing
% parameters
image = imread([pic_path, pic_name]);
%image = imresize(image, [2048, 2048]);
image = image/max(image(:));
image = image > 0.5;
image = image(:,:,1);

%% IMAGE PROCESSING TOOLS. USE AS NEEDED.
% showing the image before processing
figure; imshow(image);

% imvert image
image = image == 0;

%% closing holes up to the size dilate_dist*2
dilate_dist = 2;
disk = strel('disk', dilate_dist);
image = imdilate(image, disk);
image = imerode(image, disk);

image = imerode(image, disk);
image = imdilate(image, disk);

% shrinking the shapes by shrink_dist
shrink_dist = 1;
shrink_disk = strel('disk', shrink_dist);
image = imerode(image, shrink_disk); % change imerode to imdilate to expand the shapes

% showing the image after the processing
figure; imshow(image);

%% find image border
image_size_x = size(image, 2);
image_size_y = size(image, 1);
max_image_size = max(image_size_x, image_size_y);
% 
% image_border = bwmorph(image, 'remove');
% endpoints = bwmorph(image_border, 'endpoints');
% while(nnz(endpoints) > 0)
% 	image_border = image_border .* ~endpoints;
% 	endpoints = bwmorph(image_border, 'endpoints');
% end
% image_border = bwmorph(image_border, 'skel');
% imshow(image_border);

%% trace the borders with polygons
%opening_strings = []; % contains "absolute" (uncropped) coordinates

traced_border_paths = trace_binary(image);

final_paths = cell(length(traced_border_paths),1);
image_border = zeros(size(image));

for i = 1 : length(traced_border_paths)
	path = traced_border_paths{i};
	path = path(:,1:2);
	temp = [path(2:end,:); path(1,:)];
	repeats = find(max(abs(temp - path), [], 2));
	path = path(repeats,:);
	final_paths{i} = path(:,1:2);
	image_border(sub2ind(size(image), path(:,1), path(:,2))) = 1;
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
	smoothed_final_path = [(smoothed_path(:,2) - 1)*(area_size_x-1)/(max_image_size-1), (smoothed_path(:, 1) - 1)*(area_size_y-1)/(max_image_size-1)];
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
image_dims = size(shape_layer);
for i = 1 : length(smoothed_final_paths)
	path = smoothed_final_paths{i};
	path = round(path);
	path = [path(:,2), path(:,1)];
	
    range = [1, area_size_x; 1, area_size_y]; %+ [-1, 1; -1, 1]*padding;
	[curr_shape, converted_polygon] = draw_path(path+1, 'fill', false, 'range', range, 'fill_color', path_colors(i));
    dim = size(curr_shape);
    inner_px = get_closed_shape_inner_pixels(curr_shape(:,:,2), converted_polygon);
    
    if ~isempty(inner_px)
        %inner_px = inner_px + image_dims(1)*image_dims(2); % shift linear indices  so they correspond to the second channel
        shape_layer(inner_px) = path_colors(i);
		%shape_layer(inner_px) = 1;
    end
    
	%shape_image = curr_shape(:,:,2);
	%inner_indices = get_closed_shape_inner_pixels(shape_image);
	%[inner_rows, inner_cols] = ind2sub(size(shape_image), inner_indices);
	%new_inner_indices = sub2ind(size(shape_layer), inner_rows, inner_cols);
	%shape_layer(new_inner_indices) = path_colors(i);
	%shape_layer(1:dim(1), 1:dim(2)) = shape_layer(1:dim(1), 1:dim(2)) | curr_shape(:,:,2);
	
	image_to_show(1:dim(1), 1:dim(2), 3) = image_to_show(1:dim(1), 1:dim(2), 3) | curr_shape(:,:,3);
end

image_to_show(:,:,2) = shape_layer;
figure; imshow(image_to_show);
